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
                                       :nodes [(:id "a" :title "a" :location (:file "f"))]))))
    (should-error (code-guide-parse-string bad) :type 'code-guide-parse-error)))

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
      ;; Fold state for "b" survived the reload: "d" stays hidden.
      (should-error (code-guide-next-node) :type 'user-error)
      (code-guide-first-child)
      (should (equal (code-guide-test--current-id) "d"))
      (should (equal (code-guide-test--ids code-guide--nodes) '("new" "a" "b" "d")))
      ;; A node that vanished falls back to the first node.
      (with-temp-file guide (insert (code-guide-test--json (code-guide-test--node "only"))))
      (code-guide-reload)
      (should (equal (code-guide-test--current-id) "only")))))

(provide 'code-guide-test)
;;; code-guide-test.el ends here
