;; Shared DSL helpers for the Rotary Visual Test Matrix.

(use-modules (oop goops)
             (generator-app code-generator))

(define rotary-matrix-screen-width 1800)
(define rotary-matrix-grid-cols 54)
(define rotary-matrix-band-rows 10)

;; Change row-span and col-span together to preserve a square footprint.
(define compact-span 5)
(define standard-span 7)
(define extended-span 9)

(define compact-col 3)
(define standard-col 21)
(define extended-col 40)

(define (make-rotary-matrix-screen case-count)
  (let* ((rows (* rotary-matrix-band-rows case-count))
         (ratio (exact->inexact (/ rotary-matrix-grid-cols rows))))
    (make <screen>
      #:ratio ratio
      #:width rotary-matrix-screen-width)
    (make <grid>
      #:rows rows
      #:cols rotary-matrix-grid-cols
      #:show-grid #t)))

(define (profile-id case-code profile)
  (string-append "Rotary Matrix " case-code " " profile))

(define (profile-reference case-code profile)
  (string-append "rotaryMatrix" case-code profile))

(define (make-case-label case-code profile row col span)
  (make <label>
    #:id (string-append "Case " case-code " " profile " Label")
    #:text (string-append case-code " — " profile)
    #:justification 'centred
    #:row row
    #:col col
    #:row-span 1
    #:col-span span
    #:margin-tb 0
    #:margin-lr 0))

(define* (make-matrix-rotary case-code profile row col span
                             #:key
                             (title "")
                             (show-value #f)
                             (show-ticks #f)
                             (show-labels #f)
                             (tick-count 5)
                             (tick-labels '())
                             (icon-type -1)
                             (icon-set "")
                             (morph-icon #f)
                             (min 0.0)
                             (max 100.0)
                             (default 50.0)
                             (interval 1.0))
  (let ((id (profile-id case-code profile))
        (reference (profile-reference case-code profile)))
    (make <rotary-slider>
      #:id id
      #:parameter-id reference
      #:parameter-name id
      #:processor-reference reference
      #:version-hint 1
      #:min min
      #:max max
      #:default default
      #:interval interval
      #:scale 'linear
      #:value-type 'default
      #:suffix ""
      #:title title
      #:show-value show-value
      #:show-ticks show-ticks
      #:show-labels show-labels
      #:tick-count tick-count
      #:tick-mode 'all
      #:tick-labels tick-labels
      #:icon-type icon-type
      #:icon-set icon-set
      #:morph-icon morph-icon
      #:row row
      #:col col
      #:row-span span
      #:col-span span
      #:margin-tb 0
      #:margin-lr 0)))

(define* (make-rotary-case-triplet case-code band-row
                                   #:key
                                   (title "")
                                   (show-value #f)
                                   (show-ticks #f)
                                   (show-labels #f)
                                   (tick-count 5)
                                   (tick-labels '())
                                   (icon-type -1)
                                   (icon-set "")
                                   (morph-icon #f)
                                   (min 0.0)
                                   (max 100.0)
                                   (default 50.0)
                                   (interval 1.0))
  (define (emit profile col span)
    (make-case-label case-code profile band-row col span)
    ;; All three specimens end at band-row + 10.
    (make-matrix-rotary
     case-code profile (- (+ band-row 10) span) col span
     #:title title
     #:show-value show-value
     #:show-ticks show-ticks
     #:show-labels show-labels
     #:tick-count tick-count
     #:tick-labels tick-labels
     #:icon-type icon-type
     #:icon-set icon-set
     #:morph-icon morph-icon
     #:min min
     #:max max
     #:default default
     #:interval interval))

  (emit "COMPACT" compact-col compact-span)
  (emit "STANDARD" standard-col standard-span)
  (emit "EXTENDED" extended-col extended-span))
