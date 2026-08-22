;; Cases I-L: centre-icon geometry.
;; The raster cases use the five existing PNGs in
;; YATemplate-20260328/Resources.
(load "rotary-matrix-common.scm")

(define rotary-png-set "Resources")

(define (rotary-matrix-icons-interface dst-folder project-name)
  (make-rotary-matrix-screen 4)

  (make <image-set>
    #:name rotary-png-set
    #:source-directory "YATemplate-20260328"
    #:files '("wave_sine.png"
              "wave_square.png"
              "wave_ramp.png"
              "wave_triangle.png"
              "wave_iramp.png"))

  ;; I: fixed built-in vector centre icon, title and value.
  (make-rotary-case-triplet "I" 1
                            #:title "VECTOR ICON"
                            #:show-value #t
                            #:icon-type 0)

  ;; J: fixed raster/PNG centre image, title and value.
  (make-rotary-case-triplet "J" 11
                            #:title "PNG ICON"
                            #:show-value #t
                            #:icon-type 0
                            #:icon-set rotary-png-set)

  ;; K: vector icon, ticks, textual labels and value.
  (make-rotary-case-triplet "K" 21
                            #:show-value #t
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("SIN" "SQU" "RAMP" "TRI" "IRAMP")
                            #:icon-type 1
                            #:min 0.0
                            #:max 4.0
                            #:default 2.0
                            #:interval 1.0)

  ;; L: most complex supported combination: title, value, ticks, textual
  ;; labels and a raster centre image selected through morph-icon.
  (make-rotary-case-triplet "L" 31
                            #:title "MORPH PNG"
                            #:show-value #t
                            #:show-ticks #t
                            #:show-labels #t
                            #:tick-count 5
                            #:tick-labels
                            '("SIN" "SQU" "RAMP" "TRI" "IRAMP")
                            #:icon-set rotary-png-set
                            #:morph-icon #t
                            #:min 0.0
                            #:max 4.0
                            #:default 2.0
                            #:interval 1.0))

(MakeNewProject "pppbuttavia" rotary-matrix-icons-interface)
