(define-module (generator-app topological-normalizer)
  #:use-module (ice-9 optargs)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app dsl-model)
  #:use-module (generator-app layout)
  #:use-module (generator-app ui-metrics)
  #:use-module (generator-app topological-layout)
  #:export (dsl-component->metric-type
            dsl-model->metric-type
            normalize-topological-component
            normalize-topological-model
            normalize-topological-layout
            normalize-topological-model-layout
            solve-normalized-topological-layout))

;; This module is the only adapter between concrete DSL objects and the
;; experimental topological IR. Neither side needs knowledge of the other's
;; representation beyond its public conversion/query API.

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(define (metric-type-for-dsl-type type)
  (case type
    ((rotary-slider) 'rotary-slider)
    ((linear-slider) 'linear-slider)
    ((text-button) 'text-button)
    ((toggle-button) 'toggle-button)
    ((switch) 'switch)
    ((bypass-switch) 'bypass-switch)
    ((label) 'label)
    ((header) 'header)
    ((footer) 'footer)
    ((link) 'link)
    ((palette-label) 'palette-label)
    ((selector) 'selector)
    ((palette-selector) 'palette-selector)
    ((meter) 'meter)
    ((scope) 'scope)
    (else
     (error "DSL component has no supported metric TYPE mapping"
            type))))

(define (dsl-component->metric-type component)
  (metric-type-for-dsl-type (component-type component)))

;; Registered generation models retain the semantic DSL TYPE.  Keeping this
;; entry point here lets the shadow pipeline reuse the exact same explicit
;; mapping without teaching the solver about DSL model representation.
(define (dsl-model->metric-type model)
  (metric-type-for-dsl-type (field model 'type)))

(define (normalize-logical-id id)
  (cond
   ((symbol? id) id)
   ;; This is a lossless identity adaptation, not C++ identifier allocation or
   ;; sanitization. Topological declarations use the resulting symbol.
   ((string? id) (string->symbol id))
   ((not id) (error "Topological DSL component requires a logical id"))
   (else (error "Unsupported DSL logical id representation" id))))

(define (component-metric-variant model metric-type)
  (case metric-type
    ((linear-slider)
     (let ((orientation (field model 'orientation)))
       (unless (memq orientation '(horizontal vertical))
         (error "Cannot derive linear-slider metric variant" orientation))
       orientation))
    ((meter)
     (case (field model 'style)
       ((analog) 'analog)
       ((segmented)
        (case (field model 'orientation)
          ((vertical) 'segmented-vertical)
          ((horizontal) 'segmented-horizontal)
          (else
           (error "Cannot derive segmented meter metric variant"
                  (field model 'id) (field model 'orientation)))))
       (else
        (error "Cannot derive meter metric variant"
               (field model 'id) (field model 'style)))))
    (else #f)))

(define (metric-contract metric-type variant)
  (let ((metrics (ui-metrics metric-type)))
    (unless metrics
      (error "Missing UI metrics for normalized DSL TYPE" metric-type))
    (if variant
        (let* ((variants (field metrics 'variants))
               (entry (and variants (assoc variant variants))))
          (unless entry
            (error "Missing UI metrics variant for normalized DSL component"
                   metric-type variant))
          (cdr entry))
        (begin
          (when (field metrics 'variants)
            (error "Variant-aware metric TYPE requires a derived variant"
                   metric-type))
          metrics))))

(define (preferred-metric-profile metric-type variant)
  (let* ((contract (metric-contract metric-type variant))
         (declared (field contract 'preferred-profile)))
    (if declared
        declared
        (let* ((preferred (field contract 'preferred))
               (profiles (field contract 'profiles))
               (matches
                (if (and preferred profiles)
                    (filter
                     (lambda (entry)
                       (equal? (cdr entry) preferred))
                     profiles)
                    '())))
          (unless (= (length matches) 1)
            (error "Cannot derive a unique preferred UI metrics profile"
                   metric-type variant))
          (caar matches)))))

(define (normalize-topological-model model)
  (let* ((id (normalize-logical-id (field model 'id)))
         (metric-type (dsl-model->metric-type model))
         (variant (component-metric-variant model metric-type))
         (profile (preferred-metric-profile metric-type variant))
         (row (field model 'row))
         (col (field model 'col)))
    ;; rowSpan/colSpan in MODEL are intentionally ignored: lt:node resolves
    ;; spans exclusively through ui-metrics.
    (lt:node id metric-type profile
             #:variant variant
             #:row row
             #:col col)))

(define (normalize-topological-component component)
  (normalize-topological-model (component->model component)))

(define (legacy-span-warning model node)
  (let* ((id (normalize-logical-id (field model 'id)))
         (type (field node 'type))
         (variant (field node 'variant))
         (profile (field node 'profile))
         (size (if variant
                   (ui-profile type variant profile)
                   (ui-profile type profile)))
         (legacy-row-span (field model 'rowSpan))
         (legacy-col-span (field model 'colSpan))
         (metric-row-span (field size 'height))
         (metric-col-span (field size 'width)))
    (and (or (not (= legacy-row-span metric-row-span))
             (not (= legacy-col-span metric-col-span)))
         `((kind . legacy-span-mismatch)
           (id . ,id)
           (legacy-row-span . ,legacy-row-span)
           (legacy-col-span . ,legacy-col-span)
           (metric-row-span . ,metric-row-span)
           (metric-col-span . ,metric-col-span)))))

(define (valid-topology-declaration? declaration)
  (memq (field declaration 'kind) '(alignment group)))

(define* (normalize-topological-model-layout models topology-declarations
                                              #:key grid-model)
  (unless (list? models)
    (error "DSL component models for topological normalization must be a list"))
  (unless (list? topology-declarations)
    (error "Topological declarations must be a list"))
  (unless grid-model
    (error "Topological normalization requires an explicit DSL grid model"))
  (unless (every valid-topology-declaration? topology-declarations)
    (error "Unsupported separate topological declaration"
           topology-declarations))
  (let* ((nodes (map normalize-topological-model models))
         (warnings
          (filter-map legacy-span-warning models nodes)))
    `((screen-rows . ,(field grid-model 'rows))
      (screen-cols . ,(field grid-model 'cols))
      (warnings . ,warnings)
      (entries . ,(append nodes topology-declarations)))))

(define* (normalize-topological-layout components topology-declarations
                                        #:key grid)
  (unless (list? components)
    (error "DSL components for topological normalization must be a list"))
  (unless grid
    (error "Topological normalization requires an explicit DSL <grid>"))
  (normalize-topological-model-layout
   (map component->model components)
   topology-declarations
   #:grid-model `((rows . ,(grid:rows grid))
                  (cols . ,(grid:cols grid)))))

(define (solve-normalized-topological-layout normalized)
  (let ((rows (field normalized 'screen-rows))
        (cols (field normalized 'screen-cols))
        (entries (field normalized 'entries)))
    (lt:solve entries #:screen-rows rows #:screen-cols cols)))
