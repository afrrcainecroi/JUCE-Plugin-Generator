(define-module (generator-app generation-orchestration)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app cpp-generation)
  #:use-module (generator-app layout)
  #:use-module (generator-app topological-normalizer)
  #:use-module (generator-app physical-layout)
  #:use-module (generator-app discrete-grid-layout)
  #:use-module (generator-app standard-plugin-shell)
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
	    adapt-discrete-grid-layout
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

(define (build-topological-shadow
         models
         grid-model
         topology-declarations)

  (let* ((screen-model
          (generation-screen))

         (ui-scale
          (and screen-model
               (assoc-ref screen-model 'ui-scale)))

         (ui-size
          (and screen-model
               (assoc-ref screen-model 'ui-size)))

         (extended-grid-model
          `((rows . ,(field grid-model 'rows))
            (cols . ,(field grid-model 'cols))
            (show-grid . ,(field grid-model 'show-grid))
            (ui-scale . ,ui-scale)
            (ui-size . ,ui-size)))

         (normalized
          (normalize-topological-model-layout
           models
           topology-declarations
           #:grid-model extended-grid-model))

         (resolved
          (solve-normalized-topological-layout
           normalized)))

    `((normalized . ,normalized)
      (resolved . ,resolved)
      (comparison .
                  ,(compare-legacy-topological-layout
                    models
                    resolved)))))

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

;; ================================================================
;; DISCRETE GRID LAYOUT -> EXISTING GRID EMITTER CONTRACT
;;
;; This is a pure adapter.
;;
;; Input:
;;   - registered DSL component models
;;   - DiscreteGridLayout
;;   - current generator grid model (show-grid only)
;;
;; Output:
;;   - grid-model expected by generate-grid-code
;;   - layout-components expected by generate-grid-code
;;
;; IMPORTANT:
;;   PhysicalLayout has already resolved final geometry.
;;   Legacy margins MUST NOT be applied again here.
;; ================================================================

(define (adapt-discrete-grid-layout
         models
         discrete-layout
         generator-grid-model)

  (unless (eq? (field discrete-layout 'kind)
               'discrete-grid-layout)

    (error
      "Physical grid adapter requires DiscreteGridLayout"
      discrete-layout))


  (let* ((discrete-components
          (field discrete-layout 'components))

         (rows
          (field discrete-layout 'rows))

         (cols
          (field discrete-layout 'cols))

         (row-tracks
          (field discrete-layout 'row-tracks))

         (col-tracks
          (field discrete-layout 'col-tracks))

         (grid-model
          `((rows . ,rows)
            (cols . ,cols)
            (row-tracks . ,row-tracks)
            (col-tracks . ,col-tracks)
            (show-grid .
                       ,(field generator-grid-model
                               'show-grid))))

         (layout-components
          (map

            (lambda (model)

              (let* ((id-value
                      (field model 'id))

                     (id
                      (if (string? id-value)
                          (string->symbol id-value)
                          id-value))

                     (rectangle
                      (find
                        (lambda (entry)
                          (eq? (field entry 'id)
                               id))
                        discrete-components)))

                (unless rectangle

                  (error
                    "DiscreteGridLayout is missing a registered DSL component"
                    id))

                `((var . ,(field model 'var))
                  (row . ,(field rectangle 'row))
                  (col . ,(field rectangle 'col))
                  (rowSpan . ,(field rectangle 'rowSpan))
                  (colSpan . ,(field rectangle 'colSpan)))))

            models)))

    `((grid-model . ,grid-model)
      (layout-components . ,layout-components))))

(define* (prepare-generation-layout
          #:key
          (layout-mode 'legacy)
          (topology-declarations '()))

  (unless (memq layout-mode '(legacy topological physical))
    (error "Unknown generator layout mode" layout-mode))

  (let* ((models
          (reverse
            (generation-components)))

         (grid-model
          (generation-grid))

         (screen-model
          (generation-screen))

         (shadow
          (build-topological-shadow
            models
            grid-model
            topology-declarations)))

    (case layout-mode

      ((legacy)

       `((mode . legacy)
         (shadow . ,shadow)
         (refinement . #f)
         (physical-layout . #f)
         (discrete-layout . #f)
         (adapter . #f)))


      ((topological)

       `((mode . topological)

         (shadow . ,shadow)

         (refinement .
                     ,(refine-topological-grid
                        shadow
                        models
                        grid-model))

         (physical-layout . #f)
         (discrete-layout . #f)
         (adapter . #f)))


      ((physical)

       (let* ((normalized
               (field shadow 'normalized))

	      (screen-width
	       (field screen-model 'width))

	      (screen-ratio
	       (field screen-model 'ratio))

	      (exact-screen-ratio
	       (if (exact? screen-ratio)
		   screen-ratio
		   (rationalize
		    (inexact->exact screen-ratio)
		    1/1000000)))

	      (screen-height
	       (/ screen-width
		  exact-screen-ratio))

	      (ui-scale
	       (field screen-model 'ui-scale))

              (ui-size
               (field screen-model 'ui-size))

              (policy
               (standard-physical-layout-policy))

              (physical-layout
               (pl:solve
                 normalized
                 screen-width
                 screen-height
                 policy
                 #:base-unit-px 12
                 #:ui-scale ui-scale
                 #:ui-size ui-size))

              (discrete-layout
               (dgl:discretize
                 physical-layout))

              (adapter
               (adapt-discrete-grid-layout
                 models
                 discrete-layout
                 grid-model)))

         `((mode . physical)

           (shadow . ,shadow)

           (refinement . #f)

           (physical-layout .
                            ,physical-layout)

           (discrete-layout .
                            ,discrete-layout)

           (adapter .
                    ,adapter)))))))

(define* (generate-selected-grid-code
          #:key
          (layout-mode 'legacy)
          (topology-declarations '()))

  (case layout-mode

    ((legacy)

     (generate-grid-code))


    ((topological)

     (let* ((plan
             (prepare-generation-layout
               #:layout-mode layout-mode
               #:topology-declarations topology-declarations))

            (refinement
             (field plan 'refinement)))

       (generate-grid-code
         #:grid-model
         (field refinement 'grid-model)

         #:layout-components
         (field refinement 'layout-components))))


    ((physical)

     (let* ((plan
             (prepare-generation-layout
               #:layout-mode layout-mode
               #:topology-declarations topology-declarations))

            (adapter
             (field plan 'adapter)))

       (generate-grid-code
         #:grid-model
         (field adapter 'grid-model)

         #:layout-components
         (field adapter 'layout-components))))


    (else

     (error
       "Unknown generator layout mode"
       layout-mode))))

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
