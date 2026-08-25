(use-modules (ice-9 textual-ports)
             (oop goops)
             (srfi srfi-1)
             (generator-app code-generator)
             (generator-app generation-state)
             (generator-app generation-orchestration)
             (generator-app topological-layout)
             (generator-app topological-normalizer))

(define (check label predicate)
  (unless predicate
    (error "Topological shadow integration test failed" label)))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(define (entry-by-id entries id)
  (find (lambda (entry) (eq? (field entry 'id) id)) entries))

(define (legacy-output-snapshot)
  ;; These are the real legacy emitters for the four generated translation
  ;; units.  The embedded grid JSON is also retained separately for diagnosis.
  (let ((layout (generate-grid-code)))
    `(("PluginEditor.h" . ,(generate-member-declarations))
      ("PluginEditor.cpp" . ,(string-append (generate-constructor-code) layout))
      ("PluginProcessor.h" . ,(string-append
                                (generate-attachment-declarations)
                                (generate-parameter-code)))
      ("PluginProcessor.cpp" . ,(string-append
                                  (generate-attachment-code)
                                  (generate-dparams-code)
                                  (generate-getparams-code)
                                  (generate-valueparams-code)
                                  (generate-destroy-code)))
      ("generated-layout.json" . ,layout))))

(define (write-snapshot directory snapshot)
  (mkdir directory)
  (for-each
   (lambda (entry)
     (call-with-output-file (string-append directory "/" (car entry))
       (lambda (port) (display (cdr entry) port))))
   snapshot))

(reset-generation-state!)
(make <grid> #:rows 15 #:cols 144 #:show-grid #t)

(check 'all-concrete-dsl-types-have-explicit-metric-mapping
       (every
        (lambda (type)
          (eq? (dsl-model->metric-type `((type . ,type))) type))
        '(rotary-slider linear-slider text-button toggle-button switch
          bypass-switch label header footer link palette-label selector
          palette-selector meter scope)))

;; Real DSL instances register their real models in the generation state.
(make <scope> #:id 'scope-main #:row 2 #:col 3
      #:row-span 6 #:col-span 8)
(make <meter> #:id 'meter-v #:style 'segmented #:orientation 'vertical
      #:row 1 #:col 1 #:row-span 14 #:col-span 4)
(make <meter> #:id 'meter-h #:style 'segmented #:orientation 'horizontal
      #:row 1 #:col 5 #:row-span 4 #:col-span 14)
(make <palette-label> #:id 'palette-title #:text "Theme"
      #:row-span 1 #:col-span 4)
(make <text-button> #:id 'future-b)
(make <text-button> #:id 'future-a)

(define models (reverse (generation-components)))
(define baseline (legacy-output-snapshot))
(define empty-shadow (run-generation-topological-shadow))
(define after-empty-shadow (legacy-output-snapshot))

(check 'empty-shadow-byte-identical
       (equal? baseline after-empty-shadow))
(check 'shadow-normalization-available
       (pair? (field empty-shadow 'normalized)))
(check 'shadow-resolved-ir-available
       (pair? (field empty-shadow 'resolved)))
(check 'shadow-comparison-available
       (= (length (field empty-shadow 'comparison)) (length models)))

(let* ((resolved (field empty-shadow 'resolved))
       (scope (entry-by-id resolved 'scope-main))
       (meter-v (entry-by-id resolved 'meter-v))
       (meter-h (entry-by-id resolved 'meter-h))
       (palette (entry-by-id resolved 'palette-title))
       (scope-comparison
        (entry-by-id (field empty-shadow 'comparison) 'scope-main))
       (palette-comparison
        (entry-by-id (field empty-shadow 'comparison) 'palette-title)))
  (check 'legacy-row-col-are-hard-anchors
         (and (= (field scope 'row) 2) (= (field scope 'col) 3)))
  (check 'preferred-profile-drives-topological-span
         (and (= (field scope 'rowSpan) 10) (= (field scope 'colSpan) 18)))
  (check 'meter-orientation-variants
         (and (eq? (field meter-v 'variant) 'segmented-vertical)
              (eq? (field meter-h 'variant) 'segmented-horizontal)))
  (check 'palette-label-normalized
         (and (eq? (field palette 'type) 'palette-label)
              (eq? (field palette 'profile) 'standard)))
  (check 'size-difference-is-separate
         (and (null? (field (field scope-comparison 'differences)
                             'position-difference))
              (pair? (field (field scope-comparison 'differences)
                            'size-difference))))
  (check 'position-difference-is-separate
         (and (pair? (field (field palette-comparison 'differences)
                            'position-difference))
              (pair? (field (field palette-comparison 'differences)
                            'size-difference)))))

;; Declarations are separate from the graphical DSL.  Their member IDs may
;; refer forward to components independently of registration order.
(define declarations
  (list (lt:constrain 'future-b (lt:next-right-of 'future-a))
        (lt:constrain 'palette-title (lt:right-of 'meter-h))
        (lt:align-top 'future-a 'future-b)
        (lt:group 'shadow-group
                  #:layout 'horizontal
                  #:cohesion 'strong
                  #:area '(top-right bottom-left)
                  'future-a 'future-b)))
(define declared-shadow
  (run-generation-topological-shadow declarations))
(define declared-resolved (field declared-shadow 'resolved))
(define resolved-a (entry-by-id declared-resolved 'future-a))
(define resolved-b (entry-by-id declared-resolved 'future-b))
(define resolved-group (entry-by-id declared-resolved 'shadow-group))

(check 'alignment-group-area-cohesion-forward-reference
       (and (= (field resolved-a 'row) (field resolved-b 'row))
            (= (field resolved-b 'col)
               (+ (field resolved-a 'col) (field resolved-a 'colSpan)))
            (equal? (field resolved-group 'area)
                    '(top-right bottom-left))
            (eq? (field resolved-group 'cohesion) 'strong)))
(check 'shadow-positional-bridge
       (let ((meter-h (entry-by-id declared-resolved 'meter-h))
             (palette (entry-by-id declared-resolved 'palette-title)))
         (>= (field palette 'col)
             (+ (field meter-h 'col) (field meter-h 'colSpan)))))
(check 'declared-shadow-does-not-change-legacy-output
       (equal? baseline (legacy-output-snapshot)))

;; Materialize both snapshots under the requested generated filenames and
;; compare their bytes, independently of Scheme object equality.
(define temp-root
  (let ((now (gettimeofday)))
    (string-append "/tmp/topological-shadow-byte-identical-"
                   (number->string (car now)) "-"
                   (number->string (cdr now)))))
(define legacy-directory (string-append temp-root "-legacy"))
(define shadow-directory (string-append temp-root "-shadow"))
(write-snapshot legacy-directory baseline)
(write-snapshot shadow-directory after-empty-shadow)
(for-each
 (lambda (entry)
   (let ((name (car entry)))
     (check (string->symbol (string-append "byte-identical-" name))
            (equal?
             (call-with-input-file (string-append legacy-directory "/" name)
               get-string-all)
             (call-with-input-file (string-append shadow-directory "/" name)
               get-string-all)))))
 baseline)

(display "topological-shadow-integration-test: PASS\n")
