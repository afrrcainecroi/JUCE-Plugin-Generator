;; Joint visual test matrix for the header and footer TYPEs.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/header-footer-visual-matrix.scm

(use-modules (oop goops)
             (generator-app code-generator))

;; Experimental horizontal-banner footprints; these are not normative metrics.
;; At 1800 px, the nominal compact / standard / extended specimens are about
;; 320x29, 480x43, and 640x57 px respectively.
(define banner-profiles
  '(("COMPACT" "Compact" 3 16 2)
    ("STANDARD" "Standard" 31 24 3)
    ("EXTENDED" "Extended" 59 32 4)))

(define (make-matrix-caption type-code case-code caption
                             profile profile-code row col col-span)
  (make <label>
    #:id (string-append type-code "Matrix" case-code
                        profile-code "Caption")
    #:text (string-append caption " / " profile)
    #:justification 'centred
    #:row row
    #:col col
    #:row-span 1
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define (make-banner-specimen class type-code case-code profile-code
                              text properties row col row-span col-span)
  (apply make
         (append
          (list class
                #:id (string-append type-code "Matrix" case-code profile-code)
                #:text text
                #:row row
                #:col col
                #:row-span row-span
                #:col-span col-span
                #:margin-lr 0)
          properties)))

(define (make-banner-triplet class type-code case-code caption band-row
                             text properties)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-matrix-caption type-code case-code caption
                            name profile-code band-row col col-span)
       (make-banner-specimen class type-code case-code profile-code
                             text properties
                             (- (+ band-row 6) row-span)
                             col row-span col-span)))
   banner-profiles))

(define (make-footer-justification-triplet band-row)
  ;; One footprint per supported justification keeps the comparison on a
  ;; single row: compact=left, standard=centred, extended=right.
  (for-each
   (lambda (profile justification justification-code)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-matrix-caption
        "footer" "FJustification" "F JUSTIFICATION"
        (string-append name " / " justification-code)
        profile-code band-row col col-span)
       (make-banner-specimen
        <footer> "footer" "FJustification" profile-code
        "Copyright (c) 2025 AF-Audio"
        (list #:font-size 12.0
              #:font-style 'plain
              #:justification justification
              #:margin-tb 0)
        (- (+ band-row 6) row-span) col row-span col-span)))
   banner-profiles
   '(left centred right)
   '("LEFT" "CENTRED" "RIGHT")))

(define (header-footer-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio 1.5
    #:width 1800)
  (make <grid>
    #:rows 84
    #:cols 90
    #:show-grid #t)

  ;; HEADER: the helper's current style is bold, 32 px, centred, margin 0.
  (make-banner-triplet <header> "header" "AShortText"
                       "HEADER A SHORT TEXT" 1 "PLUGIN"
                       '(#:font-size 32.0 #:font-style bold
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <header> "header" "BTypicalText"
                       "HEADER B TYPICAL TEXT" 7 "YAPlugin"
                       '(#:font-size 32.0 #:font-style bold
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <header> "header" "CLongText"
                       "HEADER C LONG TEXT" 13
                       "SPECTRAL PROCESSING WORKSTATION"
                       '(#:font-size 32.0 #:font-style bold
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <header> "header" "DSmallFont"
                       "HEADER D SMALL FONT-SIZE" 19 "YAPlugin"
                       '(#:font-size 16.0 #:font-style bold
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <header> "header" "ETypicalFont"
                       "HEADER E HELPER FONT-SIZE 32" 25 "YAPlugin"
                       '(#:font-size 32.0 #:font-style bold
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <header> "header" "FLargeFont"
                       "HEADER F LARGE FONT-SIZE" 31 "YAPlugin"
                       '(#:font-size 48.0 #:font-style bold
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <header> "header" "GCentred"
                       "HEADER G CENTRED" 37 "CENTRED HEADER"
                       '(#:font-size 32.0 #:font-style bold
                         #:justification centred #:margin-tb 0))

  ;; FOOTER: isolate text, style, size, justification, and helper margin.
  (make-banner-triplet <footer> "footer" "AShortText"
                       "FOOTER A SHORT TEXT" 43 "INFO"
                       '(#:font-size 12.0 #:font-style plain
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <footer> "footer" "BCopyright"
                       "FOOTER B TYPICAL COPYRIGHT" 49
                       "Copyright (c) 2025 AF-Audio"
                       '(#:font-size 12.0 #:font-style plain
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <footer> "footer" "CLongText"
                       "FOOTER C LONG TEXT" 55
                       "Copyright (c) 2025 AF-Audio - All rights reserved"
                       '(#:font-size 12.0 #:font-style plain
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <footer> "footer" "DPlain"
                       "FOOTER D PLAIN FONT-STYLE" 61
                       "Copyright (c) 2025 AF-Audio"
                       '(#:font-size 12.0 #:font-style plain
                         #:justification centred #:margin-tb 0))
  (make-banner-triplet <footer> "footer" "ETypicalFont"
                       "FOOTER E HELPER FONT-SIZE 12" 67
                       "Copyright (c) 2025 AF-Audio"
                       '(#:font-size 12.0 #:font-style plain
                         #:justification centred #:margin-tb 0))
  (make-footer-justification-triplet 73)
  (make-banner-triplet <footer> "footer" "GHelperMargin"
                       "FOOTER G HELPER MARGIN-TB 12" 79
                       "Copyright (c) 2025 AF-Audio"
                       '(#:font-size 12.0 #:font-style plain
                         #:justification centred #:margin-tb 12)))

(MakeNewProject "header-footer-visual-matrix"
                header-footer-visual-matrix-interface)
