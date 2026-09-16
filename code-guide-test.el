;;; code-guide-test.el --- Tests for code-guide  -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with:
;;   emacs -Q --batch -L . -l code-guide-test.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'code-guide)

(defun code-guide-test--json (&rest nodes)
  "Return a guide JSON string with NODES."
  (json-serialize `(:version 1 :title "T" :root "." :nodes ,(vconcat nodes))))

(defun code-guide-test--node (id &rest plist)
  "Return a node object for ID with PLIST fields."
  (append (list :id id :title (or (plist-get plist :title) id)) plist))

(defmacro code-guide-test--with-repo (spec &rest body)
  "Create a temp repo from SPEC, bind `root' and `guide', run BODY.
SPEC is an alist of (RELATIVE-PATH . CONTENT); the guide is written to
`guide.codeguide.json' from the `guide' entry."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "code-guide-" t)))
          (guide (expand-file-name "guide.codeguide.json" root)))
     (unwind-protect
         (progn
           (dolist (entry ,spec)
             (let ((path (expand-file-name (car entry) root)))
               (make-directory (file-name-directory path) t)
               (with-temp-file path (insert (cdr entry)))))
           ,@body)
       (dolist (buffer (buffer-list))
         (when (or (string-prefix-p "*Code Guide" (buffer-name buffer))
                   (and (buffer-file-name buffer)
                        (string-prefix-p root (buffer-file-name buffer))))
           (kill-buffer buffer)))
       (delete-directory root t))))

(defun code-guide-test--ids (nodes)
  "Return the ids of NODES."
  (mapcar #'code-guide-node-id nodes))

(defconst code-guide-test--source
  (string-join (cl-loop for i from 1 to 40 collect (format "line %d" i)) "\n"))

(defmacro code-guide-test--with-buffer (name &rest body)
  "Create buffer NAME, bind it to `protected-buffer', and run BODY."
  (declare (indent 1))
  `(let ((protected-buffer (get-buffer-create ,name)))
     (unwind-protect
         (progn ,@body)
       (when (buffer-live-p protected-buffer)
         (kill-buffer protected-buffer)))))

;;;; Parsing

(ert-deftest code-guide-parse/basic ()
  (let ((doc (code-guide-parse-string
              (code-guide-test--json
               (code-guide-test--node "a" :comment "c"
                                      :location '(:file "f.c" :line 3 :column 2
                                                  :symbol "s" :anchor "x"))))))
    (should (equal (code-guide-document-title doc) "T"))
    (let* ((node (car (code-guide-document-nodes doc)))
           (loc (code-guide-node-location node)))
      (should (equal (code-guide-node-comment node) "c"))
      (should (equal (code-guide-location-file loc) "f.c"))
      (should (= (code-guide-location-line loc) 3))
      (should (= (code-guide-location-column loc) 2))
      (should (equal (code-guide-location-anchor loc) "x"))
      (should (= (code-guide-node-depth node) 0))
      (should (null (code-guide-node-parent node))))))

(ert-deftest code-guide-parse/nested ()
  (let* ((doc (code-guide-parse-string
               (code-guide-test--json
                (code-guide-test--node
                 "a" :children (vector (code-guide-test--node
                                        "b" :children (vector (code-guide-test--node "c"))))))))
         (a (car (code-guide-document-nodes doc)))
         (b (car (code-guide-node-children a)))
         (c (car (code-guide-node-children b))))
    (should (eq (code-guide-node-parent b) a))
    (should (eq (code-guide-node-parent c) b))
    (should (= (code-guide-node-depth c) 2))
    (should (equal (code-guide-test--ids (code-guide--flatten (list a))) '("a" "b" "c")))))

(ert-deftest code-guide-parse/narrative-node ()
  (let ((doc (code-guide-parse-string
              (code-guide-test--json (code-guide-test--node "n" :comment "only prose")))))
    (should (null (code-guide-node-location (car (code-guide-document-nodes doc)))))))

(ert-deftest code-guide-parse/duplicate-id ()
  (should-error (code-guide-parse-string
                 (code-guide-test--json (code-guide-test--node "a")
                                        (code-guide-test--node "a")))
                :type 'code-guide-parse-error)
  (should-error (code-guide-parse-string
                 (code-guide-test--json
                  (code-guide-test--node "a" :children (vector (code-guide-test--node "a")))))
                :type 'code-guide-parse-error))

(ert-deftest code-guide-parse/rejects-bad-input ()
  (dolist (bad (list "not json"
                     "[]"
                     (json-serialize '(:version 2 :title "T" :nodes []))
                     (json-serialize '(:version 1 :nodes []))
                     (json-serialize '(:version 1 :title "T" :nodes [(:title "no id")]))
                     (json-serialize '(:version 1 :title "T"
                                       :nodes [(:id "a" :title "a" :location (:file "f"))]))
                     ;; An empty anchor would loop forever in the search.
                     (json-serialize '(:version 1 :title "T"
                                       :nodes [(:id "a" :title "a"
                                                :location (:file "f" :line 1 :anchor ""))]))))
    (should-error (code-guide-parse-string bad) :type 'code-guide-parse-error)))

(ert-deftest code-guide-open/reports-guide-path-on-read-failure ()
  "A read failure names the selected guide and remains a user error."
  (let ((missing (expand-file-name "missing.codeguide.json"
                                   temporary-file-directory)))
    (condition-case err
        (progn
          (code-guide-open-file missing)
          (ert-fail "Expected the missing guide to fail"))
      (user-error
       (should (string-match-p (regexp-quote missing)
                               (error-message-string err)))))))

(ert-deftest code-guide-open/displays-guide-at-bottom ()
  "A bottom display action shows and selects the guide below other windows."
  (code-guide-test--with-repo nil
    (with-temp-file guide (insert (code-guide-test--json)))
    (save-window-excursion
      (delete-other-windows)
      (let ((code-guide-guide-display-buffer-action
             '((display-buffer-at-bottom)
               (window-height . 0.25)
               (window-parameters . ((code-guide-test-bottom . t))))))
        (code-guide-open guide)
        (should-not (one-window-p))
        (should (eq (current-buffer) (window-buffer (selected-window))))
        (should (window-at-side-p (selected-window) 'bottom))
        (should (window-parameter (selected-window)
                                  'code-guide-test-bottom))))))

(ert-deftest code-guide-open/default-and-runtime-action-reuse-buffer ()
  "Nil follows default display rules; later actions reuse the guide buffer."
  (code-guide-test--with-repo nil
    (with-temp-file guide (insert (code-guide-test--json)))
    (save-window-excursion
      (delete-other-windows)
      (let ((code-guide-guide-display-buffer-action nil)
            first)
        (let ((display-buffer-alist '((".*" display-buffer-same-window))))
          (setq first (code-guide-open guide))
          (should (one-window-p)))
        (setq code-guide-guide-display-buffer-action
              '((display-buffer-at-bottom)
                (window-parameters . ((code-guide-test-runtime . t)))))
        (let ((second (code-guide-open guide)))
          (should (eq first second))
          (should (window-parameter (selected-window)
                                    'code-guide-test-runtime)))))))

(ert-deftest code-guide-open/preserves-remote-source ()
  "Opening through a file-name handler keeps the complete remote source."
  (let* ((remote "/code-guide-test:reader@example.test:/repo/guide.codeguide.json")
         (content (code-guide-test--json))
         (handler (lambda (operation &rest args)
                    (if (eq operation 'insert-file-contents)
                        (progn
                          (insert content)
                          (list (car args) (length content)))
                      (let ((inhibit-file-name-handlers
                             (cons (cdr (assoc "\\`/code-guide-test:"
                                               file-name-handler-alist))
                                   inhibit-file-name-handlers))
                            (inhibit-file-name-operation operation))
                        (apply operation args)))))
         (file-name-handler-alist
          (cons (cons "\\`/code-guide-test:" handler)
                file-name-handler-alist))
         (buffer (code-guide-open-file remote)))
    (unwind-protect
        (should (equal (code-guide-document-source-file
                        (buffer-local-value 'code-guide--document buffer))
                       remote))
      (kill-buffer buffer))))

