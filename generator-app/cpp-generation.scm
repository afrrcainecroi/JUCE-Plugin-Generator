(define-module (generator-app cpp-generation)
  #:use-module (ice-9 format)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app registration)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app cpp-generation-common)
  #:re-export (component->member-declaration
               model->member-declaration
               model->constructor-code
               model->attachment-declaration
               model->attachment-code
               model->parameter-code
               model->dparams-code
               model->getparams-code
               model->valueparams-code
               model->destroy-code)
  #:export (generate-link-runtime-declarations-code
            generate-footer-mouse-code
            generate-footer-mouse-exit-code
            generate-footer-timer-code))

(define (error message . args)
  (scm-error 'misc-error
             #f
             (string-append
              message
              (apply string-append (map (lambda (_) " ~S") args)))
             args
             #f))

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
		  (cpp-string text))
	  (button-common-properties->cpp model)
	  )))
      ((toggle-button switch bypass-switch)
 (let ((text
        (assoc-ref model 'text))

       (default-state
        (assoc-ref model 'default-state))

       (style
        (assoc-ref model 'style))

       (role
        (assoc-ref model 'role)))

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

    (button-common-properties->cpp model)

    ;; Semantica specifica del TYPE/style switch.
    (if (eq? style 'switch)
        (format #f
                "~a.getProperties().set(\"style\", \"switch\");~%"
                var)
        "")

    ;; Comportamento legato al ROLE, non alla grafica.
    (if (memq role '(bypass dsp-bypass))
        (format #f
                "~a.onStateChange = [this] { repaint(); };~%"
                var)
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
      
      ;; ----------------------------------------------------------
      ;; LABEL-LIKE COMPONENTS
      ;;
      ;; Tutte le proprietà grafiche comuni vengono generate da
      ;; label-properties->cpp:
      ;;
      ;;   text
      ;;   font-size
      ;;   font-style
      ;;   justification
      ;;   text-colour
      ;;   minimum-horizontal-scale
      ;;   tooltip
      ;;
      ;; Header e footer non hanno quindi più proprietà grafiche
      ;; hardcoded nell'emitter.
      ;; ----------------------------------------------------------

      ((header footer label palette-label)
       (label-properties->cpp model))

      ;; ----------------------------------------------------------
      ;; LINK
      ;;
      ;; Prima genera tutte le normali proprietà di un Label.
      ;; Poi aggiunge esclusivamente il comportamento specifico
      ;; del TYPE link.
      ;; ----------------------------------------------------------

      ((link)
       (let ((url (assoc-ref model 'url)))
         (string-append
          (label-properties->cpp model)

          ;; URL and normal colour are behavioural PROPERTY values belonging
          ;; to this link instance. They are not shared RESOURCE data.
          (format #f
                  "~a.getProperties().set(\"generatedLinkUrl\", \"~a\");~%"
                  var
                  (cpp-string url))
          (format #f
                  "~a.getProperties().set(\"generatedLinkNormalColour\", static_cast<juce::int64>(~a.findColour(juce::Label::textColourId).getARGB()));~%"
                  var var)

          ;; Il nome viene utilizzato anche dalla gestione
          ;; dell'interazione mouse.
          (format #f
                  "~a.setName(\"~a\");~%"
                  var
                  (cpp-string var))

          ;; The pointing hand is restricted to the fitted text area.
          (format #f
                  "~a.setMouseCursor(juce::MouseCursor::NormalCursor);~%"
                  var)

          ;; Il PluginEditor riceve gli eventi mouse del link.
          (format #f
                  "~a.addMouseListener(this, false);~%"
                  var))))
      
      ((selector)
       (selector-constructor-code model))
      ((palette-selector)
       (string-append
        (selector-constructor-code model)
        (palette-selector-callback->cpp model)))
      (else ""))))

(define (link-models)
  (filter (lambda (model)
            (eq? (assoc-ref model 'type) 'link))
          (reverse (generation-components))))

(define-public (generate-link-runtime-declarations-code)
  (if (null? (link-models))
      ""
      (string-append "
juce::Rectangle<int> generatedLinkTextArea(juce::Label& link) const
{
    juce::GlyphArrangement glyphs;
    glyphs.addFittedText(link.getFont(),
                         link.getText(),
                         0.0f,
                         0.0f,
                         static_cast<float>(link.getWidth()),
                         static_cast<float>(link.getHeight()),
                         link.getJustificationType(),
                         1,
                         link.getMinimumHorizontalScale());

    return glyphs.getBoundingBox(0, -1, true)
                 .getSmallestIntegerContainer()
                 .getIntersection(link.getLocalBounds());
}

juce::Colour generatedLinkNormalColour(juce::Label& link) const
{
    return juce::Colour(static_cast<juce::uint32>(
        static_cast<juce::int64>(
            link.getProperties()[\"generatedLinkNormalColour\"])));
}
\nvoid mouseExit(const juce::MouseEvent& event) override
{
"
                     (generate-footer-mouse-exit-code)
                     "}
")))

(define-public (generate-footer-mouse-code)
  (apply
   string-append
   (map
    (lambda (model)
      (let ((var (assoc-ref model 'var)))
        (format #f
"if (event.eventComponent == &~a)
{
    const auto mousePosition = event.getEventRelativeTo(&~a).getPosition();
    if (generatedLinkTextArea(~a).contains(mousePosition))
    {
        juce::URL(~a.getProperties()[\"generatedLinkUrl\"].toString())
            .launchInDefaultBrowser();
    }
}
"
                var var var var)))
    (link-models))))

(define-public (generate-footer-mouse-exit-code)
  (apply
   string-append
   (map
    (lambda (model)
      (let ((var (assoc-ref model 'var)))
        (format #f
"if (event.eventComponent == &~a)
{
    ~a.setMouseCursor(juce::MouseCursor::NormalCursor);
    ~a.setColour(juce::Label::textColourId,
                 generatedLinkNormalColour(~a));
}
"
                var var var var)))
    (link-models))))

(define-public (generate-footer-timer-code)
  (apply
   string-append
   (map
    (lambda (model)
      (let ((var (assoc-ref model 'var)))
        (format #f
"if (~a.isMouseOver())
{
    const auto isOverText = generatedLinkTextArea(~a).contains(
        ~a.getMouseXYRelative());

    ~a.setMouseCursor(isOverText
        ? juce::MouseCursor::PointingHandCursor
        : juce::MouseCursor::NormalCursor);
    ~a.setColour(juce::Label::textColourId,
                 isOverText
                     ? kineticLNF.currentPalette.neonWhite
                     : generatedLinkNormalColour(~a));
}
"
                var var var var var var)))
    (link-models))))

(define-method (model->attachment-declaration (model <list>))
  (let ((type (assoc-ref model 'type))
        (var  (assoc-ref model 'var)))
    (cond
     ((button-parameter-type? type)
      (format #f
              "std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> ~aAttachment;~%"
              var))

     ((selector-parameter-model? model)
      (format #f
              "std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> ~aAttachment;~%"
              var))

     ((slider-parameter-type? type)
      (format #f
              "std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;~%"
              var))

     (else ""))
    ))

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

     ((selector-parameter-model? model)
      (format #f
	      "~aAttachment =
    std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment>(
        ap.parameters,
        \"~a\",
        ~a);~%"
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

     ((selector-parameter-model? model)
      (let ((items
             (assoc-ref model 'items))
	    (default-index
              (assoc-ref model 'default-index)))
	(format #f
		"params.push_back(
    std::make_unique<juce::AudioParameterChoice>(
        juce::ParameterID { \"~a\", ~a },
        \"~a\",
        ~a,
        ~a));~%"
		(cpp-string parameter-id)
		version-hint
		(cpp-string parameter-name)
		(choice-items->cpp items)

		;; DSL/ComboBox 1-based -> AudioParameterChoice 0-based
		(- default-index 1))))
     
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

(define-method (model->dparams-code (model <list>))
  (let ((type      (assoc-ref model 'type))
        (reference (assoc-ref model 'processor-reference)))
    (if (parameter-component-model? model)
    ;; (if (parameter-component-type? type)
        (format #f
"std::atomic<float>* param_~a = nullptr;
float value_~a;~%"
                reference
                reference)
        "")))

(define-method (model->getparams-code (model <list>))
  (let ((type         (assoc-ref model 'type))
        (reference    (assoc-ref model 'processor-reference))
        (parameter-id (assoc-ref model 'parameter-id)))

    (if (parameter-component-model? model)
    ;; (if (parameter-component-type? type)
        (format #f
"param_~a = parameters.getRawParameterValue(\"~a\");~%"
                reference
                (cpp-string parameter-id))
        "")))

(define-method (model->valueparams-code (model <list>))
  (let ((type      (assoc-ref model 'type))
        (reference (assoc-ref model 'processor-reference)))

    (if (parameter-component-model? model)
    ;; (if (parameter-component-type? type)
        (format #f
"value_~a = param_~a->load();~%"
                reference
                reference)
        "")))

(define-method (model->destroy-code (model <list>))
  "")
  ;; (let ((type (assoc-ref model 'type))
  ;;       (var  (assoc-ref model 'var)))
  ;;   (case type
  ;;     ((bypass-switch rotary-slider linear-slider)
  ;;      (format #f
  ;; 	       "~aAttachment.reset();~%"
  ;;              var))
  ;;     (else ""))))
