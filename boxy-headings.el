;;; boxy-headings.el --- View org files in a boxy diagram -*- lexical-binding: t -*-

;; Copyright (C) 2021 Free Software Foundation, Inc.

;; Author: Taylor Grinn <grinntaylor@gmail.com>
;; Version: 2.1.4
;; File: boxy-headings.el
;; Package-Requires: ((emacs "26.1") (boxy "1.0") (org "9.4"))
;; Keywords: tools
;; URL: https://gitlab.com/tygrdev/boxy-headings

;; This program is free software; you can redistribute it and/or modify
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

;; The command `boxy-headings' will display all headings in the
;; current org file as a boxy diagram.  The relationship between
;; a heading and its parent can be set by using a REL property on the
;; child heading.  Valid values for REL are:
;;
;;   - on-top
;;   - in-front
;;   - behind
;;   - above
;;   - below
;;   - right
;;   - left
;;
;;   The tooltip in `boxy-headings' shows the values for each row
;;   in `org-columns' and can be customized the same way as org
;;   columns view.

;;; Code:

;;;; Requirements

(require 'boxy)
(require 'eieio)
(require 'org-element)
(require 'org-colview)
(require 'cl-lib)

;;;; Options

(defgroup boxy-headings nil
  "Customization options for boxy-headings."
  :group 'applications)

(defcustom boxy-headings-margin-x 2
  "Horizontal margin to be used when displaying boxes."
  :type 'number)

(defcustom boxy-headings-margin-y 1
  "Vertical margin to be used when displaying boxes."
  :type 'number)

(defcustom boxy-headings-padding-x 2
  "Horizontal padding to be used when displaying boxes."
  :type 'number)

(defcustom boxy-headings-padding-y 1
  "Vertical padding to be used when displaying boxes."
  :type 'number)

(defcustom boxy-headings-include-context t
  "Whether to show context when opening a real link."
  :type 'boolean)

(defcustom boxy-headings-flex-width 80
  "When merging links, try to keep width below this."
  :type 'number)

(defcustom boxy-headings-default-visibility 1
  "Default level to display boxes."
  :type 'number)

(defcustom boxy-headings-max-visibility 2
  "Maximum visibility to show when cycling global visibility."
  :type 'number)

(defcustom boxy-headings-tooltips t
  "Show tooltips in a boxy diagram."
  :type 'boolean)

(defcustom boxy-headings-tooltip-timeout 0.5
  "Idle time before showing tooltip in a boxy diagram."
  :type 'number)

(defcustom boxy-headings-tooltip-max-width 30
  "Maximum width of all tooltips."
  :type 'number)

;;;; Faces

(defface boxy-headings-default nil
  "Default face used in boxy mode.")

(defface boxy-headings-primary
  '((((background dark)) (:foreground "turquoise"))
    (t (:foreground "dark cyan")))
  "Face for highlighting the name of a box.")

(defface boxy-headings-selected
  '((t :foreground "light slate blue"))
  "Face for the current box border under cursor.")

(defface boxy-headings-rel
  '((t :foreground "hot pink"))
  "Face for the box which is related to the box under the cursor.")

(defface boxy-headings-tooltip
  '((((background dark)) (:background "gray30" :foreground "gray"))
    (t (:background "gainsboro" :foreground "dim gray")))
  "Face for tooltips in a boxy diagram.")

;;;; Variables

(defvar boxy-headings-rel-alist
  '(("on top of"       . ("on.+top"))
    ("in front of"     . ("in.+front"))
    ("behind"          . ("behind"))
    ("below"           . ("below"))
    ("to the left of"  . ("left"))
    ("to the right of" . ("right")))
  "Mapping from a boxy relationship to a list of regexes.

Each regex will be tested against the REL property of each
heading.")

;;;; Pretty printing

(cl-defun boxy-headings-pp (box
                       &key
                       (display-buffer-fn 'display-buffer-pop-up-window)
                       (visibility boxy-headings-default-visibility)
                       (max-visibility boxy-headings-max-visibility)
                       select
                       header
                       (default-margin-x boxy-headings-margin-x)
                       (default-margin-y boxy-headings-margin-y)
                       (default-padding-x boxy-headings-padding-x)
                       (default-padding-y boxy-headings-padding-y)
                       (flex-width boxy-headings-flex-width)
                       (tooltips boxy-headings-tooltips)
                       (tooltip-timeout boxy-headings-tooltip-timeout)
                       (tooltip-max-width boxy-headings-tooltip-max-width)
                       (default-face 'boxy-headings-default)
                       (primary-face 'boxy-headings-primary)
                       (tooltip-face 'boxy-headings-tooltip)
                       (rel-face 'boxy-headings-rel)
                       (selected-face 'boxy-headings-selected))
  "Pretty print BOX in a popup buffer.

If HEADER is passed in, it will be printed above the diagram.

DISPLAY-BUFFER-FN is used to display the diagram, by
default `display-buffer-pop-up-window'.

If SELECT is non-nil, select the boxy window after displaying
it.

VISIBILITY is the initial visibility of children and
MAX-VISIBILITY is the maximum depth to display when cycling
visibility.

DEFAULT-MARGIN-X, DEFAULT-MARGIN-Y, DEFAULT-PADDING-X and
DEFAULT-PADDING-Y will be the fallback values to use if a box's
margin and padding slots are not set.

