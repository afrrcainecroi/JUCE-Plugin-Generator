(use-modules (oop goops)
             (generator-app code-generator)
             (generator-app cpp-generation)
             (generator-app dsl-model))

(define (check label predicate)
  (unless predicate
    (error "UTF-8 label generation test failed" label)))

(define model (component->model (make <footer> #:id 'copyright #:text "©")))
(define code (model->constructor-code model))

(check 'explicit-juce-utf8-construction
       (string-contains code
                        "setText(juce::String::fromUTF8(\"\\xc2\\xa9\"),"))
(check 'not-a-quoted-cpp-expression
       (not (string-contains code
                             "setText(\"juce::String::fromUTF8")))

(display "utf8-label-generation-test: PASS\n")
