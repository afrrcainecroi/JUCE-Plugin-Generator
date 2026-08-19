(define-module (generator-app validation)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app dsl-model)
  #:re-export (validate-component!)
  #:export (validate-component-model))

(define (error message . args)
  (scm-error 'misc-error
             #f
             (string-append
              message
              (apply string-append (map (lambda (_) " ~S") args)))
             args
             #f))

(define (validate-component-model model)
  (let ((id (assoc-ref model 'id))
        (type (assoc-ref model 'type))
        (var (assoc-ref model 'var)))
    (unless id
      (error "Component without logical id" model))
    (unless type
      (error "Component without type" model))
    (unless var
      (error "Component without C++ identifier" model))
    #t))

(define-method (validate-component! (b <button>))
  (unless (string? (button:text b))
    (error "Button text must be a string"
           (component:id b)))
  #t)

(define-method (validate-component! (b <toggle-button>))
  (next-method)
  (unless (boolean? (toggle-button:default-state b))
    (error "Toggle button default-state must be boolean"
           (component:id b)))
  (unless (memq (toggle-button:style b)
                '(normal switch))
    (error "Invalid toggle button style"
           (component:id b)
           (toggle-button:style b)))
  #t)

(define-method (validate-component! (c <label>))
  (unless (string? (label:text c))
    (error "Label text must be a string"
           (component:id c)))
  #t)

(define-method (validate-component! (c <selector>))
  (let ((items (selector:items c))
        (index (selector:default-index c)))
    (unless (list? items)
      (error "Selector items must be a list"
             (component:id c)))
    (unless (every string? items)
      (error "Selector items must be strings"
             (component:id c)
             items))
    (unless (integer? index)
      (error "Selector default-index must be an integer"
             (component:id c)
             index))
    (when (and (not (null? items))
               (or (< index 0)
                   (>= index (length items))))
      (error "Selector default-index outside items range"
             (component:id c)
             index))
    #t))

(define-method (validate-component! (s <slider>))
  (let ((min (slider:min s))
        (max (slider:max s))
        (default (slider:default s))
        (scale (slider:scale s)))
    (unless (< min max)
      (error "Slider min must be less than max"
             (component:id s)
             min
             max))
    (unless (and (>= default min)
                 (<= default max))
      (error "Slider default value outside range"
             (component:id s)
             default
             min
             max))
    (unless (memq scale '(linear logarithmic))
      (error "Invalid slider scale"
             (component:id s)
             scale))
    (when (eq? scale 'logarithmic)
      (unless (and (> min 0)
                   (> max 0))
        (error "Logarithmic slider requires positive min/max"
               (component:id s)
               min
               max)))
    #t))

(define-method (validate-component! (s <linear-slider>))
  (next-method)
  (unless (memq (linear-slider:orientation s)
                '(horizontal vertical))
    (error "Invalid linear slider orientation"
           (component:id s)
           (linear-slider:orientation s)))
  #t)

(define-method (validate-component! (s <rotary-slider>))
  (next-method))

(define-method (validate-component! (m <meter>))
  (unless (memq (meter:style m)
                '(segmented analog))
    (error "Invalid meter style"
           (component:id m)
           (meter:style m)))
  (unless (< (meter:range-min m)
             (meter:range-max m))
    (error "Meter range-min must be less than range-max"
           (component:id m)))
  (unless (> (meter:num-segments m) 0)
    (error "Meter num-segments must be > 0"
           (component:id m)))
  #t)

(define-method (validate-component! (s <scope>))
  #t)
