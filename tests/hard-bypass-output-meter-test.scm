(use-modules (oop goops)
             (ice-9 string-fun)
             (generator-app dsl-model)
             (generator-app dsp-generation)
             (generator-app generation-state))

(define (check label predicate)
  (unless predicate
    (error "Hard-bypass output-meter test failed" label)))

(define (position code fragment)
  (or (string-contains code fragment)
      (error "Missing generated fragment" fragment)))

(reset-generation-state!)
(make <meter> #:id 'input-meter #:role 'input-meter)
(make <normal-toggle-button>
  #:id 'bypass #:role 'bypass
  #:parameter-id "bypass" #:parameter-name "Bypass"
  #:processor-reference "bypass")
(make <linear-slider>
  #:id 'output-gain #:role 'output-gain
  #:parameter-id "outputGain" #:parameter-name "Output Gain"
  #:processor-reference "outputGain")
(make <meter> #:id 'output-meter #:role 'output-meter)

(define code (generate-process-code))
(define input-pos (position code "// INPUT METER"))
(define bypass-pos (position code "// HARD BYPASS"))
(define bypass-output-pos
  (position code "outputMeterPeak.store(peak, std::memory_order_relaxed);"))
(define return-pos (position code "        return;"))
(define output-gain-pos (position code "// OUTPUT GAIN"))
(define normal-output-pos
  (string-contains code
                   "outputMeterPeak.store(peak, std::memory_order_relaxed);"
                   (+ bypass-output-pos 1)))

(check 'input-before-hard-bypass (< input-pos bypass-pos))
(check 'hard-bypass-meter-before-return
       (and (< bypass-pos bypass-output-pos) (< bypass-output-pos return-pos)))
(check 'normal-output-after-output-gain
       (and normal-output-pos (< output-gain-pos normal-output-pos)))

(display "hard-bypass-output-meter-test: PASS\n")
