(use-modules (ice-9 string-fun)
             (ice-9 textual-ports)
             (oop goops)
             (generator-app code-generator)
             (generator-app dsp-generation)
             (generator-app generation-state))

(define (check label predicate)
  (unless predicate
    (error "scope tap-points test failed" label)))

(define (field alist key) (assoc-ref alist key))

(define invalid-counter 0)
(define (rejected? taps)
  (set! invalid-counter (+ invalid-counter 1))
  (catch #t
    (lambda ()
      (make <scope> #:id (string-append "invalid-scope-" (number->string invalid-counter))
            #:role 'scope #:tap-points taps)
      #f)
    (lambda args #t)))

(reset-generation-state!)
(let ((default (make <scope> #:id "default-scope" #:role 'scope)))
  (check 'default-post-dsp
         (equal? (field (component->model default) 'tap-points)
                 '(post-dsp))))

(for-each
 (lambda (entry)
   (let ((id (car entry)) (taps (cdr entry)))
   (reset-generation-state!)
   (let ((scope (make <scope> #:id id #:role 'scope
                      #:tap-points taps)))
     (check (list 'valid taps)
            (equal? (field (component->model scope) 'tap-points) taps)))))
 '(("pre-scope" pre-dsp)
   ("post-scope" post-dsp)
   ("dual-scope" pre-dsp post-dsp)))

(for-each
 (lambda (taps)
   (reset-generation-state!)
   (check (list 'invalid taps) (rejected? taps)))
 '(() (unknown) (pre-dsp pre-dsp) (post-dsp pre-dsp)
   (pre-dsp post-dsp pre-dsp)))

(define (register-runtime-fixture taps suffix)
  (reset-generation-state!)
  (make <linear-slider> #:id (string-append "input-gain-" suffix) #:role 'input-gain
        #:processor-reference "inputGain")
  (make <scope> #:id (string-append "scope-main-" suffix) #:role 'scope #:tap-points taps)
  (make <linear-slider> #:id (string-append "output-gain-" suffix) #:role 'output-gain
        #:processor-reference "outputGain")
  (make <meter> #:id (string-append "output-meter-" suffix)
        #:role 'output-meter))

(register-runtime-fixture '(post-dsp) "single")
(let ((members (generate-dsp-runtime-members-code))
      (process (generate-process-code))
      (timer (generate-timer-code)))
  (check 'single-post-resource
         (and (string-contains members "scopeMainSinglePostDspFifo")
              (not (string-contains members "scopeMainSinglePreDspFifo"))))
  (check 'single-post-wiring
         (and (string-contains timer "fetchPostFromProcessor")
              (not (string-contains timer "fetchPreFromProcessor"))))
  (check 'post-before-output-gain
         (< (string-contains process "SCOPE POST-DSP TAP")
            (string-contains process "OUTPUT GAIN"))))

(register-runtime-fixture '(pre-dsp post-dsp) "dual-runtime")
(let ((members (generate-dsp-runtime-members-code))
      (process (generate-process-code))
      (timer (generate-timer-code)))
  (check 'dual-resources
         (and (string-contains members "scopeMainDualRuntimePreDspFifo")
              (string-contains members "scopeMainDualRuntimePostDspFifo")))
  (check 'dual-wiring
         (and (string-contains timer "fetchPreFromProcessor")
              (string-contains timer "fetchPostFromProcessor")))
  (check 'pre-after-input-gain
         (< (string-contains process "INPUT GAIN")
            (string-contains process "SCOPE PRE-DSP TAP")))
  (check 'pre-before-post
         (< (string-contains process "SCOPE PRE-DSP TAP")
            (string-contains process "SCOPE POST-DSP TAP")))
  (check 'post-before-output-gain-dual
         (< (string-contains process "SCOPE POST-DSP TAP")
            (string-contains process "OUTPUT GAIN")))
  (check 'output-meter-after-output-gain
         (< (string-contains process "OUTPUT GAIN")
            (string-contains process "OUTPUT METER"))))

(let ((renderer
       (call-with-input-file "YATemplate/Source/KineticLookAndFeel.cpp"
         get-string-all))
      (api
       (call-with-input-file "YATemplate/Source/KineticLookAndFeel.h"
         get-string-all)))
  (check 'renderer-dual-api
         (and (string-contains api "fetchPreFromProcessor")
              (string-contains api "fetchPostFromProcessor")
              (string-contains api "secondaryFifo")))
  (check 'renderer-common-scale
         (and (string-contains renderer
                               "heightFactor = plotBounds.getHeight() * 0.45f")
              (string-contains renderer "const auto makePath")))
  (check 'renderer-semantic-colours
         (and (string-contains renderer "palette.neonAux.withAlpha(0.5f)")
              (string-contains renderer "palette.neonCore.withAlpha(0.92f)"))))

(display "scope-tap-points-test: PASS\n")
