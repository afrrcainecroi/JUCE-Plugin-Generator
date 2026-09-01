(define-module (generator-app dsp-generation)
  #:use-module (ice-9 format)
  #:use-module (generator-app registration)
  #:export (generate-process-code
            generate-process-wetdry-prefix
            generate-paint-over-children-code
	    generate-timer-code
	    generate-dsp-runtime-members-code
	    generate-oversampling-prepare-code
	    generate-oversampling-release-code
	    generate-oversampling-runtime-members-code
	    oversampling-model
	    generate-fft-infrastructure-code
	    generate-fft-runtime-members-code
	    generate-myplugin-fft-members-code

	    generate-myplugin-fft-init-code
	    generate-myplugin-process-audio-buffer-code
	    generate-myplugin-process-audio-block-code
	    generate-myplugin-audio-init-code
	    generate-myplugin-prepare-code
	    generate-myplugin-reset-code
	    generate-latency-prepare-code
	    generate-latency-runtime-members-code
	    generate-process-wet-latency-code
	    generate-process-dry-latency-code
	    generate-myplugin-developer-latency-code
	    generate-myplugin-developer-latency-declaration-code
	    ))

(define (scope-model)
  (role-model 'scope))

(define (scope-tap-points)
  (let ((model (scope-model)))
    (if model (assoc-ref model 'tap-points) '())))

(define (scope-has-tap? tap)
  (and (memq tap (scope-tap-points)) #t))

(define (scope-resource-base tap)
  (string-append
   (assoc-ref (scope-model) 'var)
   (if (eq? tap 'pre-dsp) "PreDsp" "PostDsp")))

(define (dry-reference-required?)
  (or (role-present? 'wet-dry)
      (role-present? 'delta-monitor)))

(define (safety-limiter-models)
  (let ((limiter (role-model 'safety-limiter))
        (ceiling (role-model 'safety-limiter-ceiling)))
    (cond
     ((and limiter ceiling)
      (cons limiter ceiling))
     ((or limiter ceiling)
      (error
       "Safety Limiter requires both safety-limiter and safety-limiter-ceiling roles"))
     (else
      #f))))

(define-public (generate-process-code)
  (string-append
   (generate-process-input-meter)
   (generate-process-bypass)
   (generate-process-input-gain)
   (generate-process-scope-tap 'pre-dsp)
   (generate-process-wetdry-prefix)

   (generate-process-dsp)
   (generate-process-wet-latency-code)
   (generate-process-dry-latency-code)

   (generate-process-wetdry-postfix)
   (generate-process-scope-tap 'post-dsp)
   (generate-process-output-gain)
   (generate-process-safety-limiter)
   (generate-process-output-meter)
   ))

(define (generate-process-bypass)
  (let ((model
         (find-component-by-role 'bypass)))

    (if model

        (let ((ref
               (assoc-ref model
                          'processor-reference)))

          (if (latency-infrastructure-required?)

              ;; ==================================================
              ;; HARD BYPASS CON LATENZA FISSA
              ;; ==================================================

              (format #f
"
    // ==========================================================
    // HARD BYPASS
    //
    // Anche il bypass deve rispettare la latenza fissa
    // dichiarata all'host.
    // ==========================================================

    if (value_~a >= 0.5f)
    {
        if (generatedMaximumLatencySamples > 0)
        {
            const int generatedDelayBufferSize =
                generatedDryDelayBuffer.getNumSamples();

            const int generatedNumChannels =
                juce::jmin(
                    buffer.getNumChannels(),
                    generatedDryDelayBuffer.getNumChannels());

            for (int sample = 0;
                 sample < buffer.getNumSamples();
                 ++sample)
            {
                int readPosition =
                    generatedDryDelayWritePosition
                    - generatedMaximumLatencySamples;

                if (readPosition < 0)
                    readPosition +=
                        generatedDelayBufferSize;

                for (int ch = 0;
                     ch < generatedNumChannels;
                     ++ch)
                {
                    auto* audio =
                        buffer.getWritePointer(ch);

                    auto* delay =
                        generatedDryDelayBuffer
                            .getWritePointer(ch);

                    const float input =
                        audio[sample];

                    audio[sample] =
                        delay[readPosition];

                    delay[
                        generatedDryDelayWritePosition]
                        = input;
                }

                ++generatedDryDelayWritePosition;

                if (generatedDryDelayWritePosition
                    >= generatedDelayBufferSize)
                {
                    generatedDryDelayWritePosition = 0;
                }
            }
        }

~a
        return;
    }

"
                      ref
                      (generate-process-output-meter))

              ;; ==================================================
              ;; NESSUNA INFRASTRUTTURA DI LATENZA
              ;; ==================================================

              (format #f
"
    // HARD BYPASS
    if (value_~a >= 0.5f)
    {
~a
        return;
    }

"
                      ref
                      (generate-process-output-meter))))

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

(define (generate-process-dsp-body)

  (let ((oversampling
         (oversampling-model))
        (fft
         (fft-model)))

    (string-append

     ;; ==========================================================
     ;; FFT / SPECTRAL PROCESSING
     ;;
     ;; Sempre a sample-rate host.
     ;; ==========================================================

     (if fft
         "
    // FFT / SPECTRAL DSP
    myplugin->processFFT(buffer);

"
         "")

     ;; ==========================================================
     ;; TIME DOMAIN DSP / OVERSAMPLING
     ;; ==========================================================

     (if oversampling

         (let ((ref
                (assoc-ref oversampling
                           'processor-reference)))

           (format #f
"    switch (static_cast<int>(value_~a))
    {
        case 0:
        {
            // Oversampling OFF / 1x
            myplugin->processAudio(
                buffer,
                1);
            break;
        }

        case 1:
        {
            // 2x
            juce::dsp::AudioBlock<float> block(buffer);

            auto oversampledBlock =
                oversampling2x->processSamplesUp(block);

            myplugin->processAudio(
                oversampledBlock,
                2);

            oversampling2x->processSamplesDown(block);
            break;
        }

        case 2:
        {
            // 4x
            juce::dsp::AudioBlock<float> block(buffer);

            auto oversampledBlock =
                oversampling4x->processSamplesUp(block);

            myplugin->processAudio(
                oversampledBlock,
                4);

            oversampling4x->processSamplesDown(block);
            break;
        }

        case 3:
        {
            // 8x
            juce::dsp::AudioBlock<float> block(buffer);

            auto oversampledBlock =
                oversampling8x->processSamplesUp(block);

            myplugin->processAudio(
                oversampledBlock,
                8);

            oversampling8x->processSamplesDown(block);
            break;
        }

        default:
            myplugin->processAudio(
                buffer,
                1);
            break;
    }

"
                   ref))

         "
    myplugin->processAudio(
        buffer,
        1);

"))))

(define (generate-process-dsp)
  (let ((dsp-bypass
         (find-component-by-role 'dsp-bypass)))

    (if dsp-bypass
        (let ((ref
               (assoc-ref dsp-bypass
                          'processor-reference)))
          (string-append
           (format #f
"    // DSP
    if (value_~a < 0.5f)
    {
"
                   ref)

           (generate-process-dsp-body)

           "    }\n\n"))

        (string-append
         "    // DSP\n"
         (generate-process-dsp-body)))))



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

(define (generate-process-safety-limiter)
  (let ((models (safety-limiter-models)))
    (if models
        (let ((limiter-ref
               (assoc-ref (car models) 'processor-reference))
              (ceiling-ref
               (assoc-ref (cdr models) 'processor-reference)))
          (format #f
"    // SAFETY LIMITER
    if (value_~a >= 0.5f)
    {
        // JUCE's limiter has a fixed -10 dB first stage and +10 dB
        // internal makeup at the configured -6.25 dB threshold.
        // Map the selected ceiling to that first-stage threshold,
        // then map the final hard clip back to the requested ceiling.
        const auto safetyLimiterCeilingGain =
            juce::Decibels::decibelsToGain(value_~a);

        const auto safetyLimiterInputGain =
            juce::Decibels::decibelsToGain(
                -10.0f - value_~a);

        buffer.applyGain(safetyLimiterInputGain);

        juce::dsp::AudioBlock<float> safetyLimiterBlock(buffer);
        juce::dsp::ProcessContextReplacing<float>
            safetyLimiterContext(safetyLimiterBlock);

        generatedSafetyLimiter.process(safetyLimiterContext);
        buffer.applyGain(safetyLimiterCeilingGain);
    }

"
                  limiter-ref
                  ceiling-ref
                  ceiling-ref))
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

(define (generate-process-scope-tap tap)
  (if (scope-has-tap? tap)
      (let ((base (scope-resource-base tap)))
        (format #f "    // SCOPE ~a TAP
    {
        const float* data = buffer.getReadPointer(0);
        const int numSamples = buffer.getNumSamples();
        const int step = juce::jmax(1, (numSamples + 127) / 128);
        int idx = ~aWriteIdx.load(std::memory_order_relaxed);

        for (int i = 0; i < numSamples; i += step)
        {
            ~aFifo[idx].store(data[i], std::memory_order_relaxed);
            idx = (idx + 1) % 128;
        }

        ~aWriteIdx.store(idx, std::memory_order_relaxed);
    }

"
                (if (eq? tap 'pre-dsp) "PRE-DSP" "POST-DSP")
                base base base))
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
  (if (dry-reference-required?)
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
  (let ((wetdry-model
         (role-model 'wet-dry))
        (delta-model
         (role-model 'delta-monitor)))

    (cond

     ;; ==========================================================
     ;; DELTA MONITOR + WET/DRY
     ;;
     ;; DELTA is a monitoring mode:
     ;;
     ;;   delta OFF -> normal wet/dry mix
     ;;   delta ON  -> aligned wet - aligned dry
     ;;
     ;; Wet/Dry is intentionally ignored while DELTA is active.
     ;; ==========================================================

     ((and wetdry-model delta-model)
      (let* ((wet-ref
              (assoc-ref wetdry-model 'processor-reference))
             (wet-min
              (assoc-ref wetdry-model 'min))
             (wet-max
              (assoc-ref wetdry-model 'max))
             (delta-ref
              (assoc-ref delta-model 'processor-reference)))

        (format #f
"    // DELTA MONITOR / WET-DRY
    if (value_~a >= 0.5f)
    {
        // Monitor only what the DSP changed:
        //     DELTA = aligned wet - aligned dry
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            auto* wet = buffer.getWritePointer(ch);
            const auto* dry = dryBuffer.getReadPointer(ch);
            const int numSamples = buffer.getNumSamples();

            juce::FloatVectorOperations::addWithMultiply(
                wet,
                dry,
                -1.0f,
                numSamples);
        }
    }
    else
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
                delta-ref
                wet-ref wet-min wet-max wet-min)))

     ;; ==========================================================
     ;; DELTA MONITOR ONLY
     ;; ==========================================================

     (delta-model
      (let ((delta-ref
             (assoc-ref delta-model 'processor-reference)))

        (format #f
"    // DELTA MONITOR
    if (value_~a >= 0.5f)
    {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            auto* wet = buffer.getWritePointer(ch);
            const auto* dry = dryBuffer.getReadPointer(ch);
            const int numSamples = buffer.getNumSamples();

            juce::FloatVectorOperations::addWithMultiply(
                wet,
                dry,
                -1.0f,
                numSamples);
        }
    }

"
                delta-ref)))

     ;; ==========================================================
     ;; WET/DRY ONLY -- preserve previous generated behaviour.
     ;; ==========================================================

     (wetdry-model
      (let* ((ref
              (assoc-ref wetdry-model 'processor-reference))
             (min
              (assoc-ref wetdry-model 'min))
             (max
              (assoc-ref wetdry-model 'max)))

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
                ref min max min)))

     (else
      ""))))


(define-public (generate-timer-code)
  (string-append

   ;; INPUT METER
   (let ((model (role-model 'input-meter)))
     (if model
         (format #f
                 "~a.updateLevel(ap.~a.exchange(0.0f, std::memory_order_relaxed));~%"
                 (assoc-ref model 'var)
                 (meter-peak-var model))
         ""))

   ;; OUTPUT METER
   (let ((model (role-model 'output-meter)))
     (if model
         (format #f
                 "~a.updateLevel(ap.~a.exchange(0.0f, std::memory_order_relaxed));~%"
                 (assoc-ref model 'var)
                 (meter-peak-var model))
         ""))

   ;; SCOPE
   (let ((model (scope-model)))
     (if model
         (string-append
          (if (scope-has-tap? 'pre-dsp)
              (let ((base (scope-resource-base 'pre-dsp)))
                (format #f
"~a.fetchPreFromProcessor(
    ap.~aFifo,
    ap.~aWriteIdx.load(std::memory_order_relaxed));~%"
                        (assoc-ref model 'var) base base))
              "")
          (if (scope-has-tap? 'post-dsp)
              (let ((base (scope-resource-base 'post-dsp)))
                (format #f
"~a.fetchPostFromProcessor(
    ap.~aFifo,
    ap.~aWriteIdx.load(std::memory_order_relaxed));~%"
                        (assoc-ref model 'var) base base))
              ""))
         ""))))


(define-public (generate-dsp-runtime-members-code)
  (string-append

   (let ((model (role-model 'input-meter)))
     (if model
         (format #f
                 "std::atomic<float> ~a { 0.0f };~%"
                 (meter-peak-var model))
         ""))

   (let ((model (role-model 'output-meter)))
     (if model
         (format #f
                 "std::atomic<float> ~a { 0.0f };~%"
                 (meter-peak-var model))
         ""))

   (if (scope-has-tap? 'pre-dsp)
       (let ((base (scope-resource-base 'pre-dsp)))
         (format #f "std::array<std::atomic<float>, 128> ~aFifo {};~%std::atomic<int> ~aWriteIdx { 0 };~%" base base))
       "")
   (if (scope-has-tap? 'post-dsp)
       (let ((base (scope-resource-base 'post-dsp)))
         (format #f "std::array<std::atomic<float>, 128> ~aFifo {};~%std::atomic<int> ~aWriteIdx { 0 };~%" base base))
       "")

   (if (safety-limiter-models)
       "juce::dsp::Limiter<float> generatedSafetyLimiter;\n"
       "")

   (generate-oversampling-runtime-members-code)
   (generate-latency-runtime-members-code)
   ))

(define (oversampling-model)
  (role-model 'oversampling))

(define-public (generate-oversampling-runtime-members-code)
  (if (oversampling-model)
      (string-append
       "std::unique_ptr<juce::dsp::Oversampling<float>> oversampling2x;\n"
       "std::unique_ptr<juce::dsp::Oversampling<float>> oversampling4x;\n"
       "std::unique_ptr<juce::dsp::Oversampling<float>> oversampling8x;\n")
      ""))

(define-public (generate-oversampling-prepare-code)
  (if (oversampling-model)
      "
    const auto processingChannels =
        static_cast<size_t>(
            juce::jmax(
                1,
                juce::jmax(
                    getTotalNumInputChannels(),
                    getTotalNumOutputChannels())));

    oversampling2x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            processingChannels,
            1,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR,
            false,
            true);

    oversampling4x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            processingChannels,
            2,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR,
            false,
            true);

    oversampling8x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            processingChannels,
            3,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR,
            false,
            true);

    oversampling2x->initProcessing(
        static_cast<size_t>(samplesPerBlock));

    oversampling4x->initProcessing(
        static_cast<size_t>(samplesPerBlock));

    oversampling8x->initProcessing(
        static_cast<size_t>(samplesPerBlock));

    oversampling2x->reset();
    oversampling4x->reset();
    oversampling8x->reset();

"
      ""))

(define-public (generate-oversampling-release-code)
  (if (oversampling-model)
      "
    oversampling2x.reset();
    oversampling4x.reset();
    oversampling8x.reset();
"
      ""))


(define (fft-model)
  (role-model 'fft-size))

(define (fft-enabled?)
  (if (fft-model) #t #f))

;; RealPlugin::getLatencySamples() is a developer contract, not a DSL role.
;; Its value is known only after the four factor-specific instances have been
;; prepared, so processor-side fixed-latency support must always be available.
(define (latency-infrastructure-required?) #t)

(define-public (generate-fft-infrastructure-code)
  (let ((model (fft-model)))
    (if model
        (let ((ref
               (assoc-ref model
                          'processor-reference)))
          (format #f
"
class GeneratedStft
{
public:
    GeneratedStft() = default;

    static int parameterToFFTSize(float value) noexcept
    {
        switch (static_cast<int>(value))
        {
            case 0:  return 0;
            case 1:  return 256;
            case 2:  return 512;
            case 3:  return 1024;
            case 4:  return 2048;
            case 5:  return 4096;
            case 6:  return 8192;
            default: return 0;
        }
    }

    int getRequestedFFTSize(
        const JX11AudioProcessor& processor) const noexcept
    {
        return parameterToFFTSize(
            processor.value_~a);
    }

    void prepare(
        int newFFTSize,
        int numChannels,
        int newMaximumBlockSize,
        double newSampleRate)
    {
        jassert(
            juce::isPowerOfTwo(
                newFFTSize));

        jassert(
            numChannels > 0);

        jassert(
            newMaximumBlockSize > 0);

        fftSize =
            newFFTSize;

        hopSize =
            fftSize / 2;

        maximumBlockSize =
            newMaximumBlockSize;

        sampleRate =
            newSampleRate;


        fft =
            std::make_unique<
                juce::dsp::FFT>(
                    static_cast<int>(
                        std::log2(
                            static_cast<double>(
                                fftSize))));


        // =====================================================
        // SQRT-HANN WINDOWS
        //
        // analysis * synthesis = Hann
        // con overlap 50%.
        // =====================================================

        analysisWindow.resize(
            static_cast<size_t>(
                fftSize));

        synthesisWindow.resize(
            static_cast<size_t>(
                fftSize));

        for (int n = 0;
             n < fftSize;
             ++n)
        {
            const float hann =
                0.5f
                * (1.0f
                   - std::cos(
                       2.0f
                       * juce::MathConstants<float>::pi
                       * static_cast<float>(n)
                       / static_cast<float>(
                           fftSize - 1)));

            const float w =
                std::sqrt(
                    juce::jmax(
                        0.0f,
                        hann));

            analysisWindow[
                static_cast<size_t>(n)] =
                    w;

            synthesisWindow[
                static_cast<size_t>(n)] =
                    w;
        }


        // =====================================================
        // CHANNEL STATE
        //
        // Tutta la memoria viene allocata qui.
        // Nessuna allocazione durante process().
        // =====================================================

        channels.clear();

        channels.resize(
            static_cast<size_t>(
                numChannels));

        for (auto& channel : channels)
        {
            channel.fifo.assign(
                static_cast<size_t>(
                    fftSize),
                0.0f);

            channel.reim.assign(
                static_cast<size_t>(
                    2 * fftSize),
                0.0f);

            channel.outputRing.assign(
                static_cast<size_t>(
                    2 * fftSize + 1),
                0.0f);

            channel.analysis.assign(
                static_cast<size_t>(
                    fftSize),
                0.0f);

            channel.synthesis.assign(
                static_cast<size_t>(
                    fftSize),
                0.0f);

            channel.fifoFill =
                0;

            channel.outputRead =
                0;
        }
    }


    void reset() noexcept
    {
        for (auto& channel : channels)
        {
            std::fill(
                channel.fifo.begin(),
                channel.fifo.end(),
                0.0f);

            std::fill(
                channel.reim.begin(),
                channel.reim.end(),
                0.0f);

            std::fill(
                channel.outputRing.begin(),
                channel.outputRing.end(),
                0.0f);

            std::fill(
                channel.analysis.begin(),
                channel.analysis.end(),
                0.0f);

            std::fill(
                channel.synthesis.begin(),
                channel.synthesis.end(),
                0.0f);

            channel.fifoFill =
                0;

            channel.outputRead =
                0;
        }
    }


    int getFFTSize() const noexcept
    {
        return fftSize;
    }


    int getHopSize() const noexcept
    {
        return hopSize;
    }


    int getLatencySamples() const noexcept
    {
        return fftSize;
    }


    double getSampleRate() const noexcept
    {
        return sampleRate;
    }


    void process(
        juce::dsp::AudioBlock<float>& block,
        FFTProcessor& fftProcessor)
    {
        jassert(
            fft != nullptr);

        const auto numChannels =
            static_cast<int>(
                block.getNumChannels());

        const auto numSamples =
            static_cast<int>(
                block.getNumSamples());

        jassert(
            numChannels
            <= static_cast<int>(
                channels.size()));

        jassert(
            numSamples
            <= maximumBlockSize);

        if (fft == nullptr
            || numChannels
               > static_cast<int>(
                   channels.size())
            || numSamples
               > maximumBlockSize)
        {
            return;
        }

        for (int ch = 0;
             ch < numChannels;
             ++ch)
        {
            processChannel(
                channels[
                    static_cast<size_t>(
                        ch)],
                block.getChannelPointer(
                    static_cast<size_t>(
                        ch)),
                numSamples,
                ch,
                fftProcessor);
        }
    }


private:

    struct Channel
    {
        std::vector<float> fifo;
        std::vector<float> reim;

        // Timeline di uscita.
        //
        // I frame sintetizzati vengono sommati qui
        // tramite overlap-add.
        std::vector<float> outputRing;

        std::vector<float> analysis;
        std::vector<float> synthesis;

        int fifoFill = 0;

        // Posizione della timeline che deve
        // essere emessa al prossimo sample.
        int outputRead = 0;
    };


    void processFrame(
        Channel& channel,
        int channelIndex,
        int outputStart,
        FFTProcessor& fftProcessor)
    {
        // =====================================================
        // ANALYSIS
        // =====================================================

        std::memcpy(
            channel.analysis.data(),
            channel.fifo.data(),
            sizeof(float)
                * static_cast<size_t>(
                    fftSize));

        for (int i = 0;
             i < fftSize;
             ++i)
        {
            channel.analysis[
                static_cast<size_t>(i)]
                *= analysisWindow[
                    static_cast<size_t>(i)];
        }


        // =====================================================
        // REAL FFT BUFFER
        // =====================================================

        std::memcpy(
            channel.reim.data(),
            channel.analysis.data(),
            sizeof(float)
                * static_cast<size_t>(
                    fftSize));

        std::fill(
            channel.reim.begin()
                + fftSize,
            channel.reim.end(),
            0.0f);


        fft->performRealOnlyForwardTransform(
            channel.reim.data());


        // =====================================================
        // DEVELOPER FFT CALLBACK
        // =====================================================

        FFTProcessContext context;

        context.fftSize =
            fftSize;

        context.sampleRate =
            sampleRate;

        context.channel =
            channelIndex;

        fftProcessor.processFFT(
            channel.reim,
            context);


        // =====================================================
        // SYNTHESIS
        // =====================================================

        fft->performRealOnlyInverseTransform(
            channel.reim.data());

        std::memcpy(
            channel.synthesis.data(),
            channel.reim.data(),
            sizeof(float)
                * static_cast<size_t>(
                    fftSize));

        for (int i = 0;
             i < fftSize;
             ++i)
        {
            channel.synthesis[
                static_cast<size_t>(i)]
                *= synthesisWindow[
                    static_cast<size_t>(i)];
        }


        // =====================================================
        // OUTPUT TIMELINE / OVERLAP-ADD
        //
        // Il frame può essere calcolato soltanto quando
        // tutti i suoi fftSize campioni sono disponibili.
        //
        // outputStart rappresenta il prossimo campione
        // della timeline d'uscita.
        //
        // In questo modo la latenza causale della STFT
        // è esattamente fftSize campioni e non dipende
        // dalla dimensione del blocco host.
        // =====================================================

        const int outputRingSize =
            static_cast<int>(
                channel.outputRing.size());

        for (int i = 0;
             i < fftSize;
             ++i)
        {
            const int outputIndex =
                (outputStart + i)
                % outputRingSize;

            channel.outputRing[
                static_cast<size_t>(
                    outputIndex)]
                += channel.synthesis[
                    static_cast<size_t>(
                        i)];
        }


        // =====================================================
        // ADVANCE ANALYSIS FIFO
        //
        // overlap 50%:
        // manteniamo gli ultimi fftSize-hopSize campioni.
        // =====================================================

        std::memmove(
            channel.fifo.data(),
            channel.fifo.data()
                + hopSize,
            sizeof(float)
                * static_cast<size_t>(
                    fftSize
                    - hopSize));

        channel.fifoFill -=
            hopSize;
    }


    void processChannel(
        Channel& channel,
        float* samples,
        int numSamples,
        int channelIndex,
        FFTProcessor& fftProcessor)
    {
        const int outputRingSize =
            static_cast<int>(
                channel.outputRing.size());

        jassert(
            outputRingSize
            > fftSize);


        // =====================================================
        // SAMPLE STREAM
        //
        // Il codice lavora sample-by-sample soltanto per
        // mantenere una timeline indipendente dal block size.
        //
        // FFT e callback continuano invece ad essere eseguite
        // frame-by-frame.
        // =====================================================

        for (int i = 0;
             i < numSamples;
             ++i)
        {
            // Salviamo il sample host prima di
            // sostituirlo con il sample STFT.
            const float inputSample =
                samples[i];


            // =================================================
            // OUTPUT CURRENT TIMELINE SAMPLE
            // =================================================

            samples[i] =
                channel.outputRing[
                    static_cast<size_t>(
                        channel.outputRead)];

            // Una volta emesso il campione,
            // la cella può essere riutilizzata.
            channel.outputRing[
                static_cast<size_t>(
                    channel.outputRead)] =
                0.0f;

            channel.outputRead =
                (channel.outputRead + 1)
                % outputRingSize;


            // =================================================
            // INPUT FIFO
            // =================================================

            channel.fifo[
                static_cast<size_t>(
                    channel.fifoFill)] =
                inputSample;

            ++channel.fifoFill;


            // =================================================
            // COMPLETE FRAME
            // =================================================

            if (channel.fifoFill
                >= fftSize)
            {
                // outputRead ora punta esattamente
                // al prossimo sample della timeline.
                //
                // Il nuovo frame viene schedulato
                // da quella posizione in avanti.

                processFrame(
                    channel,
                    channelIndex,
                    channel.outputRead,
                    fftProcessor);
            }
        }
    }


    std::vector<Channel> channels;

    std::unique_ptr<
        juce::dsp::FFT> fft;

    std::vector<float>
        analysisWindow;

    std::vector<float>
        synthesisWindow;

    int fftSize =
        1024;

    int hopSize =
        512;

    int maximumBlockSize =
        0;

    double sampleRate =
        44100.0;
};
"
                  ref))
        "")))

(define-public (generate-myplugin-fft-members-code)
  (let ((model (fft-model)))
    (if model
        (let ((ref
               (assoc-ref model
                          'processor-reference)))
          (format #f
"
    GeneratedStft stft256;
    GeneratedStft stft512;
    GeneratedStft stft1024;
    GeneratedStft stft2048;
    GeneratedStft stft4096;
    GeneratedStft stft8192;

    FFTProcessor fftProcessor256   { processor };
    FFTProcessor fftProcessor512   { processor };
    FFTProcessor fftProcessor1024  { processor };
    FFTProcessor fftProcessor2048  { processor };
    FFTProcessor fftProcessor4096  { processor };
    FFTProcessor fftProcessor8192  { processor };

    void processFFT(
        juce::AudioBuffer<float>& buffer)
    {
        juce::dsp::AudioBlock<float> block(buffer);

        switch (
            static_cast<int>(
                processor->value_~a))
        {
            case 0:
                return;

            case 1:
                stft256.process(
                    block,
                    fftProcessor256);
                break;

            case 2:
                stft512.process(
                    block,
                    fftProcessor512);
                break;

            case 3:
                stft1024.process(
                    block,
                    fftProcessor1024);
                break;

            case 4:
                stft2048.process(
                    block,
                    fftProcessor2048);
                break;

            case 5:
                stft4096.process(
                    block,
                    fftProcessor4096);
                break;

            case 6:
                stft8192.process(
                    block,
                    fftProcessor8192);
                break;

            default:
                return;
        }
    }
"
                  ref))
        "")))


(define-public (generate-myplugin-fft-init-code)
  "")

(define-public (generate-myplugin-process-audio-buffer-code)
  "
    juce::ignoreUnused(oversamplingFactor);

    juce::dsp::AudioBlock<float> block(buffer);

    AudioProcessContext context;

    context.sampleRate =
        processor->value_info_sampleRate;

    context.oversamplingFactor = 1;

    realPlugin1x->processAudio(
        block,
        context);
")

(define-public (generate-myplugin-process-audio-block-code)
  "
    AudioProcessContext context;

    context.sampleRate =
        processor->value_info_sampleRate
        * oversamplingFactor;

    context.oversamplingFactor =
        oversamplingFactor;

    switch (oversamplingFactor)
    {
        case 2:
            realPlugin2x->processAudio(
                buffer,
                context);
            break;

        case 4:
            realPlugin4x->processAudio(
                buffer,
                context);
            break;

        case 8:
            realPlugin8x->processAudio(
                buffer,
                context);
            break;

        default:
            realPlugin1x->processAudio(
                buffer,
                context);
            break;
    }
")


(define-public (generate-myplugin-audio-init-code)
  "
    realPlugin1x =
        std::make_unique<RealPlugin>(processor);

    realPlugin2x =
        std::make_unique<RealPlugin>(processor);

    realPlugin4x =
        std::make_unique<RealPlugin>(processor);

    realPlugin8x =
        std::make_unique<RealPlugin>(processor);
")


(define-public (generate-myplugin-prepare-code)
  (string-append
   "
    const double hostSampleRate =
        sampleRate;

    const int hostMaximumBlockSize =
        juce::jmax(
            1,
            samplesPerBlock);

    const int audioChannels =
        juce::jmax(
            1,
            numChannels);


    // ==========================================================
    // TIME DOMAIN DSP
    // ==========================================================

    {
        AudioPrepareContext context;

        context.sampleRate =
            hostSampleRate;

        context.maximumBlockSize =
            hostMaximumBlockSize;

        context.numChannels =
            audioChannels;

        context.oversamplingFactor = 1;

        realPlugin1x->prepare(context);
    }

    {
        AudioPrepareContext context;

        context.sampleRate =
            hostSampleRate * 2.0;

        context.maximumBlockSize =
            hostMaximumBlockSize * 2;

        context.numChannels =
            audioChannels;

        context.oversamplingFactor = 2;

        realPlugin2x->prepare(context);
    }

    {
        AudioPrepareContext context;

        context.sampleRate =
            hostSampleRate * 4.0;

        context.maximumBlockSize =
            hostMaximumBlockSize * 4;

        context.numChannels =
            audioChannels;

        context.oversamplingFactor = 4;

        realPlugin4x->prepare(context);
    }

    {
        AudioPrepareContext context;

        context.sampleRate =
            hostSampleRate * 8.0;

        context.maximumBlockSize =
            hostMaximumBlockSize * 8;

        context.numChannels =
            audioChannels;

        context.oversamplingFactor = 8;

        realPlugin8x->prepare(context);
    }

"
   (generate-safety-limiter-prepare-code)
   (if (fft-enabled?)
       "


    // ==========================================================
    // FFT / STFT
    // ==========================================================

    stft256.prepare(
        256,
        audioChannels,
        hostMaximumBlockSize,
        hostSampleRate);

    stft512.prepare(
        512,
        audioChannels,
        hostMaximumBlockSize,
        hostSampleRate);

    stft1024.prepare(
        1024,
        audioChannels,
        hostMaximumBlockSize,
        hostSampleRate);

    stft2048.prepare(
        2048,
        audioChannels,
        hostMaximumBlockSize,
        hostSampleRate);

    stft4096.prepare(
        4096,
        audioChannels,
        hostMaximumBlockSize,
        hostSampleRate);

    stft8192.prepare(
        8192,
        audioChannels,
        hostMaximumBlockSize,
        hostSampleRate);


    FFTPrepareContext fftContext;

    fftContext.sampleRate =
        hostSampleRate;

    fftContext.numChannels =
        audioChannels;


    fftContext.fftSize = 256;
    fftProcessor256.prepareFFT(fftContext);

    fftContext.fftSize = 512;
    fftProcessor512.prepareFFT(fftContext);

    fftContext.fftSize = 1024;
    fftProcessor1024.prepareFFT(fftContext);

    fftContext.fftSize = 2048;
    fftProcessor2048.prepareFFT(fftContext);

    fftContext.fftSize = 4096;
    fftProcessor4096.prepareFFT(fftContext);

    fftContext.fftSize = 8192;
    fftProcessor8192.prepareFFT(fftContext);
"
       "")
   "
    reset();
"))

(define-public (generate-myplugin-reset-code)
  (string-append
   "
    realPlugin1x->reset();
    realPlugin2x->reset();
    realPlugin4x->reset();
    realPlugin8x->reset();
"
   (generate-safety-limiter-reset-code)
   (if (fft-enabled?)
       "
    stft256.reset();
    stft512.reset();
    stft1024.reset();
    stft2048.reset();
    stft4096.reset();
    stft8192.reset();

    fftProcessor256.resetFFT();
    fftProcessor512.resetFFT();
    fftProcessor1024.resetFFT();
    fftProcessor2048.resetFFT();
    fftProcessor4096.resetFFT();
    fftProcessor8192.resetFFT();
"
       "")))

(define (generate-safety-limiter-prepare-code)
  (if (safety-limiter-models)
      "
    // ==========================================================
    // SAFETY LIMITER (host sample rate, no oversampling)
    // ==========================================================

    {
        juce::dsp::ProcessSpec safetyLimiterSpec;
        safetyLimiterSpec.sampleRate = hostSampleRate;
        safetyLimiterSpec.maximumBlockSize =
            static_cast<juce::uint32>(hostMaximumBlockSize);
        safetyLimiterSpec.numChannels =
            static_cast<juce::uint32>(audioChannels);

        processor->generatedSafetyLimiter.setThreshold(-6.25f);
        processor->generatedSafetyLimiter.setRelease(100.0f);
        processor->generatedSafetyLimiter.prepare(safetyLimiterSpec);
    }

"
      ""))

(define (generate-safety-limiter-reset-code)
  (if (safety-limiter-models)
      "
    processor->generatedSafetyLimiter.reset();
"
      ""))



(define-public (generate-latency-prepare-code)
  (let ((fft
         (fft-model))
        (oversampling
         (oversampling-model)))

    (if (latency-infrastructure-required?)

        (string-append
         "
    // ==========================================================
    // GENERATED FIXED LATENCY
    // ==========================================================

    int generatedMaximumFFTLatency = 0;
    int generatedMaximumOversamplingLatency = 0;
    int generatedMaximumDeveloperLatency = 0;

"

         ;; ------------------------------------------------------
         ;; MAXIMUM FFT LATENCY
         ;; ------------------------------------------------------

         (if fft
             "
    generatedMaximumFFTLatency = 8192;

"
             "")

         ;; ------------------------------------------------------
         ;; MAXIMUM OVERSAMPLING LATENCY
         ;; ------------------------------------------------------

         (if oversampling
             "
    generatedMaximumOversamplingLatency =
        juce::roundToInt(
            oversampling8x->getLatencyInSamples());

"
             "")

         ;; ------------------------------------------------------
         ;; MAXIMUM DEVELOPER DSP LATENCY
         ;; ------------------------------------------------------

         "
    if (myplugin != nullptr)
    {
        generatedMaximumDeveloperLatency =
            juce::jmax(
                myplugin->getDeveloperLatencySamples(1),
                juce::jmax(
                    myplugin->getDeveloperLatencySamples(2),
                    juce::jmax(
                        myplugin->getDeveloperLatencySamples(4),
                        myplugin->getDeveloperLatencySamples(8))));
    }

"

         ;; ------------------------------------------------------
         ;; FIXED GLOBAL LATENCY + DELAY BUFFERS
         ;; ------------------------------------------------------

         "
    generatedMaximumLatencySamples =
        generatedMaximumFFTLatency
        + generatedMaximumOversamplingLatency
        + generatedMaximumDeveloperLatency;

    generatedActualLatencySamples = 0;

    generatedDryDelayWritePosition = 0;
    generatedWetDelayWritePosition = 0;

    if (generatedMaximumLatencySamples > 0)
    {
        const int generatedLatencyChannels =
            juce::jmax(
                1,
                juce::jmax(
                    getTotalNumInputChannels(),
                    getTotalNumOutputChannels()));

        const int generatedDelayBufferSize =
            generatedMaximumLatencySamples
            + samplesPerBlock
            + 1;

        generatedDryDelayBuffer.setSize(
            generatedLatencyChannels,
            generatedDelayBufferSize,
            false,
            true,
            false);

        generatedWetDelayBuffer.setSize(
            generatedLatencyChannels,
            generatedDelayBufferSize,
            false,
            true,
            false);

        generatedDryDelayBuffer.clear();
        generatedWetDelayBuffer.clear();
    }


    // La latenza vista dall'host rimane costante
    // per tutte le configurazioni FFT / oversampling /
    // developer DSP.
    setLatencySamples(
        generatedMaximumLatencySamples);

")

        "")))

(define-public (generate-latency-runtime-members-code)
  (if (latency-infrastructure-required?)

      "
    // ==========================================================
    // GENERATED LATENCY COMPENSATION
    // ==========================================================

    juce::AudioBuffer<float>
        generatedDryDelayBuffer;

    juce::AudioBuffer<float>
        generatedWetDelayBuffer;

    int generatedDryDelayWritePosition = 0;
    int generatedWetDelayWritePosition = 0;

    int generatedMaximumLatencySamples = 0;
    int generatedActualLatencySamples = 0;

"

      ""))






(define-public (generate-process-dry-latency-code)
  (if (and
       (dry-reference-required?)
       (latency-infrastructure-required?))

      "
    // ==========================================================
    // GENERATED DRY LATENCY COMPENSATION
    // ==========================================================

    if (generatedMaximumLatencySamples > 0)
    {
        const int generatedDelayBufferSize =
            generatedDryDelayBuffer.getNumSamples();

        const int generatedNumChannels =
            juce::jmin(
                dryBuffer.getNumChannels(),
                generatedDryDelayBuffer.getNumChannels());

        for (int sample = 0;
             sample < dryBuffer.getNumSamples();
             ++sample)
        {
            int readPosition =
                generatedDryDelayWritePosition
                - generatedMaximumLatencySamples;

            if (readPosition < 0)
                readPosition += generatedDelayBufferSize;

            for (int ch = 0;
                 ch < generatedNumChannels;
                 ++ch)
            {
                auto* dry =
                    dryBuffer.getWritePointer(ch);

                auto* delay =
                    generatedDryDelayBuffer.getWritePointer(ch);

                const float input =
                    dry[sample];

                dry[sample] =
                    delay[readPosition];

                delay[
                    generatedDryDelayWritePosition]
                    = input;
            }

            ++generatedDryDelayWritePosition;

            if (generatedDryDelayWritePosition
                >= generatedDelayBufferSize)
            {
                generatedDryDelayWritePosition = 0;
            }
        }
    }

"

      ""))



(define-public (generate-myplugin-developer-latency-code)
  "
int MyPlugin::getDeveloperLatencySamples(
    int oversamplingFactor) const noexcept
{
    switch (oversamplingFactor)
    {
        case 2:
            return realPlugin2x->getLatencySamples();

        case 4:
            return realPlugin4x->getLatencySamples();

        case 8:
            return realPlugin8x->getLatencySamples();

        default:
            return realPlugin1x->getLatencySamples();
    }
}
")

(define-public (generate-myplugin-developer-latency-declaration-code)
  "
    int getDeveloperLatencySamples(
        int oversamplingFactor) const noexcept;
")


(define-public (generate-process-wet-latency-code)
  (let* ((fft
          (fft-model))
         (oversampling
          (oversampling-model))
         (dsp-bypass
          (find-component-by-role 'dsp-bypass))
         (os-ref
          (and oversampling
               (assoc-ref oversampling
                          'processor-reference))))

    (if (latency-infrastructure-required?)

        (string-append

         "
    // ==========================================================
    // GENERATED WET LATENCY COMPENSATION
    // ==========================================================

    generatedActualLatencySamples = 0;

    if (generatedMaximumLatencySamples > 0)
    {

"

         ;; ======================================================
         ;; FFT latency
         ;; ======================================================

         (if fft
             (let ((ref
                    (assoc-ref fft
                               'processor-reference)))
               (format #f
"
    switch (static_cast<int>(value_~a))
    {
        case 1:
            generatedActualLatencySamples += 256;
            break;

        case 2:
            generatedActualLatencySamples += 512;
            break;

        case 3:
            generatedActualLatencySamples += 1024;
            break;

        case 4:
            generatedActualLatencySamples += 2048;
            break;

        case 5:
            generatedActualLatencySamples += 4096;
            break;

        case 6:
            generatedActualLatencySamples += 8192;
            break;

        default:
            break;
    }

"
                       ref))
             "")

         ;; ======================================================
         ;; Oversampling latency
         ;; ======================================================

         (if oversampling
             (let ((ref
                    (assoc-ref oversampling
                               'processor-reference)))
               (format #f
"
    switch (static_cast<int>(value_~a))
    {
        case 1:
            generatedActualLatencySamples +=
                juce::roundToInt(
                    oversampling2x->getLatencyInSamples());
            break;

        case 2:
            generatedActualLatencySamples +=
                juce::roundToInt(
                    oversampling4x->getLatencyInSamples());
            break;

        case 3:
            generatedActualLatencySamples +=
                juce::roundToInt(
                    oversampling8x->getLatencyInSamples());
            break;

        default:
            break;
    }

"
                       ref))
             "")

         ;; ======================================================
         ;; Developer DSP latency
         ;;
         ;; RealPlugin::getLatencySamples() restituisce la latenza
         ;; del DSP developer espressa in campioni host.
         ;; ======================================================

         (if oversampling
             (format #f
"
    {
        int generatedOversamplingFactor = 1;

        switch (static_cast<int>(value_~a))
        {
            case 1:
                generatedOversamplingFactor = 2;
                break;

            case 2:
                generatedOversamplingFactor = 4;
                break;

            case 3:
                generatedOversamplingFactor = 8;
                break;

            default:
                break;
        }

        generatedActualLatencySamples +=
            myplugin->getDeveloperLatencySamples(
                generatedOversamplingFactor);
    }

"
                     os-ref)

             "
    generatedActualLatencySamples +=
        myplugin->getDeveloperLatencySamples(1);

")

         ;; ======================================================
         ;; DSP BYPASS
         ;;
         ;; Se tutta la catena DSP viene bypassata:
         ;;
         ;;     FFT + oversampling + developer DSP
         ;;
         ;; non vengono eseguiti e quindi la latenza naturale
         ;; della wet path diventa zero.
         ;; ======================================================

         (if dsp-bypass
             (let ((ref
                    (assoc-ref dsp-bypass
                               'processor-reference)))
               (format #f
"
    if (value_~a >= 0.5f)
    {
        generatedActualLatencySamples = 0;
    }

"
                       ref))
             "")

         ;; ======================================================
         ;; Compensazione fino alla latenza fissa
         ;; ======================================================

         "
    const int generatedWetDelaySamples =
        juce::jmax(
            0,
            generatedMaximumLatencySamples
            - generatedActualLatencySamples);


    if (generatedWetDelaySamples > 0)
    {
        const int generatedDelayBufferSize =
            generatedWetDelayBuffer.getNumSamples();

        const int generatedNumChannels =
            juce::jmin(
                buffer.getNumChannels(),
                generatedWetDelayBuffer.getNumChannels());

        for (int sample = 0;
             sample < buffer.getNumSamples();
             ++sample)
        {
            int readPosition =
                generatedWetDelayWritePosition
                - generatedWetDelaySamples;

            if (readPosition < 0)
                readPosition += generatedDelayBufferSize;

            for (int ch = 0;
                 ch < generatedNumChannels;
                 ++ch)
            {
                auto* wet =
                    buffer.getWritePointer(ch);

                auto* delay =
                    generatedWetDelayBuffer
                        .getWritePointer(ch);

                const float input =
                    wet[sample];

                wet[sample] =
                    delay[readPosition];

                delay[
                    generatedWetDelayWritePosition]
                    = input;
            }

            ++generatedWetDelayWritePosition;

            if (generatedWetDelayWritePosition
                >= generatedDelayBufferSize)
            {
                generatedWetDelayWritePosition = 0;
            }
        }
    }
    }

")

        "")))
