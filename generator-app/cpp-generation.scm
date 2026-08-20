(define-module (generator-app cpp-generation)
  #:use-module (ice-9 format)
  #:use-module (oop goops)
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app registration)
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
               model->destroy-code))

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
       (let ((text          (assoc-ref model 'text))
	     (font-size     (assoc-ref model 'font-size))
	     (justification (assoc-ref model 'justification)))
	 (string-append
	  (format #f
		  "addAndMakeVisible(~a);~%"
		  var)
	  (format #f
		  "~a.setText(\"~a\", juce::dontSendNotification);~%"
		  var
		  (cpp-string text))
	  (format #f
		  "~a.setFont(juce::FontOptions(~af).withStyle(\"Bold\"));~%"
		  var
		  font-size)
	  (format #f
		  "~a.setJustificationType(~a);~%"
		  var
		  (justification->cpp justification))
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

(define-method (model->valueparams-code (model <list>))
  (let ((type      (assoc-ref model 'type))
        (reference (assoc-ref model 'processor-reference)))

    (if (parameter-component-type? type)
        (format #f
"value_~a = param_~a->load();~%"
                reference
                reference)
        "")))

(define-method (model->destroy-code (model <list>))
  (let ((type (assoc-ref model 'type))
        (var  (assoc-ref model 'var)))
    (case type
      ((bypass-switch rotary-slider linear-slider)
       (format #f
"~aAttachment.reset();~%"
               var))
      (else ""))))
