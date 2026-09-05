(use-modules (ice-9 string-fun)
             (ice-9 textual-ports)
             (ice-9 regex)
             (oop goops)
             (generator-app code-generator)
             (generator-app dsp-generation)
             (generator-app generation-state)
             (generator-app tools))

;; Run from the repository root:
;; GUILE_AUTO_COMPILE=0 guile --no-auto-compile -L . tests/host-transport-generation-test.scm
;; Source/generation checks for the snapshot boundary and its propagation.
;; No full JUCE build is required.

(define (check label predicate)
  (unless predicate
    (error "host transport generation test failed" label)))

(define (position text fragment)
  (or (string-contains text fragment)
      (error "missing source fragment" fragment)))

(define (occurrences text fragment)
  (let loop ((start 0) (count 0))
    (let ((next (string-contains text fragment start)))
      (if next
          (loop (+ next (string-length fragment)) (+ count 1))
          count))))

(define processor
  (call-with-input-file "YATemplate/Source/PluginProcessor.cpp" get-string-all))
(define header
  (call-with-input-file "YATemplate/Source/PluginProcessor.h" get-string-all))
(define myplugin-header
  (call-with-input-file "YATemplate/Source/MyPlugin.h" get-string-all))
(define myplugin-source
  (call-with-input-file "YATemplate/Source/MyPlugin.cpp" get-string-all))
(define plugin-dsp
  (call-with-input-file "YATemplate/Source/PluginDSP.h" get-string-all))

(for-each
 (lambda (code)
   (check 'myplugin-both-overloads-take-const-transport-reference
          (= 2 (occurrences code "const HostTransportInfo& transport"))))
 (list myplugin-header myplugin-source))
(check 'developer-contract-takes-separate-const-transport-reference
       (string-match
        "void processAudio\\([[:space:]]*juce::dsp::AudioBlock<float>& block,[[:space:]]*const AudioProcessContext& context,[[:space:]]*const HostTransportInfo& transport\\)"
        plugin-dsp))
(check 'audio-process-context-unchanged
       (string-match
        "struct AudioProcessContext[[:space:]]*\\{[[:space:]]*double sampleRate = 44100.0;[[:space:]]*int oversamplingFactor = 1;[[:space:]]*\\};"
        plugin-dsp))
(for-each
 (lambda (code)
   (check 'no-host-query-in-wrappers-or-developer-dsp
          (not (string-match "getPlayHead|getPosition|PositionInfo" code))))
 (list myplugin-header myplugin-source plugin-dsp))
(define process-block
  (substring processor
             (position processor "void JX11AudioProcessor::processBlock(")
             (position processor "void JX11AudioProcessor::update()")))
(define host-query
  (substring process-block
             (position process-block "if (auto *playHead = getPlayHead())")
             (position process-block "value_info_totalNumInputChannels =")))

(check 'host-transport-info-boundary
       (and (string-contains header "struct HostTransportInfo")
            (string-contains header "bool playHeadAvailable = false;")
            (string-contains header "bool positionAvailable = false;")
            (string-contains header "juce::Optional<double> bpm;")
            (string-contains header "static constexpr double fallbackBpm = 120.0;")
            (string-contains header "double bpmOrFallback() const noexcept")))

(define snapshot-start
  (position process-block "HostTransportInfo nextHostTransport;"))
(define snapshot-end
  (position process-block "hostTransportInfo = nextHostTransport;"))
(define snapshot-code (substring process-block snapshot-start snapshot-end))

(check 'one-host-extraction-site-per-process-block
       (and (= 1 (occurrences process-block "getPlayHead("))
            (= 1 (occurrences process-block "getPosition("))
            (= 1 (occurrences process-block "getBpm("))
            (= 1 (occurrences process-block "getIsPlaying("))))

(check 'fresh-snapshot-before-host-query
       (< snapshot-start (position process-block "if (auto *playHead = getPlayHead())")))
(check 'playhead-and-position-validity
       (and (string-contains snapshot-code "playHeadAvailable = true;")
            (string-contains snapshot-code "positionAvailable = true;")
            (string-contains header "bool isPlaying = false;")))
(check 'bpm-optional-read-without-playing-gate
       (and (string-contains snapshot-code
                             "nextHostTransport.bpm = posInfo->getBpm();")
            (string-contains header "return bpm.orFallback (fallbackBpm);")))
(check 'playing-read-independently-after-bpm
       (and (string-contains snapshot-code
                             "nextHostTransport.isPlaying = posInfo->getIsPlaying();")
            (< (position host-query "getBpm()")
               (position host-query "getIsPlaying()"))
            (= 2 (occurrences host-query "if ("))))

(check 'legacy-fields-are-snapshot-adapter
       (and (string-contains process-block
                             "value_info_BPM = hostTransportInfo.bpm;")
            (string-contains process-block
                             "value_info_isPlaying = hostTransportInfo.isPlaying;")
            (string-contains header
                             "a second source of transport state")))

(check 'transport-excludes-audio-engine-info
       (and (not (string-contains
                  (substring header (position header "struct HostTransportInfo")
                            (position header "class JX11AudioProcessor :"))
                  "sampleRate"))
            (not (string-contains
                  (substring header (position header "struct HostTransportInfo")
                            (position header "class JX11AudioProcessor :"))
                  "oversamplingFactor"))))

