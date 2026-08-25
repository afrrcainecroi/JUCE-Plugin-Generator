(use-modules (ice-9 textual-ports)
             (ice-9 string-fun)
             (json)
             (oop goops)
             (srfi srfi-1)
             (generator-app code-generator)
             (generator-app generation-state)
             (generator-app generation-orchestration)
             (generator-app topological-layout)
             (generator-app topological-normalizer))

(define (check label predicate)
  (unless predicate
    (error "Topological generated layout test failed" label)))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(define (entry-by-id entries id)
  (find (lambda (entry) (eq? (field entry 'id) id)) entries))

(define (json-from-grid-code code)
  (let* ((prefix "juce::String jsonString = R\"(")
         (start0 (string-contains code prefix))
         (start (+ start0 (string-length prefix)))
         (end (string-contains code ")\";" start)))
    (json-string->scm (substring code start end))))

(define (json-field object key)
  (or (assoc-ref object key)
      (assoc-ref object (symbol->string key))))

(define (json-component-by-var components var)
  (find (lambda (component)
          (equal? (json-field component 'var) var))
        (vector->list components)))

(define (node-entry? entry)
  (and (field entry 'type) (field entry 'row) (field entry 'col)))

(define (relative-geometry-preserved? original discrete screen-rows
                                        screen-cols refined-rows refined-cols)
  (and (= (/ (- (field original 'col) 1) screen-cols)
          (/ (- (field discrete 'col) 1) refined-cols))
       (= (/ (field original 'colSpan) screen-cols)
          (/ (field discrete 'colSpan) refined-cols))
       (= (/ (- (field original 'row) 1) screen-rows)
          (/ (- (field discrete 'row) 1) refined-rows))
       (= (/ (field original 'rowSpan) screen-rows)
          (/ (field discrete 'rowSpan) refined-rows))))

(reset-generation-state!)
(make <grid> #:rows 15 #:cols 144 #:show-grid #t)

;; Deliberately wrong legacy spans prove that topological emission consumes
;; ui-metrics.  The even/odd center alignment creates col=3/2 exactly.
(make <text-button> #:id 'even #:row 1 #:col 1
      #:row-span 91 #:col-span 92)
(make <rotary-slider> #:id 'odd #:row-span 93 #:col-span 94
      #:parameter-id "odd" #:parameter-name "Odd"
      #:processor-reference "odd")
(make <meter> #:id 'meter-h #:style 'segmented #:orientation 'horizontal
      #:row 10 #:col 1 #:row-span 95 #:col-span 96)
(make <palette-label> #:id 'palette-title #:text "Theme"
      #:row 10 #:col 15 #:row-span 97 #:col-span 98)
(make <normal-toggle-button> #:id 'future-b
      #:parameter-id "futureB" #:parameter-name "Future B"
      #:processor-reference "futureB"
      #:row-span 89 #:col-span 88)
(make <normal-toggle-button> #:id 'future-a
      #:parameter-id "futureA" #:parameter-name "Future A"
      #:processor-reference "futureA"
      #:row-span 87 #:col-span 86)

(define declarations
  (list
   ;; Explicit positional bridge declarations: these are not supplied by a
   ;; group or anchor.
   (lt:constrain 'future-b (lt:next-right-of 'future-a))
   (lt:constrain 'palette-title (lt:right-of 'meter-h))
   (lt:align-center-x 'even 'odd)
   (lt:align-top 'future-a 'future-b)
   (lt:group 'hierarchical-group
             #:layout 'horizontal
             #:cohesion 'strong
             #:area '(top-right bottom-left)
             'future-a 'future-b)))

(define plan
  (prepare-generation-layout
   #:layout-mode 'topological
   #:topology-declarations declarations))
(define shadow (field plan 'shadow))
(define refinement (field plan 'refinement))
(define original (field refinement 'original-resolved))
(define discrete (field refinement 'discrete-resolved))
(define original-nodes (filter node-entry? original))
(define discrete-nodes (filter node-entry? discrete))

(check 'rational-resolved-ir
       (and (= (field (entry-by-id original 'odd) 'col) 3/2)
            (exact? (field (entry-by-id original 'odd) 'col))))
(check 'minimal-independent-refinement-factors
       (and (= (field refinement 'dx) 2)
            (= (field refinement 'dy) 1)))
(check 'one-based-final-screen-lines
       (and (= (+ (field refinement 'screen-cols) 1)
               (+ 1 (* (field refinement 'dx) 144)))
            (= (+ (field refinement 'screen-rows) 1)
               (+ 1 (* (field refinement 'dy) 15)))))
(check 'hierarchical-area-placement-resolved
       (= (field (entry-by-id original 'future-a) 'row) 2))
(check 'discrete-ir-integers-only
       (every
        (lambda (node)
          (every exact-integer?
                 (map (lambda (key) (field node key))
                      '(row col rowSpan colSpan))))
        discrete-nodes))
(check 'exact-relative-geometry-invariant
       (every
        (lambda (node)
          (relative-geometry-preserved?
           node (entry-by-id discrete (field node 'id))
            15 144
           (field refinement 'screen-rows)
           (field refinement 'screen-cols)))
        original-nodes))

(let* ((group (entry-by-id discrete 'hierarchical-group))
       (a (entry-by-id discrete 'future-a))
       (b (entry-by-id discrete 'future-b)))
  (check 'group-cohesion-alignment-area-applied
         (and (= (field a 'row) (field b 'row))
              (= (field b 'col) (+ (field a 'col) (field a 'colSpan)))
              (equal? (field group 'area) '(top-right bottom-left))
              (eq? (field group 'cohesion) 'strong))))
(check 'explicit-positional-declarations-applied
       (let ((meter (entry-by-id original 'meter-h))
             (palette (entry-by-id original 'palette-title)))
         (>= (field palette 'col)
             (+ (field meter 'col) (field meter 'colSpan)))))

(define legacy-code (generate-grid-code))
(define selected-legacy-code
  (generate-selected-grid-code
   #:layout-mode 'legacy
   #:topology-declarations declarations))
(check 'legacy-byte-identical (string=? legacy-code selected-legacy-code))

(define topological-code
  (generate-selected-grid-code
   #:layout-mode 'topological
   #:topology-declarations declarations))
(define emitted-json (json-from-grid-code topological-code))
(define emitted-grid (json-field emitted-json 'grid))
(define emitted-components (json-field emitted-json 'components))

(check 'refined-grid-tracks-emitted
       (and (= (json-field emitted-grid 'rows) 15)
            (= (json-field emitted-grid 'cols) 288)))
(check 'json-layout-coordinates-are-integers
       (every
        (lambda (component)
          (every integer?
                 (map (lambda (key) (json-field component key))
                      '(row col rowSpan colSpan))))
        (vector->list emitted-components)))

(for-each
 (lambda (model)
   (let* ((id-value (field model 'id))
          (id (if (string? id-value) (string->symbol id-value) id-value))
          (node (entry-by-id discrete id))
          (component
           (json-component-by-var emitted-components (field model 'var))))
     (check
      (string->symbol (string-append "emitted-resolved-" (symbol->string id)))
      (and (= (json-field component 'row) (field node 'row))
           (= (json-field component 'col) (field node 'col))
           (= (json-field component 'rowSpan) (field node 'rowSpan))
           (= (json-field component 'colSpan) (field node 'colSpan))))))
 (reverse (generation-components)))

(let ((meter (entry-by-id discrete 'meter-h))
      (palette (entry-by-id discrete 'palette-title)))
  (check 'variant-aware-meter-footprint
         (and (eq? (field meter 'variant) 'segmented-horizontal)
              (= (field meter 'rowSpan) 3)
              (= (field meter 'colSpan) (* 2 14))))
  (check 'palette-label-footprint
         (and (eq? (field palette 'type) 'palette-label)
              (= (field palette 'rowSpan) 3)
              (= (field palette 'colSpan) (* 2 12)))))

;; Integer-only coordinates require no refinement and remain structurally
;; identical after the exact transformation.
(reset-generation-state!)
(make <grid> #:rows 15 #:cols 144 #:show-grid #t)
(make <scope> #:id 'integer-scope #:row 2 #:col 3)
(define integer-plan (prepare-generation-layout #:layout-mode 'topological))
(define integer-refinement (field integer-plan 'refinement))
(check 'integer-case-no-refinement
       (and (= (field integer-refinement 'dx) 1)
            (= (field integer-refinement 'dy) 1)
            (equal? (field integer-refinement 'original-resolved)
                    (field integer-refinement 'discrete-resolved))))

(display "topological-generated-layout-test: PASS (Dx=2 Dy=1)\n")
