(use-modules (ice-9 string-fun)
             (oop goops)
             (generator-app code-generator)
             (generator-app dsp-generation)
             (generator-app generation-state)
             (generator-app tools))

(define (check label predicate)
  (unless predicate
    (error "Safety Limiter generation test failed" label)))

(define (position text fragment)
  (or (string-contains text fragment)
      (error "Missing generated fragment" fragment)))

(define (make-slider id role reference)
  (make <rotary-slider>
    #:id id
    #:role role
    #:parameter-id reference
    #:parameter-name reference
    #:processor-reference reference))

(define (make-toggle id role reference)
  (make <normal-toggle-button>
    #:id id
    #:role role
    #:parameter-id reference
    #:parameter-name reference
    #:processor-reference reference))

;; Capability absent: no limiter runtime or process code is generated.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-slider 'output-gain 'output-gain "outputGain")
(make <meter> #:id 'output-meter #:role 'output-meter)

(let ((process (generate-process-code))
      (members (generate-dsp-runtime-members-code)))
  (check 'off-path-unchanged
         (and (not (string-contains process "SAFETY LIMITER"))
              (not (string-contains process "generatedSafetyLimiter"))
              (not (string-contains members "generatedSafetyLimiter")))))

;; Capability present: the limiter works in its normalised domain and Ceiling
;; maps the final hard-clipped output to the requested sample-peak level.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-toggle 'delta-monitor 'delta-monitor "deltaMonitor")
(make-slider 'output-gain 'output-gain "outputGain")
(make-toggle 'safety-limiter 'safety-limiter "safetyLimiter")
(make-slider 'safety-limiter-ceiling
             'safety-limiter-ceiling
             "safetyLimiterCeiling")
(make <meter> #:id 'output-meter #:role 'output-meter)

(let* ((process (generate-process-code))
       (members (generate-dsp-runtime-members-code))
       (prepare (generate-myplugin-prepare-code))
       (reset (generate-myplugin-reset-code))
       (delta-pos (position process "// DELTA MONITOR"))
       (gain-pos (position process "// OUTPUT GAIN"))
       (limiter-pos (position process "// SAFETY LIMITER"))
       (pre-gain-pos
        (position process "buffer.applyGain(safetyLimiterInputGain)"))
       (process-pos
        (position process
                  "generatedSafetyLimiter.process(safetyLimiterContext)"))
       (post-gain-pos
        (position process "buffer.applyGain(safetyLimiterCeilingGain)"))
       (meter-pos (position process "// OUTPUT METER")))
  (check 'pipeline-order
         (and (< delta-pos gain-pos)
              (< gain-pos limiter-pos)
              (< limiter-pos meter-pos)))
  (check 'toggle-gates-processing
         (and (string-contains process "if (value_safetyLimiter >= 0.5f)")
              (string-contains process
                               "generatedSafetyLimiter.process(safetyLimiterContext)")))
  (check 'normalised-limiter-order
         (and (< limiter-pos pre-gain-pos)
              (< pre-gain-pos process-pos)
              (< process-pos post-gain-pos)
              (< post-gain-pos meter-pos)))
  (check 'ceiling-drives-final-gain
         (and (string-contains
               process
               "decibelsToGain(value_safetyLimiterCeiling)")
              (string-contains
               process
               "-10.0f - value_safetyLimiterCeiling")
              (not (string-contains
                    process
                    "setThreshold(value_safetyLimiterCeiling)"))))
  (check 'runtime-member
         (string-contains members
                          "juce::dsp::Limiter<float> generatedSafetyLimiter"))
  (check 'host-rate-prepare
         (and (string-contains prepare
                               "safetyLimiterSpec.sampleRate = hostSampleRate")
              (string-contains prepare "setThreshold(-6.25f)")
              (string-contains prepare "setRelease(100.0f)")
              (string-contains prepare
                               "generatedSafetyLimiter.prepare(safetyLimiterSpec)")))
  (check 'reset
         (string-contains reset "generatedSafetyLimiter.reset()")))

;; DSP bypass wraps developer DSP only; the limiter remains later in the path.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-toggle 'dsp-bypass 'dsp-bypass "dspBypass")
(make-toggle 'safety-limiter 'safety-limiter "safetyLimiter")
(make-slider 'safety-limiter-ceiling
             'safety-limiter-ceiling
             "safetyLimiterCeiling")

(let ((process (generate-process-code)))
  (check 'dsp-bypass-does-not-bypass-limiter
         (< (position process "if (value_dspBypass < 0.5f)")
            (position process "// SAFETY LIMITER"))))

;; Hard/general bypass retains its early return and therefore skips the whole
;; normal output chain, including the optional limiter.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-toggle 'hard-bypass 'bypass "bypass")
(make-toggle 'safety-limiter 'safety-limiter "safetyLimiter")
(make-slider 'safety-limiter-ceiling
             'safety-limiter-ceiling
             "safetyLimiterCeiling")

(let ((process (generate-process-code)))
  (check 'hard-bypass-skips-limiter
         (< (position process "        return;")
            (position process "// SAFETY LIMITER"))))

;; A partial capability is rejected instead of emitting invalid C++.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-toggle 'safety-limiter 'safety-limiter "safetyLimiter")
(check 'partial-capability-rejected
       (catch #t
         (lambda ()
           (generate-process-code)
           #f)
         (lambda args #t)))

(display "safety-limiter-generation-test: PASS\n")
