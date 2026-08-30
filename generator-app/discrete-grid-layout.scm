(define-module (generator-app discrete-grid-layout)

  #:use-module (srfi srfi-1)

  #:export (dgl:discretize))


;; ======================================================================
;; HELPERS
;; ======================================================================

(define (field alist key)

  (let ((entry
         (assoc key alist)))

    (and entry
         (cdr entry))))


(define (require-exact-number value description)

  (unless (and (number? value)
               (exact? value))

    (error
      "DiscreteGridLayout requires exact physical geometry"
      description
      value))

  value)


;; ======================================================================
;; SORTED UNIQUE EXACT BOUNDARIES
;;
;; We deliberately avoid deriving a uniform lattice quantum.
;;
;; A physical axis:
;;
;;     b0 < b1 < b2 < ... < bn
;;
;; becomes n variable-width tracks:
;;
;;     b1-b0
;;     b2-b1
;;     ...
;;     bn-b(n-1)
;;
;; This representation is lossless but compact.
;; ======================================================================

(define (insert-boundary value sorted)

  (cond

    ((null? sorted)
     (list value))

    ((= value
        (car sorted))
     sorted)

    ((< value
        (car sorted))
     (cons value
           sorted))

    (else

     (cons
       (car sorted)

       (insert-boundary
         value
         (cdr sorted))))))


(define (sorted-unique-boundaries values)

  (fold
    (lambda (value result)

      (require-exact-number
        value
        'boundary)

      (insert-boundary
        value
        result))

    '()
    values))


;; ======================================================================
;; PHYSICAL BOUNDARIES
;; ======================================================================

(define (x-boundaries components screen-width)

  (sorted-unique-boundaries

    (append

      (list
        0
        screen-width)

      (append-map

        (lambda (rectangle)

          (let ((x
                 (require-exact-number
                   (field rectangle 'x)
                   'x))

                (width
                 (require-exact-number
                   (field rectangle 'width)
                   'width)))

            (list
              x
              (+ x width))))

        components))))


(define (y-boundaries components screen-height)

  (sorted-unique-boundaries

    (append

      (list
        0
        screen-height)

      (append-map

        (lambda (rectangle)

          (let ((y
                 (require-exact-number
                   (field rectangle 'y)
                   'y))

                (height
                 (require-exact-number
                   (field rectangle 'height)
                   'height)))

            (list
              y
              (+ y height))))

        components))))


;; ======================================================================
;; TRACK WIDTHS
;;
;; boundaries:
;;
;;   (b0 b1 b2 ... bn)
;;
;; tracks:
;;
;;   (b1-b0 b2-b1 ... bn-b(n-1))
;; ======================================================================

(define (boundary-tracks boundaries)

  (let loop ((rest boundaries)
             (result '()))

    (if (or (null? rest)
            (null? (cdr rest)))

        (reverse result)

        (let ((track
               (- (cadr rest)
                  (car rest))))

          (unless (> track 0)

            (error
              "DiscreteGridLayout produced non-positive track"
              (car rest)
              (cadr rest)))

          (loop
            (cdr rest)
            (cons track
                  result))))))


;; ======================================================================
;; BOUNDARY LOOKUP
;;
;; Returns a zero-based boundary index.
;; ======================================================================

(define (boundary-index boundaries coordinate)

  (let loop ((rest boundaries)
             (index 0))

    (cond

      ((null? rest)

       (error
         "Physical coordinate is not represented by a boundary"
         coordinate
         boundaries))

      ((= coordinate
          (car rest))

       index)

      (else

       (loop
         (cdr rest)
         (+ index 1))))))


;; ======================================================================
;; DISCRETIZE ONE COMPONENT
;;
;; If:
;;
;;   start = boundary[i]
;;   end   = boundary[j]
;;
;; then:
;;
;;   grid coordinate = i + 1
;;   span            = j - i
;;
;; JUCE grid coordinates therefore remain one-based.
;; ======================================================================

(define (discretize-component
         rectangle
         x-boundary-list
         y-boundary-list)

  (let* ((id
          (field rectangle 'id))

         (x
          (require-exact-number
            (field rectangle 'x)
            'x))

         (y
          (require-exact-number
            (field rectangle 'y)
            'y))

         (width
          (require-exact-number
            (field rectangle 'width)
            'width))

         (height
          (require-exact-number
            (field rectangle 'height)
            'height))

         (x-end
          (+ x width))

         (y-end
          (+ y height))

         (x-start-index
          (boundary-index
            x-boundary-list
            x))

         (x-end-index
          (boundary-index
            x-boundary-list
            x-end))

         (y-start-index
          (boundary-index
            y-boundary-list
            y))

         (y-end-index
          (boundary-index
            y-boundary-list
            y-end))

         (col
          (+ 1
             x-start-index))

         (row
          (+ 1
             y-start-index))

         (col-span
          (- x-end-index
             x-start-index))

         (row-span
          (- y-end-index
             y-start-index)))

    (unless (> col-span 0)

      (error
        "DiscreteGridLayout produced invalid column span"
        id
        col-span))

    (unless (> row-span 0)

      (error
        "DiscreteGridLayout produced invalid row span"
        id
        row-span))


    ;; ----------------------------------------------------------
    ;; Exact reconstruction proof.
    ;; ----------------------------------------------------------

    (unless (= x
               (list-ref
                 x-boundary-list
                 (- col 1)))

      (error
        "Discrete X reconstruction failed"
        id))

    (unless (= y
               (list-ref
                 y-boundary-list
                 (- row 1)))

      (error
        "Discrete Y reconstruction failed"
        id))

    (unless (= x-end
               (list-ref
                 x-boundary-list
                 (+ (- col 1)
                    col-span)))

      (error
        "Discrete X-end reconstruction failed"
        id))

    (unless (= y-end
               (list-ref
                 y-boundary-list
                 (+ (- row 1)
                    row-span)))

      (error
        "Discrete Y-end reconstruction failed"
        id))


    `((id . ,id)
      (row . ,row)
      (col . ,col)
      (rowSpan . ,row-span)
      (colSpan . ,col-span))))


;; ======================================================================
;; AUTHORITATIVE DISCRETE GRID CONVERSION -- VERSION 2
;;
;; Input:
;;
;;   PhysicalLayout
;;
;; Output:
;;
;;   compact variable-track DiscreteGridLayout
;;
;;
;; IMPORTANT:
;;
;; - topology is NOT solved again
;; - UI metrics are NOT consulted
;; - structures are NOT emitted
;; - old 40x60 grid is NOT consulted
;; - no uniform minimum quantum is created
;; - each physical boundary becomes one grid boundary
;; - track widths preserve exact physical proportions
;; ======================================================================

(define (dgl:discretize physical-layout)

  (unless
      (eq? (field physical-layout 'kind)
           'physical-layout)

    (error
      "DiscreteGridLayout requires PhysicalLayout input"
      physical-layout))


  (let* ((screen
          (field physical-layout 'screen))

         (components
          (field physical-layout 'components))

         (screen-width
          (require-exact-number
            (field screen 'width)
            'screen-width))

         (screen-height
          (require-exact-number
            (field screen 'height)
            'screen-height)))

    (unless (> screen-width 0)

      (error
        "Physical screen width must be positive"
        screen-width))

    (unless (> screen-height 0)

      (error
        "Physical screen height must be positive"
        screen-height))


    (let* ((xb
            (x-boundaries
              components
              screen-width))

           (yb
            (y-boundaries
              components
              screen-height))

           (column-tracks
            (boundary-tracks xb))

           (row-tracks
            (boundary-tracks yb))

           (cols
            (length column-tracks))

           (rows
            (length row-tracks))

           (discrete-components
            (map

              (lambda (rectangle)

                (discretize-component
                  rectangle
                  xb
                  yb))

              components)))


      ;; --------------------------------------------------------
      ;; Global reconstruction checks.
      ;; --------------------------------------------------------

      (unless (= (fold + 0 column-tracks)
                 screen-width)

        (error
          "Discrete column tracks do not reconstruct screen width"
          column-tracks
          screen-width))

      (unless (= (fold + 0 row-tracks)
                 screen-height)

        (error
          "Discrete row tracks do not reconstruct screen height"
          row-tracks
          screen-height))


      `((kind . discrete-grid-layout)

        (version . 2)

        (rows . ,rows)
        (cols . ,cols)

        (row-boundaries . ,yb)
        (col-boundaries . ,xb)

        (row-tracks . ,row-tracks)
        (col-tracks . ,column-tracks)

        (components . ,discrete-components)

        (validation .
                    ((exact-reconstruction . ok)))))))
