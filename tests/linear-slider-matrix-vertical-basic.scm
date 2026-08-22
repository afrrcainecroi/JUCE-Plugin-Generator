;; Vertical cases A-D: base, title and current-value geometry.
(load "linear-slider-matrix-common.scm")

(define (linear-vertical-basic-interface dst-folder project-name)
  (make-linear-matrix-screen 'vertical 4)

  (make-linear-case-triplet 'vertical "A" 1)
  (make-linear-case-triplet 'vertical "B" 21
                            #:title "TITLE")
  (make-linear-case-triplet 'vertical "C" 41
                            #:show-value #t)
  (make-linear-case-triplet 'vertical "D" 61
                            #:title "TITLE"
                            #:show-value #t))

(MakeNewProject "linear-matrix-vertical-basic"
                linear-vertical-basic-interface)
