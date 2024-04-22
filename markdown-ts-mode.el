;;; markdown-ts-mode.el --- Major mode for Markdown using Treesitter -*- lexical-binding: t; -*-
;;
;; Author: Rahul M. Juliato
;; Created: April 1st, 2024
;; Version: 0.3.0
;; Keywords: languages, matching, faces
;; URL: https://github.com/LionyxML/markdown-ts-mode
;; Package-Requires: ((emacs "29.1"))
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;;; Commentary:
;; `markdown-ts-mode` is a major mode that provides BASIC syntax
;; highlight and iMenu navigation.
;;
;; To enable it, install the package and call it when needed with:
;; (markdown-ts-mode)
;;
;; You can also setup it to be used automatically like:
;;
;; (use-package markdown-ts-mode
;;    :mode ("\\.md\\'" . markdown-ts-mode)
;;    :defer 't
;;    :config
;;    (add-to-list 'treesit-language-source-alist '(markdown "https://github.com/tree-sitter-grammars/tree-sitter-markdown" "split_parser" "tree-sitter-markdown/src"))
;;    (add-to-list 'treesit-language-source-alist '(markdown-inline "https://github.com/tree-sitter-grammars/tree-sitter-markdown" "split_parser" "tree-sitter-markdown-inline/src")))
;;
;; NOTE: please note you need BOTH markdown and markdown-inline grammars installed!
;;       so please, run `treesit-install-language-grammar' twice.
;;

;;; Code:
(require 'treesit)
(require 'subr-x)

(defvar markdown-ts--treesit-settings
  (treesit-font-lock-rules
   :language 'markdown-inline
   :override t
   :feature 'delimiter
   '([ "[" "]" "(" ")" ] @shadow)

   :language 'markdown
   :feature 'paragraph
   '([((setext_heading) @font-lock-keyword-face)
      ((atx_heading) @font-lock-keyword-face)
      ((thematic_break) @shadow)
      ((indented_code_block) @font-lock-string-face)
      (list_item (list_marker_star) @font-lock-keyword-face)
      (list_item (list_marker_plus) @font-lock-keyword-face)
      (list_item (list_marker_minus) @font-lock-keyword-face)
      (list_item (list_marker_dot) @font-lock-keyword-face)
      (fenced_code_block (fenced_code_block_delimiter) @font-lock-doc-face)
      (fenced_code_block (code_fence_content) @font-lock-string-face)
      ((block_quote_marker) @font-lock-string-face)
      (block_quote (paragraph) @font-lock-string-face)
      (block_quote (block_quote_marker) @font-lock-string-face)
      ])
   
   :language 'markdown-inline
   :feature 'paragraph-inline
   '([
      ((image_description) @link)
      ((link_destination) @font-lock-string-face)
      ((code_span) @font-lock-string-face)
      ((emphasis) @underline)
      ((strong_emphasis) @bold)
      (inline_link (link_text) @link)
      (inline_link (link_destination) @font-lock-string-face)
      (shortcut_link (link_text) @link)])))

(defun markdown-ts-imenu-node-p (node)
  "Check if NODE is a valid entry to imenu."
  (equal (treesit-node-type (treesit-node-parent node))
         "atx_heading"))

(defun markdown-ts-imenu-name-function (node)
  "Return an imenu entry if NODE is a valid header."
  (let ((name (treesit-node-text node)))
    (if (markdown-ts-imenu-node-p node)
	(thread-first (treesit-node-parent node)(treesit-node-text))
      name)))

(defun markdown-ts-setup ()
  "Setup treesit for `markdown-ts-mode'."
  (setq-local treesit-font-lock-settings markdown-ts--treesit-settings)
  (treesit-major-mode-setup))


(define-derived-mode markdown-ts-mode fundamental-mode "markdown[ts]"
  "Major mode for editing Markdown using tree-sitter grammar."
  (setq-local font-lock-defaults nil
	          treesit-font-lock-feature-list '((delimiter)
					                           (paragraph)
					                           (paragraph-inline)))

  (setq-local treesit-simple-imenu-settings
              `(("Headings" markdown-ts-imenu-node-p nil markdown-ts-imenu-name-function)))

  (when (treesit-ready-p 'markdown-inline)
    (treesit-parser-create 'markdown-inline)
    (treesit-parser-create 'markdown)
    (markdown-ts-setup)))

(provide 'markdown-ts-mode)
;;; markdown-ts-mode.el ends here
