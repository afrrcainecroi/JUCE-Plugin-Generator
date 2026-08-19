(define-module (generator-app code-generator)
  #:use-module ((algorithms) #:prefix algo:)
  #:use-module ((f) #:prefix f:)
  #:use-module ((f ports) #:prefix fp:)
  #:use-module (pfds sets)
  #:use-module (mtfa error-handler)
  #:use-module (mtfa utils)
  #:use-module (mtfa serializer)
  #:use-module (mtfa unordered-set)
  #:use-module (mtfa unordered-map)
  #:use-module (mtfa star-map)
  #:use-module (mtfa simple_db)
  #:use-module (mtfa eis)
  #:use-module (mtfa va)
  #:use-module (mtfa extset)
  #:use-module (mtfa umset)
  #:use-module (mtfa web)
  #:use-module (mtfa brg)
  #:use-module (mtfa avl)
  #:use-module (mtfa eqt)
  #:use-module (gnutls)
  #:use-module (scheme kwargs)
  #:use-module (search basic)
  #:use-module (math primes)
  #:use-module (match-bind)
  #:use-module (graph topological-sort)
  #:use-module (rnrs bytevectors)
  #:use-module (rnrs arithmetic bitwise)
  #:use-module (rnrs enums)
  #:use-module ((rnrs io ports) #:prefix ioports::)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-11)
  #:use-module ((srfi srfi-18) #:prefix srfi-18::) ;;thread e mutex
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-41) ;;streams
  #:use-module (srfi srfi-42) ;;Eager Comprehensions
  #:use-module (srfi srfi-43)
  #:use-module (srfi srfi-45)
  #:use-module (srfi srfi-60)
  #:use-module (srfi srfi-111) ;;Boxes
  #:use-module (srfi srfi-171)
  #:use-module (web uri)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 pretty-print)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 peg)
  #:use-module (ice-9 peg string-peg)
  #:use-module (ice-9 vlist)
  #:use-module (ice-9 q)
  #:use-module (ice-9 binary-ports)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 threads)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 control)
  #:use-module (ice-9 match)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 eval-string)
  #:use-module (ice-9 local-eval)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 arrays)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 optargs)
  #:use-module (ice-9 string-fun)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (json)
  #:use-module (system syntax)
  #:use-module (system foreign)
  #:use-module (system foreign-library)
  #:use-module (web server)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (web client)
  ;;
  #:use-module (generator-app globals)
  #:use-module (generator-app tools)
  #:use-module (generator-app genera-classi)
  #:use-module (generator-app generation-protocols)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app resources)
  #:use-module (generator-app layout)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app validation)
  #:use-module (generator-app registration)
  #:use-module (generator-app cpp-generation-common)
  #:use-module (generator-app cpp-generation)
  #:use-module (generator-app dsp-generation)
  #:re-export (register-image-set!
               register-component!
               validate-component!
               component-type
               component->model
               component->member-declaration
               model->member-declaration
               model->constructor-code
               model->attachment-declaration
               model->attachment-code
               model->parameter-code
               model->dparams-code
               model->getparams-code
               model->valueparams-code
               model->destroy-code
               <image-set>
               image-set:name
               image-set:source-directory
               image-set:files
               materialize-image-sets!
               generate-image-resource-jucer-code
               update-jucer-image-resources!
               generated-resource-filename
               generate-image-resource-cpp-code
               <grid>
               grid:rows
               grid:cols
               grid:show-grid
               <screen>
               screen:ratio
               screen:width
               register-grid!
               register-screen!
               generate-layout-data-components
               generate-screen-size-code
               generate-grid-code
               <component>
               component:id
               component:role
               component:row
               component:col
               component:row-span
               component:col-span
               component:margin-tb
               component:margin-lr
               <label>
               label:text
               label:justification
               <header>
               <footer>
               <link>
               link:url
               <palette-label>
               palette-label:enable
               palette-label:default-theme
               <selector>
               selector:items
               selector:default-index
               <palette-selector>
               <button>
               button:text
               <text-button>
               <toggle-button>
               toggle-button:default-state
               toggle-button:style
               toggle-button:parameter-id
               toggle-button:parameter-name
               toggle-button:tooltip
               toggle-button:processor-reference
               toggle-button:version-hint
               <normal-toggle-button>
               <switch>
               <bypass-switch>
               <slider>
               slider:parameter-id
               slider:parameter-name
               slider:processor-reference
               slider:version-hint
               slider:title
               slider:min
               slider:max
               slider:default
               slider:interval
               slider:scale
               slider:value-type
               slider:suffix
               slider:show-value
               slider:show-ticks
               slider:show-labels
               slider:tick-count
               slider:tick-mode
               slider:tick-labels
               <rotary-slider>
               rotary-slider:icon-type
               rotary-slider:morph-icon
               rotary-slider:icon-set
               <linear-slider>
               linear-slider:orientation
               <meter>
               meter:style
               meter:scale-type
               meter:is-sharp
               meter:glow-multiplier
               meter:range-min
               meter:range-max
               meter:num-segments
               meter:tick-mode
               <scope>
               scope:grid-style
               scope:is-sharp
               scope:glow-multiplier
               <header-footer>
               header-footer:id
               header-footer:title-header
               header-footer:row-header
               header-footer:col-header
               header-footer:row-span-header
               header-footer:col-span-header
               header-footer:margin-tb-header
               header-footer:margin-lr-header
               header-footer:title-footer
               header-footer:row-footer
               header-footer:col-footer
               header-footer:row-span-footer
               header-footer:col-span-footer
               header-footer:margin-tb-footer
               header-footer:margin-lr-footer
               header-footer:title-link
               header-footer:url-link
               header-footer:row-link
               header-footer:col-link
               header-footer:row-span-link
               header-footer:col-span-link
               header-footer:margin-tb-link
               header-footer:margin-lr-link
               <palette>
               palette:id
               palette:enable
               palette:default-theme
               palette:title-palette
               palette:row-palette
               palette:col-palette
               palette:row-span-palette
               palette:col-span-palette
               palette:margin-tb-palette
               palette:margin-lr-palette
               palette:row-selector
               palette:col-selector
               palette:row-span-selector
               palette:col-span-selector
               palette:margin-tb-selector
               palette:margin-lr-selector
               find-component
               find-component-by-role
               component-id-used?
               component-role-used?
               validate-component-role
               role-present?
               role-model
               component-cpp-var
               slider-parameter-type?
               button-parameter-type?
               parameter-component-type?
               processor-param-var
               processor-value-var
               processor-reference
               slider-scale->cpp
               bool->cpp
               slider-kinetic-properties->cpp
               rotary-kinetic-properties->cpp
               tick-labels->cpp
               cpp-string
               selector-items->cpp
               generate-process-code
               generate-process-wetdry-prefix
               generate-paint-over-children-code)
  )

