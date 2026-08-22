;; Visual test for discrete textual tick labels and current VALUE labels.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/linear-slider-discrete-labels.scm

(load "linear-slider-matrix-common.scm")

(define discrete-labels '("SINE" "TRI" "SQUARE" "RAMP"))

(define (make-discrete-caption id text row col col-span)
  (make <label>
    #:id id
    #:text text
    #:justification 'centred
    #:row row
    #:col col
    #:row-span 1
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define (make-discrete-slider orientation profile default
                              row col row-span col-span)
  (make-matrix-linear
   orientation "DISCRETE" profile row col row-span col-span
   #:min 0
   #:max 3
   #:default default
   #:interval 1
   #:show-value #t
   #:show-ticks #t
   #:show-labels #t
   #:tick-count 4
   #:tick-labels discrete-labels))

(define (linear-slider-discrete-labels-interface dst-folder project-name)
  ;; 66x32 keeps grid cells approximately square at the nominal size.
  (make <screen>
    #:ratio (exact->inexact (/ 66 32))
    #:width 1800)
  (make <grid>
    #:rows 32
    #:cols 66
    #:show-grid #t)

  ;; Horizontal footprints: 10x3, 14x4, 18x5.
  (make-discrete-caption "Discrete Horizontal Compact Label"
                         "H COMPACT: 0 / SINE" 1 2 10)
  (make-discrete-slider 'horizontal "HCOMPACT" 0 5 2 3 10)

  (make-discrete-caption "Discrete Horizontal Standard Label"
                         "H STANDARD: 1 / TRI" 1 24 14)
  (make-discrete-slider 'horizontal "HSTANDARD" 1 4 24 4 14)

  (make-discrete-caption "Discrete Horizontal Extended Label"
                         "H EXTENDED: 2 / SQUARE" 1 47 18)
  (make-discrete-slider 'horizontal "HEXTENDED" 2 3 47 5 18)

  ;; Vertical footprints: 3x10, 4x14, 5x18.
  (make-discrete-caption "Discrete Vertical Compact Label"
                         "V COMPACT: 3 / RAMP" 10 2 10)
  (make-discrete-slider 'vertical "VCOMPACT" 3 21 5 10 3)

  (make-discrete-caption "Discrete Vertical Standard Label"
                         "V STANDARD: 0 / SINE" 10 22 12)
  (make-discrete-slider 'vertical "VSTANDARD" 0 17 25 14 4)

  (make-discrete-caption "Discrete Vertical Extended Label"
                         "V EXTENDED: 1 / TRI" 10 44 14)
  (make-discrete-slider 'vertical "VEXTENDED" 1 13 49 18 5))

(MakeNewProject "linear-slider-discrete-labels"
                linear-slider-discrete-labels-interface)
