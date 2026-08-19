(define-module (generator-app code-generator)
  #:use-module ((algorithms) #:prefix algo:)
  #:use-module ((f) #:prefix f:)
  #:use-module ((f ports) #:prefix fp:)
  #:use-module (pfds sets)
  #:use-module (mtfa error-handler)
  #:use-module (mtfa utils)
  #:use-module (mtfa serializer)
  #:use-module (mtfa unordered-set)
  #:use-module (mtfa unordered-map)
  #:use-module (mtfa star-map)
  #:use-module (mtfa simple_db)
  #:use-module (mtfa eis)
  #:use-module (mtfa va)
  #:use-module (mtfa extset)
  #:use-module (mtfa umset)
  #:use-module (mtfa web)
  #:use-module (mtfa brg)
  #:use-module (mtfa avl)
  #:use-module (mtfa eqt)
  #:use-module (gnutls)
  #:use-module (scheme kwargs)
  #:use-module (search basic)
  #:use-module (math primes)
  #:use-module (match-bind)
  #:use-module (graph topological-sort)
  #:use-module (rnrs bytevectors)
  #:use-module (rnrs arithmetic bitwise)
  #:use-module (rnrs enums)
  #:use-module ((rnrs io ports) #:prefix ioports::)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-11)
  #:use-module ((srfi srfi-18) #:prefix srfi-18::) ;;thread e mutex
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-41) ;;streams
  #:use-module (srfi srfi-42) ;;Eager Comprehensions
  #:use-module (srfi srfi-43)
  #:use-module (srfi srfi-45)
  #:use-module (srfi srfi-60)
  #:use-module (srfi srfi-111) ;;Boxes
  #:use-module (srfi srfi-171)
  #:use-module (web uri)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 pretty-print)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 peg)
  #:use-module (ice-9 peg string-peg)
  #:use-module (ice-9 vlist)
  #:use-module (ice-9 q)
  #:use-module (ice-9 binary-ports)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 threads)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 control)
  #:use-module (ice-9 match)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 eval-string)
  #:use-module (ice-9 local-eval)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 arrays)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 optargs)
  #:use-module (ice-9 string-fun)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (json)
  #:use-module (system syntax)
  #:use-module (system foreign)
  #:use-module (system foreign-library)
  #:use-module (web server)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (web client)
  ;;
  #:use-module (generator-app globals)
  #:use-module (generator-app tools)
  #:use-module (generator-app genera-classi)
  )

;; ======================================================================
;; RESOURCE MODEL
;; ======================================================================

