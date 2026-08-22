;; Dedicated DSL specification for visual rotary-slider metric studies.
;;
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/rotary-metrics-test.scm

(use-modules (oop goops)
             (generator-app code-generator))

;; Screen and grid controls. A 2:1 screen with a 36x18 grid keeps grid cells
;; approximately square after the template's fixed 10 px editor inset.
(define rotary-metrics-screen-width 1200)
(define rotary-metrics-screen-ratio 2.0)
(define rotary-metrics-grid-rows 18)
(define rotary-metrics-grid-cols 36)

;; Profile layout controls. Change row-span and col-span together to preserve
;; a square grid footprint. Rows are selected so all three profiles end at
;; the same grid line (row 13).
(define compact-row 7)
(define compact-col 2)
(define compact-row-span 6)
(define compact-col-span 6)

(define standard-row 5)
(define standard-col 12)
(define standard-row-span 8)
(define standard-col-span 8)

(define extended-row 3)
(define extended-col 25)
(define extended-row-span 10)
(define extended-col-span 10)

(define (make-metrics-rotary id parameter-id processor-reference title
                             row col row-span col-span
                             show-ticks show-labels)
  (make <rotary-slider>
    #:id id

    ;; Identical functional profile for all three controls. Parameter identity
    ;; is necessarily unique so that the generated APVTS remains valid.
    #:parameter-id parameter-id
    #:parameter-name id
    #:processor-reference processor-reference
    #:version-hint 1
    #:min 0.0
    #:max 100.0
    #:default 50.0
    #:interval 1.0
    #:scale 'linear
    #:value-type 'default
    #:suffix " %"

    ;; Visual profile.
    #:title title
    #:show-value #t
    #:show-ticks show-ticks
    #:show-labels show-labels
    #:tick-count 5
    #:tick-mode 'all
    #:tick-labels '()

    ;; Layout remains entirely in the DSL.
    #:row row
    #:col col
    #:row-span row-span
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define (rotary-metrics-test-interface dst-folder project-name)
  (make <screen>
    #:ratio rotary-metrics-screen-ratio
    #:width rotary-metrics-screen-width)

  (make <grid>
    #:rows rotary-metrics-grid-rows
    #:cols rotary-metrics-grid-cols
    #:show-grid #t)

  (make-metrics-rotary
   "Rotary Metrics Compact"
   "rotaryMetricsCompact"
   "rotaryMetricsCompact"
   "COMPACT"
   compact-row compact-col compact-row-span compact-col-span
   #f #f)

  (make-metrics-rotary
   "Rotary Metrics Standard"
   "rotaryMetricsStandard"
   "rotaryMetricsStandard"
   "STANDARD"
   standard-row standard-col standard-row-span standard-col-span
   #f #f)

  (make-metrics-rotary
   "Rotary Metrics Extended"
   "rotaryMetricsExtended"
   "rotaryMetricsExtended"
   "EXTENDED"
   extended-row extended-col extended-row-span extended-col-span
   #t #t))

(MakeNewProject "pppbuttavia" rotary-metrics-test-interface)
