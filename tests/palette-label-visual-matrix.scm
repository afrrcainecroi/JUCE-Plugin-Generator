;; Visual matrix for the concrete palette-label DSL TYPE. It intentionally
;; compares label geometry while varying both inherited and palette metadata.

(use-modules (oop goops)
             (generator-app code-generator))

(define profiles
  '(("COMPACT" 1 8 2)
    ("STANDARD" 11 12 3)
    ("EXTENDED" 25 16 4)))

(define (make-caption id text row)
  (make <label>
    #:id id #:text text #:justification 'centred
    #:row row #:col 1 #:row-span 1 #:col-span 48
    #:margin-tb 0 #:margin-lr 0))

(define (make-palette-label-case id text row properties)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (col (list-ref profile 1))
           (col-span (list-ref profile 2))
           (row-span (list-ref profile 3)))
       (apply make
              (append
               (list <palette-label>
                     #:id (string-append id name)
                     #:text text
                     #:row row
                     #:col col
                     #:row-span row-span
                     #:col-span col-span
                     #:margin-tb 0
                     #:margin-lr 0)
               properties))))
   profiles))

(define (palette-label-visual-matrix-interface dst-folder project-name)
  (make <screen> #:ratio 1.25 #:width 1500)
  (make <grid> #:rows 46 #:cols 48 #:show-grid #t)

  (make-caption "shortCaption" "SHORT / PLAIN / CENTRED" 1)
  (make-palette-label-case
   "short" "Theme" 2
   '(#:font-size 12.0 #:font-style plain #:justification centred
     #:enable #t #:default-theme 3))

  (make-caption "longCaption" "LONG / BOLD / LEFT" 8)
  (make-palette-label-case
   "long" "A deliberately long palette theme label" 9
   '(#:font-size 12.0 #:font-style bold #:justification centred-left
     #:minimum-horizontal-scale 0.7 #:enable #t #:default-theme 8))

  (make-caption "smallCaption" "SMALL FONT / RIGHT" 15)
  (make-palette-label-case
   "small" "Theme" 16
   '(#:font-size 8.0 #:font-style plain #:justification centred-right
     #:enable #t #:default-theme 1))

  (make-caption "largeCaption" "LARGE FONT / BOLD / TOP" 22)
  (make-palette-label-case
   "large" "Theme Palette" 23
   '(#:font-size 24.0 #:font-style bold #:justification top-left
     #:enable #t #:default-theme 17))

  ;; enable/default-theme are palette composition metadata. Direct instances
  ;; remain ordinary juce::Label renderings and expose whether either value
  ;; accidentally changes bounds or decoration.
  (make-caption "disabledCaption" "ENABLE #F / DEFAULT THEME 18 / BOTTOM" 29)
  (make-palette-label-case
   "disabled" "Disabled metadata" 30
   '(#:font-size 12.0 #:font-style plain #:justification bottom-right
     #:enable #f #:default-theme 18))

  (make-caption "colourCaption" "INHERITED TEXT COLOUR / MIN SCALE 1.0" 36)
  (make-palette-label-case
   "colour" "Palette Label" 37
   '(#:font-size 16.0 #:font-style bold #:justification centred
     #:text-colour neon-white #:minimum-horizontal-scale 1.0
     #:enable #t #:default-theme 3)))

(MakeNewProject "palette-label-visual-matrix"
                palette-label-visual-matrix-interface)
