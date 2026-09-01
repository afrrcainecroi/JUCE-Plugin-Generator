(use-modules (ice-9 format)
             (ice-9 string-fun)
             (oop goops)
             (srfi srfi-1)
             (generator-app code-generator)
             (generator-app generation-state)
             (generator-app standard-plugin-shell)
             (generator-app tools))

(define (check label predicate)
  (unless predicate
    (error "Standard component display config test failed" label)))

(define (model-property id property)
  (let ((model (find-component id)))
    (and model (assoc-ref model property))))

(define (contains-for-model? generated id fragment)
  (let ((model (find-component id)))
    (and model
         (string-contains
          generated
          (format #f fragment (assoc-ref model 'var))))))

(define standard-override-config
  '((components
     (input-gain
      (enabled . #t)
      (display-name . "INPUT LEVEL TEST")
      (tooltip . "Input gain tooltip test")
      (profile . #f)
      (width-scale . 1)
      (height-scale . 1))
     (dsp-bypass
      (enabled . #t)
      (display-name . "DSP TEST")
      (tooltip . "DSP bypass tooltip test")
      (profile . #f)
      (width-scale . 1)
      (height-scale . 1)))))

;; Standard rotary/linear and toggle components map display-name and tooltip
;; without changing their logical or APVTS identities.
(reset-generation-state!)
(reset-cpp-identifiers!)
(standard-plugin-interface
 ""
 "Display Config Test"
 #:config standard-override-config)

(let ((constructor (generate-constructor-code)))
  (check 'slider-display-name
         (equal? (model-property "input-gain" 'title)
                 "INPUT LEVEL TEST"))
  (check 'slider-tooltip
         (equal? (model-property "input-gain" 'tooltip)
                 "Input gain tooltip test"))
  (check 'toggle-display-name
         (equal? (model-property "dsp-bypass" 'text)
                 "DSP TEST"))
  (check 'toggle-tooltip
         (equal? (model-property "dsp-bypass" 'tooltip)
                 "DSP bypass tooltip test"))
  (check 'slider-tooltip-generated
         (contains-for-model?
          constructor
          "input-gain"
          "~a.setTooltip(\"Input gain tooltip test\")"))
  (check 'toggle-tooltip-generated
         (contains-for-model?
          constructor
          "dsp-bypass"
          "~a.setTooltip(\"DSP bypass tooltip test\")"))
  (check 'slider-title-generated
         (contains-for-model?
          constructor
          "input-gain"
          "~a.getProperties().set(\"title\", \"INPUT LEVEL TEST\")"))
  (check 'toggle-text-generated
         (contains-for-model?
          constructor
          "dsp-bypass"
          "~a.setButtonText(\"DSP TEST\")")))

(check 'slider-id-unchanged
       (equal? (model-property "input-gain" 'id) "input-gain"))
(check 'slider-role-unchanged
       (eq? (model-property "input-gain" 'role) 'input-gain))
(check 'slider-parameter-id-unchanged
       (equal? (model-property "input-gain" 'parameter-id) "inputGain"))
(check 'slider-reference-unchanged
       (equal? (model-property "input-gain" 'processor-reference)
               "inputGain"))
(check 'toggle-id-unchanged
       (equal? (model-property "dsp-bypass" 'id) "dsp-bypass"))
(check 'toggle-role-unchanged
       (eq? (model-property "dsp-bypass" 'role) 'dsp-bypass))
(check 'toggle-parameter-id-unchanged
       (equal? (model-property "dsp-bypass" 'parameter-id) "dspBypass"))
(check 'toggle-reference-unchanged
       (equal? (model-property "dsp-bypass" 'processor-reference)
               "dspBypass"))

;; With no overrides, all existing visible names and the title fallback remain
;; exactly as before; empty tooltips do not add generated UI statements.
(reset-generation-state!)
(reset-cpp-identifiers!)
(standard-plugin-interface "" "Fallback Plugin" #:config '())

(check 'plugin-title-fallback
       (equal? (model-property "plugin-title" 'text) "Fallback Plugin"))
(check 'input-gain-fallback
       (equal? (model-property "input-gain" 'title) "INPUT GAIN"))
(check 'output-gain-fallback
       (equal? (model-property "output-gain" 'title) "OUTPUT GAIN"))
(check 'wet-dry-fallback
       (equal? (model-property "wet-dry" 'title) "WET / DRY"))
(check 'oversampling-fallback
       (equal? (model-property "oversampling" 'title) "OVERSAMPLING"))
(check 'dsp-bypass-fallback
       (equal? (model-property "dsp-bypass" 'text) "DSP BYPASS"))
(check 'bypass-fallback
       (equal? (model-property "bypass" 'text) "BYPASS"))
(check 'empty-slider-tooltip-fallback
       (equal? (model-property "input-gain" 'tooltip) ""))

;; Load the authoritative YAEnhancer declarations, then override only visual
;; properties through the same standard config used for optional placement.
(load-from-path "plugins/YAEnhancerR1.scm")

(define required-component-properties
  '(enabled display-name tooltip profile width-scale height-scale))

(for-each
 (lambda (entry)
   (for-each
    (lambda (property)
      (check (list 'complete-yaenhancer-config (car entry) property)
             (assoc property (cdr entry))))
    required-component-properties))
 (cdr (assoc 'components yaenhancer-standard-config)))

(define (replace-property properties property value)
  (cons (cons property value)
        (filter (lambda (entry) (not (eq? (car entry) property)))
                properties)))

(define (override-component-property config id property value)
  (map
   (lambda (section)
     (if (eq? (car section) 'components)
         (cons
          'components
          (map
           (lambda (entry)
             (if (eq? (car entry) id)
                 (cons id
                       (replace-property (cdr entry) property value))
                 entry))
           (cdr section)))
         section))
   config))

(define optional-overrides
  '((auto-gain display-name "AUTO TEST")
    (auto-gain tooltip "Auto tooltip test")
    (delta-monitor display-name "DELTA TEST")
    (delta-monitor tooltip "Delta tooltip test")
    (safety-limiter display-name "LIMITER TEST")
    (safety-limiter tooltip "Limiter tooltip test")
    (safety-limiter-ceiling display-name "CEILING TEST")
    (safety-limiter-ceiling tooltip "Ceiling tooltip test")))

(set! yaenhancer-standard-config
      (fold
       (lambda (override config)
         (override-component-property
          config
          (list-ref override 0)
          (list-ref override 1)
          (list-ref override 2)))
       yaenhancer-standard-config
       optional-overrides))

(reset-generation-state!)
(reset-cpp-identifiers!)
(plugin-interface "" "YAEnhancer Config Test")

(check 'auto-gain-config-display
       (equal? (model-property "auto-gain" 'text) "AUTO TEST"))
(check 'auto-gain-config-tooltip
       (equal? (model-property "auto-gain" 'tooltip) "Auto tooltip test"))
(check 'delta-config-display
       (equal? (model-property "delta-monitor" 'text) "DELTA TEST"))
(check 'delta-config-tooltip
       (equal? (model-property "delta-monitor" 'tooltip)
               "Delta tooltip test"))
(check 'safety-config-display
       (equal? (model-property "safety-limiter" 'text) "LIMITER TEST"))
(check 'safety-config-tooltip
       (equal? (model-property "safety-limiter" 'tooltip)
               "Limiter tooltip test"))
(check 'ceiling-config-display
       (equal? (model-property "safety-limiter-ceiling" 'title)
               "CEILING TEST"))
(check 'ceiling-config-tooltip
       (equal? (model-property "safety-limiter-ceiling" 'tooltip)
               "Ceiling tooltip test"))

(check 'delta-role-unchanged
       (eq? (model-property "delta-monitor" 'role) 'delta-monitor))
(check 'delta-parameter-id-unchanged
       (equal? (model-property "delta-monitor" 'parameter-id)
               "deltaMonitorID"))
(check 'delta-reference-unchanged
       (equal? (model-property "delta-monitor" 'processor-reference)
               "deltaMonitor"))
(check 'safety-role-unchanged
       (eq? (model-property "safety-limiter" 'role) 'safety-limiter))
(check 'safety-parameter-id-unchanged
       (equal? (model-property "safety-limiter" 'parameter-id)
               "safetyLimiterID"))
(check 'safety-reference-unchanged
       (equal? (model-property "safety-limiter" 'processor-reference)
               "safetyLimiter"))
(check 'ceiling-role-unchanged
       (eq? (model-property "safety-limiter-ceiling" 'role)
            'safety-limiter-ceiling))
(check 'ceiling-parameter-id-unchanged
       (equal? (model-property "safety-limiter-ceiling" 'parameter-id)
               "safetyLimiterCeilingID"))
(check 'ceiling-reference-unchanged
       (equal? (model-property "safety-limiter-ceiling"
                               'processor-reference)
               "safetyLimiterCeiling"))

(display "standard-component-display-config-test: PASS\n")