;;;; Root resolution

(ert-deftest code-guide-resolve/relative-root ()
  (code-guide-test--with-repo `(("sub/src/f.c" . ,code-guide-test--source)
                                ("guides/guide.codeguide.json" . ""))
    (let* ((guide (expand-file-name "guides/guide.codeguide.json" root))
           (doc (progn
                  (with-temp-file guide
                    (insert (json-serialize
                             `(:version 1 :title "T" :root "../sub"
                               :nodes [,(code-guide-test--node
                                         "a" :location '(:file "src/f.c" :line 1))]))))
                  (code-guide-parse-file guide))))
      (should (equal (code-guide-document-root-directory doc)
                     (expand-file-name "sub/" root)))
      (should (equal (code-guide-resolve-file
                      doc (code-guide-node-location (car (code-guide-document-nodes doc))))
                     (expand-file-name "sub/src/f.c" root)))
      (should (null (code-guide-validate-document doc))))))

(ert-deftest code-guide-resolve/preserves-remote-identity ()
  "Relative guide paths retain their complete remote identity."
  (let* ((source "/ssh:reader@example.test:/srv/repo/guides/guide.codeguide.json")
         (doc (code-guide-parse-string
               (json-serialize
                `(:version 1 :title "T" :root "../source"
                  :nodes [,(code-guide-test--node
                            "a" :location '(:file "lib/f.el" :line 1))]))
               source))
         (location (code-guide-node-location
                    (car (code-guide-document-nodes doc)))))
    (should (equal (code-guide-document-source-file doc) source))
    (should (equal (code-guide-document-root-directory doc)
                   "/ssh:reader@example.test:/srv/repo/source/"))
    (should (equal (code-guide-resolve-file doc location)
                   "/ssh:reader@example.test:/srv/repo/source/lib/f.el"))))

(ert-deftest code-guide-resolve/missing-file ()
  (code-guide-test--with-repo `(("src/f.c" . ,code-guide-test--source))
    (with-temp-file guide
      (insert (code-guide-test--json
               (code-guide-test--node "ok" :location '(:file "src/f.c" :line 5))
               (code-guide-test--node "missing" :location '(:file "src/nope.c" :line 1))
               (code-guide-test--node "far" :location '(:file "src/f.c" :line 9999))
               (code-guide-test--node "out" :location '(:file "../../etc/passwd" :line 1)))))
    (let* ((doc (code-guide-parse-file guide))
           (diags (code-guide-validate-document doc))
           (messages (mapcar (lambda (d) (nth 3 d)) diags)))
      (should (= (length diags) 3))
      (should (cl-every (lambda (d) (eq (car d) 'error)) diags))
      (should (cl-some (lambda (m) (string-match-p "missing: file does not exist" m)) messages))
      (should (cl-some (lambda (m) (string-match-p "far: line outside file" m)) messages))
      (should (cl-some (lambda (m) (string-match-p "out: file is outside" m)) messages)))))

(ert-deftest code-guide-resolve/sibling-prefix-is-outside-root ()
  "A directory whose name merely starts with the root name is outside it."
  (code-guide-test--with-repo `(("sub/f.c" . ,code-guide-test--source)
                                ("sub-evil/f.c" . ,code-guide-test--source))
    (with-temp-file guide
      (insert (json-serialize
               `(:version 1 :title "T" :root "sub"
                 :nodes [,(code-guide-test--node "in" :location '(:file "f.c" :line 1))
                         ,(code-guide-test--node "out" :location '(:file "../sub-evil/f.c" :line 1))]))))
    (let ((diags (code-guide-validate-document (code-guide-parse-file guide))))
      (should (= (length diags) 1))
      (should (string-match-p "out: file is outside" (nth 3 (car diags)))))))

(ert-deftest code-guide-property/root-containment ()
  "Invariant: roots contain themselves and descendants, not siblings."
  (code-guide-test--with-repo nil
    (dotimes (index 25)
      (let* ((name (format "root-%d" index))
             (dir (expand-file-name name root))
             (child (expand-file-name "nested/file.el" dir))
             (sibling (expand-file-name (concat name "-sibling/file.el") root))
             (doc (make-code-guide-document :root dir)))
        (make-directory (file-name-directory child) t)
        (make-directory (file-name-directory sibling) t)
        (with-temp-file child)
        (with-temp-file sibling)
        (should (code-guide--inside-root-p doc dir))
        (should (code-guide--inside-root-p doc child))
        (should-not (code-guide--inside-root-p doc sibling))))))

;;;; Locations

(ert-deftest code-guide-location/line ()
  (with-temp-buffer
    (insert code-guide-test--source)
    (code-guide--goto-location (make-code-guide-location :file "f" :line 7 :column 3))
    (should (= (line-number-at-pos) 7))
    (should (= (current-column) 2))))

(ert-deftest code-guide-location/nearby-anchor ()
  (with-temp-buffer
    (insert code-guide-test--source)
    (let ((code-guide-anchor-search-range 5))
      ;; Anchor drifted 3 lines below the recorded line.
      (should (= (code-guide-location-target-line
                  (make-code-guide-location :file "f" :line 10 :anchor "line 13"))
                 13))
      ;; Nearest of several matches wins.
      (should (= (code-guide-location-target-line
                  (make-code-guide-location :file "f" :line 20 :anchor "line 2"))
                 20))
      ;; Out of range falls back to the recorded line.
      (should (= (code-guide-location-target-line
                  (make-code-guide-location :file "f" :line 5 :anchor "line 30"))
                 5))
      ;; Missing anchor falls back too.
      (should (= (code-guide-location-target-line
                  (make-code-guide-location :file "f" :line 5 :anchor "nowhere"))
                 5)))))

(ert-deftest code-guide-location/anchor-validation-warns ()
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide
      (insert (code-guide-test--json
               (code-guide-test--node "a" :location '(:file "f.c" :line 2 :anchor "zzz")))))
    (let ((diags (code-guide-validate-document (code-guide-parse-file guide))))
      (should (= (length diags) 1))
      (should (eq (car (car diags)) 'warning)))))

;;;; Navigation in a rendered buffer

(defun code-guide-test--tree-guide ()
  "Return JSON for a tree: a > (b > (c d)) e."
  (code-guide-test--json
   (code-guide-test--node
    "a" :comment "A comment"
    :children (vector (code-guide-test--node
                       "b" :location '(:file "f.c" :line 2)
                       :children (vector (code-guide-test--node "c" :location '(:file "f.c" :line 3))
                                         (code-guide-test--node "d" :location '(:file "f.c" :line 4))))))
   (code-guide-test--node "e" :location '(:file "f.c" :line 5))))

(defun code-guide-test--current-id ()
  "Return the id of the node at point."
  (code-guide-node-id (code-guide-current-node)))

(ert-deftest code-guide-navigation/depth-first ()
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (with-current-buffer (code-guide-open-file guide)
      (should (equal (code-guide-test--current-id) "a"))
      (let (order)
        (push (code-guide-test--current-id) order)
        (dotimes (_ 4)
          (code-guide-next-node)
          (push (code-guide-test--current-id) order))
        (should (equal (nreverse order) '("a" "b" "c" "d" "e"))))
      (should-error (code-guide-next-node) :type 'user-error)
      (code-guide-previous-node)
      (should (equal (code-guide-test--current-id) "d"))
      ;; Folding hides the subtree from n/p.
      (code-guide-parent)
      (code-guide-toggle-subtree)
      (should (equal (code-guide-test--current-id) "b"))
      (code-guide-next-node)
      (should (equal (code-guide-test--current-id) "e"))
      (code-guide-previous-node)
      (should (equal (code-guide-test--current-id) "b"))
      ;; Going to a hidden child unfolds its parent.
      (code-guide-first-child)
      (should (equal (code-guide-test--current-id) "c")))))

(ert-deftest code-guide-navigation/siblings ()
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (with-current-buffer (code-guide-open-file guide)
      (code-guide-next-sibling)
      (should (equal (code-guide-test--current-id) "e"))
      (should-error (code-guide-next-sibling) :type 'user-error)
      (code-guide-previous-sibling)
      (should (equal (code-guide-test--current-id) "a"))
      (code-guide-next-node) (code-guide-next-node)
      (should (equal (code-guide-test--current-id) "c"))
      (code-guide-next-sibling)
      (should (equal (code-guide-test--current-id) "d"))
      (should-error (code-guide-next-sibling) :type 'user-error))))

(ert-deftest code-guide-navigation/parent ()
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (with-current-buffer (code-guide-open-file guide)
      (should-error (code-guide-parent) :type 'user-error)
      (dotimes (_ 3) (code-guide-next-node))
      (should (equal (code-guide-test--current-id) "d"))
      (code-guide-parent)
      (should (equal (code-guide-test--current-id) "b"))
      (code-guide-parent)
      (should (equal (code-guide-test--current-id) "a")))))

(defun code-guide-test--select-imenu-entry (entry)
  "Select Imenu ENTRY through its documented special-item interface."
  (apply (nth 2 entry) (car entry) (cadr entry) (nthcdr 3 entry)))

(ert-deftest code-guide-property/imenu-covers-and-selects-every-node ()
  "Imenu lists every node once in reading order and selects its target."
  (random (number-to-string code-guide-test--seed))
  (message "code-guide property seed: %d" code-guide-test--seed)
  (dotimes (trial 25)
    (let* ((tree (pcase trial
                   (0 [])
                   (1 (vector (code-guide-test--node "only")))
                   (_ (code-guide-test--random-tree 0 (list 0)))))
           (expected (mapcar #'car (code-guide-test--reference-dfs tree)))
           (json (json-serialize `(:version 1 :title "T" :nodes ,tree)))
           (context (format "seed=%d trial=%d" code-guide-test--seed trial)))
      (with-temp-buffer
        (code-guide-mode)
        (code-guide--load (code-guide-parse-string json))
        (let ((entries (funcall imenu-create-index-function)))
          (should (equal (cons context (length entries))
                         (cons context (length expected))))
          (cl-mapc
           (lambda (entry id)
             (code-guide-test--select-imenu-entry entry)
             (should (equal (cons context (code-guide-test--current-id))
                            (cons context id))))
           entries expected)
          (should (zerop (hash-table-count code-guide--visited))))))))

(ert-deftest code-guide-imenu/folded-and-duplicate-nodes ()
  "Duplicate labels identify each node, and folded targets remain selectable."
  (let ((json
         (code-guide-test--json
          (code-guide-test--node
           "parent" :title "Punct! Ω"
           :children (vector (code-guide-test--node "one" :title "Check")
                             (code-guide-test--node "two" :title "Check")))
          (code-guide-test--node
           "other" :title "Other"
           :children (vector (code-guide-test--node "three" :title "Check"))))))
    (with-temp-buffer
      (code-guide-mode)
      (code-guide--load (code-guide-parse-string json))
      (should (equal (mapcar #'car (funcall imenu-create-index-function))
                     '("Punct! Ω"
                       "Punct! Ω / Check [1]"
                       "Punct! Ω / Check [2]"
                       "Other"
                       "Other / Check")))
      (code-guide--goto-node (car code-guide--nodes))
      (code-guide-toggle-subtree)
      (let ((entry (nth 2 (funcall imenu-create-index-function))))
        (code-guide-test--select-imenu-entry entry)
        (should (equal (code-guide-test--current-id) "two"))
        (should-not (gethash "parent" code-guide--folded))))))

(ert-deftest code-guide-imenu/literal-label-collisions-remain-selectable ()
  "Literal path and occurrence syntax cannot make two entries ambiguous."
  (let ((json
         (code-guide-test--json
          (code-guide-test--node "flat" :title "A / B")
          (code-guide-test--node
           "parent" :title "A"
           :children (vector (code-guide-test--node "child" :title "B")))
          (code-guide-test--node
           "duplicates" :title "P"
           :children (vector (code-guide-test--node "one" :title "Check")
                             (code-guide-test--node "two" :title "Check")
                             (code-guide-test--node "literal"
                                                    :title "Check [1]"))))))
    (with-temp-buffer
      (code-guide-mode)
      (code-guide--load (code-guide-parse-string json))
      (let* ((entries (funcall imenu-create-index-function))
             (labels (mapcar #'car entries))
             (expected '("flat" "parent" "child"
                         "duplicates" "one" "two" "literal")))
        (should (= (length labels)
                   (length (delete-dups (copy-sequence labels)))))
        (cl-mapc
         (lambda (entry id)
           (code-guide-test--select-imenu-entry entry)
           (should (equal (code-guide-test--current-id) id)))
         entries expected)))))

(ert-deftest code-guide-visit/goes-to-line-and-keeps-focus-on-preview ()
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (let ((buffer (code-guide-open-file guide)))
      (with-current-buffer buffer
        (code-guide-next-node)
        (let ((window (code-guide-visit-node (code-guide-current-node) t)))
          (should (window-live-p window))
          (with-current-buffer (window-buffer window)
            (should (equal (file-name-nondirectory (buffer-file-name)) "f.c"))
            (should (= (line-number-at-pos (window-point window)) 2))))
        (should (gethash "b" code-guide--visited))
        (should (eq (get-text-property (+ (point) 2) 'face) 'code-guide-visited-face))))))

(ert-deftest code-guide-visit/guide-and-source-actions-are-independent ()
  "Guide and source buffers honor separate display actions."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (save-window-excursion
      (delete-other-windows)
      (let ((code-guide-guide-display-buffer-action
             '((display-buffer-at-bottom)
               (window-parameters . ((code-guide-test-guide . t)))))
            (code-guide-display-buffer-action
             '((display-buffer-pop-up-window)
               (inhibit-same-window . t)
               (window-parameters . ((code-guide-test-source . t))))))
        (code-guide-open guide)
        (let ((guide-window (selected-window)))
          (code-guide-next-node)
          (let ((source-window (code-guide-preview)))
            (should (eq (selected-window) guide-window))
            (should (window-parameter guide-window 'code-guide-test-guide))
            (should (window-parameter source-window 'code-guide-test-source))
            (should-not (eq guide-window source-window))
            (should (equal (file-name-nondirectory
                            (buffer-file-name (window-buffer source-window)))
                           "f.c"))))))))

(ert-deftest code-guide-visit/preview-never-replaces-guide-in-one-window-frame ()
  "Invariant: after a preview the guide window still shows the guide.
Holds for the default action, and when a user rule or a frame too small
for `display-buffer-pop-up-window' forces the same window."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (let ((buffer (code-guide-open-file guide)))
      (dolist (case (list (list nil nil)
                          (list '((".*" display-buffer-same-window)) nil)
                          (list nil 1000)))
        (pcase-let ((`(,alist ,threshold) case))
          (save-window-excursion
            (delete-other-windows)
            (set-window-buffer (selected-window) buffer)
            (with-current-buffer buffer
              (code-guide-next-node)
              (let* ((display-buffer-alist alist)
                     (split-height-threshold (or threshold split-height-threshold))
                     (split-width-threshold (or threshold split-width-threshold))
                     (guide-window (selected-window))
                     (source-window (code-guide-preview)))
                (should (eq (selected-window) guide-window))
                (should (eq (window-buffer guide-window) buffer))
                (should-not (eq source-window guide-window))
                (should (equal (file-name-nondirectory
                                (buffer-file-name (window-buffer source-window)))
                               "f.c"))))))))))

(ert-deftest code-guide-visit/protected-buffer-survives-all-commands ()
  "A protected window is invariant across every source command."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (code-guide-test--with-buffer "*claude-code[code-guide]*"
      (save-window-excursion
        (delete-other-windows)
        (let* ((guide-buffer (code-guide-open-file guide))
               (guide-window (selected-window))
               (protected-window (split-window-right))
               (code-guide-protected-buffer-name-patterns
                '("\\`\\*claude-code\\[code-guide\\]\\*\\'")))
          (set-window-buffer guide-window guide-buffer)
          (set-window-buffer protected-window protected-buffer)
          (with-current-buffer guide-buffer
            (code-guide-next-node)
            (dolist (command '(code-guide-preview
                               code-guide-visit
                               code-guide-visit-other-window))
              (select-window guide-window)
              (funcall command)
              (should (eq (window-buffer protected-window)
                          protected-buffer))
              (should (eq (window-buffer guide-window) guide-buffer)))))))))

(ert-deftest code-guide-property/protected-buffer-matching ()
  "Name patterns and the predicate agree with their OR contract."
  (random (number-to-string code-guide-test--seed))
  (message "code-guide property seed: %d" code-guide-test--seed)
  (dotimes (trial 25)
    (let* ((suffix (format "%x" (random #xffff)))
           (name (format "*assistant-%s*" suffix))
           (family (format "\\`\\*assistant-%c" (aref suffix 0)))
           (predicate-name (format "*predicate-%s*" suffix)))
      (code-guide-test--with-buffer name
        (let ((code-guide-protected-buffer-name-patterns (list family))
              (code-guide-protected-buffer-predicate
               (lambda (buffer)
                 (string= (buffer-name buffer) predicate-name))))
          (should (code-guide--protected-buffer-p protected-buffer))
          (with-temp-buffer
            (rename-buffer predicate-name t)
            (should (code-guide--protected-buffer-p (current-buffer))))
          (with-temp-buffer
            (rename-buffer (format "*other-%d*" trial) t)
            (should-not (code-guide--protected-buffer-p (current-buffer)))))))))

(ert-deftest code-guide-visit/protection-errors-before-display ()
  "Bad protection configuration leaves visible buffers unchanged."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (let ((guide-buffer (code-guide-open-file guide)))
      (save-window-excursion
        (set-window-buffer (selected-window) guide-buffer)
        (with-current-buffer guide-buffer
          (code-guide-next-node)
          (let ((code-guide-protected-buffer-name-patterns '("\\(")))
            (should-error (code-guide-preview) :type 'invalid-regexp)
            (should (eq (window-buffer (selected-window)) guide-buffer)))
          (let ((candidate-window (split-window-right))
                (candidate-buffer (get-buffer-create "*candidate*"))
                (code-guide-protected-buffer-name-patterns nil)
                (code-guide-protected-buffer-predicate
                 (lambda (_) (error "predicate failed"))))
            (unwind-protect
                (progn
                  (set-window-buffer candidate-window candidate-buffer)
                  (should-error (code-guide-preview) :type 'error)
                  (should (eq (window-buffer (selected-window)) guide-buffer)))
              (kill-buffer candidate-buffer))))))))

(ert-deftest code-guide-visit/rejects-custom-protected-destination ()
  "A custom display rule cannot replace a protected buffer."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (code-guide-test--with-buffer "*protected*"
      (save-window-excursion
        (delete-other-windows)
        (let* ((guide-buffer (code-guide-open-file guide))
               (guide-window (selected-window))
               (protected-window (split-window-right))
               (code-guide-protected-buffer-name-patterns
                '("\\`\\*protected\\*\\'"))
               (code-guide-display-buffer-action
                `((,(lambda (buffer _)
                       (set-window-dedicated-p protected-window nil)
                       (set-window-buffer protected-window buffer)
                       protected-window)))))
          (set-window-buffer guide-window guide-buffer)
          (set-window-buffer protected-window protected-buffer)
          (with-current-buffer guide-buffer
            (code-guide-next-node)
            (let ((source-window (code-guide-preview)))
              (should (eq (window-buffer protected-window)
                          protected-buffer))
              (should-not (eq source-window protected-window))
              (should-not (eq source-window guide-window)))))))))

(ert-deftest code-guide-visit/restores-dedication-after-display-error ()
  "A display error restores protected window state."
  (code-guide-test--with-buffer "*protected*"
    (save-window-excursion
      (delete-other-windows)
      (let* ((protected-window (selected-window))
             (code-guide-protected-buffer-name-patterns
              '("\\`\\*protected\\*\\'")))
        (set-window-buffer protected-window protected-buffer)
        (cl-letf (((symbol-function 'display-buffer)
                   (lambda (&rest _) (error "display failed"))))
          (should-error
           (code-guide--display-source-buffer
            (get-buffer-create "*source*") nil)
           :type 'error))
        (should-not (window-dedicated-p protected-window))
        (should (eq (window-buffer protected-window) protected-buffer))
        (kill-buffer "*source*")))))

(ert-deftest code-guide-visit/runtime-protection-change-takes-effect ()
  "The next source action observes changed protection settings."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (code-guide-test--with-buffer "*runtime-protected*"
      (save-window-excursion
        (delete-other-windows)
        (let* ((guide-buffer (code-guide-open-file guide))
               (guide-window (selected-window))
               (target-window (split-window-right))
               (code-guide-protected-buffer-name-patterns
                '("\\`\\*runtime-protected\\*\\'"))
               (code-guide-display-buffer-action
                `((,(lambda (buffer _)
                       (set-window-dedicated-p target-window nil)
                       (set-window-buffer target-window buffer)
                       target-window)))))
          (set-window-buffer guide-window guide-buffer)
          (set-window-buffer target-window protected-buffer)
          (with-current-buffer guide-buffer
            (code-guide-next-node)
            (code-guide-preview)
            (should (eq (window-buffer target-window) protected-buffer))
            (setq code-guide-protected-buffer-name-patterns nil)
            (code-guide-preview)
            (should (equal (file-name-nondirectory
                            (buffer-file-name (window-buffer target-window)))
                           "f.c"))))))))

(ert-deftest code-guide-visit/protects-buffer-on-remote-source-path ()
  "Remote source resolution uses the same protected-window display path."
  (let* ((remote "/code-guide-test:reader@example.test:/repo/guide.codeguide.json")
         (source "/code-guide-test:reader@example.test:/repo/f.c")
         (content (code-guide-test--json
                   (code-guide-test--node
                    "remote" :location '(:file "f.c" :line 1))))
         (handler (lambda (operation &rest args)
                    (if (eq operation 'insert-file-contents)
                        (progn
                          (insert content)
                          (list (car args) (length content)))
                      (let ((inhibit-file-name-handlers
                             (cons (cdr (assoc "\\`/code-guide-test:"
                                               file-name-handler-alist))
                                   inhibit-file-name-handlers))
                            (inhibit-file-name-operation operation))
                        (apply operation args)))))
         (file-name-handler-alist
          (cons (cons "\\`/code-guide-test:" handler)
                file-name-handler-alist))
         (guide-buffer (code-guide-open-file remote))
         requested
         source-buffer)
    (unwind-protect
        (code-guide-test--with-buffer "*remote-protected*"
          (save-window-excursion
            (delete-other-windows)
            (let ((guide-window (selected-window))
                  (protected-window (split-window-right))
                  (code-guide-protected-buffer-name-patterns
                   '("\\`\\*remote-protected\\*\\'")))
              (set-window-buffer guide-window guide-buffer)
              (set-window-buffer protected-window protected-buffer)
              (cl-letf (((symbol-function 'file-readable-p) (lambda (_) t))
                        ((symbol-function 'find-file-noselect)
                         (lambda (file &rest _)
                           (setq requested file
                                 source-buffer
                                 (get-buffer-create "*remote-source*"))
                           (with-current-buffer source-buffer
                             (setq buffer-file-name file)
                             (erase-buffer)
                             (insert code-guide-test--source))
                           source-buffer)))
                (with-current-buffer guide-buffer
                  (code-guide-preview)
                  (should (equal requested source))
                  (should (eq (window-buffer protected-window)
                              protected-buffer)))))))
      (when (buffer-live-p source-buffer) (kill-buffer source-buffer))
      (when (buffer-live-p guide-buffer) (kill-buffer guide-buffer)))))

(ert-deftest code-guide-visit/all-protected-uses-fresh-window ()
  "A source already visible in a protected window gets a safe destination."
  (code-guide-test--with-buffer "*protected-source*"
    (let ((second-buffer (get-buffer-create "*protected-second*"))
          (guide-buffer (get-buffer-create "*guide*")))
      (unwind-protect
          (save-window-excursion
            (delete-other-windows)
            (let* ((guide-window (selected-window))
                   (source-window (split-window-right))
                   (second-window (split-window-below))
                   (code-guide-protected-buffer-name-patterns
                    '("\\`\\*protected-.*\\*\\'")))
              (set-window-buffer guide-window guide-buffer)
              (set-window-buffer source-window protected-buffer)
              (set-window-buffer second-window second-buffer)
              (let ((destination
                     (code-guide--display-source-buffer
                      protected-buffer guide-window)))
                (should-not (memq destination
                                  (list guide-window
                                        source-window
                                        second-window)))
                (should (eq (window-buffer source-window)
                            protected-buffer))
                (should-not (window-dedicated-p source-window))
                (should (eq (window-buffer second-window)
                            second-buffer))
                (should-not (window-dedicated-p second-window))
                (should (eq (window-buffer destination)
                            protected-buffer)))))
        (kill-buffer second-buffer)
        (kill-buffer guide-buffer)))))

(ert-deftest code-guide-visit/no-safe-destination-preserves-protected-window ()
  "Failure leaves protected windows unchanged and restores dedication."
  (code-guide-test--with-buffer "*protected*"
    (let ((guide-buffer (get-buffer-create "*guide*"))
          (source-buffer (get-buffer-create "*source*")))
      (unwind-protect
          (save-window-excursion
            (delete-other-windows)
            (let* ((guide-window (selected-window))
                   (protected-window (split-window-right))
                   (code-guide-protected-buffer-name-patterns
                    '("\\`\\*protected\\*\\'"))
                   (display-calls 0))
              (set-window-buffer guide-window guide-buffer)
              (set-window-buffer protected-window protected-buffer)
              (cl-letf (((symbol-function 'split-window)
                         (lambda (&rest _) nil))
                        ((symbol-function 'display-buffer)
                         (lambda (&rest _)
                           (and (= (cl-incf display-calls) 1)
                                protected-window))))
                (should-error
                 (code-guide--display-source-buffer
                  source-buffer guide-window)
                 :type 'user-error))
              (should (= display-calls 2))
              (should (eq (window-buffer guide-window) guide-buffer))
              (should (eq (window-buffer protected-window)
                          protected-buffer))
              (should-not (window-dedicated-p protected-window))))
        (kill-buffer guide-buffer)
        (kill-buffer source-buffer)))))

(ert-deftest code-guide-visit/preserves-multiple-protected-windows ()
  "Preview and visit preserve every simultaneously protected window."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (let ((first-buffer (get-buffer-create "*assistant-one*"))
          (second-buffer (get-buffer-create "*assistant-two*")))
      (unwind-protect
          (save-window-excursion
            (delete-other-windows)
            (let* ((guide-buffer (code-guide-open-file guide))
                   (guide-window (selected-window))
                   (first-window (split-window-right))
                   (second-window (split-window-below))
                   (code-guide-protected-buffer-name-patterns
                    '("\\`\\*assistant-")))
              (set-window-buffer guide-window guide-buffer)
              (set-window-buffer first-window first-buffer)
              (set-window-buffer second-window second-buffer)
              (with-current-buffer guide-buffer
                (code-guide-next-node)
                (dolist (command '(code-guide-preview code-guide-visit))
                  (select-window guide-window)
                  (let ((source-window (funcall command)))
                    (should-not (memq source-window
                                      (list guide-window
                                            first-window
                                            second-window)))
                    (should (equal (file-name-nondirectory
                                    (buffer-file-name
                                     (window-buffer source-window)))
                                   "f.c"))
                    (should (eq (window-buffer first-window) first-buffer))
                    (should (eq (window-buffer second-window)
                                second-buffer)))))))
        (kill-buffer first-buffer)
        (kill-buffer second-buffer)))))

(ert-deftest code-guide-visit/rejects-protected-display-buffer-alist-window ()
  "A global same-window rule cannot reuse a protected selected window."
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (code-guide-test--with-buffer "*protected-global-rule*"
      (save-window-excursion
        (delete-other-windows)
        (let* ((guide-buffer (code-guide-open-file guide))
               (guide-window (selected-window))
               (protected-window (split-window-right))
               (display-buffer-alist
                '(("f\\.c\\'" display-buffer-same-window)))
               (code-guide-protected-buffer-name-patterns
                '("\\`\\*protected-global-rule\\*\\'")))
          (set-window-buffer guide-window guide-buffer)
          (set-window-buffer protected-window protected-buffer)
          (select-window protected-window)
          (with-current-buffer guide-buffer
            (code-guide-next-node)
            (let ((source-window (code-guide-preview)))
              (should (eq (window-buffer protected-window)
                          protected-buffer))
              (should-not (eq source-window protected-window))
              (should-not (eq source-window guide-window))
              (should (equal (file-name-nondirectory
                              (buffer-file-name
                               (window-buffer source-window)))
                             "f.c")))))))))

;;;; Properties over generated trees

(defconst code-guide-test--seed 20260916
  "Fixed seed for generated trees; printed on failure.")

(defun code-guide-test--random-tree (depth counter)
  "Return a random node vector at DEPTH.  COUNTER is a cons cell holding the next id."
  (let ((count (if (> depth 2) 0 (random 4)))
        nodes)
    (dotimes (_ count)
      (let ((id (format "n%d" (cl-incf (car counter)))))
        (push (apply #'code-guide-test--node id
                     :children (code-guide-test--random-tree (1+ depth) counter)
                     (when (zerop (random 2))
                       (list :location (list :file "f.c" :line (1+ (random 40))))))
              nodes)))
    (vconcat (nreverse nodes))))

(defun code-guide-test--walk-forward ()
  "Return ids visited by `n' from the first node until it errors."
  (let (order)
    (push (code-guide-test--current-id) order)
    (while (ignore-errors (code-guide-next-node) t)
      (push (code-guide-test--current-id) order))
    (nreverse order)))

(defun code-guide-test--reference-dfs (tree &optional depth)
  "Independent oracle: (ID . DEPTH) pairs of the generated plist TREE in
depth-first order.  Never consults the package."
  (let ((depth (or depth 0)))
    (mapcan (lambda (node)
              (cons (cons (plist-get node :id) depth)
                    (code-guide-test--reference-dfs (plist-get node :children)
                                                    (1+ depth))))
            (append tree nil))))

(ert-deftest code-guide-property/navigation-round-trip ()
  "Invariants on random trees: `n' visits every node once in depth-first order,
`p' walks the same path in reverse, `u' undoes `d', and parent depth is
child depth minus one.  Empty and single-node trees are included."
  (random (number-to-string code-guide-test--seed))
  (message "code-guide property seed: %d" code-guide-test--seed)
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (dotimes (trial 25)
      (let* ((tree (pcase trial
                     (0 [])
                     (1 (vector (code-guide-test--node "only")))
                     (_ (code-guide-test--random-tree 0 (list 0)))))
             (json (json-serialize `(:version 1 :title "T" :nodes ,tree))))
        (with-temp-file guide (insert json))
        (with-current-buffer (code-guide-open-file guide)
          (let* ((reference (code-guide-test--reference-dfs tree))
                 (expected (mapcar #'car reference))
                 (context (format "seed=%d trial=%d json=%s"
                                  code-guide-test--seed trial json)))
            (if (null expected)
                (progn
                  (should (null (code-guide-current-node)))
                  (should-error (code-guide-next-node) :type 'user-error))
              (let ((forward (code-guide-test--walk-forward)))
                (should (equal (cons context forward) (cons context expected)))
                (should (= (length forward) (length (delete-dups (copy-sequence forward)))))
                (let (backward)
                  (push (code-guide-test--current-id) backward)
                  (while (ignore-errors (code-guide-previous-node) t)
                    (push (code-guide-test--current-id) backward))
                  (should (equal (cons context backward) (cons context expected))))
                (should (equal (cons context
                                     (mapcar (lambda (n) (cons (code-guide-node-id n)
                                                               (code-guide-node-depth n)))
                                             code-guide--nodes))
                               (cons context reference)))
                (dolist (node code-guide--nodes)
                  (when (code-guide-node-children node)
                    (code-guide--goto-node node)
                    (code-guide-first-child)
                    (code-guide-parent)
                    (should (equal (cons context (code-guide-test--current-id))
                                   (cons context (code-guide-node-id node))))))))))))))

(ert-deftest code-guide-property/parse-render-round-trip ()
  "Invariant: a parsed tree renders one heading per node, in order, and
every heading carries its node.  Titles are random strings."
  (random (number-to-string code-guide-test--seed))
  (message "code-guide property seed: %d" code-guide-test--seed)
  (dotimes (trial 25)
    (let* ((counter (list 0))
           (tree (code-guide-test--random-tree 0 counter))
           (json (json-serialize `(:version 1 :title "T" :nodes ,tree)))
           (context (format "seed=%d trial=%d" code-guide-test--seed trial)))
      (with-temp-buffer
        (code-guide-mode)
        (code-guide--load (code-guide-parse-string json))
        (let ((rendered nil) (pos (point-min)))
          (while pos
            (when-let* ((id (get-text-property pos 'code-guide-node-id)))
              (unless (equal id (car rendered)) (push id rendered)))
            (setq pos (next-single-property-change pos 'code-guide-node-id)))
          (should (equal (cons context (nreverse rendered))
                         (cons context (mapcar #'car (code-guide-test--reference-dfs tree)))))
          (should (= (length code-guide--nodes) (car counter))))))))


(ert-deftest code-guide-property/open-distinguishes-same-basename-guides ()
  "Different guide identities never share a buffer."
  (code-guide-test--with-repo nil
    (dotimes (trial 10)
      (let* ((one (expand-file-name
                   (format "one-%d/guide.codeguide.json" trial) root))
             (two (expand-file-name
                   (format "two-%d/guide.codeguide.json" trial) root))
             (context (format "trial=%d" trial)))
        (dolist (file (list one two))
          (make-directory (file-name-directory file) t)
          (with-temp-file file (insert (code-guide-test--json))))
        (let ((one-buffer (code-guide-open-file one))
              (two-buffer (code-guide-open-file two)))
          (should-not (eq one-buffer two-buffer))
          (should (eq one-buffer (code-guide-open-file one)))
          (should (equal
                   (cons context
                         (mapcar (lambda (buffer)
                                   (code-guide-document-source-file
                                    (buffer-local-value
                                     'code-guide--document buffer)))
                                 (list one-buffer two-buffer)))
                   (cons context (list one two)))))))))
;;;; Reload

(ert-deftest code-guide-reload/preserve-node-id ()
  (code-guide-test--with-repo `(("f.c" . ,code-guide-test--source))
    (with-temp-file guide (insert (code-guide-test--tree-guide)))
    (with-current-buffer (code-guide-open-file guide)
      (dotimes (_ 3) (code-guide-next-node))
      (should (equal (code-guide-test--current-id) "d"))
      (code-guide-parent)
      (code-guide-toggle-subtree)
      ;; Agent rewrites the guide: new node first, "d" survives.
      (with-temp-file guide
        (insert (code-guide-test--json
                 (code-guide-test--node "new")
                 (code-guide-test--node
                  "a" :children (vector (code-guide-test--node
                                         "b" :children (vector (code-guide-test--node "d"))))))))
      (code-guide-next-node)
      (should (equal (code-guide-test--current-id) "e"))
      (code-guide-previous-node)
      (code-guide-reload)
      (should (equal (code-guide-document-source-file code-guide--document)
                     guide))
      ;; Fold state for "b" survived the reload: "d" stays hidden.
      (should-error (code-guide-next-node) :type 'user-error)
      (code-guide-first-child)
      (should (equal (code-guide-test--current-id) "d"))
      (should (equal (code-guide-test--ids code-guide--nodes) '("new" "a" "b" "d")))
      ;; A node that vanished falls back to the first node.
      (with-temp-file guide (insert (code-guide-test--json (code-guide-test--node "only"))))
      (code-guide-reload)
      (should (equal (code-guide-test--current-id) "only")))))

(defun code-guide-test--imenu-labels (&optional refresh)
  "Return reader entries from the Imenu index, optionally forcing REFRESH."
  (mapcar #'car
          (cl-remove-if
           (lambda (entry)
             (and (numberp (cdr entry)) (< (cdr entry) 0)))
           (imenu--make-index-alist refresh))))

(ert-deftest code-guide-imenu/reload-freshness ()
  "Imenu reflects successful reloads and keeps the last valid guide."
  (code-guide-test--with-repo nil
    (with-temp-file guide
      (insert (code-guide-test--json
               (code-guide-test--node "old" :title "Old"))))
    (with-current-buffer (code-guide-open-file guide)
      (should (equal (code-guide-test--imenu-labels t) '("Old")))
      (with-temp-file guide
        (insert (code-guide-test--json
                 (code-guide-test--node "new" :title "New"))))
      (code-guide-reload)
      (should (equal (code-guide-test--imenu-labels) '("New")))
      (should (equal (code-guide-document-source-file code-guide--document)
                     guide))
      (with-temp-file guide (insert "not json"))
      (should-error (code-guide-reload) :type 'user-error)
      (should (equal (code-guide-test--imenu-labels) '("New")))))
  (with-temp-buffer
    (code-guide-mode)
    (code-guide--load (code-guide-parse-string (code-guide-test--json)))
    (should-not (funcall imenu-create-index-function))))

(provide 'code-guide-test)
;;; code-guide-test.el ends here
