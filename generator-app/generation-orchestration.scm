(define-module (generator-app generation-orchestration)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app cpp-generation)
  #:export (generate-member-declarations
            generate-constructor-code
            generate-attachment-declarations
            generate-attachment-code
            generate-parameter-code
            generate-dparams-code
            generate-getparams-code
            generate-valueparams-code
            generate-destroy-code))

(define (generate-member-declarations)
  (apply string-append
         (map model->member-declaration
              (reverse (generation-components)))))

(define (generate-constructor-code)
  (apply string-append
         (map model->constructor-code
              (reverse (generation-components)))))

(define (generate-attachment-declarations)
  (apply string-append
         (map model->attachment-declaration
              (reverse (generation-components)))))

(define (generate-attachment-code)
  (apply string-append
         (map model->attachment-code
              (reverse (generation-components)))))

(define (generate-parameter-code)
  (apply string-append
         (map model->parameter-code
              (reverse (generation-components)))))

(define (generate-dparams-code)
  (apply string-append
         (map model->dparams-code
              (reverse (generation-components)))))

(define (generate-getparams-code)
  (apply string-append
         (map model->getparams-code
              (reverse (generation-components)))))

(define (generate-valueparams-code)
  (apply string-append
         (map model->valueparams-code
              (reverse (generation-components)))))

(define (generate-destroy-code)
  (apply string-append
         (map model->destroy-code
              (reverse (generation-components)))))
