(define-module (generator-app dsp-generation)
  #:use-module (ice-9 format)
  #:use-module (generator-app registration)
  #:export (generate-process-code
            generate-process-wetdry-prefix
            generate-paint-over-children-code
	    generate-footer-timer-code
	    generate-timer-code
	    generate-dsp-runtime-members-code
	    ))

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

(define-public (generate-footer-timer-code)
  (let ((model (find-component-by-type 'link)))
    (if model
        (let ((var (assoc-ref model 'var)))
          (format #f
"if (~a.isMouseOver())
{
    auto mousePos = ~a.getMouseXYRelative();

    auto font  = ~a.getFont();
    auto textW = font.getStringWidth(~a.getText());
    auto textH = juce::roundToInt(font.getHeight());

    juce::Rectangle<int> activeArea(
        0,
        ~a.getHeight() - textH,
        textW,
        textH);

    if (activeArea.contains(mousePos))
    {
        ~a.setMouseCursor(juce::MouseCursor::PointingHandCursor);
        ~a.setColour(
            juce::Label::textColourId,
            kineticLNF.currentPalette.neonWhite);
    }
    else
    {
        ~a.setMouseCursor(juce::MouseCursor::NormalCursor);
        ~a.setColour(
            juce::Label::textColourId,
            kineticLNF.currentPalette.neonWhite.withAlpha(0.6f));
    }
}
"
                  var var var var var var var var var))
        "")))


(define-public (generate-timer-code)
  (string-append

   ;; INPUT METER
   (let ((model (role-model 'input-meter)))
     (if model
         (format #f
                 "~a.updateLevel(ap.~a.load());~%"
                 (assoc-ref model 'var)
                 (meter-peak-var model))
         ""))

   ;; OUTPUT METER
   (let ((model (role-model 'output-meter)))
     (if model
         (format #f
                 "~a.updateLevel(ap.~a.load());~%"
                 (assoc-ref model 'var)
                 (meter-peak-var model))
         ""))

   ;; SCOPE
   (let ((model (role-model 'scope)))
     (if model
         (format #f
"~a.fetchFromProcessor(
    ap.scopeFifo,
    ap.scopeWriteIdx.load(std::memory_order_relaxed));~%"
                 (assoc-ref model 'var))
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

   (if (role-model 'scope)
       (format #f
               "std::array<std::atomic<float>, 128> scopeFifo {};~%std::atomic<int> scopeWriteIdx { 0 };~%")
       "")))
