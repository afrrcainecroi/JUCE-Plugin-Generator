;; Shared DSL helpers for the Linear Slider Visual Test Matrix.

(use-modules (oop goops)
             (generator-app code-generator))

(define linear-matrix-screen-width 1800)

(define horizontal-grid-cols 66)
(define horizontal-band-rows 7)
(define horizontal-profiles
  '(("COMPACT"  2 10 3)
    ("STANDARD" 24 14 4)
    ("EXTENDED" 47 18 5)))

(define vertical-grid-cols 54)
(define vertical-band-rows 20)
(define vertical-profiles
  '(("COMPACT"  5 3 10 2 10)
    ("STANDARD" 23 4 14 20 10)
    ("EXTENDED" 42 5 18 39 12)))

(define (make-linear-matrix-screen orientation case-count)
  (let* ((horizontal? (eq? orientation 'horizontal))
         (cols (if horizontal? horizontal-grid-cols vertical-grid-cols))
         (band-rows (if horizontal? horizontal-band-rows vertical-band-rows))
         (rows (* band-rows case-count)))
    (make <screen>
      #:ratio (exact->inexact (/ cols rows))
      #:width linear-matrix-screen-width)
    (make <grid>
      #:rows rows
      #:cols cols
      #:show-grid #t)))

(define (linear-profile-id orientation case-code profile)
  (string-append "Linear " (symbol->string orientation) " "
                 case-code " " profile))

(define (linear-profile-reference orientation case-code profile)
  (string-append "linear"
                 (if (eq? orientation 'horizontal) "Horizontal" "Vertical")
                 case-code profile))

(define (make-linear-case-label orientation case-code profile
                                row col col-span)
  (make <label>
    #:id (string-append (linear-profile-id orientation case-code profile)
                        " Label")
    #:text (string-append case-code " — " profile)
    #:justification 'centred
    #:row row
    #:col col
    #:row-span 1
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define* (make-matrix-linear orientation case-code profile
                             row col row-span col-span
                             #:key
                             (title "")
                             (show-value #f)
                             (show-ticks #f)
                             (show-labels #f)
                             (tick-count 5)
                             (tick-labels '())
                             (min 0.0)
                             (max 100.0)
                             (default 50.0)
                             (interval 1.0))
  (let ((id (linear-profile-id orientation case-code profile))
        (reference (linear-profile-reference orientation case-code profile)))
    (make <linear-slider>
      #:id id
      #:parameter-id reference
      #:parameter-name id
      #:processor-reference reference
      #:version-hint 1
      #:orientation orientation
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
      #:row row
      #:col col
      #:row-span row-span
      #:col-span col-span
      #:margin-tb 0
      #:margin-lr 0)))

(define* (make-linear-case-triplet orientation case-code band-row
                                   #:key
                                   (title "")
                                   (show-value #f)
                                   (show-ticks #f)
                                   (show-labels #f)
                                   (tick-count 5)
                                   (tick-labels '())
                                   (min 0.0)
                                   (max 100.0)
                                   (default 50.0)
                                   (interval 1.0))
  (define (emit profile row col row-span col-span label-col label-span)
    (make-linear-case-label orientation case-code profile
                            band-row label-col label-span)
    (make-matrix-linear
     orientation case-code profile row col row-span col-span
     #:title title
     #:show-value show-value
     #:show-ticks show-ticks
     #:show-labels show-labels
     #:tick-count tick-count
     #:tick-labels tick-labels
     #:min min
     #:max max
     #:default default
     #:interval interval))

  (if (eq? orientation 'horizontal)
      (for-each
       (lambda (profile)
         (let ((name (list-ref profile 0))
               (col (list-ref profile 1))
               (col-span (list-ref profile 2))
               (row-span (list-ref profile 3)))
           (emit name
                 (- (+ band-row horizontal-band-rows) row-span)
                 col row-span col-span col col-span)))
       horizontal-profiles)
      (for-each
       (lambda (profile)
         (let ((name (list-ref profile 0))
               (col (list-ref profile 1))
               (col-span (list-ref profile 2))
               (row-span (list-ref profile 3))
               (label-col (list-ref profile 4))
               (label-span (list-ref profile 5)))
           (emit name
                 (- (+ band-row vertical-band-rows) row-span)
                 col row-span col-span label-col label-span)))
       vertical-profiles)))
