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

(let* ((component
        (make <palette-label> #:id 'palette-title #:text "Theme"
              #:row 2 #:col 3 #:row-span 1 #:col-span 2
              #:enable #t #:default-theme 3))
       (normalized
        (normalize-topological-layout (list component) '() #:grid grid))
       (node (entry-by-id (field normalized 'entries) 'palette-title))
       (resolved
        (entry-by-id (solve-normalized-topological-layout normalized)
                     'palette-title)))
  (check 'palette-label-dedicated-metric-type
         (and (eq? (dsl-component->metric-type component) 'palette-label)
              (eq? (field node 'type) 'palette-label)
              (eq? (field node 'profile) 'standard)
              (not (field node 'variant))))
  (check 'palette-label-normalize-and-solve
         (and (= (field resolved 'row) 2)
              (= (field resolved 'col) 3)
              (= (field resolved 'rowSpan) 3)
              (= (field resolved 'colSpan) 12))))

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
                (= (field warning 'metric-row-span) 10)
                (= (field warning 'metric-col-span) 18))))
  (let ((resolved (solve-normalized-topological-layout normalized)))
    (check 'legacy-spans-not-used-by-solver
           (and (= (field (entry-by-id resolved 'scope-main) 'rowSpan) 10)
                (= (field (entry-by-id resolved 'scope-main) 'colSpan) 18)))))

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
         (and (= (field vertical-size 'width) 1)
              (= (field vertical-size 'height) 14)
              (= (field horizontal-size 'width) 14)
              (= (field horizontal-size 'height) 3))))

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
                        #:area '(center center) 'a 'b)))
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
              (equal? (field group 'area) '(center center))))
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

;; Experimental positional bridge: declarations are consumed by the
;; normalizer and attached to the target lt:node before solving.
(let* ((a (make <text-button> #:id 'bridge-a))
       (b (make <text-button> #:id 'bridge-b))
       (c (make <text-button> #:id 'bridge-c))
       (d (make <text-button> #:id 'bridge-d))
       (e (make <text-button> #:id 'bridge-e))
       (meter (make <meter> #:id 'bridge-meter #:style 'analog))
       (declarations
        (list
         ;; Forward references and multiple declarations for one target are
         ;; concatenated in declaration order.
         (lt:constrain 'bridge-b (lt:next-right-of 'bridge-a))
         (lt:constrain 'bridge-b (lt:below 'bridge-e))
         (lt:constrain 'bridge-c
                       (lt:right-of 'bridge-b)
                       (lt:below 'bridge-a))
         (lt:constrain 'bridge-d (lt:next-below 'bridge-a))
         (lt:constrain 'bridge-e (lt:above 'bridge-a))
         (lt:constrain 'bridge-meter (lt:left-of 'bridge-c))
         (lt:align-top 'bridge-a 'bridge-b)
         (lt:group 'bridge-pair #:layout 'horizontal
                   #:cohesion 'strong
                   #:area '(center center)
                   'bridge-a 'bridge-b)))
       (normalized
        (normalize-topological-layout
         (list meter e d c b a) declarations #:grid grid))
       (entries (field normalized 'entries))
       (node-b (entry-by-id entries 'bridge-b))
       (resolved (solve-normalized-topological-layout normalized))
       (ra (entry-by-id resolved 'bridge-a))
       (rb (entry-by-id resolved 'bridge-b))
       (rc (entry-by-id resolved 'bridge-c))
       (rd (entry-by-id resolved 'bridge-d))
       (re (entry-by-id resolved 'bridge-e))
       (rm (entry-by-id resolved 'bridge-meter)))
  (check 'node-constraints-declarations-consumed
         (and (= (length (field node-b 'constraints)) 2)
              (not (find (lambda (entry)
                           (eq? (field entry 'kind) 'node-constraints))
                         entries))))
  (check 'next-right-of-via-declaration
         (= (field rb 'col) (+ (field ra 'col) (field ra 'colSpan))))
  (check 'right-of-and-below-via-declaration
         (and (>= (field rc 'col)
                  (+ (field rb 'col) (field rb 'colSpan)))
              (>= (field rc 'row)
                  (+ (field ra 'row) (field ra 'rowSpan)))))
  (check 'next-below-via-declaration
         (= (field rd 'row) (+ (field ra 'row) (field ra 'rowSpan))))
  (check 'above-via-declaration
         (<= (+ (field re 'row) (field re 'rowSpan)) (field ra 'row)))
  (check 'variant-aware-node-constraint
         (and (eq? (field rm 'variant) 'analog)
              (<= (+ (field rm 'col) (field rm 'colSpan))
                  (field rc 'col)))))

;; Direct semantic equivalence with a manually constrained lt:node.
(let* ((manual
        (lt:solve
         (list (lt:node 'equiv-a 'text-button 'standard #:row 2 #:col 3)
               (lt:node 'equiv-b 'text-button 'standard
                        #:constraints (list (lt:next-right-of 'equiv-a))))))
       (a (make <text-button> #:id 'equiv-a #:row 2 #:col 3))
       (b (make <text-button> #:id 'equiv-b))
       (normalized
        (normalize-topological-layout
         (list a b)
         (list (lt:constrain 'equiv-b (lt:next-right-of 'equiv-a)))
         #:grid grid))
       (adapted (solve-normalized-topological-layout normalized)))
  (check 'manual-node-declaration-equivalence
         (every
          (lambda (id)
            (let ((left (entry-by-id manual id))
                  (right (entry-by-id adapted id)))
              (every (lambda (key) (= (field left key) (field right key)))
                     '(row col rowSpan colSpan))))
          '(equiv-a equiv-b))))

(check 'node-constraints-missing-target-rejected
       (rejected?
        (lambda ()
          (normalize-topological-layout
           (list (make <text-button> #:id 'only-node))
           (list (lt:constrain 'missing (lt:right-of 'only-node)))
           #:grid grid))))

(let* ((component (make <text-button> #:id 'normalized-area-node))
       (normalized
        (normalize-topological-layout
         (list component)
         (list (lt:place-in-area 'normalized-area-node 'top))
         #:grid grid))
       (resolved (solve-normalized-topological-layout normalized))
       (node (entry-by-id resolved 'normalized-area-node)))
  (check 'node-area-declaration-normalized
         (and (= (field node 'col) 9)
              (= (field node 'row) 1)
              (= (field node 'colSpan) 8)
              (= (field node 'rowSpan) 3))))

(check 'node-constraints-zero-rejected
       (rejected? (lambda () (lt:constrain 'only-node))))
(check 'node-constraints-non-symbol-target-rejected
       (rejected?
        (lambda () (lt:constrain "only-node" (lt:right-of 'other)))))
(check 'node-constraints-non-positional-rejected
       (rejected?
        (lambda ()
          (lt:constrain 'only-node (lt:align-left 'only-node 'other)))))
(check 'node-constraints-malformed-rejected
       (rejected?
        (lambda ()
          (normalize-topological-layout
           (list (make <text-button> #:id 'malformed-node))
           (list '((kind . node-constraints)
                   (node . malformed-node)
                   (constraints . (((relation . right-of))))))
           #:grid grid))))

(display "topological-normalizer-test: PASS\n")
