;; Visual and functional diagnostic for the link TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/link-visual-functional-test.scm
;;
;; This intentionally does not define normative metrics or compensate for
;; runtime behaviour. Inspect the generated C++ before changing the runtime.

(use-modules (oop goops)
             (generator-app code-generator))

;; Experimental horizontal footprints, aligned with the header/footer matrix.
(define link-profiles
  '(("COMPACT" "Compact" 3 16 2)
    ("STANDARD" "Standard" 31 24 3)
    ("EXTENDED" "Extended" 59 32 4)))

(define (profile-name profile) (list-ref profile 0))
(define (profile-code profile) (list-ref profile 1))
(define (profile-col profile) (list-ref profile 2))
(define (profile-col-span profile) (list-ref profile 3))
(define (profile-row-span profile) (list-ref profile 4))

(define (make-link-caption case-code caption profile row)
  (make <label>
    #:id (string-append "linkMatrix" case-code
                        (profile-code profile) "Caption")
    #:text (string-append caption " / " (profile-name profile))
    #:justification 'centred
    #:row row
    #:col (profile-col profile)
    #:row-span 1
    #:col-span (profile-col-span profile)
    #:margin-tb 0
    #:margin-lr 0))

(define (make-link-specimen case-code profile text url properties row)
  (apply make
         (append
          (list <link>
                #:id (string-append "linkMatrix" case-code
                                    (profile-code profile))
                #:text text
                #:url url
                #:row (- (+ row 6) (profile-row-span profile))
                #:col (profile-col profile)
                #:row-span (profile-row-span profile)
                #:col-span (profile-col-span profile)
                #:margin-tb 0
                #:margin-lr 0)
          properties)))

(define (make-link-triplet case-code caption band-row text url properties)
  (for-each
   (lambda (profile)
     (make-link-caption case-code caption profile band-row)
     (make-link-specimen case-code profile text url properties band-row))
   link-profiles))

(define (link-visual-functional-interface dst-folder project-name)
  (make <screen>
    #:ratio 1.5
    #:width 1800)
  (make <grid>
    #:rows 54
    #:cols 90
    #:show-grid #t)

  (make-link-triplet
   "AShortText" "A SHORT TEXT" 1
   "Website" "https://example.com/test-a" '())
  (make-link-triplet
   "BMediumText" "B MEDIUM TEXT" 7
   "Open documentation" "https://example.com/test-b" '())
  (make-link-triplet
   "CLongText" "C LONG TEXT" 13
   "Visit the official project documentation"
   "https://example.com/test-a" '())

  ;; D/E/F deliberately use identical text and geometry.
  (make-link-triplet
   "DLeftJustification" "D JUSTIFICATION LEFT" 19
   "Link alignment sample" "https://example.com/test-a"
   '(#:justification left))
  (make-link-triplet
   "ECentredJustification" "E JUSTIFICATION CENTRED" 25
   "Link alignment sample" "https://example.com/test-b"
   '(#:justification centred))
  (make-link-triplet
   "FRightJustification" "F JUSTIFICATION RIGHT" 31
   "Link alignment sample" "https://example.com/test-a"
   '(#:justification right))

  (make-link-triplet
   "GSmallFont" "G SMALL FONT-SIZE" 37
   "Link font sample" "https://example.com/test-a"
   '(#:font-size 10.0))
  (make-link-triplet
   "HLargeFont" "H LARGE FONT-SIZE" 43
   "Link font sample" "https://example.com/test-b"
   '(#:font-size 24.0))

  ;; Dedicated functional probes. footerLink intentionally exercises the
  ;; current stable template path; the second instance tests per-instance URL
  ;; propagation. Both identifiers are valid C++ identifiers.
  (make <link>
    #:id "footerLink"
    #:text "Functional URL A"
    #:url "https://example.com/test-a"
    #:justification 'left
    #:font-size 14.0
    #:row 49
    #:col 3
    #:row-span 3
    #:col-span 24
    #:margin-tb 0
    #:margin-lr 0)
  (make <link>
    #:id "functionalLinkTestB"
    #:text "Functional URL B"
    #:url "https://example.com/test-b"
    #:justification 'right
    #:font-size 14.0
    #:row 49
    #:col 59
    #:row-span 3
    #:col-span 24
    #:margin-tb 0
    #:margin-lr 0))

(MakeNewProject "link-visual-functional-test"
                link-visual-functional-interface)
