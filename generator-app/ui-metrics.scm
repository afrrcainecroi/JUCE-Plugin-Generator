(define-module (generator-app ui-metrics)
  #:use-module (srfi srfi-1)
  #:export (register-ui-metrics!
            ui-metrics
            ui-profile
            ui-capability-profile))

;; Intrinsic UI metrics are registered by TYPE. They do not encode ROLE,
;; instance PROPERTY values, RESOURCE identities, or layout decisions.
(define *ui-metrics-registry* '())

(define (metric-ref metrics key)
  (let ((entry (assoc key metrics)))
    (and entry (cdr entry))))

(define (register-ui-metrics! type metrics)
  (unless (symbol? type)
    (error "UI metrics TYPE must be a symbol" type))
  (unless (list? metrics)
    (error "UI metrics contract must be an association list" type metrics))
  (when (assoc type *ui-metrics-registry*)
    (error "Duplicate UI metrics TYPE" type))
  (set! *ui-metrics-registry*
        (acons type metrics *ui-metrics-registry*))
  metrics)

(define (ui-metrics type)
  (let ((entry (assoc type *ui-metrics-registry*)))
    (and entry (cdr entry))))

(define (ui-profile type selector . selectors)
  (let ((metrics (ui-metrics type)))
    (cond
     ;; Backward-compatible, non-variant query.
     ((null? selectors)
      (let* ((profiles (and metrics (metric-ref metrics 'profiles)))
             (entry (and profiles (assoc selector profiles))))
        (and entry (cdr entry))))
     ;; Variant-aware query.
     ((null? (cdr selectors))
      (let* ((variants (and metrics (metric-ref metrics 'variants)))
             (variant-entry (and variants (assoc selector variants)))
             (variant (and variant-entry (cdr variant-entry)))
             (profiles (and variant (metric-ref variant 'profiles)))
             (entry (and profiles (assoc (car selectors) profiles))))
        (and entry (cdr entry))))
     (else
      (error "ui-profile expects TYPE PROFILE or TYPE VARIANT PROFILE"
             type selector selectors)))))

(define (condition-matches? condition variant capabilities context)
  (every
   (lambda (entry)
     (let ((key (car entry))
           (expected (cdr entry)))
       (case key
         ((variant) (eq? variant expected))
         ((capabilities-all)
          (every (lambda (capability)
                   (memq capability capabilities))
                 expected))
         (else
          (equal? (metric-ref context key) expected)))))
   condition))

;; Returns an advisory profile selected by the first matching capability rule.
;; It does not alter the base contract and is not connected to layout.
(define* (ui-capability-profile type variant capabilities effect
                                #:optional (context '()))
  (let* ((metrics (ui-metrics type))
         (rules (or (and metrics
                         (or (metric-ref metrics 'capability-rules)
                             (metric-ref metrics
                                         'capability-size-preferences)))
                    '())))
    (let loop ((remaining rules))
      (if (null? remaining)
          #f
          (let* ((rule (car remaining))
                 (condition (metric-ref rule 'when))
                 (result (assoc effect rule)))
            (if (and result
                     (condition-matches? condition variant
                                         capabilities context))
                (cdr result)
                (loop (cdr remaining))))))))

(register-ui-metrics!
 'rotary-slider
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))

   (visual-min
    . ((width . 5)
       (height . 5)))

   (preferred
    . ((width . 7)
       (height . 7)))

   (useful-max
    . ((width . 9)
       (height . 9)))

   (aspect
    . ((minimum . 0.85)
       (preferred . 1.0)
       (maximum . 1.15)))

   (gap
    . ((horizontal
        . ((minimum . 0.5)
           (preferred . 1.0)))
       (vertical
        . ((minimum . 0.5)
           (preferred . 1.0)))))

   (anchors
    . (left right top bottom center-x center-y))

   (profiles
    . ((compact
        . ((width . 5)
           (height . 5)))
       (standard
        . ((width . 7)
           (height . 7)))
       (extended
        . ((width . 9)
           (height . 9)))))

   (capabilities
    . (title
       value
       ticks
       tick-labels
       vector-icon
       raster-icon
       morph-icon))

   ;; Capability-dependent rules are advisory metadata. They do not alter
   ;; visual-min and are not consumed by the current layout implementation.
   (capability-size-preferences
    . (((when
         . ((capabilities-all . (ticks tick-labels))
            (space . abundant)))
        (preferred-profile . extended))
       ((when
         . ((capabilities-all . (morph-icon))
            (configuration . morph/full)
            (space . abundant)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'linear-slider
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))

   (variants
    . ((horizontal
        . ((visual-min
            . ((width . 10) (height . 3)))
           (preferred
            . ((width . 14) (height . 4)))
           (useful-max
            . ((width . 18) (height . 5)))
           (visual-min-profile . compact)
           (preferred-profile . standard)
           (useful-max-profile . extended)
           (profiles
            . ((compact . ((width . 10) (height . 3)))
               (standard . ((width . 14) (height . 4)))
               (extended . ((width . 18) (height . 5)))))))
       (vertical
        . ((visual-min
            . ((width . 3) (height . 10)))
           (preferred
            . ((width . 4) (height . 14)))
           (useful-max
            . ((width . 5) (height . 18)))
           (visual-min-profile . compact)
           (preferred-profile . standard)
           (useful-max-profile . extended)
           (profiles
            . ((compact . ((width . 3) (height . 10)))
               (standard . ((width . 4) (height . 14)))
               (extended . ((width . 5) (height . 18)))))))))

   (capabilities
    . (title value ticks tick-labels discrete-text-value))

   ;; Rules are advisory metadata and are not consumed by layout.
   (capability-rules
    . (((when
         . ((variant . vertical)
            (capabilities-all . (tick-labels))))
        (minimum-visual-profile . standard))
       ((when
         . ((variant . horizontal)
            (capabilities-all . (ticks tick-labels title value))
            (space . abundant)))
        (preferred-profile . extended))
       ((when
         . ((variant . vertical)
            (capabilities-all . (ticks tick-labels title value))
            (space . abundant)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'text-button
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 5) (height . 2)))
   (preferred . ((width . 8) (height . 3)))
   (useful-max . ((width . 12) (height . 4)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 5) (height . 2)))
       (standard . ((width . 8) (height . 3)))
       (extended . ((width . 12) (height . 4)))))
   (aspect
    . ((minimum . 2.5)
       (preferred . 2.67)
       (maximum . 3.0)))
   (capabilities
    . (text hover-feedback pressed-feedback))
   (capability-rules
    . (((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-aspect-ratio . 4.0))))))

(register-ui-metrics!
 'toggle-button
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 4) (height . 3)))
   (preferred . ((width . 6) (height . 4)))
   (useful-max . ((width . 8) (height . 5)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 4) (height . 3)))
       (standard . ((width . 6) (height . 4)))
       (extended . ((width . 8) (height . 5)))))
   (aspect
    . ((minimum . 1.33)
       (preferred . 1.5)
       (maximum . 1.6)))
   (capabilities
    . (text toggle-state hover-feedback pressed-or-toggle-feedback))
   (capability-rules
    . (((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'switch
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 5) (height . 3)))
   (preferred . ((width . 7) (height . 4)))
   (useful-max . ((width . 10) (height . 5)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 5) (height . 3)))
       (standard . ((width . 7) (height . 4)))
       (extended . ((width . 10) (height . 5)))))
   (aspect
    . ((minimum . 1.67)
       (preferred . 1.75)
       (maximum . 2.0)))
   (capabilities
    . (text toggle-state track thumb))
   (capability-rules
    . (((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'bypass-switch
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 5) (height . 3)))
   (preferred . ((width . 7) (height . 4)))
   (useful-max . ((width . 10) (height . 5)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 5) (height . 3)))
       (standard . ((width . 7) (height . 4)))
       (extended . ((width . 10) (height . 5)))))
   (aspect
    . ((minimum . 1.67)
       (preferred . 1.75)
       (maximum . 2.0)))
   (natural-geometry
    . ((form . switch)
       (orientation . horizontal)))
   (role-effect-on-footprint . none)
   (capabilities
    . (text toggle-state enabled track thumb disabled-feedback))
   (content-dependent
    . ((enabled . ((footprint-effect . none)))
       (toggle-state . ((footprint-effect . none)))
       (disabled-feedback . ((footprint-effect . none)))))
   (capability-rules
    . (((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'label
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   ;; These profiles describe the base TYPE geometry observed by the visual
   ;; matrix. Label sizing remains content-dependent; the profiles are not a
   ;; guarantee that arbitrary text and font configurations will fit.
   (visual-min . ((width . 8) (height . 2)))
   (preferred . ((width . 12) (height . 3)))
   (useful-max . ((width . 16) (height . 4)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 8) (height . 2)))
       (standard . ((width . 12) (height . 3)))
       (extended . ((width . 16) (height . 4)))))
   (capabilities
    . (text font-size font-style minimum-horizontal-scale justification))
   (content-dependent
    . ((text-length
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (font-size
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (minimum-horizontal-scale
        . ((effect . fitted-text-compression)
           (classification . renderer-configured)))
       (font-style
        . ((footprint-effect . not-significant-in-current-matrix)))
       (justification
        . ((footprint-effect . none)
           (minimum-footprint-effect . none)))))
   ;; Content rules are advisory metadata only. They do not alter visual-min
   ;; and are not consumed by the current layout implementation.
   (capability-rules
    . (((when
         . ((capabilities-all . (text font-size))
            (text-length-class . long)
            (font-size-class . large)))
        (preferred-profile . extended))
       ((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))
       ((when
         . ((capabilities-all . (font-size))
            (font-size-class . large)))
        (preferred-profile . standard))))))

(register-ui-metrics!
 'header
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   ;; Header sizing remains content-dependent. These base profiles describe
   ;; the single-line horizontal banner observed by the visual matrix.
   (visual-min . ((width . 16) (height . 2)))
   (preferred . ((width . 24) (height . 3)))
   (useful-max . ((width . 32) (height . 4)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 16) (height . 2)))
       (standard . ((width . 24) (height . 3)))
       (extended . ((width . 32) (height . 4)))))
   (natural-geometry
    . ((form . horizontal-banner)
       (lines . single)))
   (capabilities
    . (text font-size font-style justification))
   (content-dependent
    . ((text-length
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (font-size
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (font-style
        . ((footprint-effect . not-significant-in-current-matrix)))
       (justification
        . ((footprint-effect . none)
           (minimum-footprint-effect . none)))))
   ;; Content rules are advisory metadata only. They do not alter visual-min
   ;; and are not consumed by the current layout implementation.
   (capability-rules
    . (((when
         . ((capabilities-all . (text font-size))
            (text-length-class . long)
            (font-size-class . large)))
        (preferred-profile . extended))
       ((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))
       ((when
         . ((capabilities-all . (font-size))
            (font-size-class . large)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'footer
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   ;; Footer sizing remains content-dependent. These base profiles describe
   ;; the thin single-line horizontal banner observed by the visual matrix.
   (visual-min . ((width . 16) (height . 2)))
   (preferred . ((width . 24) (height . 3)))
   (useful-max . ((width . 32) (height . 4)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 16) (height . 2)))
       (standard . ((width . 24) (height . 3)))
       (extended . ((width . 32) (height . 4)))))
   (natural-geometry
    . ((form . thin-horizontal-banner)
       (lines . single)))
   (capabilities
    . (text font-size font-style justification margin-tb margin-lr))
   (content-dependent
    . ((text-length
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (font-size
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (margin-tb
        . ((effect . minimum-visual-profile)
           (classification . descriptive-advisory)))
       (margin-lr
        . ((classification . descriptive-advisory)))
       (font-style
        . ((footprint-effect . not-significant-in-current-matrix)))
       (justification
        . ((footprint-effect . none)
           (minimum-footprint-effect . none)))))
   ;; margin-tb-class is descriptive: this contract intentionally defines no
   ;; numeric threshold and does not change the helper's margin-tb default.
   (capability-rules
    . (((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))
       ((when
         . ((capabilities-all . (margin-tb))
            (margin-tb-class . large)))
        (minimum-visual-profile . extended))))))

(register-ui-metrics!
 'link
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 8) (height . 2)))
   (preferred . ((width . 12) (height . 2)))
   (useful-max . ((width . 16) (height . 2)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 8) (height . 2)))
       (standard . ((width . 12) (height . 2)))
       (extended . ((width . 16) (height . 2)))))
   (natural-geometry
    . ((form . interactive-horizontal-text)
       (lines . single)))
   (capabilities
    . (text url font-size font-style justification
            minimum-horizontal-scale interactive-hit-area
            hover-feedback cursor-feedback))
   (content-dependent
    . ((text-length
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (font-size
        . ((classification . descriptive-advisory)))
       (minimum-horizontal-scale
        . ((effect . fitted-text-compression)
           (classification . renderer-configured)))
       (font-style
        . ((footprint-effect . not-significant-in-current-matrix)))
       (justification
        . ((footprint-effect . none)
           (minimum-footprint-effect . none)))
       (url
        . ((footprint-effect . none)))))
   ;; The current matrix supports no font-size profile rule or numeric
   ;; threshold for long text.
   (capability-rules
    . (((when
         . ((capabilities-all . (text))
            (text-length-class . long)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'selector
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 8) (height . 2)))
   (preferred . ((width . 12) (height . 2)))
   (useful-max . ((width . 16) (height . 2)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 8) (height . 2)))
       (standard . ((width . 12) (height . 2)))
       (extended . ((width . 16) (height . 2)))))
   (natural-geometry
    . ((form . horizontal-combo-box)
       (lines . single)))
   (capabilities
    . (items default-index justification enabled parameter-binding
             arrow-region popup-menu))
   (content-dependent
    . ((items/text-length
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (justification
        . ((footprint-effect . none)
           (minimum-footprint-effect . none)))
       (enabled . ((footprint-effect . none)))
       (parameter-binding . ((footprint-effect . none)))
       (default-index . ((footprint-effect . none)))
       (arrow-region . ((classification . renderer-configured)))
       ;; The popup has its own geometry and does not affect the footprint of
       ;; the closed control.
       (popup-menu . ((footprint-effect . none)))))
   (capability-rules
    . (((when
         . ((capabilities-all . (items))
            (text-length-class . long)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'palette-selector
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 8) (height . 2)))
   (preferred . ((width . 12) (height . 2)))
   (useful-max . ((width . 16) (height . 2)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 8) (height . 2)))
       (standard . ((width . 12) (height . 2)))
       (extended . ((width . 16) (height . 2)))))
   (natural-geometry
    . ((form . horizontal-combo-box)
       (lines . single)))
   (capabilities
    . (items default-index justification enabled parameter-binding
             arrow-region popup-menu predefined-palette-set palette-callback))
   (content-dependent
    . ((items/text-length
        . ((effect . preferred-profile)
           (classification . descriptive-advisory)))
       (justification
        . ((footprint-effect . none)
           (minimum-footprint-effect . none)))
       (enabled . ((footprint-effect . none)))
       (parameter-binding . ((footprint-effect . none)))
       (default-index . ((footprint-effect . none)))
       (arrow-region . ((classification . renderer-configured)))
       (popup-menu . ((footprint-effect . none)))
       (predefined-palette-set . ((footprint-effect . none)))
       (palette-callback . ((footprint-effect . none)))))
   (capability-rules
    . (((when
         . ((capabilities-all . (items))
            (text-length-class . long)))
        (preferred-profile . extended))))))

(register-ui-metrics!
 'meter
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (variants
    . ((segmented-vertical
        . ((visual-min . ((width . 3) (height . 10)))
           (preferred . ((width . 4) (height . 14)))
           (useful-max . ((width . 5) (height . 18)))
           (visual-min-profile . compact)
           (preferred-profile . standard)
           (useful-max-profile . extended)
           (profiles
            . ((compact . ((width . 3) (height . 10)))
               (standard . ((width . 4) (height . 14)))
               (extended . ((width . 5) (height . 18)))))
           (natural-geometry
            . ((form . segmented-meter) (orientation . vertical)))
           (capabilities
            . (scale-type scale-labels num-segments level enabled))))
       (segmented-horizontal
        . ((visual-min . ((width . 10) (height . 3)))
           (preferred . ((width . 14) (height . 4)))
           (useful-max . ((width . 18) (height . 5)))
           (visual-min-profile . compact)
           (preferred-profile . standard)
           (useful-max-profile . extended)
           (profiles
            . ((compact . ((width . 10) (height . 3)))
               (standard . ((width . 14) (height . 4)))
               (extended . ((width . 18) (height . 5)))))
           (natural-geometry
            . ((form . segmented-meter) (orientation . horizontal)))
           (capabilities
            . (scale-type scale-labels num-segments level enabled))))
       (analog
        . ((visual-min . ((width . 6) (height . 5)))
           (preferred . ((width . 9) (height . 7)))
           (useful-max . ((width . 12) (height . 9)))
           (visual-min-profile . compact)
           (preferred-profile . standard)
           (useful-max-profile . extended)
           (profiles
            . ((compact . ((width . 6) (height . 5)))
               (standard . ((width . 9) (height . 7)))
               (extended . ((width . 12) (height . 9)))))
           (natural-geometry
            . ((form . analog-meter) (orientation . radial)))
           (capabilities . (scale-type scale-labels needle sharp level))))))
   (content-dependent
    . ((scale-type
        . ((canonical-values . (db linear vu))
           (footprint-effect . content-dependent-label-density)
           (structural-geometry-effect . none)
           (value-advisory
            . ((vu
                . ((variant . segmented-horizontal)
                   (preferred-profile . extended)))))))
       (num-segments . ((footprint-effect . none)))
       (level . ((footprint-effect . none)))
       (enabled . ((footprint-effect . none)))
       (sharp . ((footprint-effect . none)))))
   ;; Rules are advisory metadata and are not consumed by layout.
   (capability-rules
    . (((when
         . ((variant . segmented-vertical)
            (capabilities-all . (scale-labels))))
        (minimum-visual-profile . standard))
       ((when
         . ((variant . segmented-horizontal)
            (capabilities-all . (scale-labels))))
        (preferred-profile . standard))
       ((when
         . ((variant . analog)
            (capabilities-all . (scale-labels))))
        (preferred-profile . standard))))))

(register-ui-metrics!
 'scope
 '((technical-min
    . ((normative? . #f)
       (status . to-be-derived)
       (width . #f)
       (height . #f)))
   (visual-min . ((width . 8) (height . 6)))
   (preferred . ((width . 12) (height . 8)))
   (useful-max . ((width . 16) (height . 10)))
   (visual-min-profile . compact)
   (preferred-profile . standard)
   (useful-max-profile . extended)
   (profiles
    . ((compact . ((width . 8) (height . 6)))
       (standard . ((width . 12) (height . 8)))
       (extended . ((width . 16) (height . 10)))))
   (natural-geometry
    . ((form . waveform-scope)
       (orientation . horizontal)
       (aspect-class . moderately-panoramic)))
   (capabilities
    . (grid-style waveform amplitude-labels is-sharp glow-multiplier
                  runtime-signal))
   (content-dependent
    . ((grid-style
        . ((canonical-values . (radar minimal))
           (footprint-effect . none)))
       (waveform . ((footprint-effect . none)))
       (amplitude-labels
        . ((footprint-effect . none)
           (classification . structural-renderer-content)))
       (is-sharp . ((footprint-effect . none)))
       (glow-multiplier . ((footprint-effect . none)))
       (runtime-signal . ((footprint-effect . none)))))
   ;; Descriptive renderer geometry only. These fixed pixel regions do not
   ;; alter logical layout profiles and are not consumed by layout.
   (renderer-geometry
    . ((label-region . ((fixed-width-px . 30)))
       (plot-inset . ((fixed-px . 4)))))))
