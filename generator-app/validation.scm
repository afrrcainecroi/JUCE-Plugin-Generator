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

(define (validate-required-parameter-binding! component
                                                parameter-id
                                                parameter-name
                                                processor-reference)
  (for-each
   (lambda (field)
     (let ((name (car field))
           (value (cdr field)))
       (unless (and (string? value)
                    (not (string-null? value)))
         (error "Parameter-generating component requires a non-empty string binding field"
                (component:id component)
                name
                value))))
   `((parameter-id . ,parameter-id)
     (parameter-name . ,parameter-name)
     (processor-reference . ,processor-reference)))
  #t)

(define-method (validate-component! (b <button>))
  (unless (string? (button:text b))
    (error "Button text must be a string"
           (component:id b)))
  #t)

(define-method (validate-component! (b <toggle-button>))
  (next-method)
  (validate-required-parameter-binding!
   b
   (toggle-button:parameter-id b)
   (toggle-button:parameter-name b)
   (toggle-button:processor-reference b))
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

    ;; ----------------------------------------------------------
    ;; Validazioni generali del selector
    ;; ----------------------------------------------------------

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
    (when (or (< index 0)
              (> index (length items)))
      (error "Selector default-index outside items range"
             (component:id c)
             index))

    ;; ----------------------------------------------------------
    ;; Validazioni aggiuntive se il selector è parameterized
    ;; ----------------------------------------------------------
    (let ((parameter-id (selector:parameter-id c)))
      (when parameter-id

        (when (null? items)
          (error "Parameterized selector requires at least one item"
                 (component:id c)))

        (unless (and (string? parameter-id)
                     (not (string-null? parameter-id)))
          (error "Parameterized selector requires parameter-id"
                 (component:id c)))

        (unless (and (string? (selector:parameter-name c))
                     (not (string-null?
                           (selector:parameter-name c))))
          (error "Parameterized selector requires parameter-name"
                 (component:id c)))

        (unless (and (string? (selector:processor-reference c))
                     (not (string-null?
                           (selector:processor-reference c))))
          (error "Parameterized selector requires processor-reference"
                 (component:id c)))

        ;; AudioParameterChoice deve avere una scelta reale.
        ;; 0 per ComboBox significa "nothing selected".
        (when (= index 0)
          (error "Parameterized selector requires default-index >= 1"
                 (component:id c)))))

    #t))

(define-method (validate-component! (s <slider>))
  (validate-required-parameter-binding!
   s
   (slider:parameter-id s)
   (slider:parameter-name s)
   (slider:processor-reference s))
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
  (unless (and (symbol? (meter:orientation m))
               (memq (meter:orientation m) '(vertical horizontal)))
    (error "Invalid meter orientation; expected one of (vertical horizontal)"
           (component:id m)
           (meter:orientation m)))
  (unless (memq (meter:scale-type m)
                '(db linear vu))
    (error "Invalid meter scale-type; expected one of (db linear vu)"
           (component:id m)
           (meter:scale-type m)))
  (unless (< (meter:range-min m)
             (meter:range-max m))
    (error "Meter range-min must be less than range-max"
           (component:id m)))
  (unless (> (meter:num-segments m) 0)
    (error "Meter num-segments must be > 0"
           (component:id m)))
  #t)

(define-method (validate-component! (s <scope>))
  (unless (memq (scope:grid-style s)
                '(radar minimal))
    (error "Invalid scope grid-style; expected one of (radar minimal)"
           (component:id s)
           (scope:grid-style s)))
  (let ((taps (scope:tap-points s)))
    (unless (and (list? taps) (not (null? taps)))
      (error "Invalid scope tap-points; expected a non-empty list"
             (component:id s) taps))
    (unless (every (lambda (tap) (memq tap '(pre-dsp post-dsp))) taps)
      (error "Invalid scope tap-points; expected pre-dsp and/or post-dsp"
             (component:id s) taps))
    (unless (= (length taps) (length (delete-duplicates taps)))
      (error "Invalid scope tap-points; duplicate taps are not allowed"
             (component:id s) taps))
    (unless (<= (length taps) 2)
      (error "Invalid scope tap-points; at most two taps are supported"
             (component:id s) taps))
    (when (= (length taps) 2)
      (unless (equal? taps '(pre-dsp post-dsp))
        (error "Invalid dual scope tap order; expected (pre-dsp post-dsp)"
               (component:id s) taps))))
  #t)
