;; Horizontal cases E-H: tick and tick-label geometry.
(load "linear-slider-matrix-common.scm")

(define (linear-horizontal-ticks-interface dst-folder project-name)
  (make-linear-matrix-screen 'horizontal 4)

  (make-linear-case-triplet 'horizontal "E" 1
                            #:show-ticks #t
                            #:show-labels #f
                            #:tick-count 5)
  (make-linear-case-triplet 'horizontal "F" 8
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5)
  (make-linear-case-triplet 'horizontal "G" 15
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("LOW" "25" "MID" "75" "HIGH"))
  (make-linear-case-triplet 'horizontal "H" 22
                            #:title "FULL"
                            #:show-value #t
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("LOW" "25" "MID" "75" "HIGH")))

(MakeNewProject "linear-matrix-horizontal-ticks"
                linear-horizontal-ticks-interface)
