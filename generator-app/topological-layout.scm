(define-module (generator-app topological-layout)
  #:use-module (ice-9 optargs)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app ui-metrics)
  #:export (lt:node
            lt:group
	    lt:stack
            lt:place-in-area
            lt:next-right-of
            lt:next-left-of
            lt:next-above
            lt:next-below
            lt:right-of
            lt:left-of
            lt:above
            lt:below
            lt:align-left
            lt:align-right
            lt:align-top
            lt:align-bottom
            lt:align-center-x
            lt:align-center-y
            lt:solve))

;; Experimental logical layout IR. It is intentionally independent from the
;; component DSL, the JUCE grid emitter, screen dimensions and pixels.
(define* (lt:node id type profile
                  #:key (variant #f) row col (constraints '())
                  (width-scale 1) (height-scale 1))
  (unless (symbol? id)
    (error "Topological layout node id must be a symbol" id))
  (unless (symbol? type)
    (error "Topological layout TYPE must be a symbol" id type))
  (unless (symbol? profile)
    (error "Topological layout profile must be a symbol" id profile))
  (unless (or (not variant) (symbol? variant))
    (error "Topological layout variant must be a symbol or #f"
           id variant))
  (unless (and (or (not row) (integer? row))
               (or (not col) (integer? col)))
    (error "Topological layout anchors must be integers" id row col))
  
  ;; Validazione e quantizzazione razionale esatta degli scaler
  (let ((w-scale (if (exact? width-scale) width-scale (rationalize (inexact->exact width-scale) 1/1000000)))
        (h-scale (if (exact? height-scale) height-scale (rationalize (inexact->exact height-scale) 1/1000000))))
    (unless (and (number? w-scale) (> w-scale 0))
      (error "width-scale must be a positive number" id w-scale))
    (unless (and (number? h-scale) (> h-scale 0))
      (error "height-scale must be a positive number" id h-scale))
      
    `((kind . node)
      (id . ,id)
      (type . ,type)
      (variant . ,variant)
      (profile . ,profile)
      (width-scale . ,w-scale)
      (height-scale . ,h-scale)
      (row . ,row)
      (col . ,col)
      (constraints . ,constraints))))

(define area-symbols
  '(top-left top top-right
    left center right
    bottom-left bottom bottom-right))

(define (validate-area-path! owner area)
  (unless (or (symbol? area)
              (and (list? area) (not (null? area))))
    (error "Topological layout area must be a symbol or non-empty proper path"
           owner area))
  (let ((path (if (symbol? area) (list area) area)))
    (unless (every symbol? path)
      (error "Topological layout area path must contain symbols" owner area))
    (unless (every (lambda (item) (memq item area-symbols)) path)
      (error "Invalid topological layout area path" owner area))))

(define (lt:place-in-area node area)
  (unless (symbol? node)
    (error "Topological node-area target must be a symbol" node))
  (validate-area-path! node area)
  `((kind . node-area)
    (node . ,node)
    (area . ,area)))

(define (lt:group id . arguments)
  (unless (symbol? id)
    (error "Topological layout group id must be a symbol" id))
  (let* ((parsed
          (let loop ((remaining arguments)
                     (layout #f)
                     (cohesion #f)
                     (cross-align #f)
                     (cross-align-seen? #f)
                     (gap 0)
                     (gap-seen? #f)
                     (area #f)
                     (area-seen? #f)
                     (members '()))
            (cond
             ((null? remaining)
              (list layout cohesion cross-align cross-align-seen?
                    gap gap-seen? area area-seen? (reverse members)))
             ((eq? (car remaining) #:layout)
              (when (or layout (null? (cdr remaining)))
                (error "Invalid or duplicate group #:layout" id arguments))
              (loop (cddr remaining) (cadr remaining) cohesion
                    cross-align cross-align-seen? gap gap-seen?
                    area area-seen? members))
             ((eq? (car remaining) #:cohesion)
              (when (or cohesion (null? (cdr remaining)))
                (error "Invalid or duplicate group #:cohesion" id arguments))
              (loop (cddr remaining) layout (cadr remaining)
                    cross-align cross-align-seen? gap gap-seen?
                    area area-seen? members))
             ((eq? (car remaining) #:cross-align)
              (when (or cross-align-seen? (null? (cdr remaining)))
                (error "Invalid or duplicate group #:cross-align"
                       id arguments))
              (loop (cddr remaining) layout cohesion (cadr remaining) #t
                    gap gap-seen? area area-seen? members))
             ((eq? (car remaining) #:gap)
              (when (or gap-seen? (null? (cdr remaining)))
                (error "Invalid or duplicate group #:gap" id arguments))
              (loop (cddr remaining) layout cohesion
                    cross-align cross-align-seen? (cadr remaining) #t
                    area area-seen? members))
             ((eq? (car remaining) #:area)
              (when (or area-seen? (null? (cdr remaining)))
                (error "Invalid or duplicate group #:area" id arguments))
              (loop (cddr remaining) layout cohesion
                    cross-align cross-align-seen? gap gap-seen?
                    (cadr remaining) #t members))
             ((keyword? (car remaining))
              (error "Unknown topological layout group keyword"
                     id (car remaining)))
             (else
              (loop (cdr remaining) layout cohesion
                    cross-align cross-align-seen? gap gap-seen?
                    area area-seen?
                    (cons (car remaining) members))))))
         (layout (list-ref parsed 0))
         (cohesion (list-ref parsed 1))
         (cross-align (list-ref parsed 2))
         (cross-align-seen? (list-ref parsed 3))
         (gap (list-ref parsed 4))
         (gap-seen? (list-ref parsed 5))
         (area (list-ref parsed 6))
         (area-seen? (list-ref parsed 7))
         (members (list-ref parsed 8)))
    (unless layout
      (error "Topological layout group requires #:layout" id arguments))
    (unless (memq layout '(horizontal vertical))
      (error "Invalid topological layout group layout" id layout))
    (unless (or (not cohesion) (symbol? cohesion))
      (error "Topological layout group cohesion must be a symbol"
             id cohesion))
    (unless (or (not cohesion) (memq cohesion '(strong medium weak)))
      (error "Invalid topological layout group cohesion" id cohesion))
    (when cross-align-seen?
      (unless (symbol? cross-align)
        (error "Topological layout group cross-align must be a symbol"
               id cross-align))
      (unless (memq cross-align '(start center end))
        (error "Invalid topological layout group cross-align"
               id cross-align)))
    (when gap-seen?
      (unless (and (number? gap) (real? gap) (exact? gap) (>= gap 0))
        (error "Topological layout group gap must be a non-negative exact real number"
               id gap)))
    (when area-seen?
      (validate-area-path! id area))
    (unless (>= (length members) 2)
      (error "Topological layout group requires at least two members"
             id members))
    (unless (every symbol? members)
      (error "Topological layout group members must be node ids" id members))
    (unless (= (length members) (length (delete-duplicates members eq?)))
      (error "Duplicate member in topological layout group" id members))
    `((kind . group)
      (id . ,id)
      (layout . ,layout)
      (cohesion . ,cohesion)
      (cross-align . ,(and cross-align-seen? cross-align))
      (gap . ,gap)
      (area . ,(and area-seen? area))
      (members . ,members))))

;; ======================================================================
;; FIRST-CLASS TOPOLOGICAL STACK
;;
;; Unlike lt:group, a stack is a real geometric layout entity.
;; It owns a derived bounding box and may therefore be referenced by
;; positional constraints, alignments and area placement.
;;
;; Members may be:
;;
;;   - node ids
;;   - stack ids
;;   - nested inline lt:stack declarations
;;
;; Stacks never become JUCE components.
;; ======================================================================

(define (lt:stack id . arguments)
  (unless (symbol? id)
    (error "Topological stack id must be a symbol" id))

  (let loop ((remaining arguments)
             (layout #f)
             (gap 0)
             (gap-seen? #f)
             (cross-align 'center)
             (cross-align-seen? #f)
             (members '()))

    (cond

     ((null? remaining)

      (unless layout
        (error "Topological stack requires #:layout" id))

      (unless (memq layout '(horizontal vertical))
        (error "Topological stack invalid layout" id layout))

      (unless (memq cross-align '(start center end))
        (error "Topological stack invalid cross-align"
               id
               cross-align))

      (unless (and (number? gap)
                   (real? gap)
                   (exact? gap)
                   (>= gap 0))
        (error "Topological stack invalid gap"
               id
               gap))

      (when (null? members)
        (error "Topological stack requires at least one member"
               id))

      `((kind . stack)
        (id . ,id)
        (layout . ,layout)
        (gap . ,gap)
        (cross-align . ,cross-align)
        (members . ,(reverse members))))

     ((eq? (car remaining) #:layout)

      (when (or layout
                (null? (cdr remaining)))
        (error "Invalid or duplicate stack #:layout"
               id))

      (loop (cddr remaining)
            (cadr remaining)
            gap
            gap-seen?
            cross-align
            cross-align-seen?
            members))

     ((eq? (car remaining) #:gap)

      (when (or gap-seen?
                (null? (cdr remaining)))
        (error "Invalid or duplicate stack #:gap"
               id))

      (loop (cddr remaining)
            layout
            (cadr remaining)
            #t
            cross-align
            cross-align-seen?
            members))

     ((eq? (car remaining) #:cross-align)

      (when (or cross-align-seen?
                (null? (cdr remaining)))
        (error "Invalid or duplicate stack #:cross-align"
               id))

      (loop (cddr remaining)
            layout
            gap
            gap-seen?
            (cadr remaining)
            #t
            members))

     ((keyword? (car remaining))

      (error "Unknown topological stack keyword"
             id
             (car remaining)))

     (else

      (loop (cdr remaining)
            layout
            gap
            gap-seen?
            cross-align
            cross-align-seen?
            (cons (car remaining)
                  members))))))


(define (make-constraint relation reference)
  (unless (symbol? reference)
    (error "Topological layout reference must be a symbol"
           relation reference))
  `((relation . ,relation) (reference . ,reference)))

(define (lt:next-right-of reference)
  (make-constraint 'next-right-of reference))
(define (lt:next-left-of reference)
  (make-constraint 'next-left-of reference))
(define (lt:next-above reference)
  (make-constraint 'next-above reference))
(define (lt:next-below reference)
  (make-constraint 'next-below reference))
(define (lt:right-of reference)
  (make-constraint 'right-of reference))
(define (lt:left-of reference)
  (make-constraint 'left-of reference))
(define (lt:above reference)
  (make-constraint 'above reference))
(define (lt:below reference)
  (make-constraint 'below reference))

(define (make-alignment relation ids)
  (unless (>= (length ids) 2)
    (error "Hard alignment requires at least two node ids" relation ids))
  (unless (every symbol? ids)
    (error "Hard alignment node ids must be symbols" relation ids))
  `((kind . alignment) (relation . ,relation) (nodes . ,ids)))

(define (lt:align-left . ids)
  (make-alignment 'align-left ids))
(define (lt:align-right . ids)
  (make-alignment 'align-right ids))
(define (lt:align-top . ids)
  (make-alignment 'align-top ids))
(define (lt:align-bottom . ids)
  (make-alignment 'align-bottom ids))
(define (lt:align-center-x . ids)
  (make-alignment 'align-center-x ids))
(define (lt:align-center-y . ids)
  (make-alignment 'align-center-y ids))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

;; ======================================================================
;; STACK NORMALIZATION
;;
;; Nested stack declarations are lifted into the global layout IR.
;; Parent stacks retain only the logical ids of their children.
;; ======================================================================

(define (stack-entry? entry)
  (and (list? entry)
       (eq? (field entry 'kind) 'stack)))


(define (flatten-one-stack stack)
  (let loop ((remaining (field stack 'members))
             (member-ids '())
             (nested '()))

    (if (null? remaining)

        (let ((normalized-stack
               (map
                (lambda (entry)
                  (if (eq? (car entry) 'members)
                      (cons 'members
                            (reverse member-ids))
                      entry))
                stack)))

          (cons normalized-stack
                (reverse nested)))

        (let ((member (car remaining)))

          (cond

           ((symbol? member)

            (loop (cdr remaining)
                  (cons member member-ids)
                  nested))

           ((stack-entry? member)

            (let* ((flattened
                    (flatten-one-stack member))

                   (nested-stack
                    (car flattened))

                   (nested-id
                    (field nested-stack 'id)))

              (loop
               (cdr remaining)
               (cons nested-id member-ids)
               (append (reverse flattened)
                       nested))))

           (else

            (error
             "Topological stack member must be a node/stack id or nested stack"
             (field stack 'id)
             member)))))))


(define (flatten-entries entries)
  (append-map
   (lambda (entry)
     (if (stack-entry? entry)
         (flatten-one-stack entry)
         (list entry)))
   entries))

(define (node-by-id nodes id)
  (find (lambda (node) (eq? (field node 'id) id)) nodes))

(define (stack-by-id stacks id)
  (find
   (lambda (stack)
     (eq? (field stack 'id) id))
   stacks))


(define (entity-by-id nodes stacks id)
  (or
   (node-by-id nodes id)
   (stack-by-id stacks id)))

(define (node-size node)
  (let* ((id (field node 'id))
         (type (field node 'type))
         (variant (field node 'variant))
         (profile (field node 'profile))
         (metrics (ui-metrics type)))
    (unless metrics
      (error "Unknown UI metrics TYPE" id type))
    (if variant
        (let* ((variants (field metrics 'variants))
               (variant-entry (and variants (assoc variant variants))))
          (unless variants
            (error "UI metrics TYPE has no variants" id type variant))
          (unless variant-entry
            (error "Unknown UI metrics variant" id type variant))
          (let ((size (ui-profile type variant profile)))
            (unless size
              (error "Missing UI metrics profile for variant"
                     id type variant profile))
            (cons (field size 'width) (field size 'height))))
        (let ((size (ui-profile type profile)))
          (unless size
            (error "Missing logical UI metrics profile" id type profile))
          (cons (field size 'width) (field size 'height))))))

;; ======================================================================
;; MINIMUM VISUAL SIZE
;;
;; Used by the physical-fit phase.
;; The preferred metric remains node-size; this function returns
;; the visual-min metric for the same TYPE / variant.
;; ======================================================================

(define (node-visual-min-size node)

  (let* ((id
          (field node 'id))

         (type
          (field node 'type))

         (variant
          (field node 'variant))

         (metrics
          (ui-metrics type))

         (contract
          (if variant

              (let* ((variants
                      (field metrics 'variants))

                     (entry
                      (and variants
                           (assoc variant variants))))

                (unless entry
                  (error
                   "Unknown UI metrics variant"
                   id
                   type
                   variant))

                (cdr entry))

              metrics))

         (minimum
          (field contract 'visual-min)))

    (unless minimum
      (error
       "Missing visual-min UI metric"
       id
       type
       variant))

    (cons
     (field minimum 'width)
     (field minimum 'height))))

;; ======================================================================
;; GLOBAL MINIMUM SCALE
;;
;; The global scale may shrink preferred metrics, but never below
;; the visual-min contract of any real UI component.
;; ======================================================================

(define (minimum-global-ui-scale nodes)

  (fold

   (lambda (node current-minimum)

     (let* ((preferred
             (node-size node))

            (minimum
             (node-visual-min-size node))

            (width-ratio
             (/ (car minimum)
                (car preferred)))

            (height-ratio
             (/ (cdr minimum)
                (cdr preferred))))

       (max current-minimum
            width-ratio
            height-ratio)))

   0
   nodes))

(define (scaled-node-sizes nodes scale)

  (map

   (lambda (node)

     (let ((size
            (node-size node)))

       (cons
        (field node 'id)

        (cons
         (* (car size) scale)
         (* (cdr size) scale)))))

   nodes))
;; ======================================================================
;; STACK BOUNDING BOXES
;; ======================================================================

(define (compute-one-stack-size stack sizes)

  (let* ((layout
          (field stack 'layout))

         (gap
          (field stack 'gap))

         (members
          (field stack 'members))

         (member-sizes
          (map
           (lambda (member)
             (let ((size
                    (assoc-ref sizes member)))

               (unless size
                 (error
                  "Cannot resolve topological stack member size"
                  (field stack 'id)
                  member))

               size))
           members)))

    (if (eq? layout 'horizontal)

        ;; ------------------------------------------------------
        ;; HORIZONTAL
        ;; ------------------------------------------------------

        (cons
         (+ (apply + (map car member-sizes))
            (* gap
				 (- (length members) 1)))

         (apply max
                (map cdr member-sizes)))

        ;; ------------------------------------------------------
        ;; VERTICAL
        ;; ------------------------------------------------------

        (cons
         (apply max
                (map car member-sizes))

         (+ (apply + (map cdr member-sizes))
            (* gap
				 (- (length members) 1)))))))


(define (compute-stack-sizes stacks initial-sizes)

  (let loop ((pending stacks)
             (sizes initial-sizes))

    (if (null? pending)

        sizes

        (let ((resolvable
               (filter
                (lambda (stack)
                  (every
                   (lambda (member)
                     (assoc member sizes))
                   (field stack 'members)))
                pending)))

          (when (null? resolvable)
            (error
             "Cyclic or unresolvable topological stack dependencies"
             pending))

          (let ((new-sizes sizes))

            (for-each
             (lambda (stack)

               (set! new-sizes
                     (acons
                      (field stack 'id)
                      (compute-one-stack-size
                       stack
                       new-sizes)
                      new-sizes)))

             resolvable)

            (loop
             (filter
              (lambda (stack)
                (not (memq stack resolvable)))
              pending)

             new-sizes))))))

;; An edge (U V W) represents V >= U + W. Equalities are represented by
;; their two opposite inequalities. A positive-weight cycle is impossible.
(define (edge from to weight)
  (list from to weight))

(define (constraint-edges node reference relation sizes axis)
  (let* ((id (field node 'id))
         (reference-id (field reference 'id))
         (node-size-value (assoc-ref sizes id))
         (reference-size-value (assoc-ref sizes reference-id))
         (node-extent (if (eq? axis 'horizontal)
                          (car node-size-value)
                          (cdr node-size-value)))
         (reference-extent (if (eq? axis 'horizontal)
                               (car reference-size-value)
                               (cdr reference-size-value))))
    (case relation
      ((next-right-of)
       (and (eq? axis 'horizontal)
            (list (edge reference-id id reference-extent)
                  (edge id reference-id (- reference-extent)))))
      ((right-of)
       (and (eq? axis 'horizontal)
            (list (edge reference-id id reference-extent))))
      ((next-left-of)
       (and (eq? axis 'horizontal)
            (list (edge id reference-id node-extent)
                  (edge reference-id id (- node-extent)))))
      ((left-of)
       (and (eq? axis 'horizontal)
            (list (edge id reference-id node-extent))))
      ((next-below)
       (and (eq? axis 'vertical)
            (list (edge reference-id id reference-extent)
                  (edge id reference-id (- reference-extent)))))
      ((below)
       (and (eq? axis 'vertical)
            (list (edge reference-id id reference-extent))))
      ((next-above)
       (and (eq? axis 'vertical)
            (list (edge id reference-id node-extent)
                  (edge reference-id id (- node-extent)))))
      ((above)
       (and (eq? axis 'vertical)
            (list (edge id reference-id node-extent))))
      (else
       (error "Unknown hard positional constraint" id relation)))))

(define (alignment-offset relation size)
  (case relation
    ((align-left align-top) 0)
    ((align-right) (car size))
    ((align-bottom) (cdr size))
    ((align-center-x) (/ (car size) 2))
    ((align-center-y) (/ (cdr size) 2))
    (else (error "Unknown hard alignment constraint" relation))))

(define (alignment-axis relation)
  (case relation
    ((align-left align-right align-center-x) 'horizontal)
    ((align-top align-bottom align-center-y) 'vertical)
    (else (error "Unknown hard alignment constraint" relation))))

(define (alignment-edges alignment nodes stacks sizes axis)

  (let* ((relation
          (field alignment 'relation))

         (ids
          (field alignment 'nodes)))

    (if (not (eq? (alignment-axis relation)
                  axis))

        '()

        (let* ((reference-id
                (car ids))

               (reference
                (entity-by-id
                 nodes
                 stacks
                 reference-id)))

          (unless reference
            (error
             "Missing hard alignment reference"
             relation
             reference-id))

          (let ((reference-offset
                 (alignment-offset
                  relation
                  (assoc-ref sizes
                             reference-id))))

            (append-map

             (lambda (id)

               (unless
                   (entity-by-id nodes stacks id)

                 (error
                  "Missing hard alignment reference"
                  relation
                  id))

               (let ((delta
                      (- reference-offset
                         (alignment-offset
                          relation
                          (assoc-ref sizes id)))))

                 (list
                  (edge reference-id
                        id
                        delta)

                  (edge id
                        reference-id
                        (- delta)))))

             (cdr ids)))))))

(define (group-cross-alignment-relation group)
  (let ((layout (field group 'layout))
        (cross-align (field group 'cross-align)))
    (and cross-align
         (case layout
           ((horizontal)
            (case cross-align
              ((start) 'align-top)
              ((center) 'align-center-y)
              ((end) 'align-bottom)))
           ((vertical)
            (case cross-align
              ((start) 'align-left)
              ((center) 'align-center-x)
              ((end) 'align-right)))))))

(define (group-cross-alignment-edges group nodes stacks sizes axis)
  (let ((relation (group-cross-alignment-relation group)))
    (if relation
        (alignment-edges
	 `((kind . alignment)
	   (relation . ,relation)
	   (nodes . ,(field group 'members)))
	 nodes
	 stacks
	 sizes
	 axis)
        '())))

(define (group-edges group sizes axis)
  (let ((layout (field group 'layout))
        (cohesion (field group 'cohesion))
        (members (field group 'members)))
    (if (or cohesion
            (not (eq? layout (if (eq? axis 'horizontal)
                                 'horizontal
                                 'vertical))))
        '()
        (append-map
         (lambda (pair)
           (let* ((previous-id (car pair))
                  (current-id (cadr pair))
                  (previous-size (assoc-ref sizes previous-id))
                  (extent (if (eq? axis 'horizontal)
                              (car previous-size)
                              (cdr previous-size)))
                  (distance (+ extent (field group 'gap))))
             (list (edge previous-id current-id distance)
                   (edge current-id previous-id (- distance)))))
         (zip members (cdr members))))))

;; ======================================================================
;; STACK HARD GEOMETRY
;;
;; The stack id is its top-left logical origin.
;;
;; Child coordinates are rigidly tied to that origin.
;; ======================================================================

(define (stack-edges stack sizes axis)

  (let* ((id
          (field stack 'id))

         (layout
          (field stack 'layout))

         (gap
          (field stack 'gap))

         (cross-align
          (field stack 'cross-align))

         (members
          (field stack 'members))

         (stack-size
          (assoc-ref sizes id))

         (stack-extent
          (if (eq? axis 'horizontal)
              (car stack-size)
              (cdr stack-size)))

         (primary-axis?
          (eq? axis
               (if (eq? layout 'horizontal)
                   'horizontal
                   'vertical))))

    (if primary-axis?

        ;; ======================================================
        ;; PRIMARY AXIS
        ;; exact sequential placement
        ;; ======================================================

        (let loop ((remaining members)
                   (offset 0)
                   (result '()))

          (if (null? remaining)

              result

              (let* ((member
                      (car remaining))

                     (member-size
                      (assoc-ref sizes member))

                     (member-extent
                      (if (eq? axis 'horizontal)
                          (car member-size)
                          (cdr member-size))))

                (loop
                 (cdr remaining)

                 (+ offset
                    member-extent
                    gap)

                 (append
                  result

                  (list
                   (edge id
                         member
                         offset)

                   (edge member
                         id
                         (- offset))))))))

        ;; ======================================================
        ;; CROSS AXIS
        ;; start / center / end
        ;; ======================================================

        (append-map
         (lambda (member)

           (let* ((member-size
                   (assoc-ref sizes member))

                  (member-extent
                   (if (eq? axis 'horizontal)
                       (car member-size)
                       (cdr member-size)))

                  (offset
                   (case cross-align

                     ((start)
                      0)

                     ((center)
                      (/ (- stack-extent
                            member-extent)
                         2))

                     ((end)
                      (- stack-extent
                         member-extent))

                     (else
                      (error
                       "Invalid stack cross alignment"
                       id
                       cross-align)))))

             (list
              (edge id
                    member
                    offset)

              (edge member
                    id
                    (- offset)))))

         members))))

(define (cohesion-weight cohesion)
  (case cohesion
    ((strong) 3)
    ((medium) 2)
    ((weak) 1)
    (else (error "Unknown soft cohesion" cohesion))))

;; A wish is (WEIGHT AXIS PREVIOUS CURRENT EXTENT PREFERRED-GAP). It remains
;; separate from the authoritative hard graph until the soft optimization phase.
(define (soft-wishes groups sizes axis)
  (append-map
   (lambda (group)
     (let ((cohesion (field group 'cohesion))
           (layout (field group 'layout))
           (gap (field group 'gap))
           (members (field group 'members)))
       (if (and cohesion
                (eq? layout (if (eq? axis 'horizontal)
                                'horizontal
                                'vertical)))
           (map
            (lambda (pair)
              (let* ((previous-id (car pair))
                     (current-id (cadr pair))
                     (size (assoc-ref sizes previous-id))
                     (extent (if (eq? axis 'horizontal)
                                 (car size)
                                 (cdr size))))
                (list (cohesion-weight cohesion) axis
                      previous-id current-id extent gap)))
            (zip members (cdr members)))
           '())))
   groups))

(define (build-axis-edges
         nodes
         stacks
         node-constraints
         alignments
         groups
         sizes
         axis
         origin)

  (let ((entities
         (append nodes stacks)))

    (append

     ;; ==========================================================
     ;; EVERY FIRST-CLASS ENTITY HAS AN ORIGIN LOWER BOUND
     ;; ==========================================================

     (map
      (lambda (entity)
        (edge origin
              (field entity 'id)
              1))
      entities)


     ;; ==========================================================
     ;; EXPLICIT NODE row / col ANCHORS
     ;; ==========================================================

     (append-map

      (lambda (node)

        (let ((anchor
               (field
                node
                (if (eq? axis 'horizontal)
                    'col
                    'row)))

              (id
               (field node 'id)))

          (if anchor

              (list
               (edge origin id anchor)
               (edge id origin (- anchor)))

              '())))

      nodes)


     ;; ==========================================================
     ;; CONSTRAINTS EMBEDDED DIRECTLY IN lt:node
     ;; ==========================================================

     (append-map

      (lambda (node)

        (append-map

         (lambda (constraint)

           (let* ((relation
                   (field constraint 'relation))

                  (reference-id
                   (field constraint 'reference))

                  (reference
                   (entity-by-id
                    nodes
                    stacks
                    reference-id)))

             (unless reference
               (error
                "Missing topological layout reference"
                (field node 'id)
                reference-id))

             (or
              (constraint-edges
               node
               reference
               relation
               sizes
               axis)

              '())))

         (field node 'constraints)))

      nodes)


     ;; ==========================================================
     ;; EXTERNAL lt:constrain DECLARATIONS
     ;;
     ;; Target and reference can now both be NODE or STACK.
     ;; ==========================================================

     (append-map

      (lambda (declaration)

        (let* ((target-id
                (field declaration 'node))

               (target
                (entity-by-id
                 nodes
                 stacks
                 target-id)))

          (unless target
            (error
             "Topological node-constraints target does not exist"
             target-id))

          (append-map

           (lambda (constraint)

             (let* ((relation
                     (field constraint 'relation))

                    (reference-id
                     (field constraint 'reference))

                    (reference
                     (entity-by-id
                      nodes
                      stacks
                      reference-id)))

               (unless reference
                 (error
                  "Missing topological layout reference"
                  target-id
                  reference-id))

               (or
                (constraint-edges
                 target
                 reference
                 relation
                 sizes
                 axis)

                '())))

           (field declaration 'constraints))))

      node-constraints)


     ;; ==========================================================
     ;; ALIGNMENTS
     ;; ==========================================================

     (append-map

      (lambda (alignment)
        (alignment-edges
         alignment
         nodes
         stacks
         sizes
         axis))

      alignments)


     ;; ==========================================================
     ;; LEGACY GROUP CROSS ALIGNMENT
     ;; ==========================================================

     (append-map

      (lambda (group)
        (group-cross-alignment-edges
         group
         nodes
         stacks
         sizes
         axis))

      groups)


     ;; ==========================================================
     ;; LEGACY GROUP PRIMARY EDGES
     ;; ==========================================================

     (append-map
      (lambda (group)
        (group-edges
         group
         sizes
         axis))
      groups)


     ;; ==========================================================
     ;; FIRST-CLASS STACK GEOMETRY
     ;; ==========================================================

     (append-map
      (lambda (stack)
        (stack-edges
         stack
         sizes
         axis))
      stacks))))

(define (screen-bound-edge bound origin)
  (case (car bound)
    ((lower) (edge origin (cadr bound) (caddr bound)))
    ((upper) (edge (cadr bound) origin (- (caddr bound))))
    (else (error "Unknown logical screen bound" bound))))

(define* (solve-axis
          nodes
          stacks
          node-constraints
          alignments
          groups
          sizes
          axis
          #:optional
          (extra-edges '())
          (extra-bounds '()))

  (let* ((origin
          (gensym "layout-origin-"))

         (entity-ids
          (append
           (map
            (lambda (node)
              (field node 'id))
            nodes)

           (map
            (lambda (stack)
              (field stack 'id))
            stacks)))

         (vertices
          (cons origin
                entity-ids))

         (edges
          (append

           (build-axis-edges
            nodes
            stacks
            node-constraints
            alignments
            groups
            sizes
            axis
            origin)

           extra-edges

           (map
            (lambda (bound)
              (screen-bound-edge
               bound
               origin))
            extra-bounds)))

         (distances
          (make-hash-table)))

    (for-each
     (lambda (vertex)
       (hashq-set!
        distances
        vertex
        0))
     vertices)

    (let loop ((pass 0))

      (let ((updated? #f))

        (for-each

         (lambda (item)

           (let* ((from
                   (list-ref item 0))

                  (to
                   (list-ref item 1))

                  (weight
                   (list-ref item 2))

                  (candidate
                   (+ (hashq-ref distances from)
                      weight)))

             (when
                 (> candidate
                    (hashq-ref distances to))

               (hashq-set!
                distances
                to
                candidate)

               (set! updated? #t))))

         edges)

        (cond

         ((not updated?)
          distances)

         ((>= pass
              (- (length vertices) 1))

          (error
           "Contradictory hard positional constraints"
           axis))

         (else
          (loop (+ pass 1))))))))

(define (area-axis-index area axis)
  (case area
    ((top-left) 0)
    ((top) (if (eq? axis 'horizontal) 1 0))
    ((top-right) (if (eq? axis 'horizontal) 2 0))
    ((left) (if (eq? axis 'horizontal) 0 1))
    ((center) 1)
    ((right) (if (eq? axis 'horizontal) 2 1))
    ((bottom-left) (if (eq? axis 'horizontal) 0 2))
    ((bottom) (if (eq? axis 'horizontal) 1 2))
    ((bottom-right) 2)
    (else (error "Unknown topological screen area" area))))

(define (area-path area)
  (if (symbol? area) (list area) area))

(define (select-area-third bounds area axis)
  (let* ((lower (car bounds))
         (upper (cdr bounds))
         (third (/ (- upper lower) 3))
         (index (area-axis-index area axis)))
    (cons (+ lower (* index third))
          (+ lower (* (+ index 1) third)))))

(define (resolve-area-path screen-size area axis)
  (fold (lambda (item bounds)
          (select-area-third bounds item axis))
        (cons 1 (+ screen-size 1))
        (area-path area)))

(define (area-bbox-target-start area-bounds area axis span)
  (let* ((area-lower (car area-bounds))
         (area-upper (cdr area-bounds))
         (area-span (- area-upper area-lower))
         (area-index (area-axis-index (last (area-path area)) axis)))
    (case area-index
      ((0) area-lower)
      ((1) (+ area-lower (/ (- area-span span) 2)))
      ((2) (- area-upper span)))))

(define (area-placement-members placement)
  (if (eq? (field placement 'kind) 'group)
      (field placement 'members)
      (list (field placement 'id))))

(define (area-placement-id placement)
  (if (eq? (field placement 'kind) 'group)
      (field placement 'id)
      (field placement 'id)))

;; Groups remain derived IR objects, never graph vertices. For each hard-valid
;; candidate, group member offsets are frozen relative to the first member.
;; Group and single-node bounding boxes then share the same exact alignment.
(define (area-placement-constraints placements sizes axis distances screen-size)
  (fold
   (lambda (placement result)
     (let ((area (field placement 'area)))
       (if (not area)
           result
           (let* ((members (area-placement-members placement))
                  (reference-id (car members))
                  (reference-position (hashq-ref distances reference-id))
                  (positions
                   (map (lambda (id) (hashq-ref distances id)) members))
                  (ends
                   (map (lambda (id)
                          (+ (hashq-ref distances id)
                             (let ((size (assoc-ref sizes id)))
                               (if (eq? axis 'horizontal)
                                   (car size)
                                   (cdr size)))))
                        members))
                  (start (apply min positions))
                  (end (apply max ends))
                  (span (- end start))
                  (start-offset (- start reference-position))
                  (area-bounds (resolve-area-path screen-size area axis))
                  (target-start
                   (area-bbox-target-start area-bounds area axis span))
                  (target-reference (- target-start start-offset))
                  (rigid-edges
                   (append-map
                    (lambda (id)
                      (let ((offset (- (hashq-ref distances id)
                                       reference-position)))
                        (list (edge reference-id id offset)
                              (edge id reference-id (- offset)))))
                    (cdr members)))
                  (screen-bounds
                   (append-map
                    (lambda (id)
                      (let* ((size (assoc-ref sizes id))
                             (extent (if (eq? axis 'horizontal)
                                         (car size)
                                         (cdr size))))
                        (list (list 'lower id 1)
                              (list 'upper id (+ 1 (- screen-size extent))))))
                    members)))
             (when (> span screen-size)
               (error "Topological layout area target cannot fit logical screen"
                      (area-placement-id placement) axis span screen-size))
             (list (append (car result) rigid-edges)
                   (append (cadr result)
                           (list
                            (list 'lower reference-id
                                  target-reference)
                            (list 'upper reference-id
                                  target-reference))
                           screen-bounds))))))
   (list '() '())
   placements))

;; ======================================================================
;; GLOBAL SCREEN BOUNDS
;;
;; Every first-class entity must remain entirely inside the logical
;; screen, independently of lt:place-in-area.
;;
;; Logical coordinates are one-based.
;; ======================================================================

(define (global-screen-bounds
         nodes
         stacks
         sizes
         axis
         screen-size)

  (if (not screen-size)

      '()

      (append-map

       (lambda (entity)

         (let* ((id
                 (field entity 'id))

                (size
                 (assoc-ref sizes id))

                (extent
                 (if (eq? axis 'horizontal)
                     (car size)
                     (cdr size))))

           (list

            ;; position >= 1
            (list 'lower
                  id
                  1)

            ;; position + extent <= screen-size + 1
            (list 'upper
                  id
                  (+ 1
                     (- screen-size
                        extent))))))

       (append nodes stacks))))

(define (solve-area-axis
         nodes
         stacks
         node-constraints
         alignments
         groups
         sizes
         axis
         screen-size
         extra-edges)

  (let* ((screen-bounds
          (global-screen-bounds
           nodes
           stacks
           sizes
           axis
           screen-size))

         ;; ------------------------------------------------------
         ;; First solve:
         ;; topology + mandatory global screen containment.
         ;; ------------------------------------------------------

         (initial
          (solve-axis
           nodes
           stacks
           node-constraints
           alignments
           groups
           sizes
           axis
           extra-edges
           screen-bounds)))

    (if (not screen-size)

        initial

        (let ((placement
               (area-placement-constraints

                (append
                 groups

                 (filter
                  (lambda (node)
                    (field node 'area))
                  nodes)

                 (filter
                  (lambda (stack)
                    (field stack 'area))
                  stacks))

                sizes
                axis
                initial
                screen-size)))

          ;; ----------------------------------------------------
          ;; Second solve:
          ;;
          ;; global bounds remain mandatory;
          ;; area-specific constraints are added on top.
          ;; ----------------------------------------------------

          (solve-axis
           nodes
           stacks
           node-constraints
           alignments
           groups
           sizes
           axis

           (append
            extra-edges
            (car placement))

           (append
            screen-bounds
            (cadr placement)))))))

(define (try-solve-axis
         nodes
         stacks
         node-constraints
         alignments
         groups
         sizes
         axis
         screen-size
         extra-edges)

  (catch #t

    (lambda ()

      (solve-area-axis
       nodes
       stacks
       node-constraints
       alignments
       groups
       sizes
       axis
       screen-size
       extra-edges))

    (lambda args
      #f)))

(define (wish-gap wish distances)
  (let ((previous-id (list-ref wish 2))
        (current-id (list-ref wish 3))
        (extent (list-ref wish 4)))
    (- (hashq-ref distances current-id)
       (+ (hashq-ref distances previous-id) extent))))

(define (make-soft-cost order-violations positive-gap)
  `((order-violations . ,order-violations)
    (positive-gap . ,positive-gap)))

(define (add-soft-cost left right)
  (make-soft-cost
   (+ (assoc-ref left 'order-violations)
      (assoc-ref right 'order-violations))
   (+ (assoc-ref left 'positive-gap)
      (assoc-ref right 'positive-gap))))

(define (cohesion-pair-cost weight actual-gap preferred-gap)
  (if (< actual-gap 0)
      (make-soft-cost weight 0)
      (make-soft-cost 0
                      (* weight (abs (- actual-gap preferred-gap))))))

(define (soft-axis-cost wishes distances)
  (fold (lambda (wish total)
          (let ((weight (car wish))
                (actual-gap (wish-gap wish distances))
                (preferred-gap (list-ref wish 5)))
            (add-soft-cost
             total
             (cohesion-pair-cost weight actual-gap preferred-gap))))
        (make-soft-cost 0 0)
        wishes))

;; Each wish has three finite states: exact adjacency, non-overlap order only,
;; or no added edge. Exhaustive enumeration is deliberately small and local;
;; it is not a general LP/MIP solver. Hard-infeasible configurations vanish.
(define (soft-configurations wishes)
  (if (null? wishes)
      (list (list '() 0 0))
      (let* ((wish (car wishes))
             (previous-id (list-ref wish 2))
             (current-id (list-ref wish 3))
             (extent (list-ref wish 4))
             (preferred-gap (list-ref wish 5))
             (preferred-distance (+ extent preferred-gap))
             (exact-edges
              (list (edge previous-id current-id preferred-distance)
                    (edge current-id previous-id (- preferred-distance))))
             (order-edge (list (edge previous-id current-id extent))))
        (append-map
         (lambda (configuration)
           (let ((edges (list-ref configuration 0))
                 (exact-count (list-ref configuration 1))
                 (order-count (list-ref configuration 2)))
             (list (list (append exact-edges edges)
                         (+ exact-count 1) order-count)
                   (list (append order-edge edges)
                         exact-count (+ order-count 1))
                   configuration)))
         (soft-configurations (cdr wishes))))))

(define (better-soft-solution? cost exact-count order-count best)
  (if (not best)
      #t
      (let* ((best-cost (list-ref best 0))
             (violations (assoc-ref cost 'order-violations))
             (best-violations
              (assoc-ref best-cost 'order-violations))
             (positive-gap (assoc-ref cost 'positive-gap))
             (best-positive-gap (assoc-ref best-cost 'positive-gap)))
        (or (< violations best-violations)
            (and (= violations best-violations)
                 (< positive-gap best-positive-gap))
            (and (= violations best-violations)
                 (= positive-gap best-positive-gap)
                 (> exact-count (list-ref best 1)))
            (and (= violations best-violations)
                 (= positive-gap best-positive-gap)
                 (= exact-count (list-ref best 1))
                 (> order-count (list-ref best 2)))))))

(define (optimize-soft-axis
         nodes
         stacks
         node-constraints
         alignments
         groups
         sizes
         axis
         screen-size
         hard-result)
  (let ((wishes (soft-wishes groups sizes axis)))
    (if (null? wishes)
        hard-result
        (let loop ((configurations (soft-configurations wishes))
                   (best #f))
          (if (null? configurations)
              (if best
                  (list-ref best 3)
                  (error "No solution satisfies hard screen area constraints"
                         axis))
              (let* ((configuration (car configurations))
                     (edges (list-ref configuration 0))
                     (exact-count (list-ref configuration 1))
                     (order-count (list-ref configuration 2))
                     (result
                      (try-solve-axis
		       nodes
		       stacks
		       node-constraints
		       alignments
		       groups
		       sizes
		       axis
		       screen-size
		       edges)))
                (if result
                    (let ((cost (soft-axis-cost wishes result)))
                      (loop
                       (cdr configurations)
                       (if (better-soft-solution?
                            cost exact-count order-count best)
                           (list cost exact-count order-count result)
                           best)))
                    (loop (cdr configurations) best))))))))

(define (validate-node-ids! nodes)
  (let ((ids (map (lambda (node) (field node 'id)) nodes)))
    (unless (= (length ids) (length (delete-duplicates ids eq?)))
      (error "Duplicate topological layout node id" ids))))

(define (validate-stacks! stacks nodes groups)

  (let* ((stack-ids
          (map
           (lambda (stack)
             (field stack 'id))
           stacks))

         (node-ids
          (map
           (lambda (node)
             (field node 'id))
           nodes))

         (group-ids
          (map
           (lambda (group)
             (field group 'id))
           groups))

         (all-entity-ids
          (append
           node-ids
           stack-ids)))

    ;; ----------------------------------------------------------
    ;; unique stack ids
    ;; ----------------------------------------------------------

    (unless
        (= (length stack-ids)
           (length
            (delete-duplicates
             stack-ids
             eq?)))

      (error
       "Duplicate topological stack id"
       stack-ids))

    ;; ----------------------------------------------------------
    ;; collision with nodes / legacy groups
    ;; ----------------------------------------------------------

    (for-each

     (lambda (id)

       (when (memq id node-ids)
         (error
          "Topological stack id collides with node id"
          id))

       (when (memq id group-ids)
         (error
          "Topological stack id collides with group id"
          id)))

     stack-ids)

    ;; ----------------------------------------------------------
    ;; members
    ;; ----------------------------------------------------------

    (for-each

     (lambda (stack)

       (let ((id
              (field stack 'id))

             (members
              (field stack 'members)))

         (unless (every symbol? members)
           (error
            "Topological stack members must be logical ids"
            id
            members))

         (unless
             (= (length members)
                (length
                 (delete-duplicates
                  members
                  eq?)))

           (error
            "Duplicate topological stack member"
            id
            members))

         (for-each

          (lambda (member)

            (unless
                (memq member all-entity-ids)

              (error
               "Missing topological stack member"
               id
               member)))

          members)))

     stacks)))

(define (validate-groups! groups nodes)
  (let ((group-ids (map (lambda (group) (field group 'id)) groups))
        (node-ids (map (lambda (node) (field node 'id)) nodes)))
    (unless (= (length group-ids)
               (length (delete-duplicates group-ids eq?)))
      (error "Duplicate topological layout group id" group-ids))
    (for-each
     (lambda (group)
       (let ((id (field group 'id)))
         (when (memq id node-ids)
           (error "Topological layout group id collides with node id" id))
         (for-each
          (lambda (member)
            (unless (memq member node-ids)
              (error "Missing topological layout group member" id member)))
          (field group 'members))))
     groups)))

(define (validate-node-area-placements!
         placements
         nodes
         stacks)

  (let ((entity-ids
         (append

          (map
           (lambda (node)
             (field node 'id))
           nodes)

          (map
           (lambda (stack)
             (field stack 'id))
           stacks)))

        (targets
         (map
          (lambda (placement)
            (field placement 'node))
          placements)))

    (for-each

     (lambda (placement)

       (let ((target
              (field placement 'node))

             (area
              (field placement 'area)))

         (unless
             (memq target entity-ids)

           (error
            "Topological node-area target does not exist"
            target))

         (validate-area-path!
          target
          area)))

     placements)

    (unless
        (= (length targets)
           (length
            (delete-duplicates
             targets
             eq?)))

      (error
       "Duplicate topological node-area target"
       targets))))

(define (attach-areas entities placements)

  (map

   (lambda (entity)

     (let ((placement
            (find

             (lambda (item)
               (eq? (field item 'node)
                    (field entity 'id)))

             placements)))

       (cons
        (cons 'area
              (and placement
                   (field placement 'area)))
        entity)))

   entities))

(define (resolved-group-soft-cost group resolved-nodes)
  (let ((cohesion (field group 'cohesion)))
    (if (not cohesion)
        (make-soft-cost 0 0)
        (let ((layout (field group 'layout))
              (weight (cohesion-weight cohesion))
              (preferred-gap (field group 'gap)))
          (fold
           (lambda (pair total)
             (let* ((previous (node-by-id resolved-nodes (car pair)))
                    (current (node-by-id resolved-nodes (cadr pair)))
                    (position-key (if (eq? layout 'horizontal) 'col 'row))
                    (span-key (if (eq? layout 'horizontal)
                                  'colSpan
                                  'rowSpan))
                    (gap (- (field current position-key)
                            (+ (field previous position-key)
                               (field previous span-key)))))
               (add-soft-cost
                total
                (cohesion-pair-cost weight gap preferred-gap))))
           (make-soft-cost 0 0)
           (zip (field group 'members)
                (cdr (field group 'members))))))))

(define (resolved-group group resolved-nodes)
  (let* ((members (field group 'members))
         (resolved-members
          (map (lambda (id) (node-by-id resolved-nodes id)) members))
         (row (apply min (map (lambda (node) (field node 'row))
                              resolved-members)))
         (col (apply min (map (lambda (node) (field node 'col))
                              resolved-members)))
         (bottom (apply max
                        (map (lambda (node)
                               (+ (field node 'row) (field node 'rowSpan)))
                             resolved-members)))
         (right (apply max
                       (map (lambda (node)
                              (+ (field node 'col) (field node 'colSpan)))
                            resolved-members))))
    `((kind . group)
      (id . ,(field group 'id))
      (layout . ,(field group 'layout))
      (cohesion . ,(field group 'cohesion))
      (cross-align . ,(field group 'cross-align))
      (gap . ,(field group 'gap))
      (area . ,(field group 'area))
      (cohesion-weight . ,(and (field group 'cohesion)
                               (cohesion-weight (field group 'cohesion))))
      (members . ,members)
      (row . ,row)
      (col . ,col)
      (rowSpan . ,(- bottom row))
      (colSpan . ,(- right col))
      (soft-cost . ,(resolved-group-soft-cost group resolved-nodes)))))

(define (resolve-ui-scale scale size)
  (ui-resolve-scale scale size))

;; ======================================================================
;; PHYSICAL UI SCALE FIT
;;
;; ui-scale is the DESIRED scale, not an unconditional hard scale.
;;
;; We first try the exact requested scale.
;; If it cannot fit, we progressively reduce it while respecting
;; every component's visual-min contract.
;;
;; First implementation:
;;   - component sizes are elastic
;;   - gaps remain fixed
;;
;; Scale fallback is quantized to 0.05 to keep rational grid
;; refinement reasonably small and deterministic.
;; ======================================================================

(define ui-fit-scale-step 1/20)


(define (layout-scale-feasible?
         nodes
         stacks
         node-constraints
         alignments
         groups
         scale
         screen-rows
         screen-cols)

  (catch #t

    (lambda ()

      (let* ((node-sizes
              (scaled-node-sizes
               nodes
               scale))

             (sizes
              (compute-stack-sizes
               stacks
               node-sizes)))

        ;; Horizontal feasibility.
        (solve-area-axis
         nodes
         stacks
         node-constraints
         alignments
         groups
         sizes
         'horizontal
         screen-cols
         '())

        ;; Vertical feasibility.
        (solve-area-axis
         nodes
         stacks
         node-constraints
         alignments
         groups
         sizes
         'vertical
         screen-rows
         '())

        #t))

    (lambda args
      #f)))


(define (fit-ui-scale
         nodes
         stacks
         node-constraints
         alignments
         groups
         requested-scale
         screen-rows
         screen-cols)

  (let ((minimum-scale
         (minimum-global-ui-scale
          nodes)))

    (when (< requested-scale
             minimum-scale)

      (error
       "Requested ui-scale is below UI visual minimum"
       requested-scale
       minimum-scale))

    ;; ----------------------------------------------------------
    ;; First try exactly what the user requested.
    ;; ----------------------------------------------------------

    (if (layout-scale-feasible?
         nodes
         stacks
         node-constraints
         alignments
         groups
         requested-scale
         screen-rows
         screen-cols)

        requested-scale

        ;; ------------------------------------------------------
        ;; Requested scale does not fit.
        ;;
        ;; Search downward in deterministic 0.05 increments.
        ;; ------------------------------------------------------

        (let* ((step
                ui-fit-scale-step)

               (first-candidate
                (* step
                   (floor
                    (/ requested-scale
                       step))))

               (first-candidate
                (if (= first-candidate
                       requested-scale)

                    (- first-candidate
                       step)

                    first-candidate)))

          (let loop ((candidate
                      first-candidate))

            (cond

             ;; -------------------------------------------------
             ;; We crossed the minimum.
             ;; Try the exact minimum once.
             ;; -------------------------------------------------

             ((< candidate
                 minimum-scale)

              (if (layout-scale-feasible?
                   nodes
                   stacks
                   node-constraints
                   alignments
                   groups
                   minimum-scale
                   screen-rows
                   screen-cols)

                  minimum-scale

                  (error
                   "Topological layout cannot fit inside logical screen even at visual-min scale"
                   screen-cols
                   screen-rows
                   minimum-scale)))

             ;; -------------------------------------------------
             ;; Largest feasible candidate wins.
             ;; -------------------------------------------------

             ((layout-scale-feasible?
               nodes
               stacks
               node-constraints
               alignments
               groups
               candidate
               screen-rows
               screen-cols)

              candidate)

             (else

              (loop
               (- candidate
                  step)))))))))

(define* (lt:solve
          entries
          #:key
          screen-rows
          screen-cols
          (ui-scale #f)
          (ui-size #f))
  (unless (list? entries)
    (error
     "Topological layout input must be a list"
     entries))

  ;; ============================================================
  ;; Lift nested stacks into the global IR.
  ;; ============================================================

  (let* ((entries
          (flatten-entries entries)))

    (unless
        (every
         (lambda (entry)
           (memq
            (field entry 'kind)
            '(node
              alignment
              group
              stack
              node-area
              node-constraints)))
         entries)

      (error
       "Invalid topological layout IR entry"
       entries))

    (let* ((raw-nodes
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'node))
             entries))

           (raw-stacks
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'stack))
             entries))

           (alignments
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'alignment))
             entries))

           (groups
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'group))
             entries))

           (node-constraints
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'node-constraints))
             entries))

           (node-area-placements
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'node-area))
             entries)))

      ;; ========================================================
      ;; VALIDATION
      ;; ========================================================

      (validate-node-ids!
       raw-nodes)

      (validate-groups!
       groups
       raw-nodes)

      (validate-stacks!
       raw-stacks
       raw-nodes
       groups)

      (validate-node-area-placements!
       node-area-placements
       raw-nodes
       raw-stacks)

      ;; ========================================================
      ;; ATTACH AREA METADATA
      ;; ========================================================

      (let* ((nodes
              (attach-areas
               raw-nodes
               node-area-placements))

             (stacks
              (attach-areas
               raw-stacks
               node-area-placements))

             (area-groups
              (filter
               (lambda (group)
                 (field group 'area))
               groups)))

        ;; ======================================================
        ;; SCREEN VALIDATION
        ;; ======================================================

        (when
            (or screen-rows
                screen-cols
                (not (null? area-groups))
                (not (null? node-area-placements)))

          (unless
              (and screen-rows
                   screen-cols)

            (error
             "Logical screen rows and columns are both required"
             screen-rows
             screen-cols))

          (unless
              (and
               (integer? screen-rows)
               (exact? screen-rows)
               (> screen-rows 0)

               (integer? screen-cols)
               (exact? screen-cols)
               (> screen-cols 0))

            (error
             "Logical screen dimensions must be positive exact integers"
             screen-rows
             screen-cols)))

        ;; ======================================================
        ;; NODE + STACK SIZES
        ;; ======================================================

	(let* ((requested-scale
		(resolve-ui-scale
		 ui-scale
		 ui-size))

	       ;; ======================================================
	       ;; PHYSICAL FIT
	       ;;
	       ;; requested-scale is the user's preference.
	       ;; actual-scale is the largest scale that physically fits.
	       ;; ======================================================

	       (actual-scale
		(if (and screen-rows
			 screen-cols)

		    (fit-ui-scale
		     nodes
		     stacks
		     node-constraints
		     alignments
		     groups
		     requested-scale
		     screen-rows
		     screen-cols)

		    requested-scale))

	       (node-sizes
		(scaled-node-sizes
		 nodes
		 actual-scale))

	       (sizes
		(compute-stack-sizes
		 stacks
		 node-sizes))

               ;; =================================================
               ;; HARD SOLUTION
               ;; =================================================

               (hard-columns
                (solve-area-axis
                 nodes
                 stacks
                 node-constraints
                 alignments
                 groups
                 sizes
                 'horizontal
                 screen-cols
                 '()))

               (hard-rows
                (solve-area-axis
                 nodes
                 stacks
                 node-constraints
                 alignments
                 groups
                 sizes
                 'vertical
                 screen-rows
                 '()))

               ;; =================================================
               ;; SOFT GROUP OPTIMIZATION
               ;; =================================================

               (columns
                (optimize-soft-axis
                 nodes
                 stacks
                 node-constraints
                 alignments
                 groups
                 sizes
                 'horizontal
                 screen-cols
                 hard-columns))

               (rows
                (optimize-soft-axis
                 nodes
                 stacks
                 node-constraints
                 alignments
                 groups
                 sizes
                 'vertical
                 screen-rows
                 hard-rows))

               ;; =================================================
               ;; ONLY REAL NODES ARE EMITTED
               ;;
               ;; stacks remain compile-time layout entities.
               ;; =================================================

               (resolved-nodes
                (map

                 (lambda (node)

                   (let* ((id
                           (field node 'id))

                          (size
                           (assoc-ref sizes id)))

                     `((id . ,id)
                       (type . ,(field node 'type))
                       (variant . ,(field node 'variant))
                       (profile . ,(field node 'profile))
                       (row . ,(hashq-ref rows id))
                       (col . ,(hashq-ref columns id))
                       (rowSpan . ,(cdr size))
                       (colSpan . ,(car size)))))

                 nodes))

               (resolved-groups
                (map
                 (lambda (group)
                   (resolved-group
                    group
                    resolved-nodes))
                 groups))

               (soft-groups
                (filter
                 (lambda (group)
                   (field group 'cohesion))
                 resolved-groups))

               (total-soft-cost
                (fold

                 (lambda (group total)
                   (add-soft-cost
                    total
                    (field group
                           'soft-cost)))

                 (make-soft-cost 0 0)

                 soft-groups)))

          (append
           resolved-nodes
           resolved-groups

           (if (null? soft-groups)

               '()

               (list
                `((kind . solver-metadata)
                  (soft-cost .
                             ,total-soft-cost))))))))))