(define-public (generate-member-declarations)
  (apply string-append
         (map model->member-declaration
              (reverse (generation-components)))))


(define-public (generate-constructor-code)
  (apply string-append
         (map model->constructor-code
              (reverse (generation-components)))))

(define-public (generate-attachment-declarations)
  (apply string-append
         (map model->attachment-declaration
              (reverse (generation-components)))))

;; (define-method (model->attachment-code (model <list>))
;;   (let ((type         (assoc-ref model 'type))
;;         (var          (assoc-ref model 'var))
;;         (parameter-id (assoc-ref model 'parameter-id)))
;;     (case type
;;       ((bypass-switch)
;;        (format #f
;; 	       "~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
;;     ap.parameters,
;;     \"~a\",
;;     ~a
;; );~%"
;; 	       var
;; 	       (cpp-string parameter-id)
;; 	       var))
;;       ((rotary-slider linear-slider)
;;        (format #f
;; 	       "~aAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
;;     ap.parameters,
;;     \"~a\",
;;     ~a
;; );~%"
;;                var
;;                (cpp-string parameter-id)
;;                var))
;;       (else ""))))
(define-public (generate-attachment-code)
  (apply string-append
         (map model->attachment-code
              (reverse (generation-components)))))

;; (define-method (model->parameter-code (model <list>))
;;   (let ((type           (assoc-ref model 'type))
;;         (parameter-id   (assoc-ref model 'parameter-id))
;;         (parameter-name (assoc-ref model 'parameter-name))
;;         (default-state  (assoc-ref model 'default-state))
;; 	(version-hint (assoc-ref model 'version-hint))
;;         (default        (assoc-ref model 'default)))
;;     (case type
;;       ((bypass-switch)
;;        (format #f
;; 	       "params.push_back(
;;     std::make_unique<juce::AudioParameterBool>(
;;         juce::ParameterID { \"~a\", ~a },
;;         \"~a\",
;;         ~a));~%"
;;                (cpp-string parameter-id)
;;                version-hint
;;                (cpp-string parameter-name)
;;                (bool->cpp default-state)))
;;       ((rotary-slider linear-slider)
;;        (format #f
;; "params.push_back(
;;     std::make_unique<juce::AudioParameterFloat>(
;;         juce::ParameterID { \"~a\", ~a },
;;         \"~a\",
;;         ~a,
;;         ~a));~%"
;;          (cpp-string parameter-id)
;;          version-hint
;;          (cpp-string parameter-name)
;;          (slider-normalisable-range->cpp model)
;;          default))
;;       (else
;;        ""))))

(define-public (generate-parameter-code)

  (apply string-append
         (map model->parameter-code
              (reverse (generation-components)))))


;; (define-method (model->dparams-code (model <list>))
;;   (let ((type      (assoc-ref model 'type))
;;         (reference (assoc-ref model 'processor-reference)))
;;     (case type
;;       ((bypass-switch rotary-slider linear-slider)
;;        (format #f
;; "std::atomic<float>* param_~a = nullptr;
;; float value_~a;~%"
;;                reference
;;                reference))
;;       (else ""))))

(define-public (generate-dparams-code)
  (apply string-append
         (map model->dparams-code
              (reverse (generation-components)))))


;; (define-method (model->getparams-code (model <list>))
;;   (let ((type         (assoc-ref model 'type))
;;         (reference    (assoc-ref model 'processor-reference))
;;         (parameter-id (assoc-ref model 'parameter-id)))
;;     (case type
;;       ((bypass-switch rotary-slider linear-slider)
;;        (format #f
;; "param_~a = parameters.getRawParameterValue(\"~a\");~%"
;;                reference
;;                (cpp-string parameter-id)))
;;       (else ""))))

(define-public (generate-getparams-code)
  (apply string-append
         (map model->getparams-code
              (reverse (generation-components)))))

;; (define-method (model->valueparams-code (model <list>))
;;   (let ((type      (assoc-ref model 'type))
;;         (reference (assoc-ref model 'processor-reference)))
;;     (case type
;;       ((bypass-switch rotary-slider linear-slider)
;;        (format #f
;; "value_~a = param_~a->load();~%"
;;                reference
;;                reference))
;;       (else ""))))

(define-public (generate-valueparams-code)
  (apply string-append
         (map model->valueparams-code
              (reverse (generation-components)))))

(define-public (generate-destroy-code)
  (apply string-append
         (map model->destroy-code
              (reverse (generation-components)))))

(define (generate-oversampling-prepare-code)
  (if (role-present? 'oversampling)
      "    // OVERSAMPLING
    oversampling2x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            getTotalNumInputChannels(),
            1,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR);

    oversampling4x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            getTotalNumInputChannels(),
            2,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR);

    oversampling8x =
        std::make_unique<juce::dsp::Oversampling<float>>(
            getTotalNumInputChannels(),
            3,
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR);

    oversampling2x->initProcessing(samplesPerBlock);
    oversampling4x->initProcessing(samplesPerBlock);
    oversampling8x->initProcessing(samplesPerBlock);

    oversampling2x->reset();
    oversampling4x->reset();
    oversampling8x->reset();

"
      ""))
