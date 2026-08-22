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
