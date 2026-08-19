(define-module (generator-app generation-protocols)
  #:use-module (oop goops)
  #:export (register-image-set!
            register-component!
            validate-component!
            component-type
            component->model
            component->member-declaration
            model->member-declaration
            model->constructor-code
            model->attachment-declaration
            model->attachment-code
            model->parameter-code
            model->dparams-code
            model->getparams-code
            model->valueparams-code
            model->destroy-code))

(define-generic register-image-set!)
(define-generic register-component!)
(define-generic validate-component!)
(define-generic component-type)
(define-generic component->model)
(define-generic component->member-declaration)
(define-generic model->member-declaration)
(define-generic model->constructor-code)
(define-generic model->attachment-declaration)
(define-generic model->attachment-code)
(define-generic model->parameter-code)
(define-generic model->dparams-code)
(define-generic model->getparams-code)
(define-generic model->valueparams-code)
(define-generic model->destroy-code)
