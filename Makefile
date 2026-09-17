EMACS ?= emacs
AGENT_SKILLS_DIR ?= $(HOME)/.agents/skills

.PHONY: test compile install-skills

test:
	rm -f *.elc && $(EMACS) -Q --batch -L . -l code-guide-test.el -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch -L . --eval "(setq byte-compile-error-on-warn t)" -f batch-byte-compile code-guide.el

install-skills:
	mkdir -p "$(AGENT_SKILLS_DIR)"
	@test ! -e "$(AGENT_SKILLS_DIR)/code-guide-author" \
		|| test -L "$(AGENT_SKILLS_DIR)/code-guide-author" \
		|| { echo "Refusing to replace non-symlink: $(AGENT_SKILLS_DIR)/code-guide-author" >&2; exit 1; }
	ln -sfn "$(abspath skills/code-guide-author)" "$(AGENT_SKILLS_DIR)/code-guide-author"
