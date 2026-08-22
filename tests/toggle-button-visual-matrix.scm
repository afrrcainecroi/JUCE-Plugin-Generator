;; Visual metric matrix for the concrete toggle-button TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/toggle-button-visual-matrix.scm

(use-modules (oop goops)
             (generator-app code-generator))

(define toggle-profiles
  '(("COMPACT" "Compact" 7 4 3)
    ("STANDARD" "Standard" 27 6 4)
    ("EXTENDED" "Extended" 47 8 5)))

(define (make-toggle-caption logical-code caption profile profile-code row col)
  (make <label>
    #:id (string-append "toggleMatrix" logical-code profile-code "Caption")
    #:text (string-append caption " / " profile)
    #:justification 'centred
    #:row row
    #:col (- col 2)
    #:row-span 1
    #:col-span 12
    #:margin-tb 0
    #:margin-lr 0))

(define (make-toggle-specimen logical-code caption profile profile-code text state
                              row col row-span col-span)
  (let ((reference (string-append "toggleMatrix" logical-code profile-code)))
    (make <normal-toggle-button>
      #:id reference
      #:text text
      #:default-state state
      #:parameter-id reference
      #:parameter-name (string-append caption " " profile)
      #:processor-reference reference
      #:version-hint 1
      #:row row
      #:col col
      #:row-span row-span
      #:col-span col-span
      #:margin-tb 0
      #:margin-lr 0)))

(define (make-toggle-triplet logical-code caption band-row text state)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-toggle-caption logical-code caption name profile-code band-row col)
       (make-toggle-specimen
        logical-code caption name profile-code text state
        (- (+ band-row 7) row-span) col row-span col-span)))
   toggle-profiles))

(define (toggle-button-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio (exact->inexact (/ 60 35))
    #:width 1800)
  (make <grid>
    #:rows 35
    #:cols 60
    #:show-grid #t)

  (make-toggle-triplet "ABaseOff" "A BASE OFF" 1 "" #f)
  (make-toggle-triplet "BShortOff" "B SHORT OFF" 8 "ON" #f)
  (make-toggle-triplet "CLongOff" "C LONG OFF" 15 "VERY LONG TOGGLE LABEL" #f)
  (make-toggle-triplet "DShortOn" "D SHORT ON" 22 "ON" #t)
  (make-toggle-triplet "ELongOn" "E LONG ON" 29 "VERY LONG TOGGLE LABEL" #t))

(MakeNewProject "toggle-button-visual-matrix"
                toggle-button-visual-matrix-interface)
