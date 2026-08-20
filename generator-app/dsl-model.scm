(define-module (generator-app dsl-model)
  #:use-module (oop goops)
  #:use-module (generator-app genera-classi)
  #:use-module (generator-app generation-protocols)
  #:re-export (
	       component-type
	       component->model
	       ))

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
	    (font-size 12.0)
	    (font-style 'plain)
	    (justification 'centred)
	    (text-colour 'default)
	    (minimum-horizontal-scale 0.7)
	    (tooltip "")
	    )
	   #:code
	   (register-component! this))

(new-class <selector> (<component>)
	   (
	    (items '())
	    (default-index 0)
	    (justification 'centred-left)
	    (tooltip "")
	    (enabled #t)

	    (text-when-nothing-selected "")
	    (text-when-no-choices "No choices")
	    )
	   #:code
	   (register-component! this))

(new-class <button> (<component>)
	   (
	    (text "")
	    (tooltip "")
	    (enabled #t)
	    )
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


;; header e footer
(new-class <header-footer>
  (
   (id "Main Header Footer")

   ;; HEADER
   (title-header "YAPlugin")
   (font-size-header 32.0)
   (font-style-header 'bold)
   (justification-header 'centred)
   (text-colour-header 'neon-white)
   (minimum-horizontal-scale-header 0.7)
   (tooltip-header "")
   (row-header 1)
   (col-header 8)
   (row-span-header 1)
   (col-span-header 8)
   (margin-tb-header 0)
   (margin-lr-header 0)

   ;; FOOTER
   (title-footer "Copyright (c) 2025 AF-Audio")
   (font-size-footer 12.0)
   (font-style-footer 'plain)
   (justification-footer 'bottom-right)
   (text-colour-footer 'grey)
   (minimum-horizontal-scale-footer 0.7)
   (tooltip-footer "")
   (row-footer 15)
   (col-footer 20)
   (row-span-footer 1)
   (col-span-footer 4)
   (margin-tb-footer 12)
   (margin-lr-footer 0)

   ;; LINK
   (title-link "https://www.aacf-music.eu/")
   (url-link "https://www.aacf-music.eu/")
   (font-size-link 12.0)
   (font-style-link 'plain)
   (justification-link 'bottom-left)
   (text-colour-link 'grey)
   (minimum-horizontal-scale-link 1.0)
   (tooltip-link "")
   (row-link 15)
   (col-link 1)
   (row-span-link 1)
   (col-span-link 5)
   (margin-tb-link 0)
   (margin-lr-link 0))

  #:code
  (let ((base id))

    (make <header>
      #:id (string-append base " Header")
      #:text title-header
      #:font-size font-size-header
      #:font-style font-style-header
      #:justification justification-header
      #:text-colour text-colour-header
      #:minimum-horizontal-scale minimum-horizontal-scale-header
      #:tooltip tooltip-header
      #:row row-header
      #:col col-header
      #:row-span row-span-header
      #:col-span col-span-header
      #:margin-tb margin-tb-header
      #:margin-lr margin-lr-header)

    (make <footer>
      #:id (string-append base " Footer")
      #:text title-footer
      #:font-size font-size-footer
      #:font-style font-style-footer
      #:justification justification-footer
      #:text-colour text-colour-footer
      #:minimum-horizontal-scale minimum-horizontal-scale-footer
      #:tooltip tooltip-footer
      #:row row-footer
      #:col col-footer
      #:row-span row-span-footer
      #:col-span col-span-footer
      #:margin-tb margin-tb-footer
      #:margin-lr margin-lr-footer)

    (make <link>
      #:id (string-append base " Link")
      #:text title-link
      #:url url-link
      #:font-size font-size-link
      #:font-style font-style-link
      #:justification justification-link
      #:text-colour text-colour-link
      #:minimum-horizontal-scale minimum-horizontal-scale-link
      #:tooltip tooltip-link
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

;; COMPONENT TYPE
;;
;; Restituisce il tipo semantico concreto del componente.
;; ======================================================================
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
   `((text . ,(button:text b))
     (tooltip . ,(button:tooltip b))
     (enabled . ,(button:enabled b))
     )))

(define-method (component->model (b <toggle-button>))
  (append
   (next-method)
   `((default-state       . ,(toggle-button:default-state b))
     (style               . ,(toggle-button:style b))
     (parameter-id        . ,(toggle-button:parameter-id b))
     (parameter-name      . ,(toggle-button:parameter-name b))
     (processor-reference . ,(toggle-button:processor-reference b))
     (version-hint        . ,(toggle-button:version-hint b))
     )))

(define-method (component->model (c <label>))
  (append
   (next-method)
   `((text          . ,(label:text c))
     (justification . ,(label:justification c))
     (font-size     . ,(label:font-size c))
     (font-style    . ,(label:font-style c))
     (text-colour              . ,(label:text-colour c))
     (minimum-horizontal-scale . ,(label:minimum-horizontal-scale c))
     (tooltip                  . ,(label:tooltip c))
     )))

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
     (default-index . ,(selector:default-index c))
     (justification               . ,(selector:justification c))
     (tooltip                     . ,(selector:tooltip c))
     (enabled                     . ,(selector:enabled c))
     (text-when-nothing-selected  . ,(selector:text-when-nothing-selected c))
     (text-when-no-choices        . ,(selector:text-when-no-choices c))
     )))

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
