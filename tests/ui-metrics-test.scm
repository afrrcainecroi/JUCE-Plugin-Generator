(use-modules (srfi srfi-1)
             (generator-app ui-metrics))

(define (check label predicate)
  (unless predicate
    (error "UI metrics test failed" label)))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(let* ((metrics (ui-metrics 'rotary-slider))
       (technical-min (field metrics 'technical-min))
       (visual-min (field metrics 'visual-min))
       (preferred (field metrics 'preferred))
       (useful-max (field metrics 'useful-max))
       (aspect (field metrics 'aspect))
       (gap (field metrics 'gap))
       (horizontal-gap (field gap 'horizontal))
       (vertical-gap (field gap 'vertical))
       (capabilities (field metrics 'capabilities))
       (preferences (field metrics 'capability-size-preferences)))

  (check 'metrics-present metrics)

  (check 'technical-min-not-normative
         (and (not (field technical-min 'normative?))
              (eq? (field technical-min 'status) 'to-be-derived)
              (not (field technical-min 'width))
              (not (field technical-min 'height))))

  (check 'visual-min
         (equal? visual-min '((width . 5) (height . 5))))
  (check 'preferred
         (equal? preferred '((width . 7) (height . 7))))
  (check 'useful-max
         (equal? useful-max '((width . 9) (height . 9))))

  (check 'aspect
         (equal? aspect
                 '((minimum . 0.85)
                   (preferred . 1.0)
                   (maximum . 1.15))))

  (check 'horizontal-gap
         (equal? horizontal-gap
                 '((minimum . 0.5) (preferred . 1.0))))
  (check 'vertical-gap
         (equal? vertical-gap
                 '((minimum . 0.5) (preferred . 1.0))))

  (check 'anchors
         (equal? (field metrics 'anchors)
                 '(left right top bottom center-x center-y)))

  (check 'compact-profile
         (equal? (ui-profile 'rotary-slider 'compact)
                 '((width . 5) (height . 5))))
  (check 'standard-profile
         (equal? (ui-profile 'rotary-slider 'standard)
                 '((width . 7) (height . 7))))
  (check 'extended-profile
         (equal? (ui-profile 'rotary-slider 'extended)
                 '((width . 9) (height . 9))))

  (check 'capabilities
         (equal? capabilities
                 '(title value ticks tick-labels
                   vector-icon raster-icon morph-icon)))

  (check 'capability-preferences
         (and (= (length preferences) 2)
              (every (lambda (rule)
                       (eq? (field rule 'preferred-profile) 'extended))
                     preferences)))

  (check 'unknown-type
         (not (ui-metrics 'unknown-type)))
  (check 'unknown-profile
         (not (ui-profile 'rotary-slider 'unknown-profile))))

(let* ((metrics (ui-metrics 'linear-slider))
       (technical-min (field metrics 'technical-min))
       (variants (field metrics 'variants))
       (horizontal (field variants 'horizontal))
       (vertical (field variants 'vertical)))
  (check 'linear-metrics-present metrics)
  (check 'linear-technical-min-not-normative
         (and (not (field technical-min 'normative?))
              (eq? (field technical-min 'status) 'to-be-derived)
              (not (field technical-min 'width))
              (not (field technical-min 'height))))

  (check 'horizontal-base-profiles
         (and (eq? (field horizontal 'visual-min-profile) 'compact)
              (eq? (field horizontal 'preferred-profile) 'standard)
              (eq? (field horizontal 'useful-max-profile) 'extended)))
  (check 'vertical-base-profiles
         (and (eq? (field vertical 'visual-min-profile) 'compact)
              (eq? (field vertical 'preferred-profile) 'standard)
              (eq? (field vertical 'useful-max-profile) 'extended)))

  (check 'horizontal-profiles
         (and (equal? (ui-profile 'linear-slider 'horizontal 'compact)
                      '((width . 10) (height . 3)))
              (equal? (ui-profile 'linear-slider 'horizontal 'standard)
                      '((width . 14) (height . 4)))
              (equal? (ui-profile 'linear-slider 'horizontal 'extended)
                      '((width . 18) (height . 5)))))
  (check 'vertical-profiles
         (and (equal? (ui-profile 'linear-slider 'vertical 'compact)
                      '((width . 3) (height . 10)))
              (equal? (ui-profile 'linear-slider 'vertical 'standard)
                      '((width . 4) (height . 14)))
              (equal? (ui-profile 'linear-slider 'vertical 'extended)
                      '((width . 5) (height . 18)))))

  (check 'vertical-tick-labels-minimum
         (eq? (ui-capability-profile
               'linear-slider 'vertical '(tick-labels)
               'minimum-visual-profile)
              'standard))
  (check 'horizontal-full-preferred
         (eq? (ui-capability-profile
               'linear-slider 'horizontal
               '(title value ticks tick-labels)
               'preferred-profile '((space . abundant)))
              'extended))
  (check 'vertical-full-preferred
         (eq? (ui-capability-profile
               'linear-slider 'vertical
               '(title value ticks tick-labels)
               'preferred-profile '((space . abundant)))
              'extended))
  (check 'discrete-value-does-not-change-minimum
         (not (ui-capability-profile
               'linear-slider 'vertical '(discrete-text-value)
               'minimum-visual-profile)))

  ;; Existing rotary API remains unchanged.
  (check 'rotary-profile-backward-compatibility
         (equal? (ui-profile 'rotary-slider 'compact)
                 '((width . 5) (height . 5)))))

(define (check-nonvariant-contract type compact standard extended aspect)
  (let* ((metrics (ui-metrics type))
         (technical-min (field metrics 'technical-min)))
    (check (list type 'present) metrics)
    (check (list type 'technical-min)
           (and (not (field technical-min 'normative?))
                (eq? (field technical-min 'status) 'to-be-derived)
                (not (field technical-min 'width))
                (not (field technical-min 'height))))
    (check (list type 'profiles)
           (and (equal? (ui-profile type 'compact) compact)
                (equal? (ui-profile type 'standard) standard)
                (equal? (ui-profile type 'extended) extended)))
    (check (list type 'base-sizes)
           (and (equal? (field metrics 'visual-min) compact)
                (equal? (field metrics 'preferred) standard)
                (equal? (field metrics 'useful-max) extended)
                (eq? (field metrics 'visual-min-profile) 'compact)
                (eq? (field metrics 'preferred-profile) 'standard)
                (eq? (field metrics 'useful-max-profile) 'extended)))
    (check (list type 'aspect)
           (equal? (field metrics 'aspect) aspect))))

(check-nonvariant-contract
 'text-button
 '((width . 5) (height . 2))
 '((width . 8) (height . 3))
 '((width . 12) (height . 4))
 '((minimum . 2.5) (preferred . 2.67) (maximum . 3.0)))

(check-nonvariant-contract
 'toggle-button
 '((width . 4) (height . 3))
 '((width . 6) (height . 4))
 '((width . 8) (height . 5))
 '((minimum . 1.33) (preferred . 1.5) (maximum . 1.6)))

(check-nonvariant-contract
 'switch
 '((width . 5) (height . 3))
 '((width . 7) (height . 4))
 '((width . 10) (height . 5))
 '((minimum . 1.67) (preferred . 1.75) (maximum . 2.0)))

(check 'text-button-long-text-aspect
       (= (ui-capability-profile
           'text-button #f '(text) 'preferred-aspect-ratio
           '((text-length-class . long)))
          4.0))
(check 'toggle-button-long-text-profile
       (eq? (ui-capability-profile
             'toggle-button #f '(text) 'preferred-profile
             '((text-length-class . long)))
            'extended))
(check 'switch-long-text-profile
       (eq? (ui-capability-profile
             'switch #f '(text) 'preferred-profile
             '((text-length-class . long)))
            'extended))

(check-nonvariant-contract
 'bypass-switch
 '((width . 5) (height . 3))
 '((width . 7) (height . 4))
 '((width . 10) (height . 5))
 '((minimum . 1.67) (preferred . 1.75) (maximum . 2.0)))

(let* ((metrics (ui-metrics 'bypass-switch))
       (technical-min (field metrics 'technical-min))
       (natural-geometry (field metrics 'natural-geometry))
       (capabilities (field metrics 'capabilities))
       (content-dependent (field metrics 'content-dependent))
       (rules (field metrics 'capability-rules)))
  (check 'bypass-switch-technical-min-not-normative
         (and (not (field technical-min 'normative?))
              (eq? (field technical-min 'status) 'to-be-derived)
              (not (field technical-min 'width))
              (not (field technical-min 'height))))
  (check 'bypass-switch-natural-geometry
         (equal? natural-geometry
                 '((form . switch) (orientation . horizontal))))
  (check 'bypass-switch-capabilities
         (equal? capabilities
                 '(text toggle-state enabled track thumb disabled-feedback)))
  (check 'bypass-switch-role-does-not-affect-footprint
         (eq? (field metrics 'role-effect-on-footprint) 'none))
  (check 'bypass-switch-state-does-not-affect-footprint
         (every (lambda (capability)
                  (eq? (field (field content-dependent capability)
                              'footprint-effect)
                       'none))
                '(enabled toggle-state disabled-feedback)))
  (check 'bypass-switch-state-does-not-change-profile
         (every (lambda (capability)
                  (and (not (ui-capability-profile
                             'bypass-switch #f (list capability)
                             'preferred-profile))
                       (not (ui-capability-profile
                             'bypass-switch #f (list capability)
                             'minimum-visual-profile))))
                '(enabled toggle-state disabled-feedback)))
  (check 'bypass-switch-no-role-capability-rules
         (every (lambda (rule)
                  (let* ((condition (field rule 'when))
                         (rule-capabilities
                          (field condition 'capabilities-all)))
                    (and (not (memq 'bypass rule-capabilities))
                         (not (memq 'dsp-bypass rule-capabilities))
                         (not (memq 'hard-bypass rule-capabilities)))))
                rules)))

(check 'bypass-switch-matches-switch-profiles
       (every (lambda (profile)
                (equal? (ui-profile 'bypass-switch profile)
                        (ui-profile 'switch profile)))
              '(compact standard extended)))

(check 'bypass-switch-long-text-profile
       (eq? (ui-capability-profile
             'bypass-switch #f '(text) 'preferred-profile
             '((text-length-class . long)))
            (ui-capability-profile
             'switch #f '(text) 'preferred-profile
             '((text-length-class . long)))))

(let* ((metrics (ui-metrics 'label))
       (technical-min (field metrics 'technical-min))
       (content-dependent (field metrics 'content-dependent)))
  (check 'label-present metrics)
  (check 'label-technical-min-not-normative
         (and (not (field technical-min 'normative?))
              (eq? (field technical-min 'status) 'to-be-derived)
              (not (field technical-min 'width))
              (not (field technical-min 'height))))
  (check 'label-base-contract
         (and (equal? (field metrics 'visual-min)
                      '((width . 8) (height . 2)))
              (equal? (field metrics 'preferred)
                      '((width . 12) (height . 3)))
              (equal? (field metrics 'useful-max)
                      '((width . 16) (height . 4)))
              (eq? (field metrics 'visual-min-profile) 'compact)
              (eq? (field metrics 'preferred-profile) 'standard)
              (eq? (field metrics 'useful-max-profile) 'extended)))
  (check 'label-profiles
         (and (equal? (ui-profile 'label 'compact)
                      '((width . 8) (height . 2)))
              (equal? (ui-profile 'label 'standard)
                      '((width . 12) (height . 3)))
              (equal? (ui-profile 'label 'extended)
                      '((width . 16) (height . 4)))))
  (check 'label-capabilities
         (equal? (field metrics 'capabilities)
                 '(text font-size font-style
                   minimum-horizontal-scale justification)))
  (check 'label-content-dependent-metadata
         (and content-dependent
              (assoc 'text-length content-dependent)
              (assoc 'font-size content-dependent)
              (assoc 'minimum-horizontal-scale content-dependent)
              (eq? (field (field content-dependent 'font-style)
                          'footprint-effect)
                   'not-significant-in-current-matrix)
              (eq? (field (field content-dependent 'justification)
                          'minimum-footprint-effect)
                   'none)))
  (check 'label-long-text-prefers-extended
         (eq? (ui-capability-profile
               'label #f '(text) 'preferred-profile
               '((text-length-class . long)))
              'extended))
  (check 'label-large-font-prefers-at-least-standard
         (eq? (ui-capability-profile
               'label #f '(font-size) 'preferred-profile
               '((font-size-class . large)))
              'standard))
  (check 'label-long-large-prefers-extended
         (eq? (ui-capability-profile
               'label #f '(text font-size) 'preferred-profile
               '((text-length-class . long)
                 (font-size-class . large)))
              'extended))
  (check 'label-justification-does-not-change-minimum
         (not (ui-capability-profile
               'label #f '(justification) 'minimum-visual-profile
               '((justification . right)))))
  (check 'label-font-style-does-not-change-profile
         (not (ui-capability-profile
               'label #f '(font-style) 'preferred-profile
               '((font-style . bold))))))

(define (check-banner-contract type expected-capabilities expected-form)
  (let* ((metrics (ui-metrics type))
         (technical-min (field metrics 'technical-min))
         (content-dependent (field metrics 'content-dependent))
         (natural-geometry (field metrics 'natural-geometry)))
    (check (list type 'present) metrics)
    (check (list type 'technical-min-not-normative)
           (and (not (field technical-min 'normative?))
                (eq? (field technical-min 'status) 'to-be-derived)
                (not (field technical-min 'width))
                (not (field technical-min 'height))))
    (check (list type 'profiles)
           (and (equal? (ui-profile type 'compact)
                        '((width . 16) (height . 2)))
                (equal? (ui-profile type 'standard)
                        '((width . 24) (height . 3)))
                (equal? (ui-profile type 'extended)
                        '((width . 32) (height . 4)))))
    (check (list type 'base-contract)
           (and (equal? (field metrics 'visual-min)
                        '((width . 16) (height . 2)))
                (equal? (field metrics 'preferred)
                        '((width . 24) (height . 3)))
                (equal? (field metrics 'useful-max)
                        '((width . 32) (height . 4)))
                (eq? (field metrics 'visual-min-profile) 'compact)
                (eq? (field metrics 'preferred-profile) 'standard)
                (eq? (field metrics 'useful-max-profile) 'extended)))
    (check (list type 'natural-geometry)
           (and (eq? (field natural-geometry 'form) expected-form)
                (eq? (field natural-geometry 'lines) 'single)))
    (check (list type 'capabilities)
           (equal? (field metrics 'capabilities) expected-capabilities))
    (check (list type 'content-dependent)
           (and content-dependent
                (assoc 'text-length content-dependent)
                (assoc 'font-size content-dependent)
                (eq? (field (field content-dependent 'font-style)
                            'footprint-effect)
                     'not-significant-in-current-matrix)
                (eq? (field (field content-dependent 'justification)
                            'minimum-footprint-effect)
                     'none)))))

(check-banner-contract
 'header
 '(text font-size font-style justification)
 'horizontal-banner)
(check-banner-contract
 'footer
 '(text font-size font-style justification margin-tb margin-lr)
 'thin-horizontal-banner)

(check 'header-long-text-prefers-extended
       (eq? (ui-capability-profile
             'header #f '(text) 'preferred-profile
             '((text-length-class . long)))
            'extended))
(check 'header-large-font-prefers-extended
       (eq? (ui-capability-profile
             'header #f '(font-size) 'preferred-profile
             '((font-size-class . large)))
            'extended))
(check 'header-long-large-prefers-extended
       (eq? (ui-capability-profile
             'header #f '(text font-size) 'preferred-profile
             '((text-length-class . long)
               (font-size-class . large)))
            'extended))
(check 'footer-long-text-prefers-extended
       (eq? (ui-capability-profile
             'footer #f '(text) 'preferred-profile
             '((text-length-class . long)))
            'extended))
(check 'footer-large-margin-tb-requires-extended
       (eq? (ui-capability-profile
             'footer #f '(margin-tb) 'minimum-visual-profile
             '((margin-tb-class . large)))
            'extended))
(check 'banner-justification-does-not-change-minimum
       (and (not (ui-capability-profile
                  'header #f '(justification) 'minimum-visual-profile
                  '((justification . right))))
            (not (ui-capability-profile
                  'footer #f '(justification) 'minimum-visual-profile
                  '((justification . right))))))

(let* ((metrics (ui-metrics 'link))
       (technical-min (field metrics 'technical-min))
       (natural-geometry (field metrics 'natural-geometry))
       (content-dependent (field metrics 'content-dependent)))
  (check 'link-present metrics)
  (check 'link-technical-min-not-normative
         (and (not (field technical-min 'normative?))
              (eq? (field technical-min 'status) 'to-be-derived)
              (not (field technical-min 'width))
              (not (field technical-min 'height))))
  (check 'link-profiles
         (and (equal? (ui-profile 'link 'compact)
                      '((width . 8) (height . 2)))
              (equal? (ui-profile 'link 'standard)
                      '((width . 12) (height . 2)))
              (equal? (ui-profile 'link 'extended)
                      '((width . 16) (height . 2)))))
  (check 'link-base-contract
         (and (equal? (field metrics 'visual-min)
                      '((width . 8) (height . 2)))
              (equal? (field metrics 'preferred)
                      '((width . 12) (height . 2)))
              (equal? (field metrics 'useful-max)
                      '((width . 16) (height . 2)))
              (eq? (field metrics 'visual-min-profile) 'compact)
              (eq? (field metrics 'preferred-profile) 'standard)
              (eq? (field metrics 'useful-max-profile) 'extended)))
  (check 'link-natural-geometry
         (equal? natural-geometry
                 '((form . interactive-horizontal-text)
                   (lines . single))))
  (check 'link-capabilities
         (equal? (field metrics 'capabilities)
                 '(text url font-size font-style justification
                        minimum-horizontal-scale interactive-hit-area
                        hover-feedback cursor-feedback)))
  (check 'link-content-dependent-metadata
         (and (equal? (field content-dependent 'text-length)
                      '((effect . preferred-profile)
                        (classification . descriptive-advisory)))
              (equal? (field content-dependent 'font-size)
                      '((classification . descriptive-advisory)))
              (equal? (field content-dependent 'minimum-horizontal-scale)
                      '((effect . fitted-text-compression)
                        (classification . renderer-configured)))
              (eq? (field (field content-dependent 'font-style)
                          'footprint-effect)
                   'not-significant-in-current-matrix)
              (equal? (field content-dependent 'justification)
                      '((footprint-effect . none)
                        (minimum-footprint-effect . none)))
              (eq? (field (field content-dependent 'url)
                          'footprint-effect)
                   'none)))
  (check 'link-long-text-prefers-extended
         (eq? (ui-capability-profile
               'link #f '(text) 'preferred-profile
               '((text-length-class . long)))
              'extended))
  (check 'link-url-does-not-change-footprint
         (and (not (ui-capability-profile
                    'link #f '(url) 'preferred-profile))
              (not (ui-capability-profile
                    'link #f '(url) 'minimum-visual-profile))))
  (check 'link-justification-does-not-change-minimum
         (not (ui-capability-profile
               'link #f '(justification) 'minimum-visual-profile
               '((justification . right)))))
  (check 'link-font-style-does-not-change-profile
         (not (ui-capability-profile
               'link #f '(font-style) 'preferred-profile
               '((font-style . bold)))))
  (check 'link-large-font-has-no-profile-rule
         (not (ui-capability-profile
               'link #f '(font-size) 'preferred-profile
               '((font-size-class . large))))))

(define (check-selector-contract type expected-capabilities)
  (let* ((metrics (ui-metrics type))
         (technical-min (field metrics 'technical-min))
         (natural-geometry (field metrics 'natural-geometry))
         (content-dependent (field metrics 'content-dependent)))
    (check (list type 'present) metrics)
    (check (list type 'technical-min)
           (and (not (field technical-min 'normative?))
                (eq? (field technical-min 'status) 'to-be-derived)
                (not (field technical-min 'width))
                (not (field technical-min 'height))))
    (check (list type 'profiles)
           (and (equal? (ui-profile type 'compact)
                        '((width . 8) (height . 2)))
                (equal? (ui-profile type 'standard)
                        '((width . 12) (height . 2)))
                (equal? (ui-profile type 'extended)
                        '((width . 16) (height . 2)))))
    (check (list type 'base-contract)
           (and (equal? (field metrics 'visual-min)
                        '((width . 8) (height . 2)))
                (equal? (field metrics 'preferred)
                        '((width . 12) (height . 2)))
                (equal? (field metrics 'useful-max)
                        '((width . 16) (height . 2)))
                (eq? (field metrics 'visual-min-profile) 'compact)
                (eq? (field metrics 'preferred-profile) 'standard)
                (eq? (field metrics 'useful-max-profile) 'extended)))
    (check (list type 'natural-geometry)
           (equal? natural-geometry
                   '((form . horizontal-combo-box) (lines . single))))
    (check (list type 'capabilities)
           (equal? (field metrics 'capabilities) expected-capabilities))
    (check (list type 'content-metadata)
           (and (equal? (field content-dependent 'items/text-length)
                        '((effect . preferred-profile)
                          (classification . descriptive-advisory)))
                (equal? (field content-dependent 'justification)
                        '((footprint-effect . none)
                          (minimum-footprint-effect . none)))
                (eq? (field (field content-dependent 'enabled)
                            'footprint-effect)
                     'none)
                (eq? (field (field content-dependent 'parameter-binding)
                            'footprint-effect)
                     'none)
                (eq? (field (field content-dependent 'default-index)
                            'footprint-effect)
                     'none)
                (eq? (field (field content-dependent 'arrow-region)
                            'classification)
                     'renderer-configured)
                (eq? (field (field content-dependent 'popup-menu)
                            'footprint-effect)
                     'none)))
    (check (list type 'long-text)
           (eq? (ui-capability-profile
                 type #f '(items) 'preferred-profile
                 '((text-length-class . long)))
                'extended))
    (check (list type 'non-geometric-capabilities)
           (and (not (ui-capability-profile
                      type #f '(enabled) 'preferred-profile
                      '((enabled . #f))))
                (not (ui-capability-profile
                      type #f '(parameter-binding) 'preferred-profile))
                (not (ui-capability-profile
                      type #f '(default-index) 'preferred-profile))
                (not (ui-capability-profile
                      type #f '(justification) 'minimum-visual-profile
                      '((justification . right))))))))

(check-selector-contract
 'selector
 '(items default-index justification enabled parameter-binding
         arrow-region popup-menu))
(check-selector-contract
 'palette-selector
 '(items default-index justification enabled parameter-binding
         arrow-region popup-menu predefined-palette-set palette-callback))

(let ((content-dependent
       (field (ui-metrics 'palette-selector) 'content-dependent)))
  (check 'palette-selector-specific-capabilities-do-not-change-footprint
         (and (eq? (field (field content-dependent 'predefined-palette-set)
                          'footprint-effect)
                   'none)
              (eq? (field (field content-dependent 'palette-callback)
                          'footprint-effect)
                   'none)
              (not (ui-capability-profile
                    'palette-selector #f '(predefined-palette-set)
                    'preferred-profile))
              (not (ui-capability-profile
                    'palette-selector #f '(palette-callback)
                    'preferred-profile)))))

;; Every TYPE registered before link retains its profile API.
(check 'all-existing-types-backward-compatible
       (and (equal? (ui-profile 'rotary-slider 'compact)
                    '((width . 5) (height . 5)))
            (equal? (ui-profile 'linear-slider 'horizontal 'standard)
                    '((width . 14) (height . 4)))
            (equal? (ui-profile 'linear-slider 'vertical 'standard)
                    '((width . 4) (height . 14)))
            (equal? (ui-profile 'text-button 'standard)
                    '((width . 8) (height . 3)))
            (equal? (ui-profile 'toggle-button 'standard)
                    '((width . 6) (height . 4)))
            (equal? (ui-profile 'switch 'standard)
                    '((width . 7) (height . 4)))
            (equal? (ui-profile 'label 'standard)
                    '((width . 12) (height . 3)))
            (equal? (ui-profile 'header 'standard)
                    '((width . 24) (height . 3)))
            (equal? (ui-profile 'footer 'standard)
                    '((width . 24) (height . 3)))
            (equal? (ui-profile 'link 'standard)
                    '((width . 12) (height . 2)))))

;; Recheck both pre-existing profile APIs after registering new TYPEs.
(check 'rotary-backward-compatibility-after-extension
       (equal? (ui-profile 'rotary-slider 'compact)
               '((width . 5) (height . 5))))
(check 'linear-backward-compatibility-after-extension
       (and (equal? (ui-profile 'linear-slider 'horizontal 'standard)
                    '((width . 14) (height . 4)))
            (equal? (ui-profile 'linear-slider 'vertical 'standard)
                    '((width . 4) (height . 14)))))

(display "ui-metrics-test: PASS\n")
