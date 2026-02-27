EMACS ?= emacs

.PHONY: test compile clean

test: compile
	$(EMACS) --batch -Q \
	  --eval '(add-to-list (quote treesit-extra-load-path) (expand-file-name "~/.emacs.d/tree-sitter"))' \
	  -L . -L test \
	  -l markdown-ts-mode-test \
	  -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) --batch -Q -L . --eval '(byte-compile-file "markdown-ts-mode.el")'

clean:
	rm -f *.elc test/*.elc
