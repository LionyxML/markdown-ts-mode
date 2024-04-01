;;; markdown-ts-mode.el --- Major mode for Markdown using Treesitter -*- lexical-binding: t; -*-
;;
;; Author: Rahul M. Juliato
;; Created: April 1st, 2024
;; Version: 0.1.0
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
;;(use-package markdown-ts-mode
;;   :mode ("\\.md\\'" . markdown-ts-mode)
;;   :defer 't
;;   :config
;;   (add-to-list 'treesit-language-source-alist '(markdown "https://github.com/ikatyang/tree-sitter-markdown" "master" "src")))
;;

;;; Code:
(require 'treesit)
(require 'subr-x)

(defvar markdown-ts--treesit-settings
  (treesit-font-lock-rules
   :language 'markdown
   :feature 'atx_heading
   '((atx_heading) @font-lock-keyword-face)

   :language 'markdown
   :feature 'info_string
   '((info_string) @font-lock-warning-face)

   :language 'markdown
   :feature 'fenced_code_block
   '([(code_fence_content (text) @lazy-highlight)])

   :language 'markdown
   :feature 'link
   '([(link_text (text) @lazy-highlight)
     (link_destination (text) @link)])
   
   :language 'markdown
   :feature 'paragraph
   '([
     (code_span (text) @lazy-highlight)
     (emphasis (text) @bold)
     (strong_emphasis (text) @bold-italic)
     (code_fence_content (text) @font-lock-doc-face)
     (indented_code_block (text) @font-lock-doc-face)
     (block_quote (paragraph) @font-lock-string-face)
     (list_item (list_marker) @homoglyph)
     ])))

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
  "Major mode for editing Markdown with tree-sitter."
  (setq-local font-lock-defaults nil
	      treesit-font-lock-feature-list '((atx_heading)
					       (info_string)
					       (paragraph)
					       (link)))

  (setq-local treesit-simple-imenu-settings
              `(("Heading" markdown-ts-imenu-node-p nil markdown-ts-imenu-name-function)))

  (when (treesit-ready-p 'markdown)
    (treesit-parser-create 'markdown)
    (markdown-ts-setup)))

(provide 'markdown-ts-mode)
;;; markdown-ts-mode.el ends here
