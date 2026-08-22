;; Visual test matrix for the label TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/label-visual-matrix.scm

(use-modules (oop goops)
             (generator-app code-generator))

;; Experimental horizontal footprints; these are not normative metrics.
(define label-profiles
  '(("COMPACT" "Compact" 3 8 2)
    ("STANDARD" "Standard" 23 12 3)
    ("EXTENDED" "Extended" 43 16 4)))

(define (make-label-caption case-code caption profile profile-code row col)
  (make <label>
    #:id (string-append "labelMatrix" case-code profile-code "Caption")
    #:text (string-append caption " / " profile)
    #:justification 'centred
    #:row row
    #:col (- col 2)
    #:row-span 1
    #:col-span 12
    #:margin-tb 0
    #:margin-lr 0))

(define (make-label-specimen case-code profile-code text properties
                             row col row-span col-span)
  (apply make
         (append
          (list <label>
                #:id (string-append "labelMatrix" case-code profile-code)
                #:text text
                #:row row
                #:col col
                #:row-span row-span
                #:col-span col-span
                #:margin-tb 0
                #:margin-lr 0)
          properties)))

(define (make-label-triplet case-code caption band-row text properties)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-label-caption
        case-code caption name profile-code band-row col)
       (make-label-specimen
        case-code profile-code text properties
        (- (+ band-row 5) row-span) col row-span col-span)))
   label-profiles))

(define (label-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio 1.5
    #:width 1800)
  (make <grid>
    #:rows 51
    #:cols 60
    #:show-grid #t)

  (make-label-triplet "AShortText" "A SHORT TEXT" 1 "GAIN" '())
  (make-label-triplet "BMediumText" "B MEDIUM TEXT" 6 "INPUT GAIN" '())
  (make-label-triplet "CLongText" "C LONG TEXT" 11
                      "SPECTRAL PROCESSING SECTION" '())

  (make-label-triplet "DSmallFont" "D SMALL DSL FONT-SIZE" 16
                      "REFERENCE LABEL" '(#:font-size 10.0))
  (make-label-triplet "ELargeFont" "E LARGE DSL FONT-SIZE" 21
                      "REFERENCE LABEL" '(#:font-size 24.0))

  (make-label-triplet "FPlainFont" "F PLAIN DSL FONT-STYLE" 26
                      "REFERENCE LABEL" '(#:font-style plain))
  (make-label-triplet "GBoldFont" "G BOLD DSL FONT-STYLE" 31
                      "REFERENCE LABEL" '(#:font-style bold))

  (make-label-triplet "HLeftJustification" "H LEFT JUSTIFICATION" 36
                      "ALIGNMENT SAMPLE" '(#:justification left))
  (make-label-triplet "ICentredJustification" "I CENTRED JUSTIFICATION" 41
                      "ALIGNMENT SAMPLE" '(#:justification centred))
  (make-label-triplet "JRightJustification" "J RIGHT JUSTIFICATION" 46
                      "ALIGNMENT SAMPLE" '(#:justification right)))

(MakeNewProject "label-visual-matrix"
                label-visual-matrix-interface)
