;; Horizontal cases A-D: base, title and current-value geometry.
(load "linear-slider-matrix-common.scm")

(define (linear-horizontal-basic-interface dst-folder project-name)
  (make-linear-matrix-screen 'horizontal 4)

  (make-linear-case-triplet 'horizontal "A" 1)
  (make-linear-case-triplet 'horizontal "B" 8
                            #:title "TITLE")
  (make-linear-case-triplet 'horizontal "C" 15
                            #:show-value #t)
  (make-linear-case-triplet 'horizontal "D" 22
                            #:title "TITLE"
                            #:show-value #t))

(MakeNewProject "linear-matrix-horizontal-basic"
                linear-horizontal-basic-interface)
