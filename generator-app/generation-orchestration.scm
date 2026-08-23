(define-module (generator-app generation-orchestration)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app generation-state)
  #:use-module (generator-app cpp-generation)
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
            run-generation-topological-shadow))

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