(new-class <image-set>
           ()
           ((name "")
            (source-directory "")
            (files '()))
           #:code
           (register-image-set! this))

(define-generic register-image-set!)
(export register-image-set!)

(define-method (register-image-set! (resource <image-set>))
  (let ((name  (image-set:name resource))
	(source-directory (image-set:source-directory resource))
        (files (image-set:files resource)))

    (unless (and (string? name)
                 (not (string-null? name)))
      (error "Image set requires a non-empty name"))

    (unless (and (string? source-directory)
		 (not (string-null? source-directory)))
      (error "Image set requires a non-empty source-directory"
             name))
    
    (unless (and (list? files)
                 (every string? files))
      (error "Image set files must be a list of strings"
             name
             files))

    (for-each
     (lambda (file)
       (let ((path
              (string-append
               source-directory
               "/"
	       name "/"
               file)))
	 (unless (file-exists? path)
	   (error "Image set file does not exist"
		  name
		  path))))
     files)

    (when (find
           (lambda (entry)
             (equal? (assoc-ref entry 'name)
                     name))
           *image-sets*)
      (error "Duplicate image set name"
             name))

    (let ((model
           `((name  . ,name)
             (source-directory . ,source-directory)
             (files . ,files))))

      (set! *image-sets*
            (cons model *image-sets*))

      model)))

(define-public (materialize-image-sets! dst-folder)

  (for-each
   (lambda (image-set)

     (let* ((name
             (assoc-ref image-set 'name))

            (source-directory
             (assoc-ref image-set 'source-directory))

            (files
             (assoc-ref image-set 'files))

            (source-set-directory
             (string-append
              source-directory
              "/"
              name))

            (destination-set-directory
             (string-append
              dst-folder
              "/Resources/"
              name)))

       ;; --------------------------------------------------------
       ;; Resources/<name> è completamente gestita dal Generator.
       ;; La ricreiamo ad ogni generazione.
       ;; --------------------------------------------------------
       (when (file-exists? destination-set-directory)
         (f:delete destination-set-directory #t))

       (mkdir destination-set-directory)

       ;; --------------------------------------------------------
       ;; Copia esattamente i file dichiarati dalla DSL.
       ;; --------------------------------------------------------
       (for-each
        (lambda (file)
	  (let* ((generated-file
		  (generated-resource-filename name file))

		 (source
		  (string-append
		   source-set-directory
		   "/"
		   file))

		 (destination
		  (string-append
		   destination-set-directory
		   "/"
		   generated-file)))

	    (copy-file source destination))
          )
        files)))

   *image-sets*)

  #t)



;; ======================================================================
;; IMAGE SETS -> JUCER RESOURCE ENTRIES
;; ======================================================================

(define-public (generate-image-resource-jucer-code)

  (let ((counter 0))

    (define (next-id)
      (set! counter (+ counter 1))
      (format #f "GIR~4,'0d" counter))

    (string-concatenate
     (map
      (lambda (image-set)

        (let ((name  (assoc-ref image-set 'name))
              (files (assoc-ref image-set 'files)))

          (string-concatenate
           (map
            (lambda (file)

	      (let ((generated-file
		     (generated-resource-filename name file)))

		(format #f
			"      <FILE id=\"~a\" name=\"~a\" compile=\"0\" resource=\"1\" file=\"Resources/~a/~a\"/>~%"
			(next-id)
			generated-file
			name
			generated-file)))

            files))))

      ;; *image-sets* è costruita con cons, quindi ristabiliamo
      ;; l'ordine della DSL.
      (reverse *image-sets*)))))

;; ======================================================================
;; UPDATE JUCER IMAGE RESOURCES
;; ======================================================================

(define-public (update-jucer-image-resources! jucer-file)

  (let* ((start-marker
          "<!-- GENERATED IMAGE RESOURCES START -->")

         (end-marker
          "<!-- GENERATED IMAGE RESOURCES END -->")

         (generated-code
          (generate-image-resource-jucer-code))

         (generated-block
          (string-append
           "    "
           start-marker
           "\n"
           generated-code
           "    "
           end-marker))

         (content
          (call-with-input-file
              jucer-file
            get-string-all))

         (start-pos
          (string-contains content start-marker))

         (end-pos
          (string-contains content end-marker)))

    ;; ============================================================
    ;; CASO 1:
    ;; blocco già presente -> sostituzione completa.
    ;; ============================================================

    (if (and start-pos end-pos)

        (let* ((after-end
                (+ end-pos
                   (string-length end-marker)))

               (new-content
                (string-append
                 (substring content
                            0
                            start-pos)

                 generated-block

                 (substring content
                            after-end))))

          (call-with-output-file
              jucer-file
            (lambda (port)
              (display new-content port))))

        ;; ========================================================
        ;; CASO 2:
        ;; prima generazione -> individua GROUP Resources.
        ;; ========================================================

        (let* ((resources-marker
                "name=\"Resources\"")

               (resources-pos
                (string-contains
                 content
                 resources-marker)))

          (unless resources-pos
            (error
             "Resources group not found in .jucer"
             jucer-file))

          ;; ------------------------------------------------------
          ;; Cerchiamo il primo </GROUP> successivo a
          ;; name="Resources".
          ;;
          ;; Nel template corrente Resources non contiene GROUP
          ;; annidati, quindi questo identifica correttamente
          ;; la sua chiusura.
          ;; ------------------------------------------------------

          (let ((group-end
                 (string-contains
                  content
                  "</GROUP>"
                  resources-pos)))

            (unless group-end
              (error
               "Resources group has no closing </GROUP>"
               jucer-file))

            (let ((new-content
                   (string-append

                    (substring content
                               0
                               group-end)

                    generated-block
                    "\n"

                    (substring content
                               group-end))))

              (call-with-output-file
                  jucer-file
                (lambda (port)
                  (display new-content port)))))))

    #t))

(define-public (generated-resource-filename set-name file)
  (string-append set-name "__" file))

(define-public (generate-image-resource-cpp-code)

  (string-concatenate
   (map
    (lambda (image-set)

      (let* ((name
              (assoc-ref image-set 'name))

             (files
              (assoc-ref image-set 'files))

             (var-name
              (string-append
               "imageSet_"
               (logical-id->cpp-base name))))

        (string-append

         ;; Dichiarazione del vettore
         (format #f
                 "    std::vector<juce::Image> ~a;~%"
                 var-name)

         ;; Caricamento delle immagini
         (string-concatenate
          (map
           (lambda (file)

             (let ((symbol
                    (binary-data-symbol-name name file)))

               (format #f
                       "    ~a.push_back(juce::ImageCache::getFromMemory(BinaryData::~a, BinaryData::~aSize));~%"
                       var-name
                       symbol
                       symbol)))

           files))

         ;; Registrazione del set
         (format #f
                 "    kineticLNF.registerImageSet(\"~a\", ~a);~%~%"
                 name
                 var-name))))

    (reverse *image-sets*))))

;; ======================================================================
;; IMAGE SETS -> C++ / BinaryData
;; ======================================================================

(define (binary-data-symbol-name set-name file)

  ;; Deve partire dallo STESSO filename usato per materializzazione
  ;; e .jucer.
  (let* ((resource-name
          (generated-resource-filename set-name file))

         ;; Projucer trasforma i caratteri non alfanumerici in '_'
         (symbol-name
          (list->string
           (map
            (lambda (c)
              (if (or (char-alphabetic? c)
                      (char-numeric? c))
                  c
                  #\_))
            (string->list resource-name)))))

    ;; Sicurezza nel caso il nome risultante inizi con una cifra.
    (if (char-numeric? (string-ref symbol-name 0))
        (string-append "_" symbol-name)
        symbol-name)))

;; ======================================================================
;; COMPONENT MODEL
;; ======================================================================
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

(new-class <component>
	   (
	    ;; Identificatore logico stabile del componente
	    (id #f)
	    (role #f)
	    ;; Layout.
	    ;; In futuro row/col potranno essere calcolati dal layout solver.
	    (row #f)
	    (col #f)
	    (row-span 1)
	    (col-span 1)
	    (margin-tb 0)
	    (margin-lr 0))
	   #:code
	   #t)

(new-class <label> (<component>)
	   (
	    (text "")
	    (justification 'centred))
	   #:code
	   (register-component! this))

(new-class <selector> (<component>)
	   (
	    (items '())
	    (default-index 0))
	   #:code
	   (register-component! this))

(new-class <button> (<component>)
	   (
	    (text ""))
	   #:code
	   #t)


(new-class <text-button> (<button>)
	   ()
	   #:code
	   (register-component! this))


(new-class <toggle-button> (<button>)
	   (
	    (default-state #f)
	    (style 'normal)
	    ;; binding DAW/APVTS
	    (parameter-id #f)
	    (parameter-name #f)
	    (tooltip "")
	    (processor-reference #f)
	    (version-hint 1))
	   #:code
	   #t)


(new-class <switch> (<toggle-button>)
	   ()
	   #:code
	   (slot-set! this 'style 'switch)
	   (register-component! this))

(new-class <normal-toggle-button> (<toggle-button>)
	   ()
	   #:code
	   (register-component! this))


(new-class <meter> (<component>)
	   (
	    ;; 'segmented oppure 'analog
	    (style 'segmented)
	    ;; proprietà grafiche del KineticMeter
	    (scale-type 'default)
	    (is-sharp #f)
	    (glow-multiplier 1.0)
	    (range-min -60.0)
	    (range-max 6.0)
	    (num-segments 20)
	    (tick-mode 'all))
	   #:code
	   (register-component! this))


(new-class <scope> (<component>)
	   (
	    ;; proprietà grafiche del KineticScope
	    (grid-style 'default)
	    (is-sharp #f)
	    (glow-multiplier 1.0))
	   #:code
	   (register-component! this))

;; ======================================================================
;; SLIDER BASE CLASS
;; ======================================================================
(new-class <slider> (<component>)
	   (
	    (parameter-id #f)
	    (parameter-name #f)
	    (processor-reference #f)
	    (version-hint 1)
	    (title "")
	    (min 0.0)
	    (max 1.0)
	    (default 0.0)
	    (interval 0.0)
	    (scale 'linear)
	    (value-type 'default)
	    (suffix "")
	    (show-value #t)
	    (show-ticks #f)
	    (show-labels #f)
	    (tick-count 0)
	    (tick-mode 'all)
	    (tick-labels '()))
	   #:code
	   #t)

;; ======================================================================
;; ROTARY SLIDER
;; ======================================================================
(new-class <rotary-slider> (<slider>)
	   (
	    (icon-type -1)
	    (morph-icon #f)
	    (icon-set ""))
	   #:code
	   (register-component! this))

;; ======================================================================
;; LINEAR SLIDER
;; ======================================================================
(new-class <linear-slider> (<slider>)
	   ((orientation 'horizontal))
	   #:code
	   (register-component! this))

(new-class <header> (<label>)
  ()
  #:code
  #t)

(new-class <footer> (<label>)
  ()
  #:code
  #t)

(new-class <link> (<label>)
  ((url ""))
  #:code
  #t)

(new-class <palette-label> (<label>)
  ((enable #t)
   (default-theme 3))
  #:code
  #t)


(define-public (register-grid! grid)
  (when *grid*
    (error "Only one grid may be declared"))

  (set! *grid*
        `((rows      . ,(grid:rows grid))
          (cols      . ,(grid:cols grid))
          (show-grid . ,(grid:show-grid grid))))

  *grid*)

(define-public (register-screen! screen)
  (when *screen*
    (error "Only one screen may be declared"))

  (set! *screen*
        `((ratio . ,(screen:ratio screen))
          (width . ,(screen:width screen))))

  *screen*)


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

(define-public (generate-screen-size-code)
  (unless *screen*
    (error "<screen> has to be defined"))

  (let ((ratio (assoc-ref *screen* 'ratio))
        (width (assoc-ref *screen* 'width)))

    (format #f
"screenRatio = ~a;
standardScreenWidth = ~a;
standardScreenHeight = standardScreenWidth / screenRatio;
"
            ratio
            width)))


(define-public (generate-grid-code)

  (unless *grid*
    (error "<grid> has to be defined"))

  (let* ((rows
          (assoc-ref *grid* 'rows))

         (cols
          (assoc-ref *grid* 'cols))

         (show-grid
          (assoc-ref *grid* 'show-grid))

         ;; Forma richiesta dal JSON esistente
         (grid-data
          `(("rows" . ,rows)
            ("cols" . ,cols)))

         (grid-json
          (json-prepend-key
           "grid"
           grid-data))

         (components-json
          (json-prepend-key
           "components"
           (list->vector layout-data-components)))

         (composed
          (scm->json-string
           (append grid-json components-json)
           #:pretty #t)))

    (string-append

     ;; Debug grid
     (format #f
             "bool drawDebugGrid = ~a;\n"
             (if show-grid
                 "true"
                 "false"))

     ;; componentMap
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
       layout-data-components))

     "};\n"

     ;; JSON layout
     (format #f
             "\njuce::String jsonString = R\"(~a)\";\n"
             composed))))


;; ;;Old classes
;; ;;Lo schermo. Genera le configurazioni dello schermo , compresa la presenza o meno della griglia
;; (new-class <screen>
;; 	   ((ratio (/ (+ 1.0 (sqrt 5.0)) 2.0)) ; Diventerà #:init-form
;; 	    (width 800)			; Diventerà #:init-value
;; 	    (rows 15)			; Diventerà #:init-value
;; 	    (cols 24)
;; 	    (show-grid #t))		; Diventerà #:init-value
;; 	   #:code
;; 	   (begin
;; 	     (GenerateAssignements *SCREENSIZE*
;; 				   (screenRatio ratio)
;; 				   (standardScreenWidth width)
;; 				   (standardScreenHeight "standardScreenWidth / screenRatio"))
;; 	     ;; (AppendStringTo *GRIDONOFF* (string-append "bool drawDebugGrid = " (if show-grid "true;\n" "false;\n")))
;; 	     (set! layout-data-grid `(("rows" . ,rows)("cols" . ,cols)))))

;; header e footer
(new-class <header-footer>
	   (
	    ;; Identificatore logico del composito
	    (id "Main Header Footer")
	    ;; Header
	    (title-header "YAPlugin")
	    (row-header 1)
	    (col-header 8)
	    (row-span-header 1)
	    (col-span-header 8)
	    (margin-tb-header 0)
	    (margin-lr-header 0)
	    ;; Footer
	    (title-footer "Copyright (c) 2025 AF-Audio")
	    (row-footer 15)
	    (col-footer 20)
	    (row-span-footer 1)
	    (col-span-footer 4)
	    (margin-tb-footer 12)
	    (margin-lr-footer 0)
	    ;; Link
	    (title-link "https://www.aacf-music.eu/")
	    (url-link "https://www.aacf-music.eu/")
	    (row-link 15)
	    (col-link 1)
	    (row-span-link 1)
	    (col-span-link 5)
	    (margin-tb-link 0)
	    (margin-lr-link 0))
	   #:code
	   (let ((base id))
	     (make <header>
               #:id
               (string-append base " Header")
               #:text title-header
               #:row row-header
               #:col col-header
               #:row-span row-span-header
               #:col-span col-span-header
               #:margin-tb margin-tb-header
               #:margin-lr margin-lr-header)
	     (make <footer>
               #:id
               (string-append base " Footer")
               #:text title-footer
               #:row row-footer
               #:col col-footer
               #:row-span row-span-footer
               #:col-span col-span-footer
               #:margin-tb margin-tb-footer
               #:margin-lr margin-lr-footer)
	     (make <link>
               #:id
               (string-append base " Link")
               #:text title-link
               #:url url-link
               #:row row-link
               #:col col-link
               #:row-span row-span-link
               #:col-span col-span-link
               #:margin-tb margin-tb-link
               #:margin-lr margin-lr-link)))

(define *kinetic-palettes*
  '("Cyan (Cyberpunk)"
    "Plasma (Purple)"
    "Gold (Amber)"
    "Matrix (Green)"
    "Fire (Red)"
    "Ocean (Blue)"
    "Toxic (Lime)"
    "Radon (Pink)"
    "White (Mono)"
    "Midnight (Dark)"
    "Sunset (Orange)"
    "Mint (Teal)"
    "Vaporwave (Pink)"
    "Amber (Amber)"
    "Crimson (Red)"
    "Voltage (Yellow)"
    "Ultraviolet (Violet)"
    "Stealth (Grey)"))

(new-class <palette-selector> (<selector>)
	   ()
	   #:code
	   #t)

(new-class <palette>
	   (
	    (id "Main Palette")
	    (enable #t)
	    (default-theme 3)
	    (title-palette "Theme")
	    (row-palette 1)
	    (col-palette 20)
	    (row-span-palette 1)
	    (col-span-palette 2)
	    (margin-tb-palette 12)
	    (margin-lr-palette 0)
	    (row-selector 1)
	    (col-selector 22)
	    (row-span-selector 1)
	    (col-span-selector 3)
	    (margin-tb-selector 10)
	    (margin-lr-selector 4))
	   #:code
	   (when enable
	     (make <palette-label>
               #:id
               (string-append id " Label")
               #:text title-palette
               #:enable enable
               #:default-theme default-theme
               #:justification 'centred-right
               #:row row-palette
               #:col col-palette
               #:row-span row-span-palette
               #:col-span col-span-palette
               #:margin-tb margin-tb-palette
               #:margin-lr margin-lr-palette)
	     (make <palette-selector>
               #:id
               (string-append id " Selector")
               #:items *kinetic-palettes*
               ;; selector usa indice 0-based
               #:default-index default-theme
               #:row row-selector
               #:col col-selector
               #:row-span row-span-selector
               #:col-span col-span-selector
               #:margin-tb margin-tb-selector
               #:margin-lr margin-lr-selector)))

(new-class <bypass-switch> (<switch>)
  ()
  #:code
  #t)

(define-public (processor-param-var model)
  (string-append
   "param_"
   (assoc-ref model 'processor-reference)))

(define-public (processor-value-var model)
  (string-append
   "value_"
   (assoc-ref model 'processor-reference)))

(define-public (processor-reference model)
  (assoc-ref model 'processor-reference))

;; ======================================================================
;; COMPONENT TYPE
;;
;; Restituisce il tipo semantico concreto del componente.
;; ======================================================================
(define-generic component-type)
(export component-type)

(define-method (component-type (c <component>))
  'component)

(define-method (component-type (s <slider>))
  'slider)

(define-method (component-type (s <rotary-slider>))
  'rotary-slider)

(define-method (component-type (s <linear-slider>))
  'linear-slider)

(define-method (component-type (c <label>))
  'label)

(define-method (component-type (c <selector>))
  'selector)

(define-method (component-type (b <button>))
  'button)

(define-method (component-type (b <text-button>))
  'text-button)

(define-method (component-type (b <toggle-button>))
  'toggle-button)

(define-method (component-type (b <normal-toggle-button>))
  'toggle-button)

(define-method (component-type (b <switch>))
  'switch)

(define-method (component-type (m <meter>))
  'meter)

(define-method (component-type (s <scope>))
  'scope)

(define-method (component-type (c <header>))
  'header)

(define-method (component-type (c <footer>))
  'footer)

(define-method (component-type (c <link>))
  'link)

(define-method (component-type (c <palette-label>))
  'palette-label)

(define-method (component-type (c <palette-selector>))
  'palette-selector)

(define-method (component-type (b <bypass-switch>))
  'bypass-switch)


;; ======================================================================
;; COMPONENT -> MODEL
;;
;; Trasforma un oggetto GOOPS nel modello intermedio.
;;
;; IMPORTANTE:
;; questa operazione NON alloca il nome della variabile C++.
;; component->model deve rimanere priva di quell'effetto collaterale.
;; ======================================================================
(define-generic component->model)
(export component->model)

(define-method (component->model (c <component>))
  `((id        . ,(component:id c))
    (type      . ,(component-type c))
    (role      . ,(component:role c))
    (row       . ,(component:row c))
    (col       . ,(component:col c))
    (rowSpan   . ,(component:row-span c))
    (colSpan   . ,(component:col-span c))
    (margin-tb . ,(component:margin-tb c))
    (margin-lr . ,(component:margin-lr c))))

(define-method (component->model (b <button>))
  (append
   (next-method)
   `((text . ,(button:text b)))))

(define-method (component->model (b <toggle-button>))
  (append
   (next-method)
   `((default-state       . ,(toggle-button:default-state b))
     (style               . ,(toggle-button:style b))
     (parameter-id        . ,(toggle-button:parameter-id b))
     (parameter-name      . ,(toggle-button:parameter-name b))
     (processor-reference . ,(toggle-button:processor-reference b))
     (version-hint        . ,(toggle-button:version-hint b))
     (tooltip             . ,(toggle-button:tooltip b)))))

(define-method (component->model (c <label>))
  (append
   (next-method)
   `((text          . ,(label:text c))
     (justification . ,(label:justification c)))))

(define-method (component->model (c <link>))
  (append
   (next-method)
   `((url . ,(link:url c)))))

(define-method (component->model (c <palette-label>))
  (append
   (next-method)
   `((enable        . ,(palette-label:enable c))
     (default-theme . ,(palette-label:default-theme c)))))

(define-method (component->model (c <selector>))
  (append
   (next-method)
   `((items         . ,(selector:items c))
     (default-index . ,(selector:default-index c)))))

(define-method (component->model (s <slider>))
  (append
   (next-method)
   `((parameter-id        . ,(slider:parameter-id s))
     (parameter-name      . ,(slider:parameter-name s))
     (processor-reference . ,(slider:processor-reference s))
     (version-hint        . ,(slider:version-hint s))
     (title               . ,(slider:title s))
     (min                 . ,(slider:min s))
     (max                 . ,(slider:max s))
     (default             . ,(slider:default s))
     (interval            . ,(slider:interval s))
     (scale               . ,(slider:scale s))
     (value-type          . ,(slider:value-type s))
     (suffix              . ,(slider:suffix s))
     (show-value          . ,(slider:show-value s))
     (show-ticks          . ,(slider:show-ticks s))
     (show-labels         . ,(slider:show-labels s))
     (tick-count          . ,(slider:tick-count s))
     (tick-mode           . ,(slider:tick-mode s))
     (tick-labels         . ,(slider:tick-labels s)))))

(define-method (component->model (s <rotary-slider>))
  (append
   (next-method)
   `((icon-type  . ,(rotary-slider:icon-type s))
     (morph-icon . ,(rotary-slider:morph-icon s))
     (icon-set   . ,(rotary-slider:icon-set s)))))

(define-method (component->model (s <linear-slider>))
  (append
   (next-method)
   `((orientation . ,(linear-slider:orientation s)))))

(define-method (component->model (m <meter>))
  (append
   (next-method)
   `((style           . ,(meter:style m))
     (scale-type      . ,(meter:scale-type m))
     (is-sharp        . ,(meter:is-sharp m))
     (glow-multiplier . ,(meter:glow-multiplier m))
     (range-min       . ,(meter:range-min m))
     (range-max       . ,(meter:range-max m))
     (num-segments    . ,(meter:num-segments m))
     (tick-mode       . ,(meter:tick-mode m)))))

(define-method (component->model (s <scope>))
  (append
   (next-method)
   `((grid-style      . ,(scope:grid-style s))
     (is-sharp        . ,(scope:is-sharp s))
     (glow-multiplier . ,(scope:glow-multiplier s)))))




;; ======================================================================
;; COMPONENT REGISTRY
;;
;; *components* continua ad essere il registro centrale.
;;
;; register-component! supporta:
;;
;;   1. alist legacy già costruiti
;;   2. nuovi oggetti derivati da <component>
;;
;; ======================================================================
(define-generic register-component!)
(export register-component!)

;; ----------------------------------------------------------------------
;; Ricerca per logical ID
;; ----------------------------------------------------------------------
(define-public (find-component id)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'id)
             id))
   *components*))

(define-public (find-component-by-role role)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'role) role))
   *components*))

(define-public (component-role-used? role)
  (if (find-component-by-role role) #t #f))

(define-public (validate-component-role model)
  (let ((role (assoc-ref model 'role)))
    (when (and role
               (memq role *unique-component-roles*)
               (find-component-by-role role))
      (error "Duplicate component role" role)))
  #t)
(define-public (role-present? role)
  (if (find-component-by-role role) #t #f))

(define-public (role-model role)
  (find-component-by-role role))
;;
;; ----------------------------------------------------------------------
;; Verifica esistenza logical ID
;; ----------------------------------------------------------------------
(define-public (component-id-used? id)
  (if (find-component id)
      #t
      #f))

(define-public (slider-parameter-type? type)
  (memq type
        '(rotary-slider
          linear-slider)))

(define-public (button-parameter-type? type)
  (memq type
        '(toggle-button
          normal-toggle-button
          switch
          bypass-switch)))

(define-public (parameter-component-type? type)
  (or (slider-parameter-type? type)
      (button-parameter-type? type)))


(define (slider-properties->cpp model)
  (let ((var         (assoc-ref model 'var))
        (title       (assoc-ref model 'title))
        (value-type  (assoc-ref model 'value-type))
        (suffix      (assoc-ref model 'suffix))
        (show-value  (assoc-ref model 'show-value))
        (show-ticks  (assoc-ref model 'show-ticks))
        (show-labels (assoc-ref model 'show-labels))
        (tick-count  (assoc-ref model 'tick-count))
        (tick-mode   (assoc-ref model 'tick-mode))
        (tick-labels (assoc-ref model 'tick-labels)))

    (string-append

     (format #f
"~a.getProperties().set(\"title\", ~a);
"
             var
             (cpp-string title))

     (format #f
"~a.getProperties().set(\"valueType\", ~a);
"
             var
             (cpp-string
              (symbol->string value-type)))

     (format #f
"~a.getProperties().set(\"suffix\", ~a);
"
             var
             (cpp-string suffix))

     (format #f
"~a.getProperties().set(\"showValue\", ~a);
"
             var
             (bool->cpp show-value))

     (format #f
"~a.getProperties().set(\"showTicks\", ~a);
"
             var
             (bool->cpp show-ticks))

     (format #f
"~a.getProperties().set(\"showLabels\", ~a);
"
             var
             (bool->cpp show-labels))

     (format #f
"~a.getProperties().set(\"tickCount\", ~a);
"
             var
             tick-count)

     (format #f
"~a.getProperties().set(\"tickMode\", ~a);
"
             var
             (cpp-string
              (symbol->string tick-mode)))

     ;; tick-labels lo affrontiamo separatamente se non è già emesso.
     )))
;; ----------------------------------------------------------------------
;; Validazione di un modello già completo.
;;
;; Questa serve principalmente al percorso legacy, nel quale il modello
;; arriva già dotato anche di 'var.
;; ----------------------------------------------------------------------
(define (validate-component-model model)
  (let ((id
         (assoc-ref model 'id))
        (type
         (assoc-ref model 'type))
        (var
         (assoc-ref model 'var)))
    (unless id
      (error "Component without logical id"
             model))
    (unless type
      (error "Component without type"
             model))
    (unless var
      (error "Component without C++ identifier"
             model))
    (when (component-id-used? id)
      (error "Duplicate component logical id"
             id))
    #t))

(define (slider-normalisable-range->cpp model)
  (let ((min      (assoc-ref model 'min))
        (max      (assoc-ref model 'max))
        (interval (assoc-ref model 'interval))
        (scale    (assoc-ref model 'scale)))
    (case scale
      ((linear)
       (format #f
               "juce::NormalisableRange<float>(~a, ~a, ~a)"
               min
               max
               interval))
      ((logarithmic)
       (when (or (<= min 0)
                 (<= max 0))
         (error "Logarithmic parameter requires positive min/max"
                model))
       (let ((midpoint (sqrt (* min max))))
         (format #f
		 "[] {
    juce::NormalisableRange<float> range(~a, ~a, ~a);
    range.setSkewForCentre(~a);
    return range;
}()"
                 min
                 max
                 interval
                 midpoint)))
      (else
       (error "Invalid slider scale"
              scale)))))

;; ======================================================================
;; REGISTRAZIONE LEGACY
;;
;; Palette, header/footer e gli altri componenti non ancora migrati
;; possono continuare a passare un alist già costruito.
;; ======================================================================
(define-method (register-component! (component <list>))
  (validate-component-model component)
  (set! *components*
        (cons component
              *components*))
  component)

;; ======================================================================
;; REGISTRAZIONE NUOVO MODELLO GOOPS
;;
;; Oggetto <component>
;;      |
;;      v
;; component->model
;;      |
;;      v
;; logical-id
;;      |
;;      v
;; allocate-cpp-identifier!
;;      |
;;      v
;; aggiunta di (var . ...)
;;      |
;;      v
;; *components*
;; ======================================================================
(define-method (register-component! (component <component>))
  (validate-component! component)
  (let* ((model
          (component->model component))
         (logical-id
          (assoc-ref model 'id)))
    ;; ------------------------------------------------------------
    ;; Un nuovo componente deve sempre avere un logical ID.
    ;; ------------------------------------------------------------
    (unless logical-id
      (error "Component without logical id"
             model))
    ;; ------------------------------------------------------------
    ;; Il logical ID deve essere unico.
    ;;
    ;; Questo controllo DEVE avvenire prima dell'allocazione
    ;; dell'identificatore C++.
    ;; ------------------------------------------------------------
    (when (component-id-used? logical-id)
      (error "Duplicate component logical id"
             logical-id))
    ;; ------------------------------------------------------------
    ;; I role semantici dichiarati unici non possono comparire
    ;; più di una volta.
    ;; ------------------------------------------------------------
    (validate-component-role model)
    ;; ------------------------------------------------------------
    ;; Solo ora viene allocato il nome C++.
    ;; ------------------------------------------------------------
    (let* ((cpp-id
            (allocate-cpp-identifier!
             logical-id))
           (registered-model
            `((var . ,cpp-id)
              ,@model)))
      ;; ----------------------------------------------------------
      ;; component-type deve aver prodotto un tipo valido.
      ;; ----------------------------------------------------------
      (unless (assoc-ref registered-model 'type)
        (error "Component without type"
               registered-model))
      ;; ----------------------------------------------------------
      ;; Registrazione definitiva.
      ;; ----------------------------------------------------------
      (set! *components*
	    (cons registered-model
		  *components*))
      ;; Per ora alimentiamo anche il vecchio sistema di layout.
      ;; In futuro layout-data-components verrà prodotto dal solver.
      (set! layout-data-components
	    (cons
	     (component-model->layout-model registered-model)
	     layout-data-components))
      registered-model)))

(define (component-cpp-var component)
  (let* ((id (component:id component))
         (registered (find-component id)))
    (unless registered
      (error "Component not registered" id))
    (let ((var
           (assoc-ref registered 'var)))
      (unless var
        (error "Registered component without C++ identifier"
               registered))
      var)))
(export component-cpp-var)

(define-generic component->member-declaration)
(export component->member-declaration)

(define-method (component->member-declaration (s <slider>))
  (format #f
          "juce::Slider ~a;~%"
          (component-cpp-var s)))

(define-generic model->member-declaration)
(export model->member-declaration)

(define-method (model->member-declaration (model <list>))
  (let ((type (assoc-ref model 'type))
        (var  (assoc-ref model 'var)))
    (case type
      ((rotary-slider linear-slider)
       (format #f
               "juce::Slider ~a;~%"
               var))
      ((selector palette-selector)
       (format #f
               "juce::ComboBox ~a;~%"
               var))
      ((text-button)
       (format #f
               "juce::TextButton ~a;~%"
               var))
      ((toggle-button switch bypass-switch)
       (format #f
               "juce::ToggleButton ~a;~%"
               var))
      ((meter)
       (format #f
               "KineticMeter ~a;~%"
               var))
      ((scope)
       (format #f
               "KineticScope ~a;~%"
               var))
      ((label header footer link palette-label)
       (format #f
               "juce::Label ~a;~%"
               var))
      (else ""))))

(define (meter-properties->cpp model)
  (let ((var             (assoc-ref model 'var))
        (style           (assoc-ref model 'style))
        (scale-type      (assoc-ref model 'scale-type))
        (is-sharp        (assoc-ref model 'is-sharp))
        (glow-multiplier (assoc-ref model 'glow-multiplier))
        (range-min       (assoc-ref model 'range-min))
        (range-max       (assoc-ref model 'range-max))
        (num-segments    (assoc-ref model 'num-segments))
        (tick-mode       (assoc-ref model 'tick-mode)))
    (string-append
     (format #f
             "~a.setStyle(KineticMeter::MeterStyle::~a);~%"
             var
             (case style
               ((segmented) "Segmented")
               ((analog)    "Analog")))
     (format #f
             "~a.properties.set(\"scaleType\", \"~a\");~%"
             var
             (cpp-string
              (symbol->string scale-type)))
     (if is-sharp
         (format #f
                 "~a.properties.set(\"isSharp\", true);~%"
                 var)
         "")
     (format #f
             "~a.properties.set(\"glowMultiplier\", ~a);~%"
             var
             glow-multiplier)
     (format #f
             "~a.properties.set(\"rangeMin\", ~a);~%"
             var
             range-min)
     (format #f
             "~a.properties.set(\"rangeMax\", ~a);~%"
             var
             range-max)
     (format #f
             "~a.properties.set(\"numSegments\", ~a);~%"
             var
             num-segments)
     (format #f
             "~a.properties.set(\"tickMode\", \"~a\");~%"
             var
             (cpp-string
              (symbol->string tick-mode))))))

(define (scope-properties->cpp model)
  (let ((var             (assoc-ref model 'var))
        (grid-style      (assoc-ref model 'grid-style))
        (is-sharp        (assoc-ref model 'is-sharp))
        (glow-multiplier (assoc-ref model 'glow-multiplier)))
    (string-append
     (format #f
             "~a.properties.set(\"gridStyle\", \"~a\");~%"
             var
             (cpp-string
              (symbol->string grid-style)))
     (if is-sharp
         (format #f
                 "~a.properties.set(\"isSharp\", true);~%"
                 var)
         "")
     (format #f
             "~a.properties.set(\"glowMultiplier\", ~a);~%"
             var
             glow-multiplier))))

(define-public (generate-member-declarations)
  (apply string-append
         (map model->member-declaration
              (reverse *components*))))


(define (palette-selector-callback->cpp model)
  (let ((var
         (assoc-ref model 'var)))
    (format #f
"~a.setWantsKeyboardFocus(false);
~a.onChange = [this]
{
    KineticLookAndFeel::PaletteType type;
    switch (~a.getSelectedId())
    {
        case 1:  type = KineticLookAndFeel::PaletteType::Cyan; break;
        case 2:  type = KineticLookAndFeel::PaletteType::Plasma; break;
        case 3:  type = KineticLookAndFeel::PaletteType::Gold; break;
        case 4:  type = KineticLookAndFeel::PaletteType::Matrix; break;
        case 5:  type = KineticLookAndFeel::PaletteType::Fire; break;
        case 6:  type = KineticLookAndFeel::PaletteType::Ocean; break;
        case 7:  type = KineticLookAndFeel::PaletteType::Toxic; break;
        case 8:  type = KineticLookAndFeel::PaletteType::Radon; break;
        case 9:  type = KineticLookAndFeel::PaletteType::White; break;
        case 10: type = KineticLookAndFeel::PaletteType::Midnight; break;
        case 11: type = KineticLookAndFeel::PaletteType::Sunset; break;
        case 12: type = KineticLookAndFeel::PaletteType::Mint; break;
        case 13: type = KineticLookAndFeel::PaletteType::Vaporwave; break;
        case 14: type = KineticLookAndFeel::PaletteType::Amber; break;
        case 15: type = KineticLookAndFeel::PaletteType::Crimson; break;
        case 16: type = KineticLookAndFeel::PaletteType::Voltage; break;
        case 17: type = KineticLookAndFeel::PaletteType::Ultraviolet; break;
        case 18: type = KineticLookAndFeel::PaletteType::Stealth; break;
        default:
            type = KineticLookAndFeel::PaletteType::Cyan;
            break;
    }
    kineticLNF.animatePaletteChange(type, 2000);
    repaint();
};
~a.setWantsKeyboardFocus(true);
"
            var
            var
            var
            var)))

(define-generic model->constructor-code)
(export model->constructor-code)

(define-method (model->constructor-code (model <list>))
  (let ((type        (assoc-ref model 'type))
        (var         (assoc-ref model 'var))
        (min         (assoc-ref model 'min))
        (max         (assoc-ref model 'max))
        (interval    (assoc-ref model 'interval))
        (orientation (assoc-ref model 'orientation)))
    (case type
      ((rotary-slider)
       (string-append
        (format #f
                "addAndMakeVisible(~a);~%"
                var)
        (format #f
                "~a.setRange(~a, ~a, ~a);~%"
                var min max interval)
        (format #f
                "~a.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);~%"
                var)
	;; Il valore viene disegnato dal KineticLookAndFeel.
	;; Eliminiamo il TextBox standard JUCE.
	(format #f
		"~a.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);~%"
		var)

        (slider-scale->cpp model)
	(slider-kinetic-properties->cpp model)
	(rotary-kinetic-properties->cpp model)))
      ((linear-slider)
       (string-append
        (format #f
                "addAndMakeVisible(~a);~%"
                var)
        (format #f
                "~a.setRange(~a, ~a, ~a);~%"
                var min max interval)
        (format #f
                "~a.setSliderStyle(~a);~%"
                var
                (case orientation
                  ((horizontal)
                   "juce::Slider::LinearHorizontal")
                  ((vertical)
                   "juce::Slider::LinearVertical")
                  (else
                   (error
                    "Invalid linear slider orientation"
                    orientation))))
	;; Il valore viene disegnato dal KineticLookAndFeel.
	(format #f
		"~a.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);~%"
		var)
        (slider-scale->cpp model)
	(slider-kinetic-properties->cpp model)))
      ;; ((selector)
      ;;  (let ((items
      ;;         (assoc-ref model 'items))
      ;; 	     (default-index
      ;;          (assoc-ref model 'default-index)))
      ;; 	 (string-append
      ;; 	  (format #f
      ;; 		  "addAndMakeVisible(~a);~%"
      ;; 		  var)
      ;; 	  (selector-items->cpp
      ;; 	   var
      ;; 	   items)
      ;; 	  (format #f
      ;; 		  "~a.setSelectedItemIndex(~a, juce::dontSendNotification);~%"
      ;; 		  var
      ;; 		  default-index))))
      ((text-button)
       (let ((text
              (assoc-ref model 'text)))
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setButtonText(\"~a\");~%"
		  var
		  (cpp-string text)))))
      ((toggle-button switch bypass-switch)
       (let ((text
              (assoc-ref model 'text))
	     (default-state
               (assoc-ref model 'default-state))
	     (style
		 (assoc-ref model 'style))
	     (tooltip
              (assoc-ref model 'tooltip))
	     (role
	      (assoc-ref model 'role))
	     )
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setButtonText(\"~a\");~%"
		  var
		  (cpp-string text))
	  (format #f
		  "~a.setToggleState(~a, juce::dontSendNotification);~%"
		  var
		  (bool->cpp default-state))
	  (if (memq role '(bypass dsp-bypass))
	      (format #f
		      "~a.onStateChange = [this] { repaint(); };~%"
		      var)
	      "")
	  (if (eq? style 'switch)
              (format #f
                      "~a.getProperties().set(\"style\", \"switch\");~%"
                      var)
              "")
	      (if (and tooltip
             (not (string-null? tooltip)))
        (format #f
                "~a.setTooltip(\"~a\");~%"
                var
                (cpp-string tooltip))
        ""))))
      ((meter)
       (string-append
	(format #f
		"addAndMakeVisible(~a);~%"
		var)
	(meter-properties->cpp model)))
      ((scope)
       (string-append
	(format #f
		"addAndMakeVisible(~a);~%"
		var)
	(scope-properties->cpp model)))
      ((header)
       (let ((text (assoc-ref model 'text)))
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setText(\"~a\", juce::dontSendNotification);~%"
		  var
		  (cpp-string text))
	  (format #f
		  "~a.setFont(juce::FontOptions(32.0f).withStyle(\"Bold\"));~%"
		  var)
	  (format #f
		  "~a.setJustificationType(juce::Justification::centred);~%"
		  var)
	  (format #f
		  "~a.setColour(juce::Label::textColourId, kineticLNF.currentPalette.neonWhite);~%"
		  var))))
      ((footer)
       (let ((text (assoc-ref model 'text)))
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setText(\"~a\", juce::dontSendNotification);~%"
		  var
		  (cpp-string text))
	  (format #f
		  "~a.setName(\"~a\");~%"
		  var
		  (cpp-string var))
	  (format #f
		  "~a.setFont(juce::FontOptions(12.0f));~%"
		  var)
	  (format #f
		  "~a.setJustificationType(juce::Justification::bottomRight);~%"
		  var)
	  (format #f
		  "~a.setColour(juce::Label::textColourId, juce::Colours::grey);~%"
		  var))))
      ((link)
       (let ((text (assoc-ref model 'text)))
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setText(\"~a\", juce::dontSendNotification);~%"
		  var
		  (cpp-string text))
	  (format #f
		  "~a.setName(\"~a\");~%"
		  var
		  (cpp-string var))
	  (format #f
		  "~a.setFont(juce::FontOptions(12.0f));~%"
		  var)
	  (format #f
		  "~a.setJustificationType(juce::Justification::bottomLeft);~%"
		  var)
	  (format #f
		  "~a.setColour(juce::Label::textColourId, juce::Colours::grey);~%"
		  var)
	  (format #f
		  "~a.setMinimumHorizontalScale(1.0f);~%"
		  var)
	  (format #f
		  "~a.setMouseCursor(juce::MouseCursor::PointingHandCursor);~%"
		  var)
	  (format #f
		  "~a.addMouseListener(this, false);~%"
		  var))))
      ((selector)
       (selector-constructor-code model))
      ((palette-selector)
       (string-append
        (selector-constructor-code model)
        (palette-selector-callback->cpp model)))
      ((label palette-label)
       (let ((text
              (assoc-ref model 'text))
	     (justification
              (assoc-ref model 'justification)))
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setText(\"~a\", juce::dontSendNotification);~%"
		  var
		  (cpp-string text))
	  (format #f
		  "~a.setJustificationType(~a);~%"
		  var
		  (justification->cpp justification)))))
      (else ""))))

(define-public (generate-constructor-code)
  (apply string-append
         (map model->constructor-code
              (reverse *components*))))

(define (selector-constructor-code model)
  (let ((var
         (assoc-ref model 'var))
        (items
         (assoc-ref model 'items))
        (default-index
          (assoc-ref model 'default-index)))
    (string-append
     (format #f
             "addAndMakeVisible(~a);~%"
             var)
     (selector-items->cpp
      var
      items)
     (format #f
             "~a.setSelectedId(~a);~%"
             var
             default-index))))

(define-public (slider-scale->cpp model)
  (let ((scale (assoc-ref model 'scale))
        (var   (assoc-ref model 'var))
        (min   (assoc-ref model 'min))
        (max   (assoc-ref model 'max)))
    (case scale
      ((linear) "")
      ((logarithmic)
       (when (or (not min)
                 (not max)
                 (<= min 0)
                 (<= max 0))
         (error "Logarithmic slider requires min/max > 0" model))
       (let ((midpoint
              (sqrt (* min max))))
         (format #f "~a.setSkewFactorFromMidPoint(~a);~%" var midpoint)))
      (else (error "Invalid slider scale" scale)))))

(define-public (bool->cpp b)
  (if b "true" "false"))

(define-public (slider-kinetic-properties->cpp model)
  (let ((var         (assoc-ref model 'var))
        (title       (assoc-ref model 'title))
        (value-type  (assoc-ref model 'value-type))
        (suffix      (assoc-ref model 'suffix))
        (show-value  (assoc-ref model 'show-value))
        (show-ticks  (assoc-ref model 'show-ticks))
        (show-labels (assoc-ref model 'show-labels))
        (tick-count  (assoc-ref model 'tick-count))
        (tick-mode   (assoc-ref model 'tick-mode))
        (tick-labels (assoc-ref model 'tick-labels)))
    (string-append
     ;; title
     (if (and title
              (not (string-null? title)))
         (format #f
                 "~a.getProperties().set(\"title\", \"~a\");~%"
                 var (cpp-string title))
         "")
     ;; valueType
     (if value-type
         (format #f
                 "~a.getProperties().set(\"valueType\", \"~a\");~%"
                 var
                 (cpp-string (symbol->string value-type)))
         "")
     ;; suffix
     (if (and suffix
              (not (string-null? suffix)))
         (format #f
                 "~a.getProperties().set(\"suffix\", \"~a\");~%"
                 var (cpp-string suffix))
         "")
     ;; showValue
     (format #f
             "~a.getProperties().set(\"showValue\", ~a);~%"
             var
             (bool->cpp show-value))
     ;; showTicks:
     ;; per il rotary la PRESENZA della proprietà significa true.
     (if show-ticks
         (format #f
                 "~a.getProperties().set(\"showTicks\", true);~%"
                 var)
         "")
     ;; showLabels usa invece il valore booleano.
     (format #f
             "~a.getProperties().set(\"showLabels\", ~a);~%"
             var
             (bool->cpp show-labels))
     ;; tickCount
     (if (and tick-count
              (> tick-count 0))
         (format #f
                 "~a.getProperties().set(\"tickCount\", ~a);~%"
                 var tick-count)
         "")
     ;; tickMode
     (if tick-mode
         (format #f
                 "~a.getProperties().set(\"tickMode\", \"~a\");~%"
                 var
                 (cpp-string (symbol->string tick-mode)))
         "")
     ;; tickLabels
     (tick-labels->cpp model))))

(define-public (rotary-kinetic-properties->cpp model)
  (format #t
          "ROTARY ~s icon-set=~s morph-icon=~s~%"
          (assoc-ref model 'id)
          (assoc-ref model 'icon-set)
          (assoc-ref model 'morph-icon))
  (let ((var        (assoc-ref model 'var))
        (icon-type  (assoc-ref model 'icon-type))
        (morph-icon (assoc-ref model 'morph-icon))
        (icon-set   (assoc-ref model 'icon-set)))
    (string-append
     ;; iconType
     (if (and icon-type
              (>= icon-type 0))
         (format #f
                 "~a.getProperties().set(\"iconType\", ~a);~%"
                 var
                 icon-type)
         "")
     ;; morphIcon:
     ;; nel KineticLookAndFeel conta la PRESENZA della proprietà.
     (if morph-icon
         (format #f
                 "~a.getProperties().set(\"morphIcon\", true);~%"
                 var)
         "")
     ;; iconSet
     (if (and icon-set
              (not (string-null? icon-set)))
         (format #f
                 "~a.getProperties().set(\"iconSet\", \"~a\");~%"
                 var
                 (cpp-string icon-set))
         ""))))

(define-public (tick-labels->cpp model)
  (let ((var         (assoc-ref model 'var))
        (tick-labels (assoc-ref model 'tick-labels)))
    (if (or (not tick-labels)
            (null? tick-labels))
        ""
        (let ((array-var
               (string-append var "TickLabels")))
          (string-append
           (format #f
                   "juce::Array<juce::var> ~a;~%"
                   array-var)
           (apply string-append
                  (map
                   (lambda (label)
                     (format #f
                             "~a.add(\"~a\");~%"
                             array-var
                             (cpp-string label)))
                   tick-labels))
           (format #f
                   "~a.getProperties().set(\"tickLabels\", juce::var(~a));~%"
                   var
                   array-var))))))

(define-public (cpp-string s)
  (let ((out (open-output-string)))
    (string-for-each
     (lambda (c)
       (case c
         ((#\\)
          (display "\\\\" out))
         ((#\")
          (display "\\\"" out))
         ((#\newline)
          (display "\\n" out))
         ((#\return)
          (display "\\r" out))
         ((#\tab)
          (display "\\t" out))
         (else
          (write-char c out))))
     s)
    (get-output-string out)))

(define-generic validate-component!)
(export validate-component!)

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
  (let ((min     (slider:min s))
        (max     (slider:max s))
        (default (slider:default s))
        (scale   (slider:scale s)))
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
  ;; valida prima tutta la parte <slider>
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


(define (component-model->layout-model model)
  `((var       . ,(assoc-ref model 'var))
    (row       . ,(assoc-ref model 'row))
    (col       . ,(assoc-ref model 'col))
    (rowSpan   . ,(assoc-ref model 'rowSpan))
    (colSpan   . ,(assoc-ref model 'colSpan))
    (margin-tb . ,(assoc-ref model 'margin-tb))
    (margin-lr . ,(assoc-ref model 'margin-lr))))

(define (justification->cpp justification)
  (case justification
    ((centred)
     "juce::Justification::centred")
    ((centred-left)
     "juce::Justification::centredLeft")
    ((centred-right)
     "juce::Justification::centredRight")
    ((left)
     "juce::Justification::left")
    ((right)
     "juce::Justification::right")
    (else
     (error "Invalid label justification"
            justification))))

(define (selector-items->cpp var items)
  (apply
   string-append
   (map
    (lambda (item index)
      (format #f
              "~a.addItem(\"~a\", ~a);~%"
              var
              (cpp-string item)
              index))
    items
    (iota (length items) 1))))


(define-generic model->attachment-declaration)
(export model->attachment-declaration)

(define-method (model->attachment-declaration (model <list>))
  (let ((type (assoc-ref model 'type))
        (var  (assoc-ref model 'var)))
    (cond
     ((button-parameter-type? type)
      (format #f
              "std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> ~aAttachment;~%"
              var))

     ((slider-parameter-type? type)
      (format #f
              "std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;~%"
              var))

     (else ""))
    ;; (case type
    ;;   ((bypass-switch)
    ;;    (format #f
    ;; 	       "std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> ~aAttachment;~%"
    ;;            var))
    ;;   ((rotary-slider linear-slider)
    ;;    (format #f
    ;;            "std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;~%"
    ;;            var))
    ;;   (else ""))
    ))

(define-public (generate-attachment-declarations)
  (apply string-append
         (map model->attachment-declaration
              (reverse *components*))))

(define-generic model->attachment-code)
(export model->attachment-code)

;; (define-method (model->attachment-code (model <list>))
;;   (let ((type         (assoc-ref model 'type))
;;         (var          (assoc-ref model 'var))
;;         (parameter-id (assoc-ref model 'parameter-id)))
;;     (case type
;;       ((bypass-switch)
;;        (format #f
;; 	       "~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
;;     ap.parameters,
;;     \"~a\",
;;     ~a
;; );~%"
;; 	       var
;; 	       (cpp-string parameter-id)
;; 	       var))
;;       ((rotary-slider linear-slider)
;;        (format #f
;; 	       "~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
;;     ap.parameters,
;;     \"~a\",
;;     ~a
;; );~%"
;;                var
;;                (cpp-string parameter-id)
;;                var))
;;       (else ""))))
(define-method (model->attachment-code (model <list>))
  (let ((type         (assoc-ref model 'type))
        (var          (assoc-ref model 'var))
        (parameter-id (assoc-ref model 'parameter-id)))

    (cond
     ((button-parameter-type? type)
      (format #f
"~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
    ap.parameters,
    \"~a\",
    ~a
);~%"
              var
              (cpp-string parameter-id)
              var))

     ((slider-parameter-type? type)
      (format #f
"~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
    ap.parameters,
    \"~a\",
    ~a
);~%"
              var
              (cpp-string parameter-id)
              var))

     (else ""))))

(define-public (generate-attachment-code)
  (apply string-append
         (map model->attachment-code
              (reverse *components*))))

(define-generic model->parameter-code)
(export model->parameter-code)

;; (define-method (model->parameter-code (model <list>))
;;   (let ((type           (assoc-ref model 'type))
;;         (parameter-id   (assoc-ref model 'parameter-id))
;;         (parameter-name (assoc-ref model 'parameter-name))
;;         (default-state  (assoc-ref model 'default-state))
;; 	(version-hint (assoc-ref model 'version-hint))
;;         (default        (assoc-ref model 'default)))
;;     (case type
;;       ((bypass-switch)
;;        (format #f
;; 	       "params.push_back(
;;     std::make_unique<juce::AudioParameterBool>(
;;         juce::ParameterID { \"~a\", ~a },
;;         \"~a\",
;;         ~a));~%"
;;                (cpp-string parameter-id)
;;                version-hint
;;                (cpp-string parameter-name)
;;                (bool->cpp default-state)))
;;       ((rotary-slider linear-slider)
;;        (format #f
;; "params.push_back(
;;     std::make_unique<juce::AudioParameterFloat>(
;;         juce::ParameterID { \"~a\", ~a },
;;         \"~a\",
;;         ~a,
;;         ~a));~%"
;;          (cpp-string parameter-id)
;;          version-hint
;;          (cpp-string parameter-name)
;;          (slider-normalisable-range->cpp model)
;;          default))
;;       (else
;;        ""))))

(define-method (model->parameter-code (model <list>))
  (let ((type           (assoc-ref model 'type))
        (parameter-id   (assoc-ref model 'parameter-id))
        (parameter-name (assoc-ref model 'parameter-name))
        (default-state  (assoc-ref model 'default-state))
        (version-hint   (assoc-ref model 'version-hint))
        (default        (assoc-ref model 'default)))

    (cond
     ((button-parameter-type? type)
      (format #f
"params.push_back(
    std::make_unique<juce::AudioParameterBool>(
        juce::ParameterID { \"~a\", ~a },
        \"~a\",
        ~a));~%"
              (cpp-string parameter-id)
              version-hint
              (cpp-string parameter-name)
              (bool->cpp default-state)))

     ((slider-parameter-type? type)
      (format #f
"params.push_back(
    std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID { \"~a\", ~a },
        \"~a\",
        ~a,
        ~a));~%"
              (cpp-string parameter-id)
              version-hint
              (cpp-string parameter-name)
              (slider-normalisable-range->cpp model)
              default))

     (else ""))))

(define-public (generate-parameter-code)

  (apply string-append
         (map model->parameter-code
              (reverse *components*))))


(define-generic model->dparams-code)
(export model->dparams-code)

;; (define-method (model->dparams-code (model <list>))
;;   (let ((type      (assoc-ref model 'type))
;;         (reference (assoc-ref model 'processor-reference)))
;;     (case type
;;       ((bypass-switch rotary-slider linear-slider)
;;        (format #f
;; "std::atomic<float>* param_~a = nullptr;
;; float value_~a;~%"
;;                reference
;;                reference))
;;       (else ""))))

(define-method (model->dparams-code (model <list>))
  (let ((type      (assoc-ref model 'type))
        (reference (assoc-ref model 'processor-reference)))

    (if (parameter-component-type? type)
        (format #f
"std::atomic<float>* param_~a = nullptr;
float value_~a;~%"
                reference
                reference)
        "")))

(define-public (generate-dparams-code)
  (apply string-append
         (map model->dparams-code
              (reverse *components*))))


(define-generic model->getparams-code)
(export model->getparams-code)

;; (define-method (model->getparams-code (model <list>))
;;   (let ((type         (assoc-ref model 'type))
;;         (reference    (assoc-ref model 'processor-reference))
;;         (parameter-id (assoc-ref model 'parameter-id)))
;;     (case type
;;       ((bypass-switch rotary-slider linear-slider)
;;        (format #f
;; "param_~a = parameters.getRawParameterValue(\"~a\");~%"
;;                reference
;;                (cpp-string parameter-id)))
;;       (else ""))))

(define-method (model->getparams-code (model <list>))
  (let ((type         (assoc-ref model 'type))
        (reference    (assoc-ref model 'processor-reference))
        (parameter-id (assoc-ref model 'parameter-id)))

    (if (parameter-component-type? type)
        (format #f
"param_~a = parameters.getRawParameterValue(\"~a\");~%"
                reference
                (cpp-string parameter-id))
        "")))

(define-public (generate-getparams-code)
  (apply string-append
         (map model->getparams-code
              (reverse *components*))))

(define-generic model->valueparams-code)
(export model->valueparams-code)

;; (define-method (model->valueparams-code (model <list>))
;;   (let ((type      (assoc-ref model 'type))
;;         (reference (assoc-ref model 'processor-reference)))
;;     (case type
;;       ((bypass-switch rotary-slider linear-slider)
;;        (format #f
;; "value_~a = param_~a->load();~%"
;;                reference
;;                reference))
;;       (else ""))))

(define-method (model->valueparams-code (model <list>))
  (let ((type      (assoc-ref model 'type))
        (reference (assoc-ref model 'processor-reference)))

    (if (parameter-component-type? type)
        (format #f
"value_~a = param_~a->load();~%"
                reference
                reference)
        "")))

(define-public (generate-valueparams-code)
  (apply string-append
         (map model->valueparams-code
              (reverse *components*))))

(define-generic model->destroy-code)
(export model->destroy-code)

(define-method (model->destroy-code (model <list>))
  (let ((type (assoc-ref model 'type))
        (var  (assoc-ref model 'var)))
    (case type
      ((bypass-switch rotary-slider linear-slider)
       (format #f
"~aAttachment.reset();~%"
               var))
      (else ""))))

(define-public (generate-destroy-code)
  (apply string-append
         (map model->destroy-code
              (reverse *components*))))

(define-public (generate-process-code)
  (string-append
   (generate-process-bypass)
   (generate-process-input-gain)
   (generate-process-input-meter)
   (generate-process-wetdry-prefix)
   (generate-process-dsp)
   (generate-process-wetdry-postfix)
   (generate-process-output-gain)
   (generate-process-output-meter)
   (generate-process-scope)))

(define (generate-process-bypass)
  (let ((model (find-component-by-role 'bypass)))
    (if model
        (let ((ref (assoc-ref model 'processor-reference)))
          (format #f
"    // HARD BYPASS
    if (value_~a >= 0.5f)
        return;

"
                  ref))
        "")))


(define (meter-peak-var model)
  (string-append
   (assoc-ref model 'var)
   "Peak"))


(define (generate-process-meter role comment)
  (let ((model (role-model role)))
    (if model
        (let ((peak-var (meter-peak-var model)))
          (format #f
"    // ~a
    {
        float peak = 0.0f;

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
            peak = juce::jmax(
                peak,
                buffer.getMagnitude(ch, 0, buffer.getNumSamples()));

        ~a.store(peak, std::memory_order_relaxed);
    }

"
                  comment
                  peak-var))
        "")))

(define (generate-process-input-meter)
  (generate-process-meter 'input-meter "INPUT METER"))

(define (generate-process-output-meter)
  (generate-process-meter 'output-meter "OUTPUT METER"))

(define (generate-process-dsp)
  (let ((dsp-bypass
         (find-component-by-role 'dsp-bypass)))

    (if dsp-bypass
        (let ((ref
               (assoc-ref dsp-bypass
                          'processor-reference)))
          (format #f
"    // DSP
    if (value_~a < 0.5f)
    {
        myplugin->render(buffer);
    }

"
                  ref))

        "    // DSP
    myplugin->render(buffer);

")))

(define (generate-process-output-gain)
  (let ((model (role-model 'output-gain)))
    (if model
        (let ((ref (assoc-ref model 'processor-reference)))
          (format #f
"    // OUTPUT GAIN
    buffer.applyGain(
        juce::Decibels::decibelsToGain(value_~a));

"
                  ref))
        "")))

(define (generate-process-input-gain)
  (let ((model (find-component-by-role 'input-gain)))
    (if model
        (let ((ref (assoc-ref model 'processor-reference)))
          (format #f
"    // INPUT GAIN
    buffer.applyGain(
        juce::Decibels::decibelsToGain(value_~a));

"
                  ref))
        "")))

(define (generate-process-scope)
  (if (role-present? 'scope)
      "    // SCOPE
    {
        const float* data = buffer.getReadPointer(0);
        const int numSamples = buffer.getNumSamples();
        const int step = juce::jmax(1, numSamples / 128);
        int idx = scopeWriteIdx.load(std::memory_order_relaxed);

        for (int i = 0; i < numSamples; i += step)
        {
            scopeFifo[idx].store(data[i], std::memory_order_relaxed);
            idx = (idx + 1) % 128;
        }

        scopeWriteIdx.store(idx, std::memory_order_relaxed);
    }

"
      ""))



(define-public (generate-paint-over-children-code)
  (let ((bypass-model
         (find-component-by-role 'bypass))
        (dsp-bypass-model
         (find-component-by-role 'dsp-bypass)))

    (string-append

     ;; ==========================================================
     ;; HARD BYPASS
     ;; ==========================================================
     (if bypass-model
         (let ((var (assoc-ref bypass-model 'var)))
           (format #f
"    // ----------------------------------------------------------
    // HARD BYPASS
    // ----------------------------------------------------------
    if (~a.getToggleState())
    {
        g.fillAll(juce::Colours::black.withAlpha(0.65f));

        auto overlayArea = getLocalBounds().reduced(40);

        const float overlayFont =
            juce::jlimit(
                28.0f,
                64.0f,
                (float) juce::jmin(getWidth(), getHeight()) * 0.10f);

        g.setFont(
            juce::FontOptions(overlayFont)
                .withStyle(\"Bold\"));

        g.setColour(
            kineticLNF.currentPalette.neonWhite.withAlpha(0.92f));

        g.drawFittedText(
            \"BYPASSED\",
            overlayArea,
            juce::Justification::centred,
            1);

        for (auto* child : getChildren())
        {
            if (child != &~a)
                child->setEnabled(false);
        }
    }
    else
    {
        for (auto* child : getChildren())
        {
            if (child != &~a)
                child->setEnabled(true);
        }

"
                   var
                   var
                   var))
         "")

     ;; ==========================================================
     ;; DSP BYPASS
     ;;
     ;; Deve essere dentro l'else dell'hard bypass.
     ;; ==========================================================
     (if dsp-bypass-model
         (let ((var (assoc-ref dsp-bypass-model 'var)))
           (format #f
"        // ------------------------------------------------------
        // DSP BYPASS
        // ------------------------------------------------------
        if (~a.getToggleState())
        {
            const int badgeWidth  = juce::jmin(260, getWidth() - 40);
            const int badgeHeight = 42;

            auto badgeArea =
                getLocalBounds()
                    .withSizeKeepingCentre(
                        badgeWidth,
                        badgeHeight)
                    .translated(
                        0,
                        -getHeight() / 4);

            g.setColour(
                juce::Colours::black.withAlpha(0.72f));

            g.fillRoundedRectangle(
                badgeArea.toFloat(),
                8.0f);

            g.setColour(
                kineticLNF.currentPalette.neonWhite.withAlpha(0.90f));

            g.drawRoundedRectangle(
                badgeArea.toFloat(),
                8.0f,
                1.5f);

            const float badgeFont =
                juce::jlimit(
                    14.0f,
                    22.0f,
                    (float) badgeHeight * 0.45f);

            g.setFont(
                juce::FontOptions(badgeFont)
                    .withStyle(\"Bold\"));

            g.drawFittedText(
                \"DSP BYPASSED\",
                badgeArea,
                juce::Justification::centred,
                1);
        }
"
                   var))
         "")

     ;; Chiude l'else dell'hard bypass soltanto se esiste.
     (if bypass-model
         "    }\n"
         ""))))


(define-public (generate-process-wetdry-prefix)
  (if (role-present? 'wet-dry)
      "    // DRY COPY
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        dryBuffer.copyFrom(
            ch,
            0,
            buffer.getReadPointer(ch),
            buffer.getNumSamples());

"
      ""))

(define (generate-process-wetdry-postfix)
  (let ((model (role-model 'wet-dry)))
    (if model
        (let* ((ref (assoc-ref model 'processor-reference))
               (min (assoc-ref model 'min))
               (max (assoc-ref model 'max)))
          (format #f
"    // WET / DRY MIX
    {
        const float wetMix =
            juce::jlimit(
                0.0f,
                1.0f,
                (value_~a - ~af) / (~af - ~af));

        const float dryMix = 1.0f - wetMix;

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            auto* wet = buffer.getWritePointer(ch);
            const auto* dry = dryBuffer.getReadPointer(ch);
            const int numSamples = buffer.getNumSamples();

            juce::FloatVectorOperations::multiply(
                wet,
                wetMix,
                numSamples);

            juce::FloatVectorOperations::addWithMultiply(
                wet,
                dry,
                dryMix,
                numSamples);
        }
    }

"
                  ref min max min))
        "")))

(define (generate-oversampling-prepare-code)
  (if (role-present? 'oversampling)
      "    // OVERSAMPLING
    oversampling2x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            getTotalNumInputChannels(),
            1,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR);

    oversampling4x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            getTotalNumInputChannels(),
            2,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR);

    oversampling8x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            getTotalNumInputChannels(),
            3,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR);

    oversampling2x->initProcessing(samplesPerBlock);
    oversampling4x->initProcessing(samplesPerBlock);
    oversampling8x->initProcessing(samplesPerBlock);

    oversampling2x->reset();
    oversampling4x->reset();
    oversampling8x->reset();

"
      ""))
