;; Vertical cases E-H: tick and tick-label geometry.
(load "linear-slider-matrix-common.scm")

(define (linear-vertical-ticks-interface dst-folder project-name)
  (make-linear-matrix-screen 'vertical 4)

  (make-linear-case-triplet 'vertical "E" 1
                            #:show-ticks #t
                            #:show-labels #f
                            #:tick-count 5)
  (make-linear-case-triplet 'vertical "F" 21
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5)
  (make-linear-case-triplet 'vertical "G" 41
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("LOW" "25" "MID" "75" "HIGH"))
  (make-linear-case-triplet 'vertical "H" 61
                            #:title "FULL"
                            #:show-value #t
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("LOW" "25" "MID" "75" "HIGH")))

(MakeNewProject "linear-matrix-vertical-ticks"
                linear-vertical-ticks-interface)