;; PROCESS is generated after the template's host query, also before any
;; generated hard-bypass return. Check both plain and FFT + oversampling paths.
(check 'host-query-before-generated-audio-pipeline
       (< (position process-block "getIsLooping()")
          (position process-block "/// PROCESS START")))
(check 'template-call-passes-authoritative-snapshot
       (string-contains process-block
                        "myplugin->processAudio(buffer, 1, hostTransportInfo);"))

(for-each
 (lambda (oversampled?)
   (reset-generation-state!)
   (reset-cpp-identifiers!)
   (make <normal-toggle-button> #:id 'bypass #:role 'bypass
         #:parameter-id "bypass" #:parameter-name "Bypass"
         #:processor-reference "bypass")
   (make <normal-toggle-button> #:id 'dsp-bypass #:role 'dsp-bypass
         #:parameter-id "dspBypass" #:parameter-name "DSP Bypass"
         #:processor-reference "dspBypass")
   (when oversampled?
     (make <rotary-slider> #:id 'oversampling #:role 'oversampling
           #:parameter-id "oversampling" #:parameter-name "Oversampling"
           #:processor-reference "oversampling" #:min 0 #:max 3 #:default 0)
     (make <rotary-slider> #:id 'fft-size #:role 'fft-size
           #:parameter-id "fftSize" #:parameter-name "FFT Size"
           #:processor-reference "fftSize" #:min 0 #:max 6 #:default 0))
   (let ((process (generate-process-code))
         (audio-buffer (generate-myplugin-process-audio-buffer-code))
         (audio-block (generate-myplugin-process-audio-block-code)))
     (for-each
      (lambda (code)
        (check (list 'no-host-query-in-audio-path oversampled?)
               (not (string-match
                     "getPlayHead|getPosition|posInfo|value_info_(BPM|isPlaying|time|ppq|loop|bar|frame|edit|host|isRecording|isLooping)"
                     code))))
      (list process audio-buffer audio-block))
     (check 'every-processor-call-passes-same-member
            (and (= (if oversampled? 5 1)
                    (occurrences process "myplugin->processAudio("))
                 (= (if oversampled? 5 1)
                    (occurrences process "hostTransportInfo);"))))
     (for-each
      (lambda (factor)
        (check (list 'processor-transport-at-factor factor)
               (string-match
                (format #f
                        "myplugin->processAudio\\([[:space:]]*~a,[[:space:]]*~a,[[:space:]]*hostTransportInfo\\);"
                        (if (= factor 1) "buffer" "oversampledBlock") factor)
                process)))
      (if oversampled? '(1 2 4 8) '(1)))
     (check 'buffer-overload-forwards-reference-to-1x
            (string-match
             "realPlugin1x->processAudio\\([[:space:]]*block,[[:space:]]*context,[[:space:]]*transport\\);"
             audio-buffer))
     (for-each
      (lambda (factor)
        (check (list 'block-overload-forwards-reference factor)
               (string-match
                (format #f
                        "~a:[[:space:]]*realPlugin~ax->processAudio\\([[:space:]]*buffer,[[:space:]]*context,[[:space:]]*transport\\);"
                        (if (= factor 1) "default" (format #f "case ~a" factor))
                        factor)
                audio-block)))
      '(1 2 4 8))
     (for-each
      (lambda (code)
        (check 'no-extra-snapshot-or-processor-read-in-myplugin-body
               (not (string-match "HostTransportInfo|hostTransportInfo|transport[[:space:]]*="
                                  code))))
      (list audio-buffer audio-block))
     (check 'hard-bypass-return-before-dsp-gate
            (and (< (position process "// HARD BYPASS")
                    (position process "return;"))
                 (< (position process "return;")
                    (position process "if (value_dspBypass < 0.5f)"))
                 (< (position process "if (value_dspBypass < 0.5f)")
                    (position process "myplugin->processAudio("))))
     (check (list 'effective-rate-remains-in-audio-context oversampled?)
            (and (string-contains audio-block "AudioProcessContext context;")
                 (string-match
                  "context.sampleRate =[[:space:]]*processor->value_info_sampleRate;"
                  audio-buffer)
                 (string-contains audio-buffer "context.oversamplingFactor = 1;")
                 (string-match
                  "context.sampleRate =[[:space:]]*processor->value_info_sampleRate[[:space:]]*\\* oversamplingFactor;"
                  audio-block)
                 (not (string-contains host-query "AudioProcessContext"))
                 (not (string-contains host-query "oversamplingFactor"))))
     (when oversampled?
       (let ((fft (generate-fft-infrastructure-code)))
         (check 'fft-context-and-callback-do-not-absorb-transport
                (and (string-contains fft "FFTProcessContext context;")
                     (not (string-match "HostTransportInfo|hostTransportInfo|transport" fft))
                     (string-match
                      "fftProcessor.processFFT\\([[:space:]]*channel.reim,[[:space:]]*context\\);"
                      fft))))
       (check 'fft-remains-buffer-only-inside-dsp-gate
              (and (= 1 (occurrences process "myplugin->processFFT(buffer);"))
                   (< (position process "if (value_dspBypass < 0.5f)")
                      (position process "myplugin->processFFT(buffer);"))))
       (check 'fft-before-rate-conversion
              (< (position process "myplugin->processFFT(buffer)")
                 (position process "processSamplesUp("))))))
 '(#f #t))

(display "host-transport-generation-test: PASS (source/generation only)\n")
