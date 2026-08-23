;; Negative contract test for the scope grid-style DSL PROPERTY.
;; Run from the Generator repository root with:
;;   guile -L . -s tests/scope-grid-style-validation-test.scm

(use-modules (oop goops)
             (generator-app code-generator))

(define rejected?
  (catch #t
    (lambda ()
      (make <scope>
        #:id "invalidScopeGridStyle"
        #:grid-style 'default)
      #f)
    (lambda args #t)))

(unless rejected?
  (error "scope grid-style validation test failed"))

(display "scope grid-style 'default correctly rejected\n")
