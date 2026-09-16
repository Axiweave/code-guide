;;; code-guide.el --- Agent-authored code-reading guides  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Yu-Fu Fu

;; Author: Yu-Fu Fu <yufu@yfu.tw>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, convenience
;; URL: https://github.com/Axiweave/code-guide

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A guide is a `.codeguide.json' file: a tree of nodes, each pointing at
;; a source location and explaining why it matters.  An agent writes the
;; guide, Emacs renders it as a read-only tree.  `RET' visits a node,
;; `SPC' previews it while keeping the guide window selected, `n'/`p'
;; walk the tree in reading order, `TAB' folds a subtree, `g' reloads
;; after the agent rewrites the file, and `v' validates every location.
;;
;; The parsed object model is the source of truth.  Rendered text carries
;; the node in the `code-guide-node' text property.  Never recover the
;; structure from indentation.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'pulse)
(require 'project)
(require 'compile)

(declare-function evil-define-key "evil-core"
                  (state keymap key def &rest bindings))
(declare-function evil-set-initial-state "evil-core" (mode state))

;;;; Customization

(defgroup code-guide nil
  "Agent-authored code-reading guides."
  :group 'tools
  :prefix "code-guide-")

(defcustom code-guide-display-buffer-action
  '((display-buffer-reuse-window display-buffer-use-some-window
     display-buffer-pop-up-window)
    (inhibit-same-window . t))
  "Display action used to show a node's source buffer.
See `display-buffer' for the format.  The guide window itself is never
reused, so a preview in a one-window frame splits instead of replacing
the guide."
  :type 'sexp)

(defcustom code-guide-protected-buffer-name-patterns nil
  "Regexps matching buffer names that source display must not replace."
  :type '(repeat regexp))

(defcustom code-guide-protected-buffer-predicate nil
  "Optional function called with a buffer.
A non-nil result prevents source display from replacing that buffer's
visible windows."
  :type '(choice (const :tag "None" nil) function))

(defcustom code-guide-guide-display-buffer-action nil
  "Display action used to show a guide buffer.
See `display-buffer' for the format.  Nil preserves the default
`pop-to-buffer' behavior."
  :type 'sexp)

(defcustom code-guide-show-comments t
  "When non-nil, render each node's comment under its heading."
  :type 'boolean)

(defcustom code-guide-anchor-search-range 80
  "Lines above and below the recorded line to search for a node's anchor."
  :type 'integer)

(defcustom code-guide-allow-outside-root nil
  "When non-nil, a location may point outside the guide root."
  :type 'boolean)

(defcustom code-guide-location-column 44
  "Column at which the `file:line' of a heading starts."
  :type 'integer)

(defcustom code-guide-project-guide-globs
  '(".code-guides/*.codeguide.json"
    ".codeguide.json"
    "docs/code-guides/*.codeguide.json")
  "Globs under the project root that `code-guide-open-project-guide' searches."
  :type '(repeat string))

(defface code-guide-title-face
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for a node title.")

(defface code-guide-visited-face
  '((t :inherit shadow))
  "Face for the title of a node that has been visited.")

(defface code-guide-location-face
  '((t :inherit font-lock-comment-face))
  "Face for a node's `file:line'.")

(defface code-guide-comment-face
  '((t :inherit default))
  "Face for a node comment.")

(defface code-guide-marker-face
  '((t :inherit font-lock-keyword-face))
  "Face for the tree marker in front of a node.")

;;;; Data model

(cl-defstruct code-guide-location
  file line column symbol anchor)

(cl-defstruct code-guide-node
  id title comment location children parent depth)

(cl-defstruct code-guide-document
  version title description root nodes source-file)

(defvar-local code-guide--document nil
  "The document rendered in this guide buffer.")

(defvar-local code-guide--nodes nil
  "Depth-first list of every node in `code-guide--document'.")

(defvar-local code-guide--folded nil
  "Hash table of node ids whose subtree is folded.")

(defvar-local code-guide--visited nil
  "Hash table of node ids that were visited in this session.")

;;;; Parsing

(define-error 'code-guide-parse-error "Code guide parse error")

(defun code-guide--fail (format &rest args)
  "Signal a `code-guide-parse-error' with FORMAT and ARGS."
  (signal 'code-guide-parse-error (list (apply #'format format args))))

(defun code-guide--get (alist key &optional type)
  "Return KEY from ALIST, checking TYPE when given."
  (let ((value (alist-get key alist)))
    (when (and value type (not (funcall type value)))
      (code-guide--fail "%s: expected %s, got %S" key type value))
    value))

(defun code-guide--parse-location (alist node-id)
  "Build a `code-guide-location' from ALIST for NODE-ID."
  (unless (listp alist)
    (code-guide--fail "node %s: location must be an object" node-id))
  (let ((file (code-guide--get alist 'file #'stringp))
        (line (code-guide--get alist 'line #'integerp))
        (column (code-guide--get alist 'column #'integerp))
        (symbol (code-guide--get alist 'symbol #'stringp))
        (anchor (code-guide--get alist 'anchor #'stringp)))
    (unless (and file (> (length file) 0))
      (code-guide--fail "node %s: location needs a file" node-id))
    (unless line
      (code-guide--fail "node %s: location needs a line" node-id))
    ;; An empty anchor would match everywhere and never advance the search.
    (when (equal anchor "")
      (code-guide--fail "node %s: anchor must not be empty" node-id))
    (when (equal symbol "")
      (code-guide--fail "node %s: symbol must not be empty" node-id))
    (make-code-guide-location
     :file file :line line :column column :symbol symbol :anchor anchor)))

(defun code-guide--parse-node (alist parent depth seen)
  "Build a `code-guide-node' from ALIST under PARENT at DEPTH.
SEEN is a hash table used to reject duplicate ids."
  (unless (listp alist)
    (code-guide--fail "node must be an object, got %S" alist))
  (let ((id (code-guide--get alist 'id #'stringp))
        (title (code-guide--get alist 'title #'stringp))
        (children (alist-get 'children alist)))
    (unless (and id (> (length id) 0))
      (code-guide--fail "node without id: %S" alist))
    (when (gethash id seen)
      (code-guide--fail "duplicate node id: %s" id))
    (puthash id t seen)
    (unless (and title (> (length title) 0))
      (code-guide--fail "node %s: title is required" id))
    (unless (listp children)
      (code-guide--fail "node %s: children must be a list" id))
    (let* ((location (alist-get 'location alist))
           (node (make-code-guide-node
                  :id id :title title
                  :comment (code-guide--get alist 'comment #'stringp)
                  :location (and location
                                 (code-guide--parse-location location id))
                  :parent parent :depth depth)))
      (setf (code-guide-node-children node)
            (mapcar (lambda (child)
                      (code-guide--parse-node child node (1+ depth) seen))
                    children))
      node)))

(defun code-guide-parse-string (string &optional source-file)
  "Parse STRING as a guide document.  SOURCE-FILE records its origin."
  (let ((alist (condition-case err
                   (json-parse-string string :object-type 'alist
                                      :array-type 'list
                                      :null-object nil :false-object nil)
                 (json-parse-error
                  (code-guide--fail "invalid JSON: %s" (error-message-string err))))))
    (unless (listp alist)
      (code-guide--fail "top level must be an object"))
    (let ((version (code-guide--get alist 'version #'integerp))
          (title (code-guide--get alist 'title #'stringp))
          (nodes (alist-get 'nodes alist)))
      (unless (eql version 1)
        (code-guide--fail "unsupported version %S (only 1)" version))
      (unless (and title (> (length title) 0))
        (code-guide--fail "title is required"))
      (unless (listp nodes)
        (code-guide--fail "nodes must be a list"))
      (let ((seen (make-hash-table :test #'equal)))
        (make-code-guide-document
         :version version :title title
         :description (code-guide--get alist 'description #'stringp)
         :root (or (code-guide--get alist 'root #'stringp) ".")
         :nodes (mapcar (lambda (node) (code-guide--parse-node node nil 0 seen))
                        nodes)
         :source-file source-file)))))

(defun code-guide-parse-file (file)
  "Parse FILE as a guide document."
  (with-temp-buffer
    (insert-file-contents file)
    (code-guide-parse-string (buffer-string) (expand-file-name file))))

(defun code-guide--flatten (nodes)
  "Return NODES and all their descendants in depth-first order."
  (mapcan (lambda (node)
            (cons node (code-guide--flatten (code-guide-node-children node))))
          nodes))

;;;; Root and location resolution

(defun code-guide-document-root-directory (document)
  "Return DOCUMENT's resolved root directory, with a trailing slash."
  (let ((base (if (code-guide-document-source-file document)
                  (file-name-directory (code-guide-document-source-file document))
                default-directory)))
    (file-name-as-directory
     (expand-file-name (code-guide-document-root document) base))))

(defun code-guide-resolve-file (document location)
  "Return the absolute path of LOCATION's file under DOCUMENT's root."
  (expand-file-name (code-guide-location-file location)
                    (code-guide-document-root-directory document)))

(defun code-guide--inside-root-p (document file)
  "Return non-nil when FILE lies under DOCUMENT's root."
  (file-in-directory-p file (code-guide-document-root-directory document)))

(defun code-guide--find-anchor (anchor line)
  "Return the line nearest LINE where ANCHOR occurs in the current buffer.
Search `code-guide-anchor-search-range' lines around LINE.  Return nil
when ANCHOR does not occur there."
  (save-excursion
    (let* ((range code-guide-anchor-search-range)
           (best nil))
      (goto-char (point-min))
      (forward-line (max 0 (- line 1 range)))
      (let ((limit (save-excursion
                     (forward-line (1+ (* 2 range)))
                     (point))))
        (while (search-forward anchor limit t)
          (let ((found (line-number-at-pos)))
            (when (or (null best)
                      (< (abs (- found line)) (abs (- best line))))
              (setq best found)))))
      best)))

(defun code-guide-location-target-line (location)
  "Return the line to show for LOCATION in the current buffer.
Prefer the nearest anchor match, then the recorded line."
  (let ((line (code-guide-location-line location))
        (anchor (code-guide-location-anchor location)))
    (or (and anchor (code-guide--find-anchor anchor line))
        line)))

(defun code-guide--goto-location (location)
  "Move point in the current buffer to LOCATION."
  (widen)
  (goto-char (point-min))
  (forward-line (1- (code-guide-location-target-line location)))
  (when-let* ((column (code-guide-location-column location)))
    (move-to-column (1- column))))

;;;; Validation

(defun code-guide--line-count (file)
  "Return the number of lines in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (count-lines (point-min) (point-max))))

(defun code-guide-validate-document (document)
  "Return a list of diagnostics for DOCUMENT.
Each diagnostic is (SEVERITY FILE LINE MESSAGE) where SEVERITY is
`error' or `warning' and FILE is absolute or nil."
  (let (diagnostics)
    (dolist (node (code-guide--flatten (code-guide-document-nodes document)))
      (when-let* ((location (code-guide-node-location node)))
        (let* ((id (code-guide-node-id node))
               (file (code-guide-resolve-file document location))
               (line (code-guide-location-line location))
               (column (code-guide-location-column location))
               (anchor (code-guide-location-anchor location))
               (push-diag (lambda (severity message)
                            (push (list severity file line
                                        (format "node %s: %s" id message))
                                  diagnostics))))
          (cond
           ((and (not code-guide-allow-outside-root)
                 (not (code-guide--inside-root-p document file)))
            (funcall push-diag 'error "file is outside the guide root"))
           ((not (file-readable-p file))
            (funcall push-diag 'error "file does not exist"))
           (t
            (when (< line 1)
              (funcall push-diag 'error "line must be >= 1"))
            (when (and column (< column 1))
              (funcall push-diag 'error "column must be >= 1"))
            (let ((count (code-guide--line-count file)))
              (when (> line count)
                (funcall push-diag 'error
                         (format "line outside file (%d lines)" count))))
            (when anchor
              (with-temp-buffer
                (insert-file-contents file)
                (unless (code-guide--find-anchor anchor line)
                  (funcall push-diag 'warning "anchor not found near line")))))))))
    (nreverse diagnostics)))

(defun code-guide--show-diagnostics (document diagnostics)
  "Show DIAGNOSTICS for DOCUMENT in a `compilation-mode' buffer."
  (let ((buffer (get-buffer-create "*Code Guide Validation*"))
        (root (code-guide-document-root-directory document))
        (source (or (code-guide-document-source-file document) "guide")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq default-directory root)
        (insert (format "Validation of %s\n\n" source))
        (dolist (diag diagnostics)
          (pcase-let ((`(,severity ,file ,line ,message) diag))
            (insert (format "%s:%d: %s%s\n"
                            (file-relative-name (or file source) root)
                            (or line 1)
                            (if (eq severity 'warning) "warning: " "")
                            message))))
        (insert (format "\n%d problem(s)\n" (length diagnostics))))
      (compilation-mode)
      (goto-char (point-min)))
    (display-buffer buffer)))

;;;; Rendering

(defun code-guide--node-visible-p (node)
  "Return non-nil when no ancestor of NODE is folded."
  (let ((parent (code-guide-node-parent node)))
    (or (null parent)
        (and (not (gethash (code-guide-node-id parent) code-guide--folded))
             (code-guide--node-visible-p parent)))))

(defun code-guide--marker (node)
  "Return the tree marker string for NODE."
  (cond
   ((null (code-guide-node-children node))
    (if (code-guide-node-location node) "●" "○"))
   ((gethash (code-guide-node-id node) code-guide--folded) "▸")
   (t "▾")))

(defun code-guide--insert-node (node)
  "Insert NODE's heading and comment at point."
  (let* ((indent (make-string (* 2 (code-guide-node-depth node)) ?\s))
         (location (code-guide-node-location node))
         (start (point))
         (visited (gethash (code-guide-node-id node) code-guide--visited)))
    (insert indent
            (propertize (code-guide--marker node) 'face 'code-guide-marker-face)
            " "
            (propertize (code-guide-node-title node)
                        'face (if visited
                                  'code-guide-visited-face
                                'code-guide-title-face)))
    (when location
      (indent-to (max (1+ (current-column)) code-guide-location-column))
      (insert (propertize (format "%s:%d"
                                  (code-guide-location-file location)
                                  (code-guide-location-line location))
                          'face 'code-guide-location-face)))
    (insert "\n")
    (when (and code-guide-show-comments (code-guide-node-comment node))
      (let ((prefix (concat indent "    ")))
        (insert (propertize (concat prefix (code-guide-node-comment node) "\n")
                            'face 'code-guide-comment-face
                            'wrap-prefix prefix))))
    (add-text-properties start (point)
                         (list 'code-guide-node node
                               'code-guide-node-id (code-guide-node-id node)))))

(defun code-guide--render ()
  "Render `code-guide--document' into the current buffer."
  (let ((inhibit-read-only t)
        (document code-guide--document))
    (erase-buffer)
    (insert (propertize (code-guide-document-title document)
                        'face '(:inherit code-guide-title-face :height 1.2))
            "\n")
    (when (code-guide-document-description document)
      (insert (propertize (code-guide-document-description document)
                          'face 'code-guide-comment-face)
              "\n"))
    (insert "\n")
    (dolist (node code-guide--nodes)
      (when (code-guide--node-visible-p node)
        (code-guide--insert-node node)))
    (set-buffer-modified-p nil)))

(defun code-guide--node-position (node)
  "Return the buffer position of NODE's heading, or nil when folded away."
  (let ((id (code-guide-node-id node))
        (pos (point-min))
        found)
    (while (and (not found) pos)
      (when (equal (get-text-property pos 'code-guide-node-id) id)
        (setq found pos))
      (setq pos (next-single-property-change pos 'code-guide-node-id)))
    found))

(defun code-guide--goto-node (node)
  "Move point to NODE's heading, unfolding ancestors when needed."
  (let ((parent (code-guide-node-parent node))
        unfolded)
    (while parent
      (when (gethash (code-guide-node-id parent) code-guide--folded)
        (remhash (code-guide-node-id parent) code-guide--folded)
        (setq unfolded t))
      (setq parent (code-guide-node-parent parent)))
    (when unfolded (code-guide--render))
    (when-let* ((pos (code-guide--node-position node)))
      (goto-char pos)
      (skip-chars-forward " ")
      t)))

(defun code-guide-current-node ()
  "Return the node at point, or nil."
  (get-text-property (point) 'code-guide-node))

(defun code-guide--current-node-or-error ()
  "Return the node at point or signal a `user-error'."
  (or (code-guide-current-node)
      (user-error "No guide node at point")))

;;;; Navigation

(defun code-guide--move (step)
  "Move STEP nodes in depth-first reading order among visible nodes."
  (let* ((visible (cl-remove-if-not #'code-guide--node-visible-p code-guide--nodes))
         (current (code-guide-current-node))
         (index (if current (cl-position current visible) -1))
         (target (nth (+ index step) visible)))
    (unless (and target (>= (+ index step) 0))
      (user-error "No %s node" (if (> step 0) "next" "previous")))
    (code-guide--goto-node target)))

(defun code-guide-next-node ()
  "Move to the next node in reading order."
  (interactive)
  (code-guide--move 1))

(defun code-guide-previous-node ()
  "Move to the previous node in reading order."
  (interactive)
  (code-guide--move -1))

(defun code-guide--siblings (node)
  "Return the sibling list containing NODE."
  (if-let* ((parent (code-guide-node-parent node)))
      (code-guide-node-children parent)
    (code-guide-document-nodes code-guide--document)))

(defun code-guide--move-sibling (step)
  "Move STEP siblings from the node at point."
  (let* ((node (code-guide--current-node-or-error))
         (siblings (code-guide--siblings node))
         (index (+ step (cl-position node siblings))))
    (unless (and (>= index 0) (< index (length siblings)))
      (user-error "No %s sibling" (if (> step 0) "next" "previous")))
    (code-guide--goto-node (nth index siblings))))

(defun code-guide-next-sibling ()
  "Move to the next sibling node."
  (interactive)
  (code-guide--move-sibling 1))

(defun code-guide-previous-sibling ()
  "Move to the previous sibling node."
  (interactive)
  (code-guide--move-sibling -1))

(defun code-guide-parent ()
  "Move to the parent node."
  (interactive)
  (let ((parent (code-guide-node-parent (code-guide--current-node-or-error))))
    (unless parent (user-error "No parent node"))
    (code-guide--goto-node parent)))

(defun code-guide-first-child ()
  "Move to the first child node, unfolding when needed."
  (interactive)
  (let ((child (car (code-guide-node-children (code-guide--current-node-or-error)))))
    (unless child (user-error "No child node"))
    (code-guide--goto-node child)))

;;;; Folding

(defun code-guide-toggle-subtree ()
  "Fold or unfold the subtree under the node at point."
  (interactive)
  (let ((node (code-guide--current-node-or-error)))
    (unless (code-guide-node-children node)
      (user-error "Node has no children"))
    (let ((id (code-guide-node-id node)))
      (if (gethash id code-guide--folded)
          (remhash id code-guide--folded)
        (puthash id t code-guide--folded))
      (code-guide--render)
      (code-guide--goto-node node))))

(defun code-guide-fold-all ()
  "Fold every node that has children."
  (interactive)
  (let ((node (code-guide-current-node)))
    (dolist (n code-guide--nodes)
      (when (code-guide-node-children n)
        (puthash (code-guide-node-id n) t code-guide--folded)))
    (code-guide--render)
    (when node
      (let ((top node))
        (while (code-guide-node-parent top)
          (setq top (code-guide-node-parent top)))
        (code-guide--goto-node top)))))

(defun code-guide-unfold-all ()
  "Unfold every node."
  (interactive)
  (let ((node (code-guide-current-node)))
    (clrhash code-guide--folded)
    (code-guide--render)
    (when node (code-guide--goto-node node))))

;;;; Visiting

(defun code-guide--protected-buffer-p (buffer)
  "Return non-nil when BUFFER is protected from source display."
  (or (cl-some (lambda (regexp)
                 (string-match-p regexp (buffer-name buffer)))
               code-guide-protected-buffer-name-patterns)
      (and code-guide-protected-buffer-predicate
           (funcall code-guide-protected-buffer-predicate buffer))))

(defun code-guide--excluded-window-snapshot (guide-window)
  "Return state for visible protected windows and GUIDE-WINDOW."
  (let (snapshot)
    (dolist (frame (delete-dups (cons (selected-frame) (visible-frame-list))))
      (dolist (window (window-list frame 'nomini))
        (when (or (eq window guide-window)
                  (code-guide--protected-buffer-p (window-buffer window)))
          (push (list window
                      (window-buffer window)
                      (window-dedicated-p window))
                snapshot))))
    snapshot))

(defun code-guide--validate-protection ()
  "Validate protected-buffer configuration before display."
  (dolist (regexp code-guide-protected-buffer-name-patterns)
    (string-match-p regexp ""))
  (when (and code-guide-protected-buffer-predicate
             (not (functionp code-guide-protected-buffer-predicate)))
    (signal 'wrong-type-argument
            (list 'functionp code-guide-protected-buffer-predicate))))

(defun code-guide--restore-excluded-windows (snapshot &optional final)
  "Restore buffers in SNAPSHOT.
When FINAL is nil, keep each live window temporarily dedicated."
  (dolist (state snapshot)
    (pcase-let ((`(,window ,buffer ,dedicated) state))
      (when (window-live-p window)
        (set-window-dedicated-p window nil)
        (when (and (buffer-live-p buffer)
                   (not (eq (window-buffer window) buffer)))
          (set-window-buffer window buffer))
        (set-window-dedicated-p window (if final dedicated t))))))

(defun code-guide--safe-source-window-p (window snapshot)
  "Return non-nil when WINDOW is live and absent from SNAPSHOT."
  (and (window-live-p window)
       (not (assq window snapshot))))

(defun code-guide--display-source-buffer (buffer guide-window)
  "Display BUFFER without replacing protected windows or GUIDE-WINDOW."
  (code-guide--validate-protection)
  (let ((snapshot (code-guide--excluded-window-snapshot guide-window))
        window)
    (unwind-protect
        (progn
          (dolist (state snapshot)
            (set-window-dedicated-p (car state) t))
          (setq window (display-buffer buffer code-guide-display-buffer-action))
          (code-guide--restore-excluded-windows snapshot)
          (unless (code-guide--safe-source-window-p window snapshot)
            (setq window nil))
          (unless window
            (setq window
                  (or (ignore-errors (split-window guide-window nil 'right))
                      (ignore-errors (split-window guide-window nil 'below))))
            (when window
              (set-window-dedicated-p window nil)
              (set-window-buffer window buffer)))
          (unless window
            (setq window
                  (display-buffer buffer '((display-buffer-pop-up-frame))))
            (code-guide--restore-excluded-windows snapshot)
            (unless (code-guide--safe-source-window-p window snapshot)
              (setq window nil)))
          (or window
              (user-error "No safe window is available for the source")))
      (code-guide--restore-excluded-windows snapshot t))))

(defun code-guide-visit-node (node &optional preview)
  "Show NODE's location.  With PREVIEW, keep the guide window selected.
Return the window showing the source."
  (let ((location (code-guide-node-location node))
        (document code-guide--document))
    (unless location
      (user-error "Node %s has no location" (code-guide-node-id node)))
    (let* ((file (code-guide-resolve-file document location))
           (buffer (or (and (file-readable-p file) (find-file-noselect file))
                       (user-error "File does not exist: %s" file)))
           (guide-buffer (current-buffer))
           (guide-window (get-buffer-window guide-buffer))
           (window (code-guide--display-source-buffer buffer guide-window)))
      (with-selected-window window
        (code-guide--goto-location location)
        (recenter)
        (pulse-momentary-highlight-one-line (point)))
      (puthash (code-guide-node-id node) t code-guide--visited)
      (let ((inhibit-read-only t)
            (pos (code-guide--node-position node)))
        (when pos
          (save-excursion
            (goto-char pos)
            (let ((start (progn (skip-chars-forward " ") (+ (point) 2)))
                  (end (+ (point) 2 (length (code-guide-node-title node)))))
              (put-text-property start end 'face 'code-guide-visited-face)))))
      (unless preview (select-window window))
      window)))

(defun code-guide-visit ()
  "Visit the location of the node at point."
  (interactive)
  (code-guide-visit-node (code-guide--current-node-or-error)))

(defun code-guide-preview ()
  "Show the location of the node at point, keeping the guide selected."
  (interactive)
  (code-guide-visit-node (code-guide--current-node-or-error) t))

(defun code-guide-visit-other-window ()
  "Visit the node at point in another window."
  (interactive)
  (let ((code-guide-display-buffer-action '((display-buffer-pop-up-window))))
    (code-guide-visit)))

;;;; Buffer setup and reload

(defvar-keymap code-guide-mode-map
  :parent special-mode-map
  "RET" #'code-guide-visit
  "o" #'code-guide-visit-other-window
  "SPC" #'code-guide-preview
  "n" #'code-guide-next-node
  "p" #'code-guide-previous-node
  "]" #'code-guide-next-sibling
  "[" #'code-guide-previous-sibling
  "u" #'code-guide-parent
  "d" #'code-guide-first-child
  "TAB" #'code-guide-toggle-subtree
  "<backtab>" #'code-guide-fold-all
  "S-TAB" #'code-guide-fold-all
  "U" #'code-guide-unfold-all
  "g" #'code-guide-reload
  "v" #'code-guide-validate
  "q" #'quit-window)

(define-derived-mode code-guide-mode special-mode "Code-Guide"
  "Major mode for reading a code guide."
  (setq-local truncate-lines nil
              word-wrap t)
  (hl-line-mode 1))

(with-eval-after-load 'evil
  (evil-set-initial-state 'code-guide-mode 'motion)
  (evil-define-key '(normal motion) code-guide-mode-map
    (kbd "RET") #'code-guide-visit
    (kbd "SPC") #'code-guide-preview
    "o" #'code-guide-visit-other-window
    "n" #'code-guide-next-node
    "p" #'code-guide-previous-node
    "]" #'code-guide-next-sibling
    "[" #'code-guide-previous-sibling
    "u" #'code-guide-parent
    "d" #'code-guide-first-child
    (kbd "TAB") #'code-guide-toggle-subtree
    (kbd "S-TAB") #'code-guide-fold-all
    "U" #'code-guide-unfold-all
    "g" #'code-guide-reload
    "v" #'code-guide-validate
    "q" #'quit-window))

(defun code-guide--load (document)
  "Install DOCUMENT in the current guide buffer and render it."
  (setq code-guide--document document
        code-guide--nodes (code-guide--flatten (code-guide-document-nodes document)))
  (unless code-guide--folded
    (setq code-guide--folded (make-hash-table :test #'equal)))
  (unless code-guide--visited
    (setq code-guide--visited (make-hash-table :test #'equal)))
  (setq default-directory (code-guide-document-root-directory document))
  (code-guide--render))

(defun code-guide--buffer-name (file)
  "Return the guide buffer name for FILE."
  (format "*Code Guide: %s*" (abbreviate-file-name (expand-file-name file))))

(defun code-guide--parse-file-for-command (file)
  "Parse FILE and report its path in command errors."
  (condition-case err
      (code-guide-parse-file file)
    ((code-guide-parse-error file-error)
     (user-error "%s: %s" file (error-message-string err)))))

;;;###autoload
(defun code-guide-open-file (file)
  "Open the guide in FILE and return its buffer."
  (let* ((document (code-guide--parse-file-for-command file))
         (buffer (get-buffer-create (code-guide--buffer-name file))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'code-guide-mode)
        (code-guide-mode))
      (code-guide--load document)
      (goto-char (point-min))
      (when (car code-guide--nodes)
        (code-guide--goto-node (car code-guide--nodes))))
    buffer))

;;;###autoload
(defun code-guide-open (file)
  "Open the guide in FILE and show it."
  (interactive
   (list (read-file-name
          "Guide file: " nil nil t nil
          (lambda (candidate)
            (or (file-directory-p candidate)
                (string-suffix-p ".codeguide.json" candidate))))))
  (pop-to-buffer (code-guide-open-file file)
                 code-guide-guide-display-buffer-action))

(defun code-guide--project-guides ()
  "Return the guide files found in the current project."
  (when-let* ((project (project-current))
              (root (project-root project)))
    (mapcan (lambda (glob)
              (file-expand-wildcards (expand-file-name glob root)))
            code-guide-project-guide-globs)))

;;;###autoload
(defun code-guide-open-project-guide ()
  "Open a guide found under the current project root."
  (interactive)
  (let ((guides (code-guide--project-guides)))
    (unless guides
      (user-error "No guide found (looked in %s)"
                  (string-join code-guide-project-guide-globs ", ")))
    (code-guide-open (if (cdr guides)
                         (completing-read "Guide: " guides nil t)
                       (car guides)))))

(defun code-guide-reload ()
  "Reread the guide file, keep the node at point when its id survives."
  (interactive)
  (let* ((file (or (code-guide-document-source-file code-guide--document)
                   (user-error "Guide has no source file")))
         (current (code-guide-current-node))
         (id (and current (code-guide-node-id current)))
         (document (code-guide--parse-file-for-command file)))
    (code-guide--load document)
    (goto-char (point-min))
    (if-let* ((node (and id (cl-find id code-guide--nodes
                                     :key #'code-guide-node-id :test #'equal))))
        (code-guide--goto-node node)
      (when (car code-guide--nodes)
        (code-guide--goto-node (car code-guide--nodes))))
    (message "Reloaded %s" (file-name-nondirectory file))))

(defun code-guide-validate ()
  "Validate every location in the current guide."
  (interactive)
  (let ((diagnostics (code-guide-validate-document code-guide--document)))
    (if diagnostics
        (code-guide--show-diagnostics code-guide--document diagnostics)
      (message "Guide is valid: %d node(s)" (length code-guide--nodes)))))

(provide 'code-guide)
;;; code-guide.el ends here
