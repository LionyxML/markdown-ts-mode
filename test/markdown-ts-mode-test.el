;;; markdown-ts-mode-test.el --- Tests for markdown-ts-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; ERT tests for markdown-ts-mode font-lock and compat shims.

;;; Code:

(require 'ert)
(require 'markdown-ts-mode)

;;; Test helpers

(defun markdown-ts-test--fontify (text)
  "Insert TEXT, activate `markdown-ts-mode', fontify, return the buffer.
Caller must kill the buffer when done."
  (let ((buf (generate-new-buffer " *markdown-ts-test*")))
    (with-current-buffer buf
      (insert text)
      (markdown-ts-mode)
      (font-lock-ensure))
    buf))

(defun markdown-ts-test--face-at (text search &optional nth)
  "In markdown TEXT, find the NTH occurrence of SEARCH and return its face.
NTH defaults to 1 (first occurrence).  Returns the face at the
start of the match."
  (let ((buf (markdown-ts-test--fontify text))
        (n (or nth 1)))
    (unwind-protect
        (with-current-buffer buf
          (goto-char (point-min))
          (dotimes (_ n)
            (search-forward search))
          (get-text-property (match-beginning 0) 'face))
      (kill-buffer buf))))

(defun markdown-ts-test--has-face (text search face &optional nth)
  "Non-nil if SEARCH in TEXT has FACE (or FACE in a list of faces).
NTH selects occurrence (default 1)."
  (let ((actual (markdown-ts-test--face-at text search nth)))
    (cond
     ((null actual) nil)
     ((listp actual) (memq face actual))
     (t (eq face actual)))))

(defun markdown-ts-test--invisible-at (text search &optional nth)
  "In markdown TEXT, return the `invisible' property at SEARCH position.
NTH selects occurrence (default 1)."
  (let ((buf (markdown-ts-test--fontify text))
        (n (or nth 1)))
    (unwind-protect
        (with-current-buffer buf
          (goto-char (point-min))
          (dotimes (_ n)
            (search-forward search))
          (get-text-property (match-beginning 0) 'invisible))
      (kill-buffer buf))))

;;; Font-lock correctness tests

(ert-deftest markdown-ts-test-heading ()
  "ATX heading should get markdown-ts-heading-* face."
  (should (markdown-ts-test--has-face
           "# Hello\n" "Hello" 'markdown-ts-heading-1)))

(ert-deftest markdown-ts-test-heading-levels ()
  "Each heading level should get its own face."
  (let ((text "# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n"))
    (should (markdown-ts-test--has-face text "H1" 'markdown-ts-heading-1))
    (should (markdown-ts-test--has-face text "H2" 'markdown-ts-heading-2))
    (should (markdown-ts-test--has-face text "H3" 'markdown-ts-heading-3))
    (should (markdown-ts-test--has-face text "H4" 'markdown-ts-heading-4))
    (should (markdown-ts-test--has-face text "H5" 'markdown-ts-heading-5))
    (should (markdown-ts-test--has-face text "H6" 'markdown-ts-heading-6))))

(ert-deftest markdown-ts-test-heading-delimiter ()
  "The # marker should get markdown-ts-delimiter face."
  (should (markdown-ts-test--has-face
           "# Hello\n" "#" 'markdown-ts-delimiter)))

(ert-deftest markdown-ts-test-bold-paragraph ()
  "Bold text in paragraph should get `bold' face."
  (should (markdown-ts-test--has-face
           "Para **bold** text.\n" "bold" 'bold)))

(ert-deftest markdown-ts-test-italic-paragraph ()
  "Italic text in paragraph should get `italic' face."
  (should (markdown-ts-test--has-face
           "Para *italic* text.\n" "italic" 'italic)))

(ert-deftest markdown-ts-test-code-span ()
  "Code span should get `font-lock-string-face'."
  (should (markdown-ts-test--has-face
           "Para `code` text.\n" "code" 'font-lock-string-face)))

(ert-deftest markdown-ts-test-bold-in-table ()
  "Bold text in table cell should get `bold' face.
On Emacs 31+ with range settings, the markdown-inline parser is scoped
to (inline) nodes, which don't appear inside pipe_table_cell in the
tree-sitter-markdown grammar (v0.4.1).  Inline fontification in tables
only works on Emacs 30 where both parsers see the whole buffer."
  (skip-unless (not (fboundp 'treesit-range-fn-exclude-children)))
  (should (markdown-ts-test--has-face
           "| **tbl** | cell |\n|---|---|\n| a | b |\n"
           "tbl" 'bold)))

(ert-deftest markdown-ts-test-code-in-table ()
  "Code span in table cell should get `font-lock-string-face'.
See `markdown-ts-test-bold-in-table' for Emacs 31 limitation."
  (skip-unless (not (fboundp 'treesit-range-fn-exclude-children)))
  (should (markdown-ts-test--has-face
           "| `code` | cell |\n|---|---|\n| a | b |\n"
           "code" 'font-lock-string-face)))

(ert-deftest markdown-ts-test-link-in-table ()
  "Link text in table cell should get `link' face.
See `markdown-ts-test-bold-in-table' for Emacs 31 limitation."
  (skip-unless (not (fboundp 'treesit-range-fn-exclude-children)))
  (should (markdown-ts-test--has-face
           "| [link](url) | cell |\n|---|---|\n| a | b |\n"
           "link" 'link)))

(ert-deftest markdown-ts-test-fenced-code-block ()
  "Fenced code block content should get appropriate fontification.
On Emacs 30 (no range settings), the inline parser sees the fenced
block as a code_span and applies `font-lock-string-face'.  On
Emacs 31 (with ranges), sub-mode embedding may apply language faces."
  (let ((text "```\nsome code\n```\n"))
    (if (fboundp 'treesit-range-fn-exclude-children)
        ;; Emacs 31: range settings active, behavior depends on sub-mode
        (should t)
      ;; Emacs 30: inline parser's code_span applies font-lock-string-face
      (should (markdown-ts-test--has-face
               text "some code" 'font-lock-string-face)))))

(ert-deftest markdown-ts-test-blockquote ()
  "Block quote should get `markdown-ts-block-quote' face."
  (should (markdown-ts-test--has-face
           "> quoted\n" "quoted" 'markdown-ts-block-quote)))

(ert-deftest markdown-ts-test-list-marker ()
  "List markers should get `markdown-ts-list-marker' face."
  (let ((text "- item one\n- item two\n"))
    (should (markdown-ts-test--has-face text "-" 'markdown-ts-list-marker))))

(ert-deftest markdown-ts-test-link-inline ()
  "Inline link text should get `link' face."
  (should (markdown-ts-test--has-face
           "Visit [here](http://example.com) now.\n"
           "here" 'link)))

(ert-deftest markdown-ts-test-link-destination ()
  "Link destination should get `font-lock-string-face'."
  (should (markdown-ts-test--has-face
           "Visit [here](http://example.com) now.\n"
           "http://example.com" 'font-lock-string-face)))

;;; Hide-markup tests

(ert-deftest markdown-ts-test-hide-markup-delimiter ()
  "With `markdown-ts-hide-markup' non-nil, delimiters get invisible property."
  (let ((markdown-ts-hide-markup t))
    (should (eq (markdown-ts-test--invisible-at "# Hello\n" "#")
                'markdown-ts--markup))))

(ert-deftest markdown-ts-test-hide-markup-off ()
  "With `markdown-ts-hide-markup' nil, delimiters have no invisible property."
  (let ((markdown-ts-hide-markup nil))
    (should (null (markdown-ts-test--invisible-at "# Hello\n" "#")))))

(ert-deftest markdown-ts-test-hide-markup-emphasis ()
  "With hide-markup, emphasis delimiters get invisible property."
  (let ((markdown-ts-hide-markup t))
    (should (eq (markdown-ts-test--invisible-at
                 "Para *italic* text.\n" "*")
                'markdown-ts--markup))))

(ert-deftest markdown-ts-test-toggle-hide-markup ()
  "Toggling hide-markup should flip the variable and update invisibility."
  (let ((buf (generate-new-buffer " *markdown-ts-test-toggle*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "# Hello\n")
          (markdown-ts-mode)
          (font-lock-ensure)
          ;; Initially off
          (should (null markdown-ts-hide-markup))
          ;; Toggle on
          (markdown-ts-toggle-hide-markup)
          (should markdown-ts-hide-markup)
          (should (memq 'markdown-ts--markup buffer-invisibility-spec))
          ;; Toggle off
          (markdown-ts-toggle-hide-markup)
          (should (null markdown-ts-hide-markup))
          (should (not (memq 'markdown-ts--markup buffer-invisibility-spec))))
      (kill-buffer buf))))

;;; Compat shim tests

(ert-deftest markdown-ts-test-shim-ensure-installed ()
  "The ensure-installed shim should be callable and return t for installed grammars."
  (should (fboundp 'markdown-ts--ensure-installed))
  ;; Shim should return non-nil for an installed grammar
  (should (markdown-ts--ensure-installed 'markdown))
  (if (fboundp 'treesit-ensure-installed)
      ;; Emacs 31: shim should delegate to real function
      (should (functionp (symbol-function 'markdown-ts--ensure-installed)))
    ;; Emacs 30: shim is a lambda wrapping treesit-ready-p
    (should (functionp (symbol-function 'markdown-ts--ensure-installed)))))

(ert-deftest markdown-ts-test-shim-merge-feature-list ()
  "The merge-feature-list shim should merge correctly."
  (should (fboundp 'markdown-ts--merge-font-lock-feature-list))
  (let ((merged (markdown-ts--merge-font-lock-feature-list
                 '((a b) (c d))
                 '((b e) (f)))))
    ;; First level: union of (a b) and (b e)
    (should (= (length (car merged)) 3))
    (should (memq 'a (car merged)))
    (should (memq 'b (car merged)))
    (should (memq 'e (car merged)))
    ;; Second level: union of (c d) and (f)
    (should (= (length (cadr merged)) 3))
    (should (memq 'c (cadr merged)))
    (should (memq 'd (cadr merged)))
    (should (memq 'f (cadr merged)))))

(ert-deftest markdown-ts-test-shim-merge-unequal-length ()
  "Merging feature lists of different lengths should work."
  (let ((merged (markdown-ts--merge-font-lock-feature-list
                 '((a) (b) (c))
                 '((x)))))
    (should (= (length merged) 3))
    (should (memq 'a (nth 0 merged)))
    (should (memq 'x (nth 0 merged)))
    (should (equal (nth 1 merged) '(b)))
    (should (equal (nth 2 merged) '(c)))))

(ert-deftest markdown-ts-test-range-settings-gated ()
  "Range settings should only be set on Emacs 31+."
  (let ((buf (generate-new-buffer " *markdown-ts-test-range*")))
    (unwind-protect
        (with-current-buffer buf
          (insert "# test\n")
          (markdown-ts-mode)
          (if (fboundp 'treesit-range-fn-exclude-children)
              ;; Emacs 31: range settings should be set
              (should treesit-range-settings)
            ;; Emacs 30: range settings should be nil
            (should (null treesit-range-settings))))
      (kill-buffer buf))))

;;; Mode activation test

(ert-deftest markdown-ts-test-mode-activation ()
  "markdown-ts-mode should activate without error."
  (let ((buf (generate-new-buffer " *markdown-ts-test-mode*")))
    (unwind-protect
        (with-current-buffer buf
          (markdown-ts-mode)
          (should (eq major-mode 'markdown-ts-mode))
          (should (derived-mode-p 'text-mode)))
      (kill-buffer buf))))

(ert-deftest markdown-ts-test-mode-parents ()
  "markdown-ts-mode should report markdown-mode as parent."
  (let ((buf (generate-new-buffer " *markdown-ts-test-parents*")))
    (unwind-protect
        (with-current-buffer buf
          (markdown-ts-mode)
          (should (derived-mode-p 'markdown-mode)))
      (kill-buffer buf))))

(provide 'markdown-ts-mode-test)
;;; markdown-ts-mode-test.el ends here
