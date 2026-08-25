(use-modules (ice-9 string-fun)
             (oop goops)
             (generator-app code-generator)
             (generator-app dsp-generation)
             (generator-app generation-state)
             (generator-app tools))

(define (check label predicate)
  (unless predicate
    (error "developer-only latency generation test failed" label)))

(define (position text fragment)
  (or (string-contains text fragment)
      (error "missing generated fragment" fragment)))

(define (make-slider id role reference min max default)
  (make <rotary-slider>
    #:id id #:role role
    #:parameter-id reference #:parameter-name reference
    #:processor-reference reference
    #:min min #:max max #:default default))

(define (make-toggle id role reference)
  (make <normal-toggle-button>
    #:id id #:role role
    #:parameter-id reference #:parameter-name reference
    #:processor-reference reference))

;; Developer-only latency: no fft-size and no oversampling role.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-slider 'wet-dry 'wet-dry "wetdry" 0.0 1.0 1.0)
(make-toggle 'hard-bypass 'bypass "bypass")
(make-toggle 'dsp-bypass 'dsp-bypass "dspBypass")

(let ((prepare (generate-latency-prepare-code))
      (members (generate-latency-runtime-members-code))
      (process (generate-process-code)))
  (check 'maximum-all-four-realplugins
         (and (string-contains prepare "getDeveloperLatencySamples(1)")
              (string-contains prepare "getDeveloperLatencySamples(2)")
              (string-contains prepare "getDeveloperLatencySamples(4)")
              (string-contains prepare "getDeveloperLatencySamples(8)")))
  (check 'host-latency-reported
         (string-contains prepare
                          "setLatencySamples(\n        generatedMaximumLatencySamples);"))
  (check 'prepare-allocation-only-when-positive
         (< (position prepare "if (generatedMaximumLatencySamples > 0)")
            (position prepare "generatedDryDelayBuffer.setSize")))
  (check 'runtime-delay-resources
         (and (string-contains members "generatedDryDelayBuffer")
              (string-contains members "generatedWetDelayBuffer")
              (string-contains members "generatedMaximumLatencySamples")))
  (check 'developer-active-latency
         (string-contains process "getDeveloperLatencySamples(1)"))
  (check 'zero-latency-fast-guard
         (< (position process "if (generatedMaximumLatencySamples > 0)")
            (position process "getDeveloperLatencySamples(1)")))
  (check 'wet-dry-delay-path
         (string-contains process "GENERATED DRY LATENCY COMPENSATION"))
  (check 'hard-bypass-fixed-delay
         (let ((bypass (position process "// HARD BYPASS"))
               (delay (position process "generatedDryDelayBuffer.getNumSamples()"))
               (return (position process "return;")))
           (and (< bypass delay) (< delay return))))
  (check 'dsp-bypass-zero-actual
         (and (string-contains process "if (value_dspBypass >= 0.5f)")
              (string-contains process "generatedActualLatencySamples = 0;")))
  (check 'no-fft-or-oversampling-code
         (and (not (string-contains process "myplugin->processFFT"))
              (not (string-contains process "processSamplesUp"))
              (not (string-contains prepare "generatedMaximumFFTLatency = 8192"))
              (not (string-contains prepare "oversampling8x->getLatencyInSamples")))))

;; Without wet/dry, host/developer and bypass timing still exist, but the
;; dry-mix alignment pass is not generated.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-toggle 'hard-bypass 'bypass "bypass")
(make-toggle 'dsp-bypass 'dsp-bypass "dspBypass")
(let ((process (generate-process-code)))
  (check 'no-wetdry-no-dry-pass
         (not (string-contains process "GENERATED DRY LATENCY COMPENSATION")))
  (check 'no-wetdry-wet-padding
         (string-contains process "GENERATED WET LATENCY COMPENSATION"))
  (check 'no-wetdry-hard-bypass-padding
         (string-contains process "generatedDryDelayBuffer.getNumSamples()")))

;; Existing combined FFT + oversampling architecture remains present.
(reset-generation-state!)
(reset-cpp-identifiers!)
(make-slider 'oversampling 'oversampling "oversampling" 0.0 3.0 0.0)
(make-slider 'fft-size 'fft-size "fftSize" 0.0 6.0 0.0)
(let ((prepare (generate-latency-prepare-code))
      (process (generate-process-code)))
  (check 'fft-maximum-unchanged
         (string-contains prepare "generatedMaximumFFTLatency = 8192"))
  (check 'oversampling-maximum-unchanged
         (string-contains prepare "oversampling8x->getLatencyInSamples"))
  (check 'fft-active-latency-unchanged
         (string-contains process "generatedActualLatencySamples += 8192"))
  (check 'oversampling-active-latency-unchanged
         (string-contains process "oversampling8x->getLatencyInSamples")))

(display "developer-only-latency-generation-test: PASS\n")
