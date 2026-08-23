(use-modules (oop goops)
             (srfi srfi-1)
             (generator-app code-generator)
             (generator-app ui-metrics)
             (generator-app topological-layout)
             (generator-app topological-normalizer))

(define (check label predicate)
  (unless predicate
    (error "Topological normalizer test failed" label)))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(define (entry-by-id entries id)
  (find (lambda (entry) (eq? (field entry 'id) id)) entries))

(define (rejected? thunk)
  (catch #t
    (lambda () (thunk) #f)
    (lambda args #t)))

(define grid (make <grid>))

(define scope
  (make <scope> #:id 'scope-main #:row 2 #:col 3
        #:row-span 99 #:col-span 98))
(define rotary
  (make <rotary-slider> #:id 'gain #:row 4 #:col 5))
(define toggle
  (make <normal-toggle-button> #:id 'enabled))
(define bypass
  (make <bypass-switch> #:id 'bypass))

(check 'explicit-real-dsl-type-mapping
       (and (eq? (dsl-component->metric-type scope) 'scope)
            (eq? (dsl-component->metric-type rotary) 'rotary-slider)
            (eq? (dsl-component->metric-type toggle) 'toggle-button)
            (eq? (dsl-component->metric-type bypass) 'bypass-switch)))

(let* ((normalized
        (normalize-topological-layout
         (list scope rotary toggle bypass) '() #:grid grid))
       (entries (field normalized 'entries))
       (scope-node (entry-by-id entries 'scope-main))
       (rotary-node (entry-by-id entries 'gain)))
  (check 'grid-default-normalized
         (and (= (field normalized 'screen-rows) 15)
              (= (field normalized 'screen-cols) 24)))
  (check 'preferred-profile-from-ui-metrics
         (and (eq? (field scope-node 'profile) 'standard)
              (eq? (field rotary-node 'profile) 'standard)))
  (check 'logical-id-and-hard-anchors
         (and (eq? (field scope-node 'id) 'scope-main)
              (= (field scope-node 'row) 2)
              (= (field scope-node 'col) 3)))
  (check 'non-variant-components
         (and (not (field scope-node 'variant))
              (not (field rotary-node 'variant))))
  (let ((warning (entry-by-id (field normalized 'warnings) 'scope-main)))
    (check 'legacy-span-conflict-reported
           (and (eq? (field warning 'kind) 'legacy-span-mismatch)
                (= (field warning 'legacy-row-span) 99)
                (= (field warning 'legacy-col-span) 98)
                (= (field warning 'metric-row-span) 8)
                (= (field warning 'metric-col-span) 12))))
  (let ((resolved (solve-normalized-topological-layout normalized)))
    (check 'legacy-spans-not-used-by-solver
           (and (= (field (entry-by-id resolved 'scope-main) 'rowSpan) 8)
                (= (field (entry-by-id resolved 'scope-main) 'colSpan) 12)))))

(let* ((analog (make <meter> #:id 'analog-meter #:style 'analog
                     #:orientation 'horizontal))
       (node (normalize-topological-component analog)))
  (check 'deducible-meter-analog-variant
         (and (eq? (field node 'type) 'meter)
              (eq? (field node 'variant) 'analog)
              (eq? (field node 'profile) 'standard))))

(let* ((vertical
        (normalize-topological-component
         (make <meter> #:id 'vertical-meter #:style 'segmented
               #:orientation 'vertical)))
       (horizontal
        (normalize-topological-component
         (make <meter> #:id 'horizontal-meter #:style 'segmented
               #:orientation 'horizontal)))
       (vertical-size (ui-profile 'meter 'segmented-vertical 'standard))
       (horizontal-size
        (ui-profile 'meter 'segmented-horizontal 'standard)))
  (check 'segmented-meter-orientation-variants
         (and (eq? (field vertical 'variant) 'segmented-vertical)
              (eq? (field horizontal 'variant) 'segmented-horizontal)))
  (check 'segmented-meter-standard-profiles
         (and (= (field vertical-size 'width) 4)
              (= (field vertical-size 'height) 14)
              (= (field horizontal-size 'width) 14)
              (= (field horizontal-size 'height) 4))))

(let* ((horizontal
        (normalize-topological-component
         (make <linear-slider> #:id 'horizontal-slider
               #:orientation 'horizontal)))
       (vertical
        (normalize-topological-component
         (make <linear-slider> #:id 'vertical-slider
               #:orientation 'vertical))))
  (check 'linear-slider-existing-variant-information
         (and (eq? (field horizontal 'variant) 'horizontal)
              (eq? (field vertical 'variant) 'vertical)
              (eq? (field horizontal 'profile) 'standard)
              (eq? (field vertical 'profile) 'standard))))

(check 'missing-logical-id-rejected
       (rejected?
        (lambda ()
          (normalize-topological-component (make <scope>)))))

;; String logical ids are interned losslessly; no C++ identifier normalization
;; or allocation is involved.
(let ((node (normalize-topological-component
             (make <scope> #:id "logical.scope"))))
  (check 'string-logical-id-preserved-losslessly
         (eq? (field node 'id) 'logical.scope)))

(let* ((a (make <normal-toggle-button> #:id 'a))
       (b (make <normal-toggle-button> #:id 'b))
       (declarations
        (list (lt:align-top 'a 'b)
              (lt:group 'pair #:layout 'horizontal #:cohesion 'strong
                        #:area '(top-right bottom-left) 'a 'b)))
       (normalized
        (normalize-topological-layout (list b a) declarations #:grid grid))
       (entries (field normalized 'entries))
       (group (entry-by-id entries 'pair))
       (resolved (solve-normalized-topological-layout normalized))
       (resolved-a (entry-by-id resolved 'a))
       (resolved-b (entry-by-id resolved 'b))
       (resolved-group (entry-by-id resolved 'pair)))
  (check 'separate-alignment-and-group-declarations
         (and (eq? (field group 'kind) 'group)
              (eq? (field group 'cohesion) 'strong)
              (equal? (field group 'area) '(top-right bottom-left))))
  (check 'forward-reference-and-end-to-end-solve
         (and (= (field resolved-a 'row) (field resolved-b 'row))
              (= (field resolved-b 'col)
                 (+ (field resolved-a 'col) (field resolved-a 'colSpan)))
              (equal? (field resolved-group 'members) '(a b)))))

(let* ((a (make <normal-toggle-button> #:id 'simple-a))
       (b (make <normal-toggle-button> #:id 'simple-b))
       (normalized
        (normalize-topological-layout
         (list a b)
         (list (lt:group 'simple-area #:layout 'horizontal
                         #:area 'top-right 'simple-a 'simple-b))
         #:grid grid)))
  (check 'simple-area-declaration
         (eq? (field (entry-by-id (field normalized 'entries) 'simple-area)
                     'area)
              'top-right)))

(display "topological-normalizer-test: PASS\n")
