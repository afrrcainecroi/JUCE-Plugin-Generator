;; Dedicated visual/diagnostic test for <screen> and <grid> resizing.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/screen-resize-test.scm

(use-modules (oop goops)
             (generator-app code-generator))

(define screen-resize-test-width 800)
(define screen-resize-test-ratio 1.618033988749895)
(define screen-resize-test-rows 15)
(define screen-resize-test-cols 24)

(define (make-position-marker id text row col)
  (make <text-button>
    #:id id
    #:text text
    #:row row
    #:col col
    #:row-span 3
    #:col-span 5
    #:margin-tb 0
    #:margin-lr 0))

(define (screen-resize-test-interface dst-folder project-name)
  (make <screen>
    #:width screen-resize-test-width
    #:ratio screen-resize-test-ratio)

  (make <grid>
    #:rows screen-resize-test-rows
    #:cols screen-resize-test-cols
    #:show-grid #t)

  (make-position-marker "ScreenResizeTopLeft" "TOP LEFT" 1 1)
  (make-position-marker "ScreenResizeCentre" "CENTRE" 7 10)
  (make-position-marker "ScreenResizeBottomRight" "BOTTOM RIGHT" 13 20))

(MakeNewProject "screen-resize-test"
                screen-resize-test-interface)
