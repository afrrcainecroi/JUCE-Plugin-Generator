(use-modules (oop goops)
             (generator-app code-generator)
             (generator-app generation-state))

(define (check label predicate)
  (unless predicate
    (error "parameter binding validation test failed" label)))

(define counter 0)
(define (fresh-id prefix)
  (set! counter (+ counter 1))
  (string-append prefix "-" (number->string counter)))

(define (accepted? thunk)
  (reset-generation-state!)
  (catch #t
    (lambda () (thunk) #t)
    (lambda args #f)))

(define (rejected? thunk)
  (not (accepted? thunk)))

(define (complete-bindings class prefix . extra)
  (apply make class
         #:id (fresh-id prefix)
         #:parameter-id (string-append prefix "Id")
         #:parameter-name (string-append prefix " Name")
         #:processor-reference (string-append prefix "Ref")
         extra))

(check 'rotary-complete
       (accepted? (lambda () (complete-bindings <rotary-slider> "rotary"))))
(check 'linear-complete
       (accepted? (lambda () (complete-bindings <linear-slider> "linear"))))
(check 'slider-no-binding
       (rejected? (lambda () (make <rotary-slider> #:id (fresh-id "none")))))
(check 'slider-id-only
       (rejected? (lambda ()
                    (make <rotary-slider> #:id (fresh-id "id-only")
                          #:parameter-id "idOnly"))))
(check 'slider-missing-reference
       (rejected? (lambda ()
                    (make <linear-slider> #:id (fresh-id "missing-ref")
                          #:parameter-id "missingRef"
                          #:parameter-name "Missing Reference"))))
(check 'slider-empty-id
       (rejected? (lambda ()
                    (make <rotary-slider> #:id (fresh-id "empty-id")
                          #:parameter-id "" #:parameter-name "Empty ID"
                          #:processor-reference "emptyId"))))
(check 'slider-wrong-name-type
       (rejected? (lambda ()
                    (make <rotary-slider> #:id (fresh-id "wrong-name")
                          #:parameter-id "wrongName" #:parameter-name 'wrong
                          #:processor-reference "wrongName"))))

(for-each
 (lambda (entry)
   (let ((label (car entry)) (class (cadr entry)))
     (check (list label 'complete)
            (accepted? (lambda () (complete-bindings class (symbol->string label)))))
     (check (list label 'partial)
            (rejected? (lambda ()
                         (make class #:id (fresh-id (symbol->string label))
                               #:parameter-id "partial"
                               #:parameter-name "Partial"))))))
 (list (list 'normal-toggle <normal-toggle-button>)
       (list 'switch <switch>)
       (list 'bypass-switch <bypass-switch>)))

(check 'hard-bypass-role-valid
       (accepted? (lambda ()
                    (complete-bindings <normal-toggle-button> "hardBypass"
                                       #:role 'bypass))))
(check 'dsp-bypass-role-valid
       (accepted? (lambda ()
                    (complete-bindings <switch> "dspBypass"
                                       #:role 'dsp-bypass))))

(check 'unbound-selector-valid
       (accepted? (lambda ()
                    (make <selector> #:id (fresh-id "selector")
                          #:items '("One" "Two")
                          #:default-index 1))))

(display "parameter binding validation tests passed\n")
