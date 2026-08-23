;; Visual test matrix for the meter TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/meter-visual-matrix.scm
;;
;; The DSL has no meter orientation PROPERTY.  A segmented meter becomes
;; vertical when height > width and horizontal otherwise.  The footprints
;; below deliberately exercise that real renderer contract.

(use-modules (oop goops)
             (generator-app code-generator))

(define vertical-profiles
  '(("COMPACT" "Compact" 3 10)
    ("STANDARD" "Standard" 4 14)
    ("EXTENDED" "Extended" 5 18)))

(define horizontal-profiles
  '(("COMPACT" "Compact" 10 3)
    ("STANDARD" "Standard" 14 4)
    ("EXTENDED" "Extended" 18 5)))

(define analog-profiles
  '(("COMPACT" "Compact" 6 5)
    ("STANDARD" "Standard" 9 7)
    ("EXTENDED" "Extended" 12 9)))

(define (make-caption id text row col col-span)
  (make <label>
    #:id (string-append id "Caption")
    #:text text
    #:justification 'centred
    #:row row
    #:col col
    #:row-span 1
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define (make-meter id properties row col row-span col-span)
  (apply make
         (append
          (list <meter>
                #:id id
                #:row row
                #:col col
                #:row-span row-span
                #:col-span col-span
                #:margin-tb 0
                #:margin-lr 0)
          properties)))

(define (make-vertical-case case-code caption col properties)
  (make-caption (string-append "meterVertical" case-code)
                (string-append case-code " " caption) 1 col 9)
  (let loop ((profiles vertical-profiles) (row 3))
    (unless (null? profiles)
      (let* ((profile (car profiles))
             (name (list-ref profile 0))
             (profile-code (list-ref profile 1))
             (col-span (list-ref profile 2))
             (row-span (list-ref profile 3)))
        (make-caption
         (string-append "meterVertical" case-code profile-code "Profile")
         name row col 9)
        (make-meter
         (string-append "meterVertical" case-code profile-code)
         properties (+ row 1) (+ col 2) row-span col-span)
        (loop (cdr profiles) (+ row row-span 2))))))

(define (make-horizontal-case case-code caption row col properties)
  (make-caption (string-append "meterHorizontal" case-code)
                (string-append case-code " " caption) row col 20)
  (let loop ((profiles horizontal-profiles) (specimen-row (+ row 2)))
    (unless (null? profiles)
      (let* ((profile (car profiles))
             (name (list-ref profile 0))
             (profile-code (list-ref profile 1))
             (col-span (list-ref profile 2))
             (row-span (list-ref profile 3)))
        (make-caption
         (string-append "meterHorizontal" case-code profile-code "Profile")
         name specimen-row col 20)
        (make-meter
         (string-append "meterHorizontal" case-code profile-code)
         properties (+ specimen-row 1) (+ col 1) row-span col-span)
        (loop (cdr profiles) (+ specimen-row row-span 2))))))

(define (make-analog-case case-code caption col properties)
  (make-caption (string-append "meterAnalog" case-code)
                (string-append case-code " " caption) 94 col 14)
  (let loop ((profiles analog-profiles) (row 96))
    (unless (null? profiles)
      (let* ((profile (car profiles))
             (name (list-ref profile 0))
             (profile-code (list-ref profile 1))
             (col-span (list-ref profile 2))
             (row-span (list-ref profile 3)))
        (make-caption
         (string-append "meterAnalog" case-code profile-code "Profile")
         name row col 14)
        (make-meter
         (string-append "meterAnalog" case-code profile-code)
         (append '(#:style analog) properties)
         (+ row 1) (+ col 1) row-span col-span)
        (loop (cdr profiles) (+ row row-span 2))))))

(define (meter-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio 0.75
    #:width 1800)
  (make <grid>
    #:rows 126
    #:cols 90
    #:show-grid #t)

  ;; Segmented vertical.  KineticMeter has no DSL initial-level/peak PROPERTY;
  ;; A-D therefore expose the current static/runtime limitation instead of
  ;; inventing a way to seed the renderer.
  (make-vertical-case "A" "LOW VALUE" 2
                      '(#:style segmented #:scale-type db #:num-segments 20))
  (make-vertical-case "B" "MEDIUM VALUE" 13
                      '(#:style segmented #:scale-type db #:num-segments 20))
  (make-vertical-case "C" "HIGH VALUE" 24
                      '(#:style segmented #:scale-type db #:num-segments 20))
  (make-vertical-case "D" "PEAK" 35
                      '(#:style segmented #:scale-type db #:num-segments 20))
  (make-vertical-case "E" "SCALE DB" 46
                      '(#:style segmented #:scale-type db #:num-segments 20))
  (make-vertical-case "F" "SCALE LINEAR" 57
                      '(#:style segmented #:scale-type linear #:num-segments 20))
  (make-vertical-case "G" "SCALE VU" 68
                      '(#:style segmented #:scale-type vu #:num-segments 8))
  (make-vertical-case "H" "SCALE LINEAR / SINGLE SEGMENT" 79
                      '(#:style segmented #:scale-type linear #:num-segments 1))

  ;; Segmented horizontal.  Four cases per row keep the exact 10x3, 14x4 and
  ;; 18x5 specimens directly comparable.
  (make-horizontal-case "A" "LOW VALUE" 52 2
                        '(#:style segmented #:scale-type db #:num-segments 20))
  (make-horizontal-case "B" "MEDIUM VALUE" 52 24
                        '(#:style segmented #:scale-type db #:num-segments 20))
  (make-horizontal-case "C" "HIGH VALUE" 52 46
                        '(#:style segmented #:scale-type db #:num-segments 20))
  (make-horizontal-case "D" "PEAK" 52 68
                        '(#:style segmented #:scale-type db #:num-segments 20))
  (make-horizontal-case "E" "SCALE DB" 72 2
                        '(#:style segmented #:scale-type db #:num-segments 20))
  (make-horizontal-case "F" "SCALE LINEAR" 72 24
                        '(#:style segmented #:scale-type linear #:num-segments 20))
  (make-horizontal-case "G" "SCALE VU / SEGMENTED 8" 72 46
                        '(#:style segmented #:scale-type vu #:num-segments 8))
  (make-horizontal-case "H" "SCALE LINEAR" 72 68
                        '(#:style segmented #:scale-type linear #:num-segments 20))

  ;; Analog: square-ish profiles plus a deliberately narrow 6x9 diagnostic
  ;; in case F.  It tests the height-only radius calculation without changing
  ;; the three requested profile contracts.
  (make-analog-case "A" "SCALE DB / LOW NEEDLE" 2
                    '(#:scale-type db))
  (make-analog-case "B" "SCALE LINEAR / MEDIUM NEEDLE" 17
                    '(#:scale-type linear))
  (make-analog-case "C" "SCALE VU / HIGH NEEDLE" 32
                    '(#:scale-type vu))
  (make-analog-case "D" "SCALE DB + LABELS" 47
                    '(#:scale-type db))
  (make-analog-case "E" "SHARP NEEDLE" 62
                    '(#:scale-type db #:is-sharp #t))
  (make-caption "meterAnalogFNarrow" "F NARROW 6x9 RADIUS CLIP" 94 77 13)
  (make-meter "meterAnalogFNarrowSpecimen"
              '(#:style analog #:scale-type db)
              96 80 9 6))

(MakeNewProject "meter-visual-matrix"
                meter-visual-matrix-interface)
