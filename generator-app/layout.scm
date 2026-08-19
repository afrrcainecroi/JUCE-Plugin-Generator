(define-module (generator-app layout)
  #:use-module (ice-9 format)
  #:use-module (json)
  #:use-module (oop goops)
  #:use-module (generator-app tools)
  #:use-module (generator-app genera-classi)
  #:use-module (generator-app generation-state)
  #:export (<grid>
            grid:rows
            grid:cols
            grid:show-grid
            <screen>
            screen:ratio
            screen:width
            register-grid!
            register-screen!
            component-model->layout-model
            generate-layout-data-components
            generate-screen-size-code
            generate-grid-code))

(define (register-grid! grid)
  (when (generation-grid)
    (error "Only one grid may be declared"))
  (set-generation-grid!
   `((rows . ,(grid:rows grid))
     (cols . ,(grid:cols grid))
     (show-grid . ,(grid:show-grid grid)))))

(define (register-screen! screen)
  (when (generation-screen)
    (error "Only one screen may be declared"))
  (set-generation-screen!
   `((ratio . ,(screen:ratio screen))
     (width . ,(screen:width screen)))))

(new-class <grid>
           ()
           ((rows 15)
            (cols 24)
            (show-grid #t))
           #:code
           (register-grid! this))

(new-class <screen>
           ()
           ((ratio (/ (+ 1.0 (sqrt 5.0)) 2.0))
            (width 800))
           #:code
           (register-screen! this))

(define (generate-screen-size-code)
  (unless (generation-screen)
    (error "<screen> has to be defined"))
  (let ((ratio (assoc-ref (generation-screen) 'ratio))
        (width (assoc-ref (generation-screen) 'width)))
    (format #f
            "screenRatio = ~a;
standardScreenWidth = ~a;
standardScreenHeight = standardScreenWidth / screenRatio;
"
            ratio
            width)))

(define (component-model->layout-model model)
  `((var . ,(assoc-ref model 'var))
    (row . ,(assoc-ref model 'row))
    (col . ,(assoc-ref model 'col))
    (rowSpan . ,(assoc-ref model 'rowSpan))
    (colSpan . ,(assoc-ref model 'colSpan))
    (margin-tb . ,(assoc-ref model 'margin-tb))
    (margin-lr . ,(assoc-ref model 'margin-lr))))

(define (generate-layout-data-components)
  (map component-model->layout-model
       (reverse (generation-components))))

(define (generate-grid-code)
  (unless (generation-grid)
    (error "<grid> has to be defined"))
  (let* ((rows (assoc-ref (generation-grid) 'rows))
         (cols (assoc-ref (generation-grid) 'cols))
         (show-grid (assoc-ref (generation-grid) 'show-grid))
         (layout-components (generate-layout-data-components))
         (grid-data `(("rows" . ,rows) ("cols" . ,cols)))
         (grid-json (json-prepend-key "grid" grid-data))
         (components-json
          (json-prepend-key "components" (list->vector layout-components)))
         (composed
          (scm->json-string
           (append grid-json components-json)
           #:pretty #t)))
    (string-append
     (format #f
             "bool drawDebugGrid = ~a;\n"
             (if show-grid "true" "false"))
     "componentMap = {\n"
     (apply
      string-append
      (map
       (lambda (it)
         (let ((name (assoc-ref it 'var)))
           (format #f "{\"~a\", &~a},\n" name name)))
       layout-components))
     "};\n"
     (format #f
             "\njuce::String jsonString = R\"(~a)\";\n"
             composed))))
