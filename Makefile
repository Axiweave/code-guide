EMACS ?= emacs

.PHONY: test compile

test:
	rm -f *.elc && $(EMACS) -Q --batch -L . -l code-guide-test.el -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch -L . --eval "(setq byte-compile-error-on-warn t)" -f batch-byte-compile code-guide.el
