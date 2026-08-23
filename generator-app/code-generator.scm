(define-module (generator-app code-generator)
  #:use-module (generator-app resources)
  #:use-module (generator-app layout)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app validation)
  #:use-module (generator-app registration)
  #:use-module (generator-app cpp-generation-common)
  #:use-module (generator-app cpp-generation)
  #:use-module (generator-app dsp-generation)
  #:use-module (generator-app generation-orchestration)
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
	       selector:parameter-id
	       selector:parameter-name
	       selector:processor-reference
	       selector:version-hint
               <palette-selector>
               <button>
               button:text
               <text-button>
               <toggle-button>
               toggle-button:default-state
               toggle-button:style
               toggle-button:parameter-id
               toggle-button:parameter-name
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
               meter:orientation
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
               generate-paint-over-children-code
	       generate-footer-timer-code
	       generate-footer-mouse-code
	       generate-link-runtime-declarations-code
	       generate-timer-code
	       generate-member-declarations
               generate-constructor-code
               generate-attachment-declarations
               generate-attachment-code
               generate-parameter-code
               generate-dparams-code
               generate-getparams-code
               generate-valueparams-code
               generate-destroy-code
	       generate-footer-timer-code
	       generate-timer-code
	       generate-dsp-runtime-members-code
	       generate-oversampling-prepare-code
	       generate-oversampling-release-code
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
	       generate-myplugin-developer-latency-declaration-code
	       generate-myplugin-developer-latency-code
	       )
  )

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
