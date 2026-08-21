(use-modules
 ((algorithms) #:prefix algo:)
 ((f) #:prefix f:)
 ((f ports) #:prefix fp:)
 (pfds sets)
 (mtfa error-handler)
 (mtfa utils)
 (mtfa serializer)
 (mtfa unordered-set)
 (mtfa unordered-map)
 (mtfa star-map)
 (mtfa simple_db)
 (mtfa eis)
 (mtfa va)
 (mtfa extset)
 (mtfa umset)
 (mtfa web)
 (mtfa brg)
 (mtfa avl)
 
 (mtfa eqt)

 (gnutls)
 (scheme kwargs)
 (search basic)
 (math primes)
 (match-bind)
 (graph topological-sort)
 (rnrs bytevectors)
 (rnrs arithmetic bitwise)
 (rnrs enums)
 ((rnrs io ports) #:prefix ioports::)
 (srfi srfi-1)
 (srfi srfi-9)
 (srfi srfi-11)
 ((srfi srfi-18) #:prefix srfi-18::) ;;thread e mutex
 (srfi srfi-19)
 (srfi srfi-26)
 (srfi srfi-41) ;;streams
 (srfi srfi-42) ;;Eager Comprehensions
 (srfi srfi-43)
 (srfi srfi-45)
 (srfi srfi-60)
 (srfi srfi-111) ;;Boxes
 (srfi srfi-171)
 (web uri)
 
 (ice-9 format)
 (ice-9 ftw)
 (ice-9 rdelim)
 (ice-9 pretty-print)
 (ice-9 regex)
 (ice-9 iconv)
 (ice-9 string-fun)
 (ice-9 peg)
 (ice-9 peg string-peg)
 (ice-9 vlist)
 (ice-9 q)
 (ice-9 binary-ports)
 (ice-9 textual-ports)
 (ice-9 threads)
 (ice-9 hash-table)
 (ice-9 control)
 (ice-9 match)
 (ice-9 receive)
 (ice-9 eval-string)
 (ice-9 local-eval)
 (ice-9 textual-ports)
 (ice-9 arrays)
 (ice-9 popen)
 (ice-9 exceptions)
 (ice-9 optargs)
 (ice-9 string-fun)
 (oop goops)
 (oop goops describe)
 (json)
 (system syntax)
 (system foreign)
 (system foreign-library)
 (web server)
 (web request)
 (web response)
 (web uri)
 (web client)
 ;;
 ;;I miei moduli
 ;;
 ;; (runner)
 ;; (language)
 (generator-app globals)
 (generator-app tools)
 (generator-app genera-classi)
 (generator-app code-generator)
 (generator-app generation-state)
 )

;;
;;Per generare i codici C++
(define-public oversampling-filters '(filterHalfBandPolyphaseIIR filterHalfBandFIREquiripple))
(define-public generate-fft-code #f)  ;;Inizializza il simbolo globale per generare codice fft
(define* (GenerateC++ g::gen-var dst-folder new-name interface-definitions aggiornamento)
  ;;Inizializza i risultati
  (InitializeConstants)
    ;; Nuovo sistema identificatori DSL -> C++
  (reset-cpp-identifiers!)
  (reset-components!)

  ;; (set! *OVERSAMPLING-ENABLED* #f)
  ;; (set! *OVERSAMPLING-FILTER* 'filterHalfBandPolyphaseIIR)
  ;; (set! *OVERSAMPLING-isMaxQuality* #f)
  ;; (set! *OVERSAMPLING-useIntegerLatency* #t)
  (interface-definitions dst-folder new-name)

  ;; Materializza le RESOURCE dichiarate dalla DSL.
  (materialize-image-sets! dst-folder)
  (update-jucer-image-resources! (string-append dst-folder "/JX11.jucer"))
  ;;
  ;; ============================================================
  ;; NUOVO MODELLO COMPONENTI
  ;; ============================================================
  ;;
  (AppendStringTo *DECLARATIONS*
                  (generate-member-declarations))

  (AppendStringTo *DECLARATIONS*
                  (generate-attachment-declarations))

  (AppendStringTo *INTERFACE*
                  (generate-constructor-code))

  (AppendStringTo *INTERFACE*
                  (generate-attachment-code))

  (AppendStringTo *PARAMS*
                  (generate-parameter-code))

  (AppendStringTo *DPARAMS*
                  (generate-dparams-code))

  (AppendStringTo *GETPARAMS*
                  (generate-getparams-code))

  (AppendStringTo *VALUEPARAMS*
                  (generate-valueparams-code))

  (AppendStringTo *DESTROY*
                  (generate-destroy-code))

  (AppendStringTo *PROCESS*
                  (generate-process-code))
  
  (AppendStringTo *PAINT_OVER_CHILDREN*
                  (generate-paint-over-children-code))

  (AppendStringTo *IMAGE_RESOURCES*
                (generate-image-resource-cpp-code))

  (AppendStringTo *FOOTER_TIMER*
                  "\n"
                  (generate-footer-timer-code))

  (AppendStringTo *TIMER*
                  "\n"
                  (generate-timer-code))

  (AppendStringTo  *DSP_RUNTIME_MEMBERS*
		   "\n"
		   (generate-dsp-runtime-members-code))
  
  (AppendStringTo *OVERSAMPLING_PPC* (generate-oversampling-prepare-code))
  (AppendStringTo *OVERSAMPLING_PPCRR* (generate-oversampling-release-code))
  (AppendStringTo *FFT_INFRASTRUCTURE* "\n" (generate-fft-infrastructure-code))
  (AppendStringTo *FFT_MYPLUGIN_MEMBERS* "\n" (generate-myplugin-fft-members-code))
  (AppendStringTo *MYPLUGIN_FFT_INIT* "\n"
                (generate-myplugin-audio-init-code)
                "\n"
                (generate-myplugin-fft-init-code))
  (AppendStringTo
 *MYPLUGIN_PREPARE*
 "\n"
 (generate-myplugin-prepare-code))
  (AppendStringTo *MYPLUGIN_RENDER_BUFFER* "\n" (generate-myplugin-render-buffer-code))
  (AppendStringTo *MYPLUGIN_RENDER_BLOCK* "\n" (generate-myplugin-render-block-code))

  ;;
  ;;Genera i codici c++ per PluginEditor.cpp
  (let ((PluginEditor.cpp (string-append dst-folder "/Source/" "PluginEditor.cpp"))
	(PluginEditor.h (string-append dst-folder "/Source/" "PluginEditor.h"))
	(PluginProcessor.cpp (string-append dst-folder "/Source/" "PluginProcessor.cpp"))
	(PluginProcessor.h (string-append dst-folder "/Source/" "PluginProcessor.h"))
	(Utils.cpp (string-append dst-folder "/Source/" "Utils.cpp"))
	(Utils.h (string-append dst-folder "/Source/" "Utils.h"))
	(Synth.h (string-append dst-folder "/Source/" "Synth.h"))
	(MyPlugin.h (string-append dst-folder "/Source/" "MyPlugin.h"))
	(MyPlugin.cpp (string-append dst-folder "/Source/" "MyPlugin.cpp"))
	)
    ;;
    ;; (set! *OVERSAMPLING_PPC* (if *OVERSAMPLING-ENABLED*
    ;; 				 (begin
    ;; 				   (f-str "
    ;; oversampling = std::make_unique<juce::dsp::Oversampling<float>>(
    ;;     getTotalNumInputChannels(),
    ;;     oversampling_factor,
    ;;     juce::dsp::Oversampling<float>::FilterType::${(symbol->string *OVERSAMPLING-FILTER*)}
    ;;     ${(if *OVERSAMPLING-isMaxQuality* \"true\" \"false\")}
    ;;     ${(if *OVERSAMPLING-useIntegerLatency* \"true\" \"false\")});
    ;; oversampling->reset();
    ;; oversampling->initProcessing(static_cast<size_t>(samplesPerBlock));\n\n"))
    ;; 				 (begin
    ;; 				   "\n\n")))
    ;;
    ;; (set! *OVERSAMPLING_PPCRR* (if *OVERSAMPLING-ENABLED*
    ;; 				   (begin
    ;; 				     (f-str "
    ;;     oversampling.reset();
    ;; "))
    ;; 				   (begin
    ;; 				     "\n\n")))
    ;;
    ;; (set! *OVERSAMPLING_PPCPB* (if *OVERSAMPLING-ENABLED*
    ;; 				   (begin
    ;; 				     (f-str "
    ;;     juce::dsp::AudioBlock<float> block(buffer);
    ;;     auto oversampledBlock = oversampling->processSamplesUp(block);

    ;;     // Apply nonlinear distortion to each sample
    ;;     myplugin->render(oversampledBlock);

    ;;     oversampling->processSamplesDown(block);
    ;; ")) (begin
    ;; 				     "\n	myplugin->render(buffer);\n\n")))
    ;;
    ;; (set! *OVERSAMPLING_PPH* (if *OVERSAMPLING-ENABLED*
    ;; 				 (begin
    ;; 				   (f-str "
    ;; 	std::unique_ptr<juce::dsp::Oversampling<float>> oversampling;
    ;; 	size_t oversampling_factor=${*OVERSAMPLING-ENABLED*};
    ;; " ))
    ;; 				 (begin
    ;; 				   "\n\n")))
    ;;
    ;;Il codice per la FFT o per NON FFT, ma solo se sto generando la prima volta. Se
    ;;già esiste, non fare nulla!
    ;; (if generate-fft-code ;;Lo posso lasciare com'è poiché #f
    ;; 	(set! *SYNTH_H_RP* CODICE-PER-FFT)
    ;; 	(set! *SYNTH_H_RP* CODICE-NON-PER-FFT))
    ;; (set! *SYNTH_H_RP* "")
    ;;

    ;; (letrec-syntax ((show
    ;; 		     (syntax-rules ()
    ;; 		       ((show)
    ;; 			(Show!))
    ;; 		       ((show k1 k2 ...)
    ;; 			(begin
    ;; 			  (Show! (symbol->string 'k1) k1)
    ;; 			  (show k2 ...))))))
    ;;   (show *INTERFACE* *RESIZED* *BACKGROUND* ;; *FOOTER*
    ;; 	    *DESTROY* *DECLARATIONS* *PARAMS* *DPARAMS* *GETPARAMS* *VALUEPARAMS* *SCREENSIZE* *OVERSAMPLING_PPC* *OVERSAMPLING_PPCPB* *OVERSAMPLING_PPCRR* *OVERSAMPLING_PPH* *WETDRY_PPC_PREFIX* *WETDRY_PPC_POSTFIX* *SYNTH_H_RP* *GRID*)
    ;;   )
    ;;
    (replace-between-flags PluginEditor.cpp *INTERFACE::START* *INTERFACE::END* *INTERFACE*)
    (replace-between-flags PluginEditor.cpp *RESIZED::START* *RESIZED::END* *RESIZED*)
    (replace-between-flags PluginEditor.cpp *BACKGROUND::START* *BACKGROUND::END* *BACKGROUND*)
    (replace-between-flags PluginEditor.cpp *DESTROY::START* *DESTROY::END* *DESTROY*)
    (replace-between-flags PluginEditor.cpp *PAINT_OVER_CHILDREN::START* *PAINT_OVER_CHILDREN::END* *PAINT_OVER_CHILDREN*)
    (replace-between-flags PluginEditor.cpp *IMAGE_RESOURCES::START* *IMAGE_RESOURCES::END* *IMAGE_RESOURCES*)
    (replace-between-flags PluginEditor.h *DECLARATIONS::START* *DECLARATIONS::END* *DECLARATIONS*)
    (replace-between-flags PluginEditor.h *FOOTER_MOUSE::START* *FOOTER_MOUSE::END* *FOOTER_MOUSE*)
    (replace-between-flags PluginEditor.h *FOOTER_TIMER::START* *FOOTER_TIMER::END* *FOOTER_TIMER*)
    (replace-between-flags PluginEditor.h *TIMER::START* *TIMER::END* *TIMER*)

    (replace-between-flags PluginProcessor.cpp *PARAMS::START* *PARAMS::END* *PARAMS*)
    (replace-between-flags PluginProcessor.cpp *PROCESS::START* *PROCESS::END* *PROCESS*)
    (replace-between-flags PluginProcessor.h *DPARAMS::START* *DPARAMS::END* *DPARAMS*)
    (replace-between-flags PluginProcessor.cpp *GETPARAMS::START* *GETPARAMS::END* *GETPARAMS*)
    (replace-between-flags PluginProcessor.cpp *VALUEPARAMS::START* *VALUEPARAMS::END* *VALUEPARAMS*)
    (replace-between-flags Utils.cpp *SCREENSIZE::START* *SCREENSIZE::END* (generate-screen-size-code))
    ;;
    ;;La gestione dell'oversampling
    (replace-between-flags PluginProcessor.cpp *OVERSAMPLING_PPC::START* *OVERSAMPLING_PPC::END* *OVERSAMPLING_PPC*)
    (replace-between-flags PluginProcessor.cpp *OVERSAMPLING_PPCPB::START* *OVERSAMPLING_PPCPB::END* *OVERSAMPLING_PPCPB*)
    (replace-between-flags PluginProcessor.cpp *OVERSAMPLING_PPCRR::START* *OVERSAMPLING_PPCRR::END* *OVERSAMPLING_PPCRR*)
    (replace-between-flags PluginProcessor.h   *OVERSAMPLING_PPH::START* *OVERSAMPLING_PPH::END* *OVERSAMPLING_PPH*)
    (replace-between-flags PluginProcessor.h   *DSP_RUNTIME_MEMBERS::START* *DSP_RUNTIME_MEMBERS::END* *DSP_RUNTIME_MEMBERS*)
    ;;e;
    ;;La gestione del WET/DRY effettuata in automatico se uno slider è settato wet/DRY!
    (replace-between-flags PluginProcessor.cpp *WETDRY_PPC_PREFIX::START* *WETDRY_PPC_PREFIX::END* *WETDRY_PPC_PREFIX*)
    (replace-between-flags PluginProcessor.cpp *WETDRY_PPC_POSTFIX::START* *WETDRY_PPC_POSTFIX::END* *WETDRY_PPC_POSTFIX*)
    (replace-between-flags MyPlugin.cpp *MYPLUGIN_FFT_INIT::START* *MYPLUGIN_FFT_INIT::END* *MYPLUGIN_FFT_INIT*)
    (replace-between-flags MyPlugin.cpp *MYPLUGIN_RENDER_BUFFER::START* *MYPLUGIN_RENDER_BUFFER::END* *MYPLUGIN_RENDER_BUFFER*)
    (replace-between-flags MyPlugin.cpp *MYPLUGIN_RENDER_BLOCK::START* *MYPLUGIN_RENDER_BLOCK::END* *MYPLUGIN_RENDER_BLOCK*)
    (replace-between-flags
 MyPlugin.cpp
 *MYPLUGIN_PREPARE::START*
 *MYPLUGIN_PREPARE::END*
 *MYPLUGIN_PREPARE*)
    ;;
    ;;FFT
    (replace-between-flags Synth.h *FFT_INFRASTRUCTURE::START* *FFT_INFRASTRUCTURE::END* *FFT_INFRASTRUCTURE*)
    (replace-between-flags MyPlugin.h *FFT_MYPLUGIN_MEMBERS::START* *FFT_MYPLUGIN_MEMBERS::END* *FFT_MYPLUGIN_MEMBERS*)
    
    ;;
    (when (not (generation-grid))
      (Show! "<grid> has to be defined!!")
      (exit EXIT_FAILURE))
    (replace-between-flags PluginEditor.cpp *GRID::START* *GRID::END* (generate-grid-code))
    ;;
    ;;La gestione del fft o no fft (real plugin!)
    ;; (replace-between-flags Synth.h *SYNTH_H_RP::START* *SYNTH_H_RP::END* *SYNTH_H_RP*)
    )
  (ResaveProjucerProject dst-folder))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Costruzione dell'interfaccia ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#|
1) PluginEditor.cpp			; ;
- da ///INTERFACE START fino a ///INTERFACE END ; ;
inserire tutte le chiamate ai costruttori degli slider, bottoni, ecc ; ;
2) PluginEditor.h			; ;
- da ///INTERFACE START fino a ///INTERFACE END ; ;
inserire le dichiarazioni delle variabili utilizzate dai costruttori ; ;
|#

(define (lowercase-initial s)
  (if (zero? (string-length s))
      s
      (string-append
       (string (char-downcase (string-ref s 0)))
       (substring s 1))))
;;s è un nome del tipo ui::object::types::HorizontalLogSlider
(define-syntax-rule (gen-var-name s v)
  (begin
    (set! v (+ 1 v))
    (string-append (lowercase-initial (last (mtfa-string-split-regex s "::"))) "_" (format #f "~4,'0d" v))))

(define-public (GetNextVariableName)
  (let ((vertical-log-slider 0)
	(vertical-lin-slider 0)
	(horizontal-log-slider 0)
	(horizontal-lin-slider 0)
	(vertical-stepped-slider 0)
	(rotary-slider 0)
	(combo-box 0)
	(material-button 0)
	(material-toggle 0)
	(titles 0)
	(any-var 0))
    (lambda (type)
      (match type
	("VerticalLogSlider" (gen-var-name type vertical-log-slider))
	("HorizontalLogSlider" (gen-var-name type horizontal-log-slider))
	("VerticalLinearSlider" (gen-var-name type vertical-lin-slider))
	("HorizontalLinearSlider" (gen-var-name type horizontal-lin-slider))
	("VerticalSteppedSlider" (gen-var-name type vertical-stepped-slider))
	("RotarySlider" (gen-var-name type rotary-slider))
	("ComboBox" (gen-var-name type combo-box))
	("MaterialButton" (gen-var-name type material-button))
	("MaterialToggle" (gen-var-name type material-toggle))
	("Title" (gen-var-name type titles))
	("Var" (gen-var-name type any-var))
	(_ (Show! "!!!!!!!!!!!!!!!!!!!!!! type not found!!!!!!!!!!!!!!!!!!") #f)))))
;;
;;
(define* (MakeLogSliderParam var id name title #:key (vmin 0.001) (vmax 4.0) (initialpos 0.0) (skew-factor 0.63) (units "dB"))
  ;;Il parametro è var prefisso da p
  (let ((managed-value (if (string-ci= (string-trim-both units) "db") (f-str "return juce::String(juce::Decibels::gainToDecibels(value), 2) + \" \" + \"${units}\"") (f-str "return juce::String(value, 2) + \" \" + \"${units}\"")))
	(managed-string-value (if (string-ci= (string-trim-both units) "db") "return juce::Decibels::decibelsToGain(text.getFloatValue())" "return text.getFloatValue()")))
    (f-str "auto p${var} = new juce::AudioParameterFloat(
        \"${id}\", \"${name}\",
        juce::NormalisableRange<float>(
            ${(exact->inexact vmin)}f,
            ${(exact->inexact vmax)}f,
            [](float start, float end, float normalised) -> float
            {
                juce::ignoreUnused(start, end);
                return juce::Decibels::decibelsToGain(
                    juce::jmap(std::pow(normalised, 0.5f), ${(to-decibel vmin)}f, ${(to-decibel vmax)}f)
                );
            },
            [](float start, float end, float value) -> float
            {
                juce::ignoreUnused(start, end);
                return std::pow(
                    juce::jmap(juce::Decibels::gainToDecibels(value), ${(to-decibel vmin)}f, ${(to-decibel vmax)}f, 0.0f, 1.0f), 2.0f
                );
            }
        ),
        juce::Decibels::decibelsToGain(0.0f), // Default value at 0 dB (1.0 gain)
        juce::AudioParameterFloatAttributes()
            .withStringFromValueFunction([](float value, int)
                                         {
                                             ${managed-value};
                                         })
            .withValueFromStringFunction([](const juce::String &text)
                                         {
                                             ${managed-string-value};
                                         }));
    
    params.push_back(std::unique_ptr<juce::RangedAudioParameter>(p${var}));\n\n"
	 )))
;;
(define (MakeLinearSliderParam var title name id vmin vmax vmiddle step-size)
  (if (< step-size 0.0)
      (format #f "auto p~a = new juce::AudioParameterFloat(\"~a\", \"~a\", ~a, ~a, ~a);
    params.push_back(std::unique_ptr<juce::RangedAudioParameter>(p~a));\n\n"
	      var id name vmin vmax vmiddle var)
      (format #f "auto p~a = new juce::AudioParameterFloat(\"~a\", \"~a\", 
	juce::NormalisableRange<float>(~a, ~a, ~a), ~a);
    params.push_back(std::unique_ptr<juce::RangedAudioParameter>(p~a));\n\n"
	      var id name vmin vmax step-size vmiddle var)))
;;
(define (MakeComboBoxParam var title name id vmin vmax vmiddle values)
  (format #f "auto p~a = new juce::AudioParameterChoice(\"~a\", \"~a\", juce::StringArray~a, ~a);
    params.push_back(std::unique_ptr<juce::RangedAudioParameter>(p~a));\n\n"
	  var id name (convert-to-cstringarray values) vmiddle var))
;;
(define (convert-to-cstringarray l)
  ;;converte presupponendo si tratti sempre un un array di stringhe
  (if (zero? (length l))
      ""
      (let ((s (scm->json-string (list->vector l))))
	(string-replace-substring (string-replace-substring s "[" "{") "]" "}"))))
;;
(define (MakeMenuChoiceParam var title id name values initial-position)
  (format #f "auto p~a = new juce::AudioParameterChoice(\"~a\", \"~a\",
                                                        juce::StringArray~a, ~a);
  params.push_back(std::unique_ptr<juce::RangedAudioParameter>(p~a));\n\n"
	  var id name (convert-to-cstringarray values) initial-position var))
;;
(define (MakeButtonToggleParam var id name initial-value)
  (format #f "auto p~a = new juce::AudioParameterBool(\"~a\", \"~a\", ~a);
    params.push_back(std::unique_ptr<juce::RangedAudioParameter>(p~a));\n\n"
	  var id name initial-value var))
;;
;;
(define*-public (GenerateVerticalLogSlider paramReference title tx ty width height name id tooltip #:key (vmin 0.001) (vmax 4) (initialpos 1.0) (skew-factor 0.63) (units "dB"))
  (let ((var (g::gen-var "VerticalLogSlider")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (f-str "${var}=std::make_unique<AFLinearSlider>(
        T_VarParams{
            {\"imgPrefix\", Utils::toVar(\"slider_04\")},
            {\"isLogarithmic\", Utils::toVar(true)},
            //{\"vmin\", Utils::toVar(${vmin})},
            //{\"vmax\", Utils::toVar(${vmax})},
            //{\"initialPosition\", Utils::toVar(${initialpos})},
            //{\"skewFactor\", Utils::toVar(${skew-factor})},
            //{\"units\", Utils::toVar(\"${units}\")},
            {\"sliderStyle\", Utils::toVar(juce::Slider::LinearVertical)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::TextBoxBelow)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"${title}\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(${tx})},
            {\"ty\", Utils::toVar(${ty})},
            {\"width\", Utils::toVar(${width})}, 
            {\"height\", Utils::toVar(${height})},
            {\"knobRadius\", Utils::toVar(11)},
            {\"knobColour\", Utils::toVar(juce::Colours::orange)},
            {\"trackGradientStart\", Utils::toVar(juce::Colours::whitesmoke)},
            {\"trackGradientEnd\", Utils::toVar(juce::Colours::rebeccapurple)},
            
            {\"name\", Utils::toVar(\"${name}\")},
            {\"ID\", Utils::toVar(\"${id}\")},
        });
    	${var}->setTooltip(\"${tooltip}\");\n
    	addAndMakeVisible(${var}.get());
	${var}Attachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"${id}\", ${var}.get()->theSlider);\n\n")) ;;var title tx ty width height name id var tooltip var var id var
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "
	std::unique_ptr<AFLinearSlider> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeLogSliderParam var id name title #:vmin vmin #:vmax vmax #:units units #:initialpos initialpos #:skew-factor skew-factor))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ))
(define*-public (GenerateVerticalLogSlider-old paramReference title tx ty width height name id tooltip #:key (vmin 0.001) (vmax 4) (initialpos 1.0) (skew-factor 0.63) (units "dB"))
  (let ((var (g::gen-var "VerticalLogSlider")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (f-str "${var}=std::make_unique<AFLinearSlider>(
        T_VarParams{
            {\"imgPrefix\", Utils::toVar(\"slider_04\")},
            {\"isLogarithmic\", Utils::toVar(true)},
            //{\"vmin\", Utils::toVar(${vmin})},
            //{\"vmax\", Utils::toVar(${vmax})},
            //{\"initialPosition\", Utils::toVar(${initialpos})},
            //{\"skewFactor\", Utils::toVar(${skew-factor})},
            //{\"units\", Utils::toVar(\"${units}\")},
            {\"sliderStyle\", Utils::toVar(juce::Slider::LinearVertical)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::TextBoxBelow)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"${title}\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(${tx})},
            {\"ty\", Utils::toVar(${ty})},
            {\"width\", Utils::toVar(${width})}, 
            {\"height\", Utils::toVar(${height})},
            {\"knobRadius\", Utils::toVar(11)},
            {\"knobColour\", Utils::toVar(juce::Colours::orange)},
            {\"trackGradientStart\", Utils::toVar(juce::Colours::whitesmoke)},
            {\"trackGradientEnd\", Utils::toVar(juce::Colours::rebeccapurple)},
            
            {\"name\", Utils::toVar(\"${name}\")},
            {\"ID\", Utils::toVar(\"${id}\")},
        });
    	${var}->setTooltip(\"${tooltip}\");\n
    	addAndMakeVisible(${var}.get());
	${var}Attachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"${id}\", ${var}.get()->theSlider);\n\n")) ;;var title tx ty width height name id var tooltip var var id var
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "
	std::unique_ptr<AFLinearSlider> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeLogSliderParam var id name title #:vmin vmin #:vmax vmax #:units units #:initialpos initialpos #:skew-factor skew-factor))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ))
;;
(define*-public (GenerateHorizontalLogSlider paramReference title tx ty width height name id tooltip #:key (vmin 0.001) (vmax 4) (initialpos 1.0) (skew-factor 0.63) (units "dB"))
  (let ((var (g::gen-var "HorizontalLogSlider")))
    (AppendStringTo *INTERFACE* "\n\n\n" (format #f "~a=std::make_unique<AFLinearSlider>(
        T_VarParams{
            {\"imgPrefix\", Utils::toVar(\"slider_04\")},
            {\"isLogarithmic\", Utils::toVar(true)},
            //{\"vmin\", Utils::toVar(-60)},
            //{\"vmax\", Utils::toVar(12)},
            //{\"initialPosition\", Utils::toVar(0)},
            //{\"units\", Utils::toVar(\"${units}\")},
            //{\"skewFactor\", Utils::toVar(-4)},
            {\"sliderStyle\", Utils::toVar(juce::Slider::LinearHorizontal)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::TextBoxBelow)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(~a)}, 
            {\"height\", Utils::toVar(~a)},
            {\"knobRadius\", Utils::toVar(11)},
            {\"knobColour\", Utils::toVar(juce::Colours::aqua)},
            {\"trackGradientStart\", Utils::toVar(juce::Colours::whitesmoke)},
            {\"trackGradientEnd\", Utils::toVar(juce::Colours::rebeccapurple)},
            
            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(~a.get());
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"~a\", ~a.get()->theSlider);\n\n" var title tx ty width height name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "	std::unique_ptr<AFLinearSlider> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeLogSliderParam var id name title #:vmin vmin #:vmax vmax #:units units #:initialpos initialpos #:skew-factor skew-factor))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))
;;
(define*-public (GenerateVerticalLinearSlider paramReference title tx ty width height name id vmin vmax vmiddle tooltip #:key (step-size -1))
  (let ((var (g::gen-var "VerticalLinearSlider")))
    (AppendStringTo *INTERFACE* "\n\n\n" (format #f "~a=std::make_unique<AFLinearSlider>(
        T_VarParams{
            {\"imgPrefix\", Utils::toVar(\"slider_04\")},
            {\"isLogarithmic\", Utils::toVar(false)},
            {\"vmin\", Utils::toVar(~a)},
            {\"vmax\", Utils::toVar(~a)},
            {\"initialPosition\", Utils::toVar(~a)},
            {\"sliderStyle\", Utils::toVar(juce::Slider::LinearVertical)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::TextBoxBelow)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(~a)}, 
            {\"height\", Utils::toVar(~a)},
            {\"knobRadius\", Utils::toVar(11)},
            {\"knobColour\", Utils::toVar(juce::Colours::crimson)},
            {\"trackGradientStart\", Utils::toVar(juce::Colours::whitesmoke)},
            {\"trackGradientEnd\", Utils::toVar(juce::Colours::rebeccapurple)},
            {\"stepSize\", Utils::toVar(~a)},
            
            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
	~a->setTooltip(\"~a\");\n
	addAndMakeVisible(~a.get());
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"~a\", ~a.get()->theSlider);\n\n\n"
						 var vmin vmax vmiddle title tx ty width height step-size name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f
					       "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<AFLinearSlider> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeLinearSliderParam var title name id vmin vmax vmiddle step-size))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ))
;;
(define*-public (GenerateHorizontalLinearSlider paramReference title tx ty width height name id vmin vmax vmiddle tooltip #:key (step-size -1))
  (let ((var (g::gen-var "HorizontalLinearSlider")))
    (AppendStringTo *INTERFACE* "\n\n\n"  (format #f "~a=std::make_unique<AFLinearSlider>(
        T_VarParams{
            {\"imgPrefix\", Utils::toVar(\"slider_04\")},
            {\"isLogarithmic\", Utils::toVar(false)},
            {\"vmin\", Utils::toVar(~a)},
            {\"vmax\", Utils::toVar(~a)},
            {\"initialPosition\", Utils::toVar(~a)},
            {\"sliderStyle\", Utils::toVar(juce::Slider::LinearHorizontal)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::TextBoxBelow)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(~a)}, 
            {\"height\", Utils::toVar(~a)},
            {\"knobRadius\", Utils::toVar(11)},
            {\"knobColour\", Utils::toVar(juce::Colours::yellowgreen)},
            {\"trackGradientStart\", Utils::toVar(juce::Colours::whitesmoke)},
            {\"trackGradientEnd\", Utils::toVar(juce::Colours::rebeccapurple)},
            {\"stepSize\", Utils::toVar(~a)},

            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(~a.get());
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"~a\", ~a.get()->theSlider);\n\n\n"
						  var vmin vmax vmiddle title tx ty width height step-size name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<AFLinearSlider> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeLinearSliderParam var title name id vmin vmax vmiddle step-size))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))
;;
(define-public (GenerateVerticalSteppedSlider paramReference values initial-position title tx ty width height name id tooltip)
  (let ((var (g::gen-var "VerticalSteppedSlider")))
    (AppendStringTo *INTERFACE* "\n\n\n" (format #f "~a = std::make_unique<AFSliderStepped>(
        T_VarParams{
            {\"values\", Utils::toVar(juce::Array<juce::var>(~a))},
            {\"initialPosition\", Utils::toVar(~a)},
            {\"sliderStyle\", Utils::toVar(juce::Slider::LinearVertical)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::TextBoxBelow)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::centredBottom)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(~a)},
            {\"height\", Utils::toVar(~a)},
            {\"knobRadius\", Utils::toVar(11)},
            {\"knobColour\", Utils::toVar(juce::Colours::yellowgreen)},
            {\"trackGradientStart\", Utils::toVar(juce::Colours::whitesmoke)},
            {\"trackGradientEnd\", Utils::toVar(juce::Colours::rebeccapurple)},
            
            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(~a.get());
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"~a\", ~a.get()->theSlider);\n\n\n" var (convert-to-cstringarray values) initial-position title tx ty width height name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<AFSliderStepped> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeMenuChoiceParam var title id name values initial-position))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))
;;
(define*-public (GenerateWetDryRotarySlider paramReference title tx ty width height)
  (let ((name title)
	(id (string-append paramReference "ID"))
	(tooltip (string-append "This is a " title)))
    (unless generate-fft-code (set! *WETDRY_PPC_POSTFIX* "\n
    for (int ch=0; ch<value_info_totalNumOutputChannels; ch++) {
        auto wet  = buffer.getWritePointer(ch);
        auto dry  = dryBuffer.getReadPointer(ch);
        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            wet[i] = dry[i] * (1.0f - value_wetdry) + wet[i] * value_wetdry;
        }
    }\n
")
	    (set! *WETDRY_PPC_PREFIX* "\n
    //Salva una dry copia
    juce::AudioBuffer<float> dryBuffer;
    dryBuffer.makeCopyOf(buffer);\n
"))
    (GenerateRotarySlider paramReference '() title tx ty width height name id 0.0 1.0 0.5 tooltip #:step-size .01)))
;;
(define*-public (GenerateOversamplingRotarySlider tx ty width height
						      #:key (oversampling 1) (ovsfilter 'filterHalfBandPolyphaseIIR)
						      (isMaxQuality #f) (useIntegerLatency #t))
  ;; Ricorda che i due ultimi parametri di oversampling sono:
  ;; isMaxQuality: Se true, utilizza filtri con una transizione più netta e una reiezione della banda oscura (stopband) più aggressiva, a scapito di un maggior uso della CPU.
  ;; useIntegerLatency: Se true, la classe aggiunge un micro-ritardo frazionario per garantire che la latenza totale riportata alla DAW sia un numero intero di campioni (fondamentale per evitare problemi di sfasamento in alcuni host).

  ;;Inizializzazione dei valori di oversampling-filters
  (set! *OVERSAMPLING-ENABLED* oversampling)
  (set! *OVERSAMPLING-FILTER* ovsfilter)
  (set! *OVERSAMPLING-isMaxQuality* isMaxQuality)
  (set! *OVERSAMPLING-useIntegerLatency* useIntegerLatency)

  (let* ((paramReference "oversampling")
	 (title "OverSampling")
	 (name title)
	 (id (string-append paramReference "ID"))
	 (tooltip (string-append "This is a " title)))
    (set! *WETDRY_PPC_POSTFIX* "\n
    for (int ch=0; ch<value_info_totalNumOutputChannels; ch++) {
        auto wet  = buffer.getWritePointer(ch);
        auto dry  = dryBuffer.getReadPointer(ch);
        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            wet[i] = dry[i] * (1.0f - value_wetdry/100.0) + wet[i] * value_wetdry/100.0;
        }
    }\n
	")
    (set! *WETDRY_PPC_PREFIX* "\n
    //Salva una dry copia
    juce::AudioBuffer<float> dryBuffer;
    dryBuffer.makeCopyOf(buffer);\n
	")
    (GenerateRotarySlider paramReference '() title tx ty width height name id 0 8 1 tooltip #:step-size 1 #:isOversampling #t)))
;;
(define*-public (GenerateRotarySlider paramReference values title tx ty width height name id vmin vmax vmiddle tooltip #:key (labels '()) (step-size -1) (isOversampling #f))
  ;;(Show! (convert-to-cstringarray values) " ==> " (convert-to-cstringarray labels))
  (let ((var (g::gen-var "RotarySlider")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (format #f "~a = std::make_unique<AFRotarySlider>(
        T_VarParams{
            {\"vmin\", Utils::toVar(~a)},
            {\"vmax\", Utils::toVar(~a)},
            {\"initialPosition\", Utils::toVar(~a)},
            {\"sliderStyle\", Utils::toVar(juce::Slider::RotaryHorizontalVerticalDrag)},
            {\"textBoxStyle\", Utils::toVar(juce::Slider::~a)},
            {\"textBoxReadonly\", Utils::toVar(false)},
            {\"textEntryBoxWidth\", Utils::toVar(50)},
            {\"textEntryBoxHeight\", Utils::toVar(18)},
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleJustification\", Utils::toVar(juce::Justification::centredBottom)},
            {\"titleHeight\", Utils::toVar(30)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(~a)},
            {\"height\", Utils::toVar(~a)},
            {\"outerRingThickness\", Utils::toVar(0.10f)},
            {\"outerRingColor\", Utils::toVar(juce::Colour(0xff32353b))},
            {\"startAngle\", Utils::toVar(juce::MathConstants<float>::pi*1.25)},
            {\"endAngle\", Utils::toVar(juce::MathConstants<float>::pi*2.75)},
            {\"stopAtEnd\", Utils::toVar(true)},
            {\"outerArcGradientStartColor\", Utils::toVar(juce::Colour(0xff3de2ff))},
            {\"outerArcGradientEndColor\", Utils::toVar(juce::Colour(0xff3576a0))},
            {\"knobRadiusPerc\", Utils::toVar(0.8f)},  //leave a small hole between external circle and knob
            {\"knobGradientStartColor\", Utils::toVar(juce::Colour(0xffBBBBBB))},
            {\"knobGradientEndColor\", Utils::toVar(juce::Colour(0xff8aa6c1))},
            {\"pointerLengthPerc\", Utils::toVar(0.8f)}, //length of the pointer
            {\"pointerWidthPerc\", Utils::toVar(0.1f)}, //width of the pointer
            {\"pointerColor\", Utils::toVar(juce::Colour(0xffAA1111))},
            {\"pointerShadowColor\", Utils::toVar(juce::Colour(0xff776677))},
            {\"pointerShadowOffsetX\", Utils::toVar(1.04f)}, //percentile to increase the pointerx
            {\"pointerShadowOffsetY\", Utils::toVar(1.04f)},

            {\"values\", Utils::toVar(juce::Array<juce::var>(~a))},
            {\"labels\", Utils::toVar(juce::Array<juce::var>(~a))},
            {\"stepSize\", Utils::toVar(~a)},
            
            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(~a.get());
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        ap.parameters, \"~a\", ~a.get()->theSlider);\n\n\n" var vmin vmax vmiddle (if (zero? (length labels)) "TextBoxBelow" "NoTextBox")  title tx ty width height (convert-to-cstringarray values)
	(convert-to-cstringarray labels) step-size name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n" var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<AFRotarySlider> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> ~aAttachment;\n\n" var var))
    ;;
    (cond 
     ((> (length labels) 0) (AppendStringTo *PARAMS* "\n\n\n" (MakeComboBoxParam var title name id 0 (1- (length labels)) vmiddle labels))
      ;; (Show! "Ora in params: " *PARAMS*)
      )
     ((> (length values) 0) (AppendStringTo *PARAMS* "\n\n\n" (MakeComboBoxParam var title name id 0 (1- (length values)) vmiddle values)))
     (#t                    (AppendStringTo *PARAMS* "\n\n\n" (MakeLinearSliderParam var title name id vmin vmax vmiddle step-size))))
    
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (when isOversampling
      (AppendStringTo *VALUEPARAMS* "\n" "
    if (static_cast<size_t>(value_oversampling) != oversampling_factor) {
        oversampling_factor = static_cast<size_t>(value_oversampling);
        // Step 1: release all current resources
        releaseResources();

        // Step 2: re-initialise using current settings
        prepareToPlay (getSampleRate(), getBlockSize());
    }
"))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    )
  ;; (Show! "Esce da GenerateRotarySlider: *PARAMS*=" *PARAMS*)
  )
;;
(define*-public (GenerateComboBox paramReference values title title-up tx ty width height name id selected tooltip)
  (let ((var (g::gen-var "ComboBox")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (format #f "
	~a=make_unique<juce::ComboBox>();
	static const juce::StringArray ~a_items = ~a;
	{
	    int itemNum=1;
	    for (const auto &item : ~a_items)
	    {
	        ~a->addItem(item, itemNum++);
	    }
	}

    	~a->setSelectedId(~a);
	~a_customLNF = std::make_unique<CBLandF>(
	    juce::Colour(0xff32353b),
            juce::Colours::darkorange,
            juce::Colours::orange,
            juce::Colours::white,
            juce::Colours::white,
            juce::Colours::orange,
            juce::Colour(0xff23293b),
            juce::Colour(0xff424e5a),
            juce::Colours::white,
            juce::Colours::orange,
            juce::Colours::orange);
	~a->setLookAndFeel(~a_customLNF.get());
	~a_label.setText(\"~a\", juce::dontSendNotification);
	~a_label.attachToComponent(~a.get(), ~a);
	addAndMakeVisible(~a.get());
	addAndMakeVisible(~a_label);  // Still add the label!
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment>(
        ap.parameters, \"~a\", *~a);
" var var (convert-to-cstringarray values) var var var selected var var var var title var var (if title-up "true" "false") var var
var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a), 
        DrawingUtils::NormalizeY(~a), 
        DrawingUtils::NormalizeX(~a), 
        DrawingUtils::NormalizeY(~a));\n\n" var tx ty width height))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "
  std::unique_ptr<CBLandF> ~a_customLNF;
  std::unique_ptr<juce::ComboBox> ~a;
  juce::Label ~a_label;
  std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> ~aAttachment;
\n" var var var var))
    ;;
    ;;I params
    (AppendStringTo *PARAMS* "\n\n" (MakeComboBoxParam var title name id 0 (1- (length values)) selected values))
    ;;
    (AppendStringTo *DPARAMS* "\n" (format #f "
	std::atomic<float>* param_~a = nullptr;
	float value_~a;
	const juce::StringArray value_string_~a = ~a;
\n" paramReference paramReference paramReference (convert-to-cstringarray values)))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	// ~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))

;;Un bottone è sempre "toggleable"
;;
(define*-public (GenerateMaterialButton paramReference title-on title-off initial-status tx ty name id tooltip #:key (isToggle #t) (callback #f))
  (let ((var (g::gen-var "MaterialButton")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (format #f "{
	juce::String titleOn = \"~a\";
	juce::String titleOff = \"~a\";
	~a = std::make_unique<MaterialButton>(
        T_VarParams{
            {\"titleOn\", Utils::toVar(titleOn)},
            {\"titleOff\", Utils::toVar(titleOff)},
            {\"initialStatus\", Utils::toVar(\"~a\")},
            {\"titleLabelColor\", Utils::toVar(juce::Colours::white)},
            {\"titleLabelFont\", Utils::toVar(FontManagement::font_InterDisplay_Bold_ttf)},
            {\"titleLabelFontSize\", Utils::toVar(16.0)},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(100)},
            {\"height\", Utils::toVar(30)},
            {\"isToggleable\", Utils::toVar(~a)}, // false for push button
            {\"shadowColor\", Utils::toVar(juce::Colours::black.withAlpha(0.10f))},
            {\"baseColor\", Utils::toVar(juce::Colour(0xff2196f3))},
            {\"onColor\", Utils::toVar(juce::Colour(0xff43a047))},
            {\"offColor\", Utils::toVar(juce::Colour(0xff2196f3))},
            {\"buttonDownModifyColor\", Utils::toVar(0.18f)}, //darker
            {\"mouseOverModifyColor\", Utils::toVar(0.10f)},  //brighter
            {\"borderColorIfToggled\", Utils::toVar(0.2f)},  //darker
            {\"borderColorIfNotToggled\", Utils::toVar(0.25f)},  //darker

            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(*~a);
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
        ap.parameters, \"~a\", *~a);
	//E qui ci mettiamo il cambio di nome del bottone quando \"toggled\"
	~a->onClick = [btn = ~a.get(), titleOn, titleOff, me=this]()
	{
	    if (btn->getToggleState())
	        btn->setButtonText(titleOn);
	    else
	        btn->setButtonText(titleOff);

	    //Questa è per la callback
	    ~a;
	};
    }
\n\n\n"  title-on (if isToggle title-off title-on) var (if initial-status "true" "false") tx ty (if isToggle "true" "false") name id var tooltip var var id var var var
(if callback
    (string-append "me->ap.myplugin->ButtonCallback(" (number->string callback) ", \"" id "\");")
    "")))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n"  var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<MaterialButton> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> ~aAttachment;\n\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeButtonToggleParam var id name (if initial-status "true" "false")))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))
;;
(define-public (GenerateMaterialToggle paramReference title tx ty isToggled name id tooltip)
  (let ((var (g::gen-var "MaterialToggle")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (format #f   "~a = std::make_unique<MaterialToggle>(
        T_VarParams{
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleLabelColor\", Utils::toVar(juce::Colours::white)},
            {\"titleLabelFont\", Utils::toVar(FontManagement::font_InterDisplay_Bold_ttf)},
            {\"titleLabelFontSize\", Utils::toVar(16.0)},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(70)},
            {\"height\", Utils::toVar(60)},
            {\"isToggled\", Utils::toVar(~a)},

            {\"trackOn\", Utils::toVar(juce::Colour(0xFF2196F3))}, 
            {\"trackOff\", Utils::toVar(juce::Colour(0xFFB0BEC5))},
            {\"borderColor\", Utils::toVar(juce::Colours::grey.withAlpha(0.7f))},
            {\"thumbShadow\", Utils::toVar(juce::Colours::black.withAlpha(0.16f))},
            {\"thumbColor\", Utils::toVar(juce::Colour(0xFFF5F5F5))},

            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(*~a);
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
        ap.parameters, \"~a\", *~a);\n\n\n" var title tx ty (if isToggled "true" "false") name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n"  var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<MaterialToggle> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> ~aAttachment;\n\n" var var))
    ;;
    (AppendStringTo *PARAMS* "\n\n\n" (MakeButtonToggleParam var id name (if isToggled "true" "false")))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))
;;
;;  (GenerateBypassToggle   "Bypass"  50  540 #f "BypassToggle" "BypassToggleID" "To bypass the plugin")
;;
(define-public (GenerateBypassToggle tx ty)
  (let ((var (g::gen-var "MaterialToggle"))
	(title "Bypass")
	(name "Bypass")
	(id "AFBypass")
	(tooltip "To bypass the plugin")
	(isToggled #f)
	(paramReference "Bypass")
	)
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (format #f   "~a = std::make_unique<MaterialToggle>(
        T_VarParams{
            {\"titleLabel\", Utils::toVar(\"~a\")},
            {\"titleLabelColor\", Utils::toVar(juce::Colours::white)},
            {\"titleLabelFont\", Utils::toVar(FontManagement::font_InterDisplay_Bold_ttf)},
            {\"titleLabelFontSize\", Utils::toVar(16.0)},
            {\"titleJustification\", Utils::toVar(juce::Justification::bottomLeft)},
            {\"tx\", Utils::toVar(~a)},
            {\"ty\", Utils::toVar(~a)},
            {\"width\", Utils::toVar(70)},
            {\"height\", Utils::toVar(60)},
            {\"isToggled\", Utils::toVar(~a)},

            {\"trackOn\", Utils::toVar(juce::Colour(0xFF2196F3))}, 
            {\"trackOff\", Utils::toVar(juce::Colour(0xFFB0BEC5))},
            {\"borderColor\", Utils::toVar(juce::Colours::grey.withAlpha(0.7f))},
            {\"thumbShadow\", Utils::toVar(juce::Colours::black.withAlpha(0.16f))},
            {\"thumbColor\", Utils::toVar(juce::Colour(0xFFF5F5F5))},

            {\"name\", Utils::toVar(\"~a\")},
            {\"ID\", Utils::toVar(\"~a\")},
        });
    ~a->setTooltip(\"~a\");\n
    addAndMakeVisible(*~a);
	~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
	    ap.parameters,    // Your APVTS instance
	  \"~a\",          // Parameter ID
	    *~a            // The button to attach
	);\n\n\n" var title tx ty (if isToggled "true" "false") name id var tooltip var var id var))
    ;;
    (AppendStringTo *RESIZED* "\n\n\n" (format #f "~a->setBounds(
        DrawingUtils::NormalizeX(~a->varParameters[\"tx\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"ty\"]), 
        DrawingUtils::NormalizeX(~a->varParameters[\"width\"]), 
        DrawingUtils::NormalizeY(~a->varParameters[\"height\"]));\n\n"  var var var var var))
    ;;
    (AppendStringTo *DECLARATIONS* "\n\n\n" (format #f "std::unique_ptr<MaterialToggle> ~a;
	std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> ~aAttachment;\n\n" var var))

    (AppendStringTo *PARAMS* "\n" (format #f "//Il bottone di bypass del plugin!
	params.push_back(std::make_unique<juce::AudioParameterBool>(\"~a\", \"~a\", false));\n" id name))
    (AppendStringTo *DPARAMS* "\n" (format #f "std::atomic<float>* param_~a = nullptr;
	float value_~a;\n" paramReference paramReference))
    (AppendStringTo *GETPARAMS* "\n" (format #f "param_~a = parameters.getRawParameterValue(\"~a\");\n" paramReference id))
    (AppendStringTo *VALUEPARAMS* "\n" (format #f "value_~a = param_~a->load();\n" paramReference paramReference))
    (AppendStringTo *DESTROY* (format #f "
	~aAttachment.reset();
	~a.reset();" var var))
    ;;
    ))

;;
(define*-public (GenerateTitles #:key title footer-link footer-copyright . dummy) ;;per ora per evitare di modificare tutte le chiamate
  (let ((var (g::gen-var "Title"))
	)
    (AppendStringTo *INTERFACE*
		    "\n"
		    (f-str "
\t// Header\n\t${var}.setText(!{title}, juce::dontSendNotification);
\t${var}.setFont(juce::FontOptions(32.0f).withStyle(\"Bold\"));
\t${var}.setJustificationType(juce::Justification::centred);
\t${var}.setColour(juce::Label::textColourId, kineticLNF.currentPalette.neonWhite);
\taddAndMakeVisible(${var});
    // FOOTER
    // --- Footer Link ---
    footerLink.setText(!{footer-link}, juce::dontSendNotification);
    footerLink.setName(\"copyright\"); // Usiamo lo stesso nome per avere il font 12px dal LNF
    footerLink.setFont(juce::FontOptions(12.0f));
    footerLink.setJustificationType(juce::Justification::bottomLeft);
    footerLink.setColour(juce::Label::textColourId, juce::Colours::grey); //, kineticLNF.currentPalette.neonWhite.withAlpha(0.6f));
    footerLink.setMinimumHorizontalScale(1.0f);
    // Cambia il cursore quando passi sopra (manina)
    footerLink.setMouseCursor(juce::MouseCursor::PointingHandCursor);
    
    // Aggiungiamo il click per aprire l'URL
    footerLink.addMouseListener(this, false); 
    addAndMakeVisible(footerLink);

    // --- Copyright Label ---
    lblCopyright.setText(!{footer-copyright}, juce::dontSendNotification);
    lblCopyright.setName(\"copyright\"); // <--- AGGIUNGI QUESTO NOME IN CODICE
    lblCopyright.setFont(juce::FontOptions(12.0f)); 
    lblCopyright.setJustificationType(juce::Justification::bottomRight); 
    lblCopyright.setColour(juce::Label::textColourId, juce::Colours::grey);
    addAndMakeVisible(lblCopyright);

"))
    (AppendStringTo *DECLARATIONS* "\n"
		    (f-str "
	juce::Label ${var};
	juce::Label footerLink;
	juce::Label lblCopyright;
")
		    )
    ))
;;
(define-public (GenerateTitles-old title isImage image footer)
  (let ((var (g::gen-var "Title")))
    (AppendStringTo *INTERFACE* "\n\n\n"
		    (format #f     "//Il copyright, footer (con link al sito di AF-Audio)
    addAndMakeVisible(companyLink);
    companyLink.setFont(FontManagement::GetBestFontForSize(18, FontManagement::font_InterDisplay_Italic_ttf), false);
    companyLink.setButtonText(\"\\xA9 2025 AF-Audio\");
    companyLink.setURL(juce::URL(\"https://yourcompany.com\"));
    companyLink.setColour(juce::HyperlinkButton::textColourId, juce::Colours::lightcoral);\n\n"))
    ))
;;
(define-public (GenerateBackground bkg-id)
  (if (equal? #f bkg-id)
      (AppendStringTo *BACKGROUND* (format #f "
    // Gradiente verticale (rettangolare)
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xFF484C57),  // Top
        0, 0,
        juce::Colour(0xFF393D43),  // Bottom
        0, getHeight(),
        false));
    g.fillRect(getLocalBounds());

    // Effetto \"brushed metal\"
    for (int y = 0; y < getHeight(); y += 4)
    {
        g.setColour(juce::Colours::white.withAlpha(0.04f));
        g.drawLine(0.0f, float(y), float(getWidth()), float(y), 1.0f);
    }

    // Bordo sottile più chiaro (opzionale)
    g.setColour(juce::Colour(0xFF63676c));
    g.drawRect(getLocalBounds(), 2);

    //Il titolo
    g.setFont(FontManagement::GetBestFontForSize(DrawingUtils::NormalizeY(25), FontManagement::font_InterDisplay_SemiBold_ttf));
    g.setColour(juce::Colours::whitesmoke);
    g.drawFittedText(juce::String(JucePlugin_Name), getLocalBounds().removeFromTop(DrawingUtils::NormalizeY(30)), juce::Justification::centredBottom, 1);
"))
      (AppendStringTo *BACKGROUND* (format #f "
    static const vector<pair<const char *, const int>> images = {
        {BinaryData::bg01_jpg, BinaryData::bg01_jpgSize}, {BinaryData::bg02_jpg, BinaryData::bg02_jpgSize}, {BinaryData::bg03_jpg, BinaryData::bg03_jpgSize}, {BinaryData::bg04_jpg, BinaryData::bg04_jpgSize}, {BinaryData::bg05_jpg, BinaryData::bg05_jpgSize}, {BinaryData::bg06_jpg, BinaryData::bg06_jpgSize}, {BinaryData::bg07_jpg, BinaryData::bg07_jpgSize}, {BinaryData::bg08_jpg, BinaryData::bg08_jpgSize}, {BinaryData::bg09_jpg, BinaryData::bg09_jpgSize}, {BinaryData::bg10_jpg, BinaryData::bg10_jpgSize}, {BinaryData::bg11_jpg, BinaryData::bg11_jpgSize}, {BinaryData::bg12_jpg, BinaryData::bg12_jpgSize}, {BinaryData::bg13_jpg, BinaryData::bg13_jpgSize}, {BinaryData::bg14_jpg, BinaryData::bg14_jpgSize}, {BinaryData::bg15_jpg, BinaryData::bg15_jpgSize}, {BinaryData::bg16_jpg, BinaryData::bg16_jpgSize}, {BinaryData::bg17_jpg, BinaryData::bg17_jpgSize}, {BinaryData::bg18_jpg, BinaryData::bg18_jpgSize}, {BinaryData::bg19_jpg, BinaryData::bg19_jpgSize}, {BinaryData::bg20_jpg, BinaryData::bg20_jpgSize}, {BinaryData::bg21_jpg, BinaryData::bg21_jpgSize}, {BinaryData::bg22_jpg, BinaryData::bg22_jpgSize}, {BinaryData::bg23_jpg, BinaryData::bg23_jpgSize}, {BinaryData::bg24_jpg, BinaryData::bg24_jpgSize}, {BinaryData::bg25_jpg, BinaryData::bg25_jpgSize}, {BinaryData::bg26_jpg, BinaryData::bg26_jpgSize}, {BinaryData::bg27_jpg, BinaryData::bg27_jpgSize}, {BinaryData::bg28_jpg, BinaryData::bg28_jpgSize}, {BinaryData::bg29_jpg, BinaryData::bg29_jpgSize}, {BinaryData::bg30_jpg, BinaryData::bg30_jpgSize}, {BinaryData::bg31_jpg, BinaryData::bg31_jpgSize}, {BinaryData::bg32_jpg, BinaryData::bg32_jpgSize}, {BinaryData::bg33_jpg, BinaryData::bg33_jpgSize}, {BinaryData::bg34_jpg, BinaryData::bg34_jpgSize}, {BinaryData::bg35_jpg, BinaryData::bg35_jpgSize}, {BinaryData::bg36_jpg, BinaryData::bg36_jpgSize}, {BinaryData::bg37_jpg, BinaryData::bg37_jpgSize}, {BinaryData::bg38_jpg, BinaryData::bg38_jpgSize}, {BinaryData::bg39_jpg, BinaryData::bg39_jpgSize}, {BinaryData::bg40_jpg, BinaryData::bg40_jpgSize}, {BinaryData::bg41_jpg, BinaryData::bg41_jpgSize}, {BinaryData::bg42_jpg, BinaryData::bg42_jpgSize}, {BinaryData::bg43_jpg, BinaryData::bg43_jpgSize}, {BinaryData::bg44_jpg, BinaryData::bg44_jpgSize}, {BinaryData::bg45_jpg, BinaryData::bg45_jpgSize}, {BinaryData::bg46_jpg, BinaryData::bg46_jpgSize}, {BinaryData::bg47_jpg, BinaryData::bg47_jpgSize}, {BinaryData::bg48_jpg, BinaryData::bg48_jpgSize}, {BinaryData::bg49_jpg, BinaryData::bg49_jpgSize}, {BinaryData::bg50_jpg, BinaryData::bg50_jpgSize}, {BinaryData::bg51_jpg, BinaryData::bg51_jpgSize}, {BinaryData::bg52_jpg, BinaryData::bg52_jpgSize}, {BinaryData::bg53_jpg, BinaryData::bg53_jpgSize}, {BinaryData::bg54_jpg, BinaryData::bg54_jpgSize}, {BinaryData::bg55_jpg, BinaryData::bg55_jpgSize}, {BinaryData::bg56_jpg, BinaryData::bg56_jpgSize}, {BinaryData::bg57_jpg, BinaryData::bg57_jpgSize}, {BinaryData::bg58_jpg, BinaryData::bg58_jpgSize}, {BinaryData::bg59_jpg, BinaryData::bg59_jpgSize}, {BinaryData::bg60_jpg, BinaryData::bg60_jpgSize}};

    auto ourBackgroundImage = juce::ImageCache::getFromMemory(
        images[~a].first,
        images[~a].second);

    if (ourBackgroundImage.isValid())
    {
        // Example: Draw the image stretched to fit
        g.drawImageWithin(ourBackgroundImage,
                          getLocalBounds().getX(), getLocalBounds().getY(),
                          getWidth(), getHeight(),
                          juce::RectanglePlacement::stretchToFit);
    }
    else
    {
        // Fallback drawing if the image failed to load
              //  #38b5ff

        g.fillAll(juce::Colours::black);
        g.setColour(juce::Colours::red);
        g.drawText(\"Image Load Error\", getLocalBounds(), juce::Justification::centred);
    }

    //Il titolo
    g.setFont(FontManagement::GetBestFontForSize(DrawingUtils::NormalizeY(25), FontManagement::font_InterDisplay_SemiBold_ttf));
    g.setColour(juce::Colours::whitesmoke);
    g.drawFittedText(juce::String(JucePlugin_Name), getLocalBounds().removeFromTop(DrawingUtils::NormalizeY(30)), juce::Justification::centredBottom, 1);

" bkg-id bkg-id))))
;;
;;
(define*-public (ConfigureApp palette screen)
  ;;Attivazione della palette
  ;; { "id": "lblPalette",      "row":  1, "col": 20, "rowSpan":  1, "colSpan":  2, "margin_tb": 12 },
  ;; { "id": "paletteSelector", "row":  1, "col": 22, "rowSpan":  1, "colSpan":  3, "margin_tb": 10, "margin_lr": 4 },
  ;; (let ((title (title palette))
  ;; 	(default (default palette)))
  ;;   (Show! title ", " default)
  ;;   (AppendStringTo *INTERFACE* (f-str CODICE-PER-PALETTE))
  ;;   )
  ;; (when (enable palette)
  ;;   (AppendStringTo *INTERFACE* "addAndMakeVisible(paletteSelector);"))
  (AppendStringTo *DECLARATIONS* "
	juce::Label lblPalette;
	juce::ComboBox paletteSelector;
"))

(define (copy-template src-folder dst-folder)
  (let ((status
         (system*
          "rsync"
          "-a"
          "--exclude=.git"
          (string-append src-folder "/")
          (string-append dst-folder "/"))))
    (unless (= status 0)
      (error "Errore durante la copia del template con rsync"
             src-folder
             dst-folder))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; P R O G E T T O  M A I N:  C H I A M A R E  C O N  I L  N O M E  D E L ;;
;; P L U G - I N  E  C O N  L A  S P E C I F I C A  I N T E R F A C C I A ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
(defun*-public MakeNewProject (new-name interface-definitions #:key (generateFFTcode #f))
  ;; (begin
  ;;   (display "Something of strange happened. Call franco!!!")
  ;;   #f)
  ;; =>
  (unless (CouldIRun?)
    (return 0))
  ;;
  ;;A meno che non sia indicato, il codice non è per fft
  ;; (if generateFFTcode
  ;;     (set! generate-fft-code #t)
  ;;     (set! generate-fft-code #f)
  ;;     )
  ;;
  (set! g::gen-var (GetNextVariableName)) ;;per generare le variabili quando serviranno
  ;;
  (let* ((src-folder (string-append workspace-path template-name))
	 (dst-folder (string-append workspace-path new-name))
	 (file-info (stat dst-folder #f))
	 ;;(file-info #f);;iin questo modo ogni volta copia tutto!
	 )
    (cond
     ((eqv? #f file-info) ;;Il progetto destinazione non esiste ancora
      ;;in questo modo non chiede conferma e ogni volta copia tutto!
      (when (and #t (eqv? 'Ko (AskForOkCancel "Setting up the new project..." "Press OK to continue" "Ok" "Cancel")))
	(display "Requested to terminate.")
	(return #f))
      ;; Ora possiamo copiare il template e poi cambiare tutti i nomi nel progetto
      (ShowNotification "Wait. Code generation...")
      ;;(f:delete dst-folder #t)  ;;Per cancellare ogni volta tutta la destinazione!!!
      ;; (f:copy src-folder dst-folder #t)
      (copy-template src-folder dst-folder)
      ;;é un nuovo progetto, genero il prossimo UUID
      (let ((uuid (string->number (fs-io-to-string "uuid.txt"))))
	(do-replace-uuid (string-append src-folder "/JX11.jucer") (string-append dst-folder "/JX11.jucer") (mtfa-base62 uuid))
	(fs-io-from-string "uuid.txt" (number->string (1+ uuid))))
      ;;e per velocizzare non cancelliamo la build
      ;;(f:delete (string-append dst-folder "/Builds") #t)
      ;;
      ;; Ora possiamo cambiare tutti i nomi nel progetto
      (f:traverse dst-folder (lambda (nome) (do-replace-in-file nome old-project-name new-name)) #:files-only #t)
      ;;
      ;;Ora gli chiedo di specificare il file di configurazione dell'interfaccia utente
      (GenerateC++ g::gen-var dst-folder new-name interface-definitions #f) ;;non è aggiornamento!!
      ;;
      ;; ;; Queste tre righe non servono, è GenerateC++ che chiama la CLI di projucer e genera i makefile
      ;; (AskForOkCancel "Info" "Now you can open the project in Projucer to set the target environment (linux/Macos)" "Ok")
      ;; (RunProjucer)
      (display "Programma generato correttamente\n")
      (return #t))
     ;;
     ((eqv? (stat:type file-info) 'directory)
      ;; (match `(,(AskForRemoveLeave new-name))
      ;; 	(('Update) ;; non faccio nulla il progetto esiste già e sta bene, quindi aggiorno i codici dove serve farlo
      (GenerateC++ g::gen-var dst-folder new-name interface-definitions #t) ;;è un aggiornamento!!
      (display "Programma aggiornato correttamente\n")
      ;;  )
      ;; (_ (display "Terminazione su richiesta utente\n"))
      ;; )
      (return #t))
     ;;
     (#t ;;é qualcosa che va cancellato
      (MessageBox "Item exists and is not a folder" (format #f "L'elemento ~a non è una cartella" new-name))
      (return  #t)))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;OGNI NUOVO PROGETTO CAMBIA QUESTA FUNZIONE;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;Questa è la specifica dell'interfaccia per il progetto ZNew
;;
(define (Generic-interface-definitions dst-folder new-name)
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Input dB" 50 100 80 300 "Logarithmic VSlider modificato" "LogVSliderID" "Sono input log")
  (GenerateHorizontalLogSlider "volumedB" "VolumedB" 150 100 300 80 "Logarithmic Slider" "LogSliderID" "Sono Volume log")
  (GenerateVerticalLogSlider "outputdB" "output dB" 150 250 300 80 "Logarithmic output slider" "ID02" "output gain")
  (GenerateHorizontalLinearSlider "wetDry" "Wet/Dry" 50 400 200 80 "Wet Dry" "WetDryID" 0 100 50 "WetDry balance")
  (GenerateHorizontalLinearSlider "wetDry1" "Wet/Dry1" 50 500 200 80 "Wet Dry1" "WetDryID1" 0 100 50 "WetDry balance" #:step-size 3)

  (GenerateVerticalLinearSlider "outSqueeze" "Output Size" 600 100 80 400  "Linear VSlider" "LinearVSliderID" 0 100 50 "Sono output size lineare" #:step-size 5)
  (GenerateVerticalSteppedSlider "stepSld" '("uno" "due" "tre" "quattro" "cinque" "sei" "sette" "otto" "nove" "dieci") 5 "Altro out size" 800 100 100 400 "Linear VSlider Stepped" "LinearVSliderSteppedID" "Sono Stepped!")
  (GenerateRotarySlider "RotSld" '() "My Rotary Slider" 200 400 100 100 "Rotary Slider" "RotarySliderID" 0 100 50 "Sono un rotary!" #:step-size 2)
  (GenerateRotarySlider "RotSld1" '("wave_sine" "wave_square" "wave_triangle" "wave_ramp") "My Rotary Slider1" 300 400 100 100 "Rotary Slider1" "RotarySliderID1" 0 100 50 "Sono un rotary1!")
  ;; (GenerateMaterialButton "PushMe" 100 540 #f "Push Button" "PushButtonID" "Sono un push button")
  (GenerateMaterialButton "BtnOnOff" "Acceso" "Spento" #f 450 520 "Toggle Button" "ToggleButtonID" "Sono un toggle button")
  (GenerateMaterialToggle "BtnEnDis" "Enabled" 250 520 #t "Switch" "SwitchID" "Sono uno switch!")
  (GenerateRotarySlider "RotSld2" '() "My Rotary Slider2" 600 600 200 200 "Rotary Slider2" "RotarySliderID2" 0 100 1 "Sono un rotary1!" #:labels '("uno" "due" "tre" "quattro" "cinque"))
  (GenerateBypassToggle 50 520)
  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
  (GenerateBackground 57)
  )

(define (YANew-interface-definitions dst-folder new-name)
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Input dB" 100 100 80 250 "Logarithmic input slider" "ID01" "input gain")
  (GenerateRotarySlider "RotSld" '() "My Rotary Slider" 200 100 100 100 "Rotary Slider" "RotarySliderID" 0 100 50 "Sono un rotary!")
  (GenerateVerticalLogSlider "outputdB" "output dB" 420 100 80 250 "Logarithmic output slider" "ID02" "output gain")
  (GenerateBypassToggle 50 340)
  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
  (GenerateBackground '())
  )
;;;;;
;;Come eseguire il progetto?
;;(MakeNewProject "ZNew" ZNew-interface-definitions)

(define (YAVibrato-interface-definitions dst-folder new-name)
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Volume In" 50 100 80 400 "Log in volume" "VolumeInID" "Sono input log")
  (GenerateVerticalLogSlider "outputdB" "Volume out" 600 100 80 400  "Log out volume" "VolumeOutID" "Sono output log")
  (GenerateBypassToggle 50 520)
  (GenerateHorizontalLinearSlider "frequency" "Frequency" 150 100 400 80 "Frequency" "FrequencyID" 0.1 10 3 "Vibrato Frequency")
  (GenerateHorizontalLinearSlider "depth" "Depth" 150 210 400 80 "Depth" "DepthID" 0.1 12 2 "Vibrato Depth")
  (GenerateHorizontalLinearSlider "wetDry" "Wet/Dry" 150 320 400 80 "Wet Dry" "WetDryID" 0 100 50 "WetDry balance")
  (GenerateRotarySlider "waveform" '("wave_sine" "wave_triangle" "wave_square" "wave_ramp" "wave_iramp") "Waveforms" 300 430 130 130 "waveform1" "waveformID" 0 4 0 "Wave form selector")
  (GenerateMaterialToggle "BtnBPM" "Sync" 200 520 #f "BPM" "BPMID" "Use BPM as vibrato frequency")

  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
  (GenerateBackground 57)
  )

(define (YASwapper-interface-definitions dst-folder new-name)
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Volume In" 50 100 80 400 "Log in volume" "VolumeInID" "Sono input log")
  (GenerateVerticalLogSlider "outputdB" "Volume out" 750 100 80 400  "Log out volume" "VolumeOutID" "Sono output log")
  (GenerateBypassToggle 50 520)
  (GenerateHorizontalLinearSlider "rate" "LFO Rate (Hz)" 150 100 400 80 "LFO Rate (Hz)" "RateID" 0.1 10 1 "LFO Rate (Hz)")
  (GenerateHorizontalLinearSlider "depth" "Depth" 150 210 400 80 "Depth" "DepthID" 0.0 1.0 1.0 "Depth")
  (GenerateRotarySlider "shape" '("wave_sine" "wave_square") "LFO Shape" 300 360 130 130 "LFO Shape" "shapeID" 0 1 0 "Wave form selector")
  (GenerateMaterialButton "mode" "Swap" "Crossfade" #f 450 520 "Mode" "ModeID" "Swap mode")
  (GenerateVerticalSteppedSlider "division" '("1/4" "1/8" "1/16" "1/8T" "1/4.") 1 "Sync Division" 600 100 100 400 "Sync Division" "SyncDivisionID" "Sync division!")
  (GenerateMaterialToggle "BtnBPM" "Sync" 200 520 #f "BPM" "BPMID" "Use BPM as vibrato frequency")
  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
  (GenerateBackground 57)
  )

(define (YADelay-interface-definitions dst-folder new-name)
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Volume In" 50 100 80 400 "Log in volume" "VolumeInID" "Sono input log")
  (GenerateVerticalLogSlider "outputdB" "Volume out" 750 100 80 400  "Log out volume" "VolumeOutID" "Sono output log")
  (GenerateBypassToggle 50 590)

  (GenerateRotarySlider "delay" '() "Delay ms" 250 100 250 250 "Delay ms" "delayID" 0.1 2000 0.1 "Delay specifier"  #:step-size 0.01)
  (GenerateRotarySlider "wetdry" '() "Wet/Dry" 170 370 180 180 "Wet/Dry" "wetdryID" 0 1 0.5 "Wet Dry!" #:step-size 0.01)
  (GenerateRotarySlider "feedback" '() "FeedBack" 370 370 180 180 "FeedBack" "feedbackID" 0 1 0.1 "feedback specifier"  #:step-size 0.01)
  (GenerateVerticalSteppedSlider "division" '("1/4" "1/8" "1/16" "1/8T" "1/4." "1/8.") 1 "Sync Divisions" 600 100 100 400 "Sync Division" "SyncDivisionID" "Sync division!")

  (GenerateMaterialToggle "BtnBPM" "Sync" 200 590 #f "BPM" "BPMID" "Use BPM as delay frequency")
  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
  (GenerateBackground 57)
  )

(define (YAConvReverbero-interface-definitions dst-folder new-name)
  (let ((values '("1 Halls 01 Large Hall" "1 Halls 02 Medium Hall" "1 Halls 03 Small Hall" "1 Halls 04 Large & Near" "1 Halls 05 Medium & Near" "1 Halls 06 Small & Near" "1 Halls 07 Large & Dark" "1 Halls 08 Large & Deep" "1 Halls 09 Medium & Deep" "1 Halls 10 Concert Hall" "1 Halls 11 Gold Hall" "1 Halls 12 Sandors Hall" "1 Halls 13 Dense Hall" "1 Halls 14 Clear Hall" "1 Halls 15 Brass Hall" "1 Halls 16 Amsterdam Hall" "1 Halls 17 Berliner Hall" "1 Halls 18 Boston Hall A" "1 Halls 19 Boston Hall B" "1 Halls 20 Chicago Hall" "1 Halls 21 Vienna Hall" "1 Halls 22 Worcester Hall" "1 Halls 23 The ArchDuke" "1 Halls 24 Troy Music Hall" "1 Halls 25 Saint Sylvain" "1 Halls 26 Mechanics Hall" "1 Halls 27 Saint Gerold" "2 Plates 01 Bright Plate" "2 Plates 02 Dark Plate" "2 Plates 03 London Plate" "2 Plates 04 Snare Plate A" "2 Plates 05 Snare Plate B" "2 Plates 06 Vocal Plate" "2 Plates 07 Old Plate" "2 Plates 08 Rich Plate" "2 Plates 09 Gold Plate" "2 Plates 10 Dense Plate" "2 Plates 11 Silver Plate" "2 Plates 12 Percussion Plate" "2 Plates 13 Echo Plate" "2 Plates 14 CD Plate A" "2 Plates 15 CD Plate B" "2 Plates 16 Large Plate" "2 Plates 17 Small Plate" "2 Plates 18 Fat Plate" "2 Plates 19 Crystal Plate" "2 Plates 20 Sun Plate A" "2 Plates 21 Sun Plate B" "2 Plates 22 Sun Plate C" "2 Plates 23 Vocal Plate B" "3 Rooms 01 Studio A" "3 Rooms 02 Studio B Close" "3 Rooms 03 Studio B Far" "3 Rooms 04 Studio C" "3 Rooms 05 Studio D" "3 Rooms 06 Studio E" "3 Rooms 07 Deep Stone" "3 Rooms 08 Music Room" "3 Rooms 09 Heavy Room" "3 Rooms 10 Large Wooden Room" "3 Rooms 11 Small Wooden Room" "3 Rooms 12 Large Tiled Room" "3 Rooms 13 Medium Tiled Room" "3 Rooms 14 Small Tiled Room" "3 Rooms 15 Drum & Chamber" "3 Rooms 16 Djangos Room" "3 Rooms 17 Small Vox Room" "3 Rooms 18 Glass Room" "3 Rooms 19 Percussion Room" "3 Rooms 20 Marble Foyer" "3 Rooms 21 Large & Room" "3 Rooms 22 Small & Room" "3 Rooms 23 Large Red Room" "3 Rooms 24 Red Room" "3 Rooms 25 Blue Room" "3 Rooms 26 Large Room" "3 Rooms 27 Small Room" "3 Rooms 28 Front Room" "3 Rooms 29 Center Room" "3 Rooms 30 Back Room" "3 Rooms 31 Studio K" "3 Rooms 32 Waits Room" "3 Rooms 33 Corn Room" "3 Rooms 34 Oakland Room" "3 Rooms 35 SF Perf Room" "4 Chambers 01 Large Chamber" "4 Chambers 02 Medium Chamber" "4 Chambers 03 Small Chamber" "4 Chambers 04 Large & Dark" "4 Chambers 05 Small & Dark" "4 Chambers 06 Large & Bright" "4 Chambers 07 Small & Bright" "4 Chambers 08 Kick Chamber" "4 Chambers 09 Snare Chamber" "4 Chambers 10 Vocal Chamber" "4 Chambers 11 A&M Chamber" "4 Chambers 12 CD Chamber" "4 Chambers 13 Old Chamber" "4 Chambers 14 Deep Chamber" "4 Chambers 15 Amb Chamber A" "4 Chambers 16 Amb Chamber B" "4 Chambers 17 Sunset Chamber" "5 Ambiences 01 Large Ambience" "5 Ambiences 02 Medium Ambience" "5 Ambiences 03 Small Ambience" "5 Ambiences 04 Large & Dark" "5 Ambiences 05 Medium & Dark" "5 Ambiences 06 Small & Dark" "5 Ambiences 07 Large & Bright" "5 Ambiences 08 Medium & Bright" "5 Ambiences 09 Small & Bright" "5 Ambiences 10 Deep Ambience" "5 Ambiences 11 Long Ambience" "5 Ambiences 12 Clear Ambience" "5 Ambiences 13 Heavy Ambience" "5 Ambiences 14 Bass XXL" "5 Ambiences 15 Percussion Air" "6 Spaces 01 North Church" "6 Spaces 02 East Church" "6 Spaces 03 South Church" "6 Spaces 04 West Church" "6 Spaces 05 Cinema Room" "6 Spaces 06 Scoring Stage" "6 Spaces 07 Bath House" "6 Spaces 08 Car Park" "6 Spaces 09 Arena" "6 Spaces 10 Redwood Valley" "6 Spaces 11 Tanglewood" "6 Spaces 12 Academy Yard" "6 Spaces 13 Hillside" "6 Spaces 14 Cavern" "6 Spaces 15 Stone Quarry" "6 Spaces 16 Europa" "6 Spaces 17 Gated Space"
		  )))
    (make <screen> #:width 900)
    (GenerateVerticalLogSlider "inputdB" "Volume In" 50 100 80 400 "Log in volume" "VolumeInID" "Sono input log")
    (GenerateVerticalLogSlider "outputdB" "Volume out" 800 100 80 400  "Log out volume" "VolumeOutID" "Sono output log")
    (GenerateBypassToggle 50 590)

    (GenerateMaterialButton "LoadImpulse" "Load Impulse" "Load Impulse" #t 250 590 "Load Impulse" "LoadImpulseID" "Load impulse wav" #:isToggle #f #:callback 1)

    (GenerateWetDryRotarySlider "wetdry" "Wet/Dry" 150 200 200 200)
    (GenerateOversamplingRotarySlider 550 200 200 200 #:oversampling 1)
    ;;(GenerateRotarySlider "oversampling" '() "OverSampling" 550 200 200 200 "OverSampling" "oversamplingID" 0 8 2 "OverSampling" #:step-size 1)
    
    (GenerateRotarySlider "drive" '() "Drive" 350 200 200 200 "Drive" "driveID" 1 10 1 "Drive" #:step-size 0.1)
    (GenerateComboBox "waves" values "Select impulse" #f 500 100 250 30 "revtype" "revtypeid" 1 "Select the specific impulse for reverb")

    (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
    (GenerateBackground 57)))

;;Se vuoi generare una FFT
(define (YASimpleFFT-interface-definitions dst-folder new-name)
  ;;
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Volume In"    50 70 80 400 "Log in volume" "VolumeInID" "Sono input log")
  (GenerateVerticalLogSlider "outputdB" "Volume out" 800 70 80 400  "Log out volume" "VolumeOutID" "Sono output log")
  (GenerateBypassToggle 50 590)

  (GenerateWetDryRotarySlider "wetdry" "Wet/Dry" 200 70 150 150)
  (GenerateRotarySlider "fftsize" '() "FFT Size" 200 280 150 150 "FFTSize" "fftsizeID" 0 100 1 "FFT Size" #:labels '("256" "512" "1024" "2048" "4096" "8192"))
  ;; (GenerateRotarySlider "cutoff" '() "Cutoff" 250 100 100 100 "Cutoff" "cutoffID" 20 20000 1 "Cutoff")
  (GenerateVerticalLogSlider "cutoff" "CutOff"   425 70 80  400    "Taglio frequenza" "cutoffID" "Sono vertical slider" #:units "Hz" #:vmin 20 #:vmax 20000 #:initialpos 440 #:skew-factor 4000)
  ;;db = log(n)/log(10)*20

  ;; ;;Per provare gli orizzontali!!!
  ;; (GenerateHorizontalLogSlider "inputdB1" "Volume In"    150 450 400 80 "Log in volume" "VolumeInID1" "Sono input log")
  ;; (GenerateHorizontalLogSlider "inputdB2" "Volume In"    150 550 400 80 "Log in volume" "VolumeInID2" "Sono input log"  #:units "Hz" #:vmin 20 #:vmax 20000 #:initialpos 440 #:skew-factor 4000)

  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")
  (GenerateBackground 57))

(define (YASoundEnhancer-interface-definitions dst-folder new-name)
  (make <screen> #:width 900)
  (GenerateVerticalLogSlider "inputdB" "Volume In" 50 100 80 400 "Log in volume" "VolumeInID" "Sono input log")
  (GenerateVerticalLogSlider "outputdB" "Volume out" 800 100 80 400  "Log out volume" "VolumeOutID" "Sono output log")
  (GenerateBypassToggle 50 590)

  (GenerateRotarySlider "wetdry" '() "Wet/Dry" 150 200 200 200 "Wet/Dry" "wetdryID" 0 1 0.5 "Wet Dry!" #:step-size 0.01)
  (GenerateRotarySlider "drive" '() "Drive" 350 200 200 200 "Drive" "driveID" 1 10 1 "Drive" #:step-size 0.1)
  ;; (GenerateRotarySlider "delay" '() "Delay ms" 250 100 250 250 "Delay ms" "delayID" 0.1 2000 0.1 "Delay specifier"  #:step-size 0.01)

  ;; Even: Bright, octave-up feel
  ;; Odd: Fuzzy, classic distortion
  ;; Both: Harsh, “exciter” style
  ;; Saturate: Warm, tape/valve style
  ;; HardClip: Digital, lo-fi
  ;; SoftClip: Smooth, analog pedal
  ;; Exponential: Asymmetric, tube-like
  ;; DiodeClip: Vintage, asymmetric rectifier (e.g., classic fuzz face pedal)
  
  (GenerateVerticalSteppedSlider "options" '("Even harmonics" "Odd harmonics" "Both harmonics" "Saturate" "HardClip" "SoftClip" "Exponential" "DiodeClip") 1 "Options" 500 100 250 400 "Options" "OptionsID" "Enhance options")

  ;; (GenerateMaterialToggle "BtnBPM" "Sync" 200 590 #f "BPM" "BPMID" "Use BPM as delay frequency")
  (GenerateTitles-old new-name #f '() "www.aacf-music.eu")

  (GenerateBackground 57)
  )

(define (NewGeneric-interface dst-folder new-name)

  ;; ============================================================
  ;; SCREEN / GRID
  ;; ============================================================

  (make <screen>
        #:ratio (/ (+ 1.0 (sqrt 5.0)) 2.0)
        #:width 800)

  (make <grid>
        #:rows 24
        #:cols 24
        #:show-grid #t)

  (make <rotary-slider>
  #:id "Input Gain"
  #:role 'input-gain

  #:parameter-id "inputGain"
  #:parameter-name "Input Gain"
  #:processor-reference "inputGain"
  #:version-hint 1

  #:title "INPUT GAIN"

  #:min -24.0
  #:max 24.0
  #:default 0.0
  #:interval 0.1

  #:scale 'linear
  #:value-type 'default
  #:suffix " dB"

  #:show-value #t
  #:show-ticks #t
  #:show-labels #t
  #:tick-count 5
  #:tick-mode 'all
  #:tick-labels '("-24" "-12" "0" "+12" "+24")

  #:row 16
  #:col 1
  #:row-span 7
  #:col-span 6)

  (make <rotary-slider>
  #:id "Output Gain"
  #:role 'output-gain

  #:parameter-id "outputGain"
  #:parameter-name "Output Gain"
  #:processor-reference "outputGain"
  #:version-hint 1

  #:title "OUTPUT GAIN"

  #:min -24.0
  #:max 24.0
  #:default 0.0
  #:interval 0.1

  #:scale 'linear
  #:value-type 'default
  #:suffix " dB"

  #:show-value #t
  #:show-ticks #t
  #:show-labels #t
  #:tick-count 5
  #:tick-mode 'all
  #:tick-labels '("-24" "-12" "0" "+12" "+24")

  #:row 16
  #:col 21
  #:row-span 7
  #:col-span 6)
  

  ;; ============================================================
  ;; INPUT METER
  ;; ============================================================

  (make <meter>
    #:id "Input Level"
    #:role 'input-meter

    #:style 'segmented
    #:scale-type 'db
    #:is-sharp #f
    #:glow-multiplier 0.6
    #:range-min -60.0
    #:range-max 6.0
    #:num-segments 30
    #:tick-mode 'all

    #:row 3
    #:col 1
    #:row-span 14
    #:col-span 2
    #:margin-tb 4
    #:margin-lr 4)


  ;; ============================================================
  ;; OUTPUT METER
  ;; ============================================================

  (make <meter>
    #:id "Output Level"
    #:role 'output-meter

    #:style 'segmented
    #:scale-type 'db
    #:is-sharp #f
    #:glow-multiplier 0.6
    #:range-min -60.0
    #:range-max 6.0
    #:num-segments 30
    #:tick-mode 'all

    #:row 3
    #:col 21
    #:row-span 14
    #:col-span 2
    #:margin-tb 4
    #:margin-lr 4)

  

  ;; ============================================================
  ;; SCOPE
  ;; ============================================================

  (make <scope>
    #:id "Wave Monitor"
    #:role 'scope

    #:grid-style 'radar
    #:is-sharp #f
    #:glow-multiplier 1.2

    #:row 3
    #:col 4
    #:row-span 9
    #:col-span 16
    #:margin-tb 4
    #:margin-lr 4)


  ;; ============================================================
  ;; WET / DRY
  ;; ============================================================

  (make <linear-slider>
    #:id "Wet Dry"
    #:role 'wet-dry

    #:parameter-id "wetdry"
    #:parameter-name "Wet Dry"
    #:processor-reference "wetdry"
    #:version-hint 1

    #:orientation 'horizontal
    #:title "WET / DRY"

    #:min 0.0
    #:max 100.0
    #:default 100.0
    #:interval 1.0

    #:scale 'linear
    #:value-type 'default
    #:suffix " %"

    #:show-value #t
    #:show-ticks #t
    #:show-labels #t
    #:tick-count 5
    #:tick-mode 'all

    #:tick-labels
    '("DRY" "25" "50" "75" "WET")

    #:row 13
    #:col 5
    #:row-span 3
    #:col-span 14)


  ;; ============================================================
  ;; OVERSAMPLING
  ;; ============================================================
(make <rotary-slider>
  #:id "Oversampling"
  #:role 'oversampling

  #:parameter-id "oversampling"
  #:parameter-name "Oversampling"
  #:processor-reference "oversampling"
  #:version-hint 1

  #:title "OVERSAMPLING"

  #:min 0.0
  #:max 3.0
  #:default 0.0
  #:interval 1.0

  #:scale 'linear
  #:value-type 'default
  #:suffix ""

  #:show-value #t
  #:show-ticks #t
  #:show-labels #t
  #:tick-count 4
  #:tick-mode 'all

  #:tick-labels
  '("OFF" "2x" "4x" "8x")

  #:row 16
  #:col 4
  #:row-span 7
  #:col-span 7)
  


  ;; ============================================================
  ;; FFT SIZE
  ;; ============================================================

 (make <rotary-slider>
  #:id "FFT Size"
  #:role 'fft-size

  #:parameter-id "fftSize"
  #:parameter-name "FFT Size"
  #:processor-reference "fftSize"
  #:version-hint 1

  #:title "FFT SIZE"

  #:min 0.0
  #:max 6.0
  #:default 0.0
  #:interval 1.0

  #:scale 'linear
  #:value-type 'default
  #:suffix ""

  #:show-value #t
  #:show-ticks #t
  #:show-labels #t
  #:tick-count 7
  #:tick-mode 'all

  #:tick-labels
  '("OFF"
    "256"
    "512"
    "1024"
    "2048"
    "4096"
    "8192")

  #:row 16
  #:col 13
  #:row-span 7
  #:col-span 8) 

  )

(define-public (hard-reload-project)
  (display "Svuotamento cache di Guile...\n")

  ;; Evita che vengano riutilizzati vecchi .go
  (system "rm -rf ~/.cache/guile/ccache/*")

  (display "Ricaricamento moduli...\n")

  ;; Ordine topologico: foglie -> moduli dipendenti -> facade.
  (for-each
   (lambda (mod-name)
     (let ((mod (resolve-module mod-name #f)))
       (when mod
         (format #t "Ricaricamento di ~a in corso...\n" mod-name)
         (reload-module mod))))

   '((generator-app globals)
     (generator-app tools)
     (generator-app genera-classi)

     ;; Generic GOOPS e stato
     (generator-app generation-protocols)
     (generator-app generation-state)

     ;; DSL -> validation -> registration
     (generator-app dsl-model)
     (generator-app validation)
     (generator-app registration)

     ;; Generazione C++
     (generator-app cpp-generation-common)
     (generator-app cpp-generation)

     ;; Sottosistemi indipendenti/finali
     (generator-app resources)
     (generator-app layout)
     (generator-app dsp-generation)

     ;; Wrapper degli emitter
     (generator-app generation-orchestration)

     ;; Facade: sempre ultima
     (generator-app code-generator)))

  (display "Reload del progetto completato.\n"))


