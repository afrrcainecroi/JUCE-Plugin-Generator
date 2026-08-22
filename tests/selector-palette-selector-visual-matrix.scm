;; Joint visual/functional matrix for the selector and palette-selector TYPEs.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/selector-palette-selector-visual-matrix.scm

(use-modules (oop goops)
             (generator-app code-generator))

;; Experimental footprints; these are deliberately not normative metrics.
(define selector-profiles
  '(("COMPACT 8x2" "Compact" 3 8 2)
    ("STANDARD 12x2" "Standard" 22 12 2)
    ("EXTENDED 16x3" "Extended" 44 16 3)))

(define (make-caption id-prefix caption profile profile-code row col)
  (make <label>
    #:id (string-append id-prefix profile-code "Caption")
    #:text (string-append caption " / " profile)
    #:justification 'centred
    #:row row
    #:col (- col 1)
    #:row-span 1
    #:col-span 18
    #:margin-tb 0
    #:margin-lr 0))

(define (make-selector-specimen case-code profile-code items properties
                                row col row-span col-span)
  (apply make
         (append
          (list <selector>
                #:id (string-append "selectorMatrix" case-code profile-code)
                #:items items
                #:row row
                #:col col
                #:row-span row-span
                #:col-span col-span
                #:margin-tb 0
                #:margin-lr 0)
          properties)))

(define (make-selector-triplet case-code caption band-row items properties)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-caption (string-append "selectorMatrix" case-code)
                     caption name profile-code band-row col)
       (make-selector-specimen
        case-code profile-code items properties
        (+ band-row 1) col row-span col-span)))
   selector-profiles))

(define (parameter-properties case-code profile-code)
  (let ((safe-name
         (string-append "selector_matrix_"
                        case-code "_"
                        profile-code)))
    (list #:default-index 2
          #:parameter-id safe-name
          #:parameter-name (string-append "Selector Matrix "
                                          case-code " " profile-code)
          #:processor-reference safe-name
          #:version-hint 1)))

(define (make-parameterized-selector-triplet band-row)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-caption "selectorMatrixHParameterized"
                     "H PARAMETERIZED / CPP-SAFE"
                     name profile-code band-row col)
       (make-selector-specimen
        "HParameterized" profile-code
        '("Low" "Standard" "High")
        (parameter-properties "quality" profile-code)
        (+ band-row 1) col row-span col-span)))
   selector-profiles))

;; Use the real palette helper so the production palette list and its ordering
;; remain the single source of truth.  Index 12 is "Mint (Teal)" (shortest),
;; while index 17 is "Ultraviolet (Violet)" (longest).
(define (make-palette-triplet case-code caption band-row default-theme)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-caption (string-append "paletteSelectorMatrix" case-code)
                     caption name profile-code band-row col)
       (make <palette>
         #:id (string-append "paletteSelectorMatrix" case-code profile-code)
         #:enable #t
         #:default-theme default-theme
         #:title-palette "Theme"
         #:row-palette (+ band-row 1)
         #:col-palette (- col 2)
         #:row-span-palette row-span
         #:col-span-palette 2
         #:margin-tb-palette 0
         #:margin-lr-palette 0
         #:row-selector (+ band-row 1)
         #:col-selector col
         #:row-span-selector row-span
         #:col-span-selector col-span
         #:margin-tb-selector 0
         #:margin-lr-selector 0)))
   selector-profiles))

(define (selector-palette-selector-visual-matrix-interface
         dst-folder project-name)
  (make <screen>
    #:ratio 1.5
    #:width 1800)
  (make <grid>
    #:rows 50
    #:cols 60
    #:show-grid #t)

  (make-selector-triplet "AShort" "A SHORT TEXT" 1
                         '("A" "B" "C")
                         '(#:default-index 1))
  (make-selector-triplet "BMedium" "B MEDIUM TEXT" 5
                         '("Sine" "Triangle" "Square" "Ramp")
                         '(#:default-index 1))
  (make-selector-triplet "CLong" "C LONG TEXT" 9
                         '("Low Quality"
                           "Standard Processing"
                           "Very High Quality Processing")
                         '(#:default-index 3))
  (make-selector-triplet "DDefaultIndex" "D DEFAULT INDEX = 2" 13
                         '("First" "Selected Initially" "Third")
                         '(#:default-index 2))
  (make-selector-triplet "ECentredLeft" "E CENTRED-LEFT" 17
                         '("Left aligned" "Second" "Third")
                         '(#:default-index 1
                           #:justification centred-left))
  (make-selector-triplet "FEnabled" "F ENABLED = TRUE" 21
                         '("Enabled" "Second" "Third")
                         '(#:default-index 1 #:enabled #t))
  (make-selector-triplet "GDisabled" "G ENABLED = FALSE" 25
                         '("Disabled" "Second" "Third")
                         '(#:default-index 1 #:enabled #f))
  (make-parameterized-selector-triplet 29)
  (make-selector-triplet "INonParameterized" "I NON-PARAMETERIZED" 33
                         '("No attachment" "Second" "Third")
                         '(#:default-index 1))

  (make-palette-triplet "ATypical" "PALETTE A TYPICAL / INDEX 3" 37 3)
  (make-palette-triplet "CShortest" "PALETTE C SHORTEST / INDEX 12" 41 12)
  (make-palette-triplet "DLongest" "PALETTE D LONGEST / INDEX 17" 45 17))

(MakeNewProject "selector-palette-selector-visual-matrix"
                selector-palette-selector-visual-matrix-interface)
