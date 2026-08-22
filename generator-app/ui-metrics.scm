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
