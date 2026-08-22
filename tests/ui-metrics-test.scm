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

(display "ui-metrics-test: PASS\n")
