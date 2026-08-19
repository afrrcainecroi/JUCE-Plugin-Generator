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
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app resources)
  #:use-module (generator-app layout)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app validation)
  #:re-export (register-image-set!
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
               model->destroy-code
               <image-set>
               image-set:name
               image-set:source-directory
               image-set:files
               materialize-image-sets!
               generate-image-resource-jucer-code
               update-jucer-image-resources!
               generated-resource-filename
               generate-image-resource-cpp-code
               <grid>
               grid:rows
               grid:cols
               grid:show-grid
               <screen>
               screen:ratio
               screen:width
               register-grid!
               register-screen!
               generate-layout-data-components
               generate-screen-size-code
               generate-grid-code
               <component>
               component:id
               component:role
               component:row
               component:col
               component:row-span
               component:col-span
               component:margin-tb
               component:margin-lr
               <label>
               label:text
               label:justification
               <header>
               <footer>
               <link>
               link:url
               <palette-label>
               palette-label:enable
               palette-label:default-theme
               <selector>
               selector:items
               selector:default-index
               <palette-selector>
               <button>
               button:text
               <text-button>
               <toggle-button>
               toggle-button:default-state
               toggle-button:style
               toggle-button:parameter-id
               toggle-button:parameter-name
               toggle-button:tooltip
               toggle-button:processor-reference
               toggle-button:version-hint
               <normal-toggle-button>
               <switch>
               <bypass-switch>
               <slider>
               slider:parameter-id
               slider:parameter-name
               slider:processor-reference
               slider:version-hint
               slider:title
               slider:min
               slider:max
               slider:default
               slider:interval
               slider:scale
               slider:value-type
               slider:suffix
               slider:show-value
               slider:show-ticks
               slider:show-labels
               slider:tick-count
               slider:tick-mode
               slider:tick-labels
               <rotary-slider>
               rotary-slider:icon-type
               rotary-slider:morph-icon
               rotary-slider:icon-set
               <linear-slider>
               linear-slider:orientation
               <meter>
               meter:style
               meter:scale-type
               meter:is-sharp
               meter:glow-multiplier
               meter:range-min
               meter:range-max
               meter:num-segments
               meter:tick-mode
               <scope>
               scope:grid-style
               scope:is-sharp
               scope:glow-multiplier
               <header-footer>
               header-footer:id
               header-footer:title-header
               header-footer:row-header
               header-footer:col-header
               header-footer:row-span-header
               header-footer:col-span-header
               header-footer:margin-tb-header
               header-footer:margin-lr-header
               header-footer:title-footer
               header-footer:row-footer
               header-footer:col-footer
               header-footer:row-span-footer
               header-footer:col-span-footer
               header-footer:margin-tb-footer
               header-footer:margin-lr-footer
               header-footer:title-link
               header-footer:url-link
               header-footer:row-link
               header-footer:col-link
               header-footer:row-span-link
               header-footer:col-span-link
               header-footer:margin-tb-link
               header-footer:margin-lr-link
               <palette>
               palette:id
               palette:enable
               palette:default-theme
               palette:title-palette
               palette:row-palette
               palette:col-palette
               palette:row-span-palette
               palette:col-span-palette
               palette:margin-tb-palette
               palette:margin-lr-palette
               palette:row-selector
               palette:col-selector
               palette:row-span-selector
               palette:col-span-selector
               palette:margin-tb-selector
               palette:margin-lr-selector)
  )

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
;; ----------------------------------------------------------------------
;; Ricerca per logical ID
;; ----------------------------------------------------------------------
(define-public (find-component id)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'id)
             id))
   (generation-components)))

(define-public (find-component-by-role role)
  (find
   (lambda (component)
     (equal? (assoc-ref component 'role) role))
   (generation-components)))

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
  (let ((id (assoc-ref component 'id)))
    (when (component-id-used? id)
      (scm-error 'misc-error
                 #f
                 "Duplicate component logical id ~S"
                 (list id)
                 #f)))
  (prepend-generation-component! component))

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
      (prepend-generation-component! registered-model))))

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

(define-method (component->member-declaration (s <slider>))
  (format #f
          "juce::Slider ~a;~%"
          (component-cpp-var s)))

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
              (reverse (generation-components)))))


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
              (reverse (generation-components)))))

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

(define-public (selector-items->cpp var items)
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
              (reverse (generation-components)))))

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
              (reverse (generation-components)))))

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
              (reverse (generation-components)))))


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
              (reverse (generation-components)))))


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
              (reverse (generation-components)))))

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
              (reverse (generation-components)))))

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
              (reverse (generation-components)))))

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
