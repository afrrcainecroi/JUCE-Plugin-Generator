(define-module (generator-app generation-orchestration)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app cpp-generation)
  #:use-module (generator-app layout)
  #:use-module (generator-app topological-normalizer)
  #:export (generate-member-declarations
            generate-constructor-code
            generate-attachment-declarations
            generate-attachment-code
            generate-parameter-code
            generate-dparams-code
            generate-getparams-code
            generate-valueparams-code
            generate-destroy-code
            compare-legacy-topological-layout
            build-topological-shadow
            run-generation-topological-shadow
            refine-topological-grid
            prepare-generation-layout
            generate-selected-grid-code))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(define (resolved-node-by-id entries id)
  (find (lambda (entry)
          (and (field entry 'type)
               (eq? (field entry 'id) id)))
        entries))

(define (topological-difference key legacy-value topological-value)
  (and (not (equal? legacy-value topological-value))
       `(,key . ((legacy . ,legacy-value)
                 (topological . ,topological-value)))))

(define (compare-one-layout model resolved)
  (let* ((id-value (field model 'id))
         (id (if (string? id-value) (string->symbol id-value) id-value))
         (node (resolved-node-by-id resolved id)))
    (unless node
      (error "Resolved topological IR is missing a registered DSL component" id))
    (let* ((legacy-row (field model 'row))
           (legacy-col (field model 'col))
           (legacy-row-span (field model 'rowSpan))
           (legacy-col-span (field model 'colSpan))
           (topological-row (field node 'row))
           (topological-col (field node 'col))
           (topological-row-span (field node 'rowSpan))
           (topological-col-span (field node 'colSpan))
           (position-differences
            (filter-map identity
                        (list
                         (topological-difference
                          'row legacy-row topological-row)
                         (topological-difference
                          'col legacy-col topological-col))))
           (size-differences
            (filter-map identity
                        (list
                         (topological-difference
                          'row-span legacy-row-span topological-row-span)
                         (topological-difference
                          'col-span legacy-col-span topological-col-span)))))
      `((id . ,id)
        (legacy . ((row . ,legacy-row)
                   (col . ,legacy-col)
                   (row-span . ,legacy-row-span)
                   (col-span . ,legacy-col-span)))
        (topological . ((row . ,topological-row)
                        (col . ,topological-col)
                        (row-span . ,topological-row-span)
                        (col-span . ,topological-col-span)))
        (differences . ((position-difference . ,position-differences)
                        (size-difference . ,size-differences)))))))

(define (compare-legacy-topological-layout models resolved)
  (map (lambda (model) (compare-one-layout model resolved)) models))

(define (build-topological-shadow models grid-model topology-declarations)
  (let* ((normalized
          (normalize-topological-model-layout
           models topology-declarations #:grid-model grid-model))
         (resolved (solve-normalized-topological-layout normalized)))
    `((normalized . ,normalized)
      (resolved . ,resolved)
      (comparison . ,(compare-legacy-topological-layout models resolved)))))

;; This real-generator boundary only reads generation state.  Its diagnostic
;; result is never fed to any legacy C++ emitter.
(define* (run-generation-topological-shadow
          #:optional (topology-declarations '()))
  (build-topological-shadow
   (reverse (generation-components))
   (generation-grid)
   topology-declarations))

(define (replace-field alist key value)
  (map (lambda (entry)
         (if (eq? (car entry) key) (cons key value) entry))
       alist))

(define (replace-layout-fields entry row col row-span col-span)
  (replace-field
   (replace-field
    (replace-field
     (replace-field entry 'row row)
     'col col)
    'rowSpan row-span)
   'colSpan col-span))

(define (resolved-node? entry)
  (and (field entry 'type)
       (field entry 'row)
       (field entry 'col)))

(define (axis-refinement-factor nodes key)
  (fold (lambda (node factor)
          (let ((coordinate (field node key)))
            (unless (and (number? coordinate) (exact? coordinate))
              (error "Topological grid refinement requires exact coordinates"
                     key coordinate))
            (lcm factor (denominator coordinate))))
        1
        nodes))

(define (refine-coordinate coordinate factor)
  (+ 1 (* factor (- coordinate 1))))

(define (refine-span span factor)
  (* factor span))

(define (refine-entry entry dx dy)
  (if (and (field entry 'row) (field entry 'col)
           (field entry 'rowSpan) (field entry 'colSpan))
      (let ((row (refine-coordinate (field entry 'row) dy))
            (col (refine-coordinate (field entry 'col) dx))
            (row-span (refine-span (field entry 'rowSpan) dy))
            (col-span (refine-span (field entry 'colSpan) dx)))
        (unless (and (exact-integer? row) (exact-integer? col)
                     (exact-integer? row-span) (exact-integer? col-span))
          (error "Exact topological grid refinement did not produce integers"
                 (field entry 'id) row col row-span col-span))
        (replace-layout-fields entry row col row-span col-span))
      entry))

(define (discrete-layout-components models discrete-resolved)
  (map
   (lambda (model)
     (let* ((id-value (field model 'id))
            (id (if (string? id-value) (string->symbol id-value) id-value))
            (node (resolved-node-by-id discrete-resolved id)))
       (unless node
         (error "Discrete topological IR is missing a DSL component" id))
       `((var . ,(field model 'var))
         (row . ,(field node 'row))
         (col . ,(field node 'col))
         (rowSpan . ,(field node 'rowSpan))
         (colSpan . ,(field node 'colSpan))
         (margin-tb . ,(field model 'margin-tb))
         (margin-lr . ,(field model 'margin-lr)))))
   models))

(define (refine-topological-grid shadow models grid-model)
  (let* ((resolved (field shadow 'resolved))
         (nodes (filter resolved-node? resolved))
         (dx (axis-refinement-factor nodes 'col))
         (dy (axis-refinement-factor nodes 'row))
         (discrete-resolved
          (map (lambda (entry) (refine-entry entry dx dy)) resolved))
         (screen-cols (* dx (field (field shadow 'normalized) 'screen-cols)))
         (screen-rows (* dy (field (field shadow 'normalized) 'screen-rows)))
         (discrete-grid
          `((rows . ,screen-rows)
            (cols . ,screen-cols)
            (show-grid . ,(field grid-model 'show-grid))))
         (layout-components
          (discrete-layout-components models discrete-resolved)))
    `((dx . ,dx)
      (dy . ,dy)
      (screen-rows . ,screen-rows)
      (screen-cols . ,screen-cols)
      (original-resolved . ,resolved)
      (discrete-resolved . ,discrete-resolved)
      (grid-model . ,discrete-grid)
      (layout-components . ,layout-components))))

(define* (prepare-generation-layout
          #:key
          (layout-mode 'legacy)
          (topology-declarations '()))
  (unless (memq layout-mode '(legacy topological))
    (error "Unknown generator layout mode" layout-mode))
  (let* ((models (reverse (generation-components)))
         (grid-model (generation-grid))
         (shadow (build-topological-shadow
                  models grid-model topology-declarations)))
    (if (eq? layout-mode 'legacy)
        `((mode . legacy) (shadow . ,shadow) (refinement . #f))
        `((mode . topological)
          (shadow . ,shadow)
          (refinement . ,(refine-topological-grid
                           shadow models grid-model))))))

(define* (generate-selected-grid-code
          #:key
          (layout-mode 'legacy)
          (topology-declarations '()))
  (if (eq? layout-mode 'legacy)
      (generate-grid-code)
      (let* ((plan (prepare-generation-layout
                    #:layout-mode layout-mode
                    #:topology-declarations topology-declarations))
             (refinement (field plan 'refinement)))
        (generate-grid-code
         #:grid-model (field refinement 'grid-model)
         #:layout-components (field refinement 'layout-components)))))

(define (generate-member-declarations)
  (apply string-append
         (map model->member-declaration
              (reverse (generation-components)))))

(define (generate-constructor-code)
  (apply string-append
         (map model->constructor-code
              (reverse (generation-components)))))

(define (generate-attachment-declarations)
  (apply string-append
         (map model->attachment-declaration
              (reverse (generation-components)))))

(define (generate-attachment-code)
  (apply string-append
         (map model->attachment-code
              (reverse (generation-components)))))

(define (generate-parameter-code)
  (apply string-append
         (map model->parameter-code
              (reverse (generation-components)))))

(define (generate-dparams-code)
  (apply string-append
         (map model->dparams-code
              (reverse (generation-components)))))

(define (generate-getparams-code)
  (apply string-append
         (map model->getparams-code
              (reverse (generation-components)))))

(define (generate-valueparams-code)
  (apply string-append
         (map model->valueparams-code
              (reverse (generation-components)))))

(define (generate-destroy-code)
  (apply string-append
         (map model->destroy-code
              (reverse (generation-components)))))
