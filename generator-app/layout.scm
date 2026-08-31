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
	    screen:ui-scale
	    screen:ui-size
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
     (width . ,(screen:width screen))
     (ui-scale . ,(screen:ui-scale screen))
     (ui-size . ,(screen:ui-size screen)))))

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
            (width 800)
            (ui-scale #f)
            (ui-size #f))
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
            (exact->inexact ratio)
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


(define* (generate-grid-code #:key
                             (grid-model (generation-grid))
                             (layout-components #f))
  (unless grid-model
    (error "<grid> has to be defined"))

  (let* ((rows
          (assoc-ref grid-model 'rows))

         (cols
          (assoc-ref grid-model 'cols))

         (show-grid
          (assoc-ref grid-model 'show-grid))

         (row-tracks
          (assoc-ref grid-model 'row-tracks))

         (col-tracks
          (assoc-ref grid-model 'col-tracks))

         (layout-components
          (or layout-components
              (generate-layout-data-components)))

         (json-number-list
          (lambda (values)

            (and values

                 (list->vector

                   (map
                     (lambda (value)

                       (if (exact? value)
                           (exact->inexact value)
                           value))

                     values)))))

         (grid-data
          (append

            `(("rows" . ,rows)
              ("cols" . ,cols))

            (if row-tracks

                `(("row-tracks" .
                                 ,(json-number-list
                                    row-tracks)))

                '())

            (if col-tracks

                `(("col-tracks" .
                                 ,(json-number-list
                                    col-tracks)))

                '())))

         (grid-json
          (json-prepend-key
            "grid"
            grid-data))

         (components-json
          (json-prepend-key
            "components"
            (list->vector layout-components)))

         (composed
          (scm->json-string
            (append
              grid-json
              components-json)
            #:pretty #t)))

    (string-append

      "componentMap = {\n"

      (apply
        string-append

        (map

          (lambda (it)

            (let ((name
                   (assoc-ref it 'var)))

              (format #f
                      "{\"~a\", &~a},\n"
                      name
                      name)))

          layout-components))

      "};\n"

      (format #f
              "\njuce::String jsonString = R\"(~a)\";\n"
              composed))))
