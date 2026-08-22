(define-module (generator-app ui-metrics)
  #:use-module (srfi srfi-1)
  #:export (register-ui-metrics!
            ui-metrics
            ui-profile))

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

(define (ui-profile type profile)
  (let* ((metrics (ui-metrics type))
         (profiles (and metrics (metric-ref metrics 'profiles)))
         (entry (and profiles (assoc profile profiles))))
    (and entry (cdr entry))))

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
