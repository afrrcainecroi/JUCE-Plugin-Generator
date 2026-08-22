;; Cases E-G: tick and tick-label geometry.
;; H is excluded: image tick labels are not supported by the renderer.
(load "rotary-matrix-common.scm")

(define (rotary-matrix-ticks-interface dst-folder project-name)
  (make-rotary-matrix-screen 3)

  ;; E: ticks without labels.
  (make-rotary-case-triplet "E" 1
                            #:show-ticks #t
                            #:show-labels #f
                            #:tick-count 5)

  ;; F: ticks with numeric labels computed by the renderer.
  (make-rotary-case-triplet "F" 11
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5)

  ;; G: ticks with explicit textual labels.
  (make-rotary-case-triplet "G" 21
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("LOW" "25" "MID" "75" "HIGH")))

(MakeNewProject "pppbuttavia" rotary-matrix-ticks-interface)
