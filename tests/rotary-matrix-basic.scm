;; Cases A-D: title and current-value geometry.
(load "rotary-matrix-common.scm")

(define (rotary-matrix-basic-interface dst-folder project-name)
  (make-rotary-matrix-screen 4)

  ;; A: standard centre only.
  (make-rotary-case-triplet "A" 1
                            #:title ""
                            #:show-value #f)

  ;; B: title only.
  (make-rotary-case-triplet "B" 11
                            #:title "TITLE"
                            #:show-value #f)

  ;; C: current value only.
  (make-rotary-case-triplet "C" 21
                            #:title ""
                            #:show-value #t)

  ;; D: title and current value.
  (make-rotary-case-triplet "D" 31
                            #:title "TITLE"
                            #:show-value #t))

(MakeNewProject "pppbuttavia" rotary-matrix-basic-interface)