When adding boxes, boxy will try to keep the width below
FLEX-WIDTH.

If TOOLTIPS is nil, don't show any tooltips.

TOOLTIP-TIMEOUT is the idle time to wait before showing a
tooltip.

TOOLTIP-MAX-WIDTH is the maximum width of a tooltip.  Lines
longer than this will be truncated.

DEFAULT-FACE, PRIMARY-FACE, TOOLTIP-FACE, REL-FACE, and
SELECTED-FACE can be set to change the appearance of the boxy
diagram."
  (boxy-pp box
           :display-buffer-fn display-buffer-fn
           :visibility visibility
           :max-visibility max-visibility
           :select select
           :header header
           :default-margin-x default-margin-x
           :default-margin-y default-margin-y
           :default-padding-x default-padding-x
           :default-padding-y default-padding-y
           :flex-width flex-width
           :tooltips tooltips
           :tooltip-timeout tooltip-timeout
           :tooltip-max-width tooltip-max-width
           :default-face default-face
           :primary-face primary-face
           :tooltip-face tooltip-face
           :rel-face rel-face
           :selected-face selected-face))

;;;; Commands

;;;###autoload
(defun boxy-headings ()
  "View all org headings as a boxy diagram."
  (interactive)
  (let ((path (seq-filter
               #'identity
               (append (list (org-entry-get nil "ITEM"))
                       (reverse (org-get-outline-path)))))
        (world (save-excursion (boxy-headings--parse-headings)))
        match)
    (boxy-headings-pp world
             :display-buffer-fn 'display-buffer-same-window
             :select t)
    (while (and path (or (not match) (not (boxy-is-visible match t))))
      (setq match (boxy-find-matching (boxy-box :name (pop path)) world)))
    (when match
      (with-current-buffer (get-buffer "*Boxy*")
        (boxy-jump-to-box match)))))

;;;; Boxy implementation

(defun boxy-headings--add-heading (heading parent)
  "Add HEADING to world as a child of PARENT."
  (with-slots (markers (parent-level level)) parent
    (with-current-buffer (marker-buffer (car markers))
      (let* ((partitioned (seq-group-by
                           (lambda (h)
                             (if (member (boxy-headings--get-rel
                                          (org-element-property :begin h))
                                         boxy-children-relationships)
                                 'children
                               'siblings))
                           (cddr heading)))
             (children (alist-get 'children partitioned))
             (siblings (alist-get 'siblings partitioned))
             (pos (org-element-property :begin heading))
             (columns (save-excursion (goto-char pos) (org-columns--collect-values)))
             (max-column-length (apply #'max 0
                                       (mapcar
                                        (lambda (column)
                                          (length (cadr (car column))))
                                        columns)))
             (rel (boxy-headings--get-rel pos))
             (level (if (member rel boxy-children-relationships)
                        (+ 1 parent-level)
                      parent-level))
             (name (org-element-property :title heading))
             (box (boxy-box :name (if (string-match org-link-bracket-re name)
                                      (match-string 2 name)
                                    name)
                            :rel rel
                            :level level
                            :rel-box parent
                            :parent parent
                            :tooltip (mapconcat
                                       (lambda (column)
                                         (format
                                          (concat "%" (number-to-string max-column-length) "s : %s")
                                          (cadr (car column))
                                          (cadr column)))
                                       columns
                                       "\n")
                            :markers (list (set-marker (point-marker) pos))
                            :post-jump-hook 'org-reveal
                            :in-front (string= rel "in front of")
                            :on-top (string= rel "on top of")
                            :y-order (cond
                                      ((string= rel "in front of") 1.0e+INF)
                                      ((string= rel "on top of") -1.0e+INF)
                                      (t 0))
                            :primary t)))
        (boxy-add-next box parent)
        (if children
            (object-add-to-list box :expand-children
                                `(lambda (box)
                                   (mapc
                                    (lambda (h) (boxy-headings--add-heading h box))
                                    ',children))))
        (if siblings
            (object-add-to-list box :expand-siblings
                                `(lambda (box)
                                   (mapc
                                    (lambda (h) (boxy-headings--add-heading h box))
                                    ',siblings))))))))

;;;; Utility expressions

(defun boxy-headings--parse-headings ()
  "Create a `boxy-box' from the current buffer's headings."
  (org-columns-get-format)
  (let* ((headings (cddr (org-element-parse-buffer 'headline)))
         (title (cadr (car (org-collect-keywords '("title")))))
         (world (boxy-box))
         (document (boxy-box :name (or title (buffer-name) "Document")
                             :tooltip ""
                             :markers (list (point-min-marker)))))
    (boxy-add-next document world)
    (mapc
     (lambda (heading)
        (boxy-headings--add-heading heading document))
     headings)
    world))

(defun boxy-headings--get-rel (&optional pos)
  "Get the boxy relationship from an org heading at POS.

POS can be nil to use the heading at point.

The default relationship is 'in'."
  (let ((heading-rel (org-entry-get pos "REL")))
    (if (not heading-rel)
        "in"
      (seq-find
       (lambda (rel)
         (seq-some
          (lambda (pattern)
            (string-match-p pattern heading-rel))
          (alist-get rel boxy-headings-rel-alist
                     nil nil #'equal)))
       boxy-relationships
       "in"))))

(provide 'boxy-headings)

;;; boxy-headings.el ends here
