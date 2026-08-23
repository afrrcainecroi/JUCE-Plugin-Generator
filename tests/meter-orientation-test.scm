(use-modules (oop goops)
             (ice-9 textual-ports)
             (srfi srfi-13)
             (generator-app code-generator)
             (generator-app cpp-generation-common))

(define (check label predicate)
  (unless predicate
    (error "Meter orientation test failed" label)))

(define (rejected? thunk)
  (catch #t
    (lambda () (thunk) #f)
    (lambda args #t)))

(define vertical
  (make <meter> #:id 'vertical-meter #:style 'segmented
        #:orientation 'vertical))
(define horizontal
  (make <meter> #:id 'horizontal-meter #:style 'segmented
        #:orientation 'horizontal))
(define default-meter
  (make <meter> #:id 'default-meter))

(check 'segmented-orientations-valid
       (and (eq? (meter:orientation vertical) 'vertical)
            (eq? (meter:orientation horizontal) 'horizontal)))

(check 'meter-orientation-default-vertical
       (eq? (meter:orientation default-meter) 'vertical))

(check 'invalid-meter-orientations-rejected
       (and (rejected?
             (lambda ()
               (make <meter> #:id 'invalid-value #:orientation 'diagonal)))
            (rejected?
             (lambda ()
               (make <meter> #:id 'invalid-case #:orientation 'Vertical)))
            (rejected?
             (lambda ()
               (make <meter> #:id 'invalid-type #:orientation "vertical")))))

;; Policy A: orientation remains valid but geometrically irrelevant for analog.
(check 'analog-accepts-orientation
       (eq? (meter:orientation
             (make <meter> #:id 'analog-horizontal #:style 'analog
                   #:orientation 'horizontal))
            'horizontal))

(let* ((model (acons 'var "meter" (component->model horizontal)))
       (cpp (meter-properties->cpp model)))
  (check 'generated-cpp-canonical-orientation
         (and (string-contains cpp
                               "properties.set(\"orientation\", \"horizontal\")")
              (not (string-contains cpp "Horizontal")))))

(let ((renderer
       (call-with-input-file "YATemplate/Source/KineticLookAndFeel.cpp"
         get-string-all)))
  (check 'renderer-uses-orientation-property
         (and (string-contains renderer
                               "getWithDefault(\"orientation\", \"vertical\")")
              (not (string-contains renderer
                                    "bounds.getHeight() > bounds.getWidth()")))))

(display "meter-orientation-test: PASS\n")
