;; Visual metric matrix for the text-button TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/text-button-visual-matrix.scm

(use-modules (oop goops)
             (generator-app code-generator))

;; Experimental horizontal footprints; these are not normative metrics.
(define text-button-profiles
  '(("COMPACT" "Compact" 5 5 2)
    ("STANDARD" "Standard" 25 8 3)
    ("EXTENDED" "Extended" 45 12 4)))

(define (make-text-button-caption logical-code caption
                                  profile profile-code row col)
  (make <label>
    #:id (string-append "textButtonMatrix" logical-code
                        profile-code "Caption")
    #:text (string-append caption " / " profile)
    #:justification 'centred
    #:row row
    #:col (- col 2)
    #:row-span 1
    #:col-span 14
    #:margin-tb 0
    #:margin-lr 0))

(define (make-text-button-specimen logical-code profile-code text
                                   row col row-span col-span)
  (make <text-button>
    #:id (string-append "textButtonMatrix" logical-code profile-code)
    #:text text
    #:row row
    #:col col
    #:row-span row-span
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define (make-text-button-triplet logical-code caption band-row text)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-text-button-caption
        logical-code caption name profile-code band-row col)
       (make-text-button-specimen
        logical-code profile-code text
        (- (+ band-row 6) row-span) col row-span col-span)))
   text-button-profiles))

(define (text-button-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio 2.5
    #:width 1800)
  (make <grid>
    #:rows 24
    #:cols 60
    #:show-grid #t)

  (make-text-button-triplet "ABase" "A BASE / VERY SHORT" 1 "A")
  (make-text-button-triplet "BShort" "B SHORT" 7 "LOAD")
  (make-text-button-triplet "CMedium" "C MEDIUM" 13 "RESET ALL")
  (make-text-button-triplet "DLong" "D LONG" 19
                            "EXPORT PRESET TO FILE"))

(MakeNewProject "text-button-visual-matrix"
                text-button-visual-matrix-interface)
