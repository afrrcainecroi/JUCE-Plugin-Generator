(define-module (generator-app cpp-generation-common)
  #:use-module (ice-9 format)
  #:use-module (srfi srfi-1)
  #:export (
	    ;;slider-properties->cpp
            slider-normalisable-range->cpp
            meter-properties->cpp
            scope-properties->cpp
            palette-selector-callback->cpp
            selector-constructor-code
            slider-scale->cpp
            bool->cpp
            slider-kinetic-properties->cpp
            rotary-kinetic-properties->cpp
            tick-labels->cpp
            cpp-string
            justification->cpp
            selector-items->cpp
	    font-style->cpp
	    ))

(define (error message . args)
  (scm-error 'misc-error
             #f
             (string-append
              message
              (apply string-append (map (lambda (_) " ~S") args)))
             args
             #f))

;; (define (slider-properties->cpp model)
;;   (let ((var         (assoc-ref model 'var))
;;         (title       (assoc-ref model 'title))
;;         (value-type  (assoc-ref model 'value-type))
;;         (suffix      (assoc-ref model 'suffix))
;;         (show-value  (assoc-ref model 'show-value))
;;         (show-ticks  (assoc-ref model 'show-ticks))
;;         (show-labels (assoc-ref model 'show-labels))
;;         (tick-count  (assoc-ref model 'tick-count))
;;         (tick-mode   (assoc-ref model 'tick-mode))
;;         (tick-labels (assoc-ref model 'tick-labels)))

;;     (string-append

;;      (format #f
;; "~a.getProperties().set(\"title\", ~a);
;; "
;;              var
;;              (cpp-string title))

;;      (format #f
;; "~a.getProperties().set(\"valueType\", ~a);
;; "
;;              var
;;              (cpp-string
;;               (symbol->string value-type)))

;;      (format #f
;; "~a.getProperties().set(\"suffix\", ~a);
;; "
;;              var
;;              (cpp-string suffix))

;;      (format #f
;; "~a.getProperties().set(\"showValue\", ~a);
;; "
;;              var
;;              (bool->cpp show-value))

;;      (format #f
;; "~a.getProperties().set(\"showTicks\", ~a);
;; "
;;              var
;;              (bool->cpp show-ticks))

;;      (format #f
;; "~a.getProperties().set(\"showLabels\", ~a);
;; "
;;              var
;;              (bool->cpp show-labels))

;;      (format #f
;; "~a.getProperties().set(\"tickCount\", ~a);
;; "
;;              var
;;              tick-count)

;;      (format #f
;; "~a.getProperties().set(\"tickMode\", ~a);
;; "
;;              var
;;              (cpp-string
;;               (symbol->string tick-mode)))

;;      ;; tick-labels lo affrontiamo separatamente se non è già emesso.
;;      )))

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

(define-public (selector-constructor-code model)
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
             default-index)
     (selector-common-properties->cpp model)
     )))

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

(define-public (justification->cpp justification)
  (case justification
    ((centred)        "juce::Justification::centred")
    ((centred-left)   "juce::Justification::centredLeft")
    ((centred-right)  "juce::Justification::centredRight")
    ((left)           "juce::Justification::left")
    ((right)          "juce::Justification::right")
    ((top-left)       "juce::Justification::topLeft")
    ((top-right)      "juce::Justification::topRight")
    ((bottom-left)    "juce::Justification::bottomLeft")
    ((bottom-right)   "juce::Justification::bottomRight")
    (else
     (error "Invalid label justification" justification))))


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

(define-public (font-style->cpp style)
  (case style
    ((plain)  "")
    ((bold)   ".withStyle(\"Bold\")")
    ((italic) ".withStyle(\"Italic\")")
    (else
     (error "Invalid label font style" style))))

(define-public (label-colour->cpp colour)
  (case colour
    ((default)    #f)
    ((grey)       "juce::Colours::grey")
    ((white)      "juce::Colours::white")
    ((black)      "juce::Colours::black")
    ((neon-white) "kineticLNF.currentPalette.neonWhite")
    (else
     (error "Invalid label text colour" colour))))

(define-public (label-properties->cpp model)
  (let* ((var           (assoc-ref model 'var))
         (text          (assoc-ref model 'text))
         (font-size     (assoc-ref model 'font-size))
         (font-style    (assoc-ref model 'font-style))
         (justification (assoc-ref model 'justification))
         (text-colour   (assoc-ref model 'text-colour))
         (min-scale     (assoc-ref model 'minimum-horizontal-scale))
         (tooltip       (assoc-ref model 'tooltip))
         (colour-cpp    (label-colour->cpp text-colour)))
    (string-append
     (format #f
             "addAndMakeVisible(~a);~%"
             var)

     (format #f
             "~a.setText(\"~a\", juce::dontSendNotification);~%"
             var
             (cpp-string text))

     (format #f
             "~a.setFont(juce::FontOptions(~af)~a);~%"
             var
             font-size
             (font-style->cpp font-style))

     (format #f
             "~a.setJustificationType(~a);~%"
             var
             (justification->cpp justification))

     (if colour-cpp
         (format #f
                 "~a.setColour(juce::Label::textColourId, ~a);~%"
                 var
                 colour-cpp)
         "")

     (format #f
             "~a.setMinimumHorizontalScale(~af);~%"
             var
             min-scale)

     (if (and tooltip
              (not (string-null? tooltip)))
         (format #f
                 "~a.setTooltip(\"~a\");~%"
                 var
                 (cpp-string tooltip))
         ""))))

(define-public (button-common-properties->cpp model)
  (let ((var     (assoc-ref model 'var))
        (tooltip (assoc-ref model 'tooltip))
        (enabled (assoc-ref model 'enabled)))
    (string-append
     (format #f
             "~a.setEnabled(~a);~%"
             var
             (bool->cpp enabled))

     (if (and tooltip
              (not (string-null? tooltip)))
         (format #f
                 "~a.setTooltip(\"~a\");~%"
                 var
                 (cpp-string tooltip))
         ""))))

(define-public (selector-common-properties->cpp model)
  (let ((var              (assoc-ref model 'var))
        (justification    (assoc-ref model 'justification))
        (tooltip          (assoc-ref model 'tooltip))
        (enabled          (assoc-ref model 'enabled))
        (nothing-text     (assoc-ref model 'text-when-nothing-selected))
        (no-choices-text  (assoc-ref model 'text-when-no-choices)))
    (string-append

     (format #f
             "~a.setJustificationType(~a);~%"
             var
             (justification->cpp justification))

     (format #f
             "~a.setEnabled(~a);~%"
             var
             (bool->cpp enabled))

     (if (and nothing-text
              (not (string-null? nothing-text)))
         (format #f
                 "~a.setTextWhenNothingSelected(\"~a\");~%"
                 var
                 (cpp-string nothing-text))
         "")

     (if (and no-choices-text
              (not (string-null? no-choices-text)))
         (format #f
                 "~a.setTextWhenNoChoicesAvailable(\"~a\");~%"
                 var
                 (cpp-string no-choices-text))
         "")

     (if (and tooltip
              (not (string-null? tooltip)))
         (format #f
                 "~a.setTooltip(\"~a\");~%"
                 var
                 (cpp-string tooltip))
         ""))))


