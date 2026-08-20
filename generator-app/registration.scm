(define-module (generator-app registration)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app validation)
  #:use-module (generator-app tools)
  #:re-export (register-component!)
  #:export (find-component
            find-component-by-role
	    find-component-by-type
	    component-id-used?
            component-role-used?
            validate-component-role
            role-present?
            role-model
            component-cpp-var
            slider-parameter-type?
            button-parameter-type?
            parameter-component-type?
            processor-param-var
            processor-value-var
            processor-reference))

(define *unique-component-roles*
  '(input-gain
    output-gain
    wet-dry
    bypass
    dsp-bypass
    oversampling
    input-meter
    output-meter
    scope))

(define (error message . args)
  (scm-error 'misc-error
             #f
             (string-append
              message
              (apply string-append (map (lambda (_) " ~S") args)))
             args
             #f))

(define (processor-param-var model)
  (string-append
   "param_"
   (assoc-ref model 'processor-reference)))

(define (processor-value-var model)
  (string-append
   "value_"
   (assoc-ref model 'processor-reference)))

(define (processor-reference model)
  (assoc-ref model 'processor-reference))

(define (find-component id)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'id) id))
   (generation-components)))

(define (find-component-by-role role)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'role) role))
   (generation-components)))

(define (find-component-by-type type)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'type) type))
   (generation-components)))

(define (component-role-used? role)
  (if (find-component-by-role role) #t #f))

(define (validate-component-role model)
  (let ((role (assoc-ref model 'role)))
    (when (and role
               (memq role *unique-component-roles*)
               (find-component-by-role role))
      (error "Duplicate component role" role)))
  #t)

(define (role-present? role)
  (if (find-component-by-role role) #t #f))

(define (role-model role)
  (find-component-by-role role))

(define (component-id-used? id)
  (if (find-component id) #t #f))

(define (slider-parameter-type? type)
  (memq type '(rotary-slider linear-slider)))

(define (button-parameter-type? type)
  (memq type
        '(toggle-button
          normal-toggle-button
          switch
          bypass-switch)))

(define (parameter-component-type? type)
  (or (slider-parameter-type? type)
      (button-parameter-type? type)))

(define-method (register-component! (component <list>))
  (validate-component-model component)
  (let ((id (assoc-ref component 'id)))
    (when (component-id-used? id)
      (scm-error 'misc-error
                 #f
                 "Duplicate component logical id ~S"
                 (list id)
                 #f)))
  (prepend-generation-component! component))

(define-method (register-component! (component <component>))
  (validate-component! component)
  (let* ((model (component->model component))
         (logical-id (assoc-ref model 'id)))
    (unless logical-id
      (error "Component without logical id" model))
    (when (component-id-used? logical-id)
      (error "Duplicate component logical id" logical-id))
    (validate-component-role model)
    (let* ((cpp-id (allocate-cpp-identifier! logical-id))
           (registered-model `((var . ,cpp-id) ,@model)))
      (unless (assoc-ref registered-model 'type)
        (error "Component without type" registered-model))
      (prepend-generation-component! registered-model))))

(define (component-cpp-var component)
  (let* ((id (component:id component))
         (registered (find-component id)))
    (unless registered
      (error "Component not registered" id))
    (let ((var (assoc-ref registered 'var)))
      (unless var
        (error "Registered component without C++ identifier" registered))
      var)))
