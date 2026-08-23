(define-module (generator-app topological-layout)
  #:use-module (ice-9 optargs)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app ui-metrics)
  #:export (lt:node
            lt:group
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
                  #:key (variant #f) row col (constraints '()))
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
  `((kind . node)
    (id . ,id)
    (type . ,type)
    (variant . ,variant)
    (profile . ,profile)
    (row . ,row)
    (col . ,col)
    (constraints . ,constraints)))

(define (lt:group id . arguments)
  (unless (symbol? id)
    (error "Topological layout group id must be a symbol" id))
  (let* ((parsed
          (let loop ((remaining arguments)
                     (layout #f)
                     (cohesion #f)
                     (area #f)
                     (area-seen? #f)
                     (members '()))
            (cond
             ((null? remaining)
              (list layout cohesion area area-seen? (reverse members)))
             ((eq? (car remaining) #:layout)
              (when (or layout (null? (cdr remaining)))
                (error "Invalid or duplicate group #:layout" id arguments))
              (loop (cddr remaining) (cadr remaining) cohesion area
                    area-seen? members))
             ((eq? (car remaining) #:cohesion)
              (when (or cohesion (null? (cdr remaining)))
                (error "Invalid or duplicate group #:cohesion" id arguments))
              (loop (cddr remaining) layout (cadr remaining) area
                    area-seen? members))
             ((eq? (car remaining) #:area)
              (when (or area-seen? (null? (cdr remaining)))
                (error "Invalid or duplicate group #:area" id arguments))
              (loop (cddr remaining) layout cohesion (cadr remaining)
                    #t members))
             ((keyword? (car remaining))
              (error "Unknown topological layout group keyword"
                     id (car remaining)))
             (else
              (loop (cdr remaining) layout cohesion area area-seen?
                    (cons (car remaining) members))))))
         (layout (list-ref parsed 0))
         (cohesion (list-ref parsed 1))
         (area (list-ref parsed 2))
         (area-seen? (list-ref parsed 3))
         (members (list-ref parsed 4)))
    (unless layout
      (error "Topological layout group requires #:layout" id arguments))
    (unless (memq layout '(horizontal vertical))
      (error "Invalid topological layout group layout" id layout))
    (unless (or (not cohesion) (symbol? cohesion))
      (error "Topological layout group cohesion must be a symbol"
             id cohesion))
    (unless (or (not cohesion) (memq cohesion '(strong medium weak)))
      (error "Invalid topological layout group cohesion" id cohesion))
    (unless (or (not area-seen?) (symbol? area))
      (error "Topological layout group area must be a symbol" id area))
    (unless (or (not area-seen?)
                (memq area '(top-left top top-right
                             left center right
                             bottom-left bottom bottom-right)))
      (error "Invalid topological layout group area" id area))
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
      (area . ,(and area-seen? area))
      (members . ,members))))

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

(define (node-by-id nodes id)
  (find (lambda (node) (eq? (field node 'id) id)) nodes))

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

(define (alignment-edges alignment nodes sizes axis)
  (let* ((relation (field alignment 'relation))
         (ids (field alignment 'nodes)))
    (if (not (eq? (alignment-axis relation) axis))
        '()
        (let* ((reference-id (car ids))
               (reference (node-by-id nodes reference-id)))
          (unless reference
            (error "Missing hard alignment reference" relation reference-id))
          (let ((reference-offset
                 (alignment-offset relation
                                   (assoc-ref sizes reference-id))))
            (append-map
             (lambda (id)
               (unless (node-by-id nodes id)
                 (error "Missing hard alignment reference" relation id))
               (let ((delta
                      (- reference-offset
                         (alignment-offset relation (assoc-ref sizes id)))))
                 ;; position(id) = position(reference) + delta
                 (list (edge reference-id id delta)
                       (edge id reference-id (- delta)))))
             (cdr ids)))))))

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
                              (cdr previous-size))))
             (list (edge previous-id current-id extent)
                   (edge current-id previous-id (- extent)))))
         (zip members (cdr members))))))

(define (cohesion-weight cohesion)
  (case cohesion
    ((strong) 3)
    ((medium) 2)
    ((weak) 1)
    (else (error "Unknown soft cohesion" cohesion))))

;; A wish is (WEIGHT AXIS PREVIOUS CURRENT EXTENT). It remains separate from
;; the authoritative hard graph until the soft optimization phase.
(define (soft-wishes groups sizes axis)
  (append-map
   (lambda (group)
     (let ((cohesion (field group 'cohesion))
           (layout (field group 'layout))
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
                      previous-id current-id extent)))
            (zip members (cdr members)))
           '())))
   groups))

(define (build-axis-edges nodes alignments groups sizes axis origin)
  (append
   ;; Logical coordinates are one-based. This also chooses the deterministic
   ;; earliest solution when inequalities leave free space.
   (map (lambda (node) (edge origin (field node 'id) 1)) nodes)
   ;; Explicit row/col values are hard anchors.
   (append-map
    (lambda (node)
      (let ((anchor (field node (if (eq? axis 'horizontal) 'col 'row)))
            (id (field node 'id)))
        (if anchor
            (list (edge origin id anchor)
                  (edge id origin (- anchor)))
            '())))
    nodes)
   (append-map
    (lambda (node)
      (append-map
       (lambda (constraint)
         (let* ((relation (field constraint 'relation))
                (reference-id (field constraint 'reference))
                (reference (node-by-id nodes reference-id)))
           (unless reference
             (error "Missing topological layout reference"
                    (field node 'id) reference-id))
           (or (constraint-edges node reference relation sizes axis) '())))
       (field node 'constraints)))
    nodes)
   (append-map
    (lambda (alignment)
      (alignment-edges alignment nodes sizes axis))
    alignments)
   (append-map
    (lambda (group) (group-edges group sizes axis))
    groups)))

(define (screen-bound-edge bound origin)
  (case (car bound)
    ((lower) (edge origin (cadr bound) (caddr bound)))
    ((upper) (edge (cadr bound) origin (- (caddr bound))))
    (else (error "Unknown logical screen bound" bound))))

(define* (solve-axis nodes alignments groups sizes axis
                     #:optional (extra-edges '()) (extra-bounds '()))
  (let* ((origin (gensym "layout-origin-"))
         (vertices (cons origin (map (lambda (node) (field node 'id)) nodes)))
         (edges (append
                 (build-axis-edges nodes alignments groups sizes axis origin)
                 extra-edges
                 (map (lambda (bound) (screen-bound-edge bound origin))
                      extra-bounds)))
         (distances (make-hash-table)))
    (for-each (lambda (vertex) (hashq-set! distances vertex 0)) vertices)
    (let loop ((pass 0))
      (let ((updated? #f))
        (for-each
         (lambda (item)
           (let* ((from (list-ref item 0))
                  (to (list-ref item 1))
                  (weight (list-ref item 2))
                  (candidate (+ (hashq-ref distances from) weight)))
             (when (> candidate (hashq-ref distances to))
               (hashq-set! distances to candidate)
               (set! updated? #t))))
         edges)
        (cond
         ((not updated?) distances)
         ((>= pass (- (length vertices) 1))
          (error "Contradictory hard positional constraints" axis))
         (else (loop (+ pass 1))))))))

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

;; Groups remain derived IR objects, never graph vertices. For each hard-valid
;; candidate, member offsets are frozen relative to the first member and the
;; reference is bounded so that the derived group center lies in its third.
(define (area-placement-constraints groups sizes axis distances screen-size)
  (fold
   (lambda (group result)
     (let ((area (field group 'area)))
       (if (not area)
           result
           (let* ((members (field group 'members))
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
                  (third (/ screen-size 3))
                  (index (area-axis-index area axis))
                  (center-offset (+ (- start reference-position) (/ span 2)))
                  (center-lower (+ 1 (* index third)))
                  (center-upper (+ 1 (* (+ index 1) third)))
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
               (error "Topological layout group cannot fit logical screen"
                      (field group 'id) axis span screen-size))
             (list (append (car result) rigid-edges)
                   (append (cadr result)
                           (list
                            (list 'lower reference-id
                                  (- center-lower center-offset))
                            (list 'upper reference-id
                                  (- center-upper center-offset)))
                           screen-bounds))))))
   (list '() '())
   groups))

(define (solve-area-axis nodes alignments groups sizes axis screen-size
                         extra-edges)
  (let ((initial
         (solve-axis nodes alignments groups sizes axis extra-edges)))
    (if (not screen-size)
        initial
        (let ((placement
               (area-placement-constraints
                groups sizes axis initial screen-size)))
          (solve-axis nodes alignments groups sizes axis
                      (append extra-edges (car placement))
                      (cadr placement))))))

(define (try-solve-axis nodes alignments groups sizes axis screen-size
                        extra-edges)
  (catch #t
    (lambda ()
      (solve-area-axis nodes alignments groups sizes axis
                       screen-size extra-edges))
    (lambda args #f)))

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

(define (soft-axis-cost wishes distances)
  (fold (lambda (wish total)
          (let ((weight (car wish))
                (gap (wish-gap wish distances)))
            (add-soft-cost
             total
             (if (< gap 0)
                 (make-soft-cost weight 0)
                 (make-soft-cost 0 (* weight gap))))))
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
             (exact-edges
              (list (edge previous-id current-id extent)
                    (edge current-id previous-id (- extent))))
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

(define (optimize-soft-axis nodes alignments groups sizes axis screen-size
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
                      (try-solve-axis nodes alignments groups sizes axis
                                      screen-size edges)))
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

(define (resolved-group-soft-cost group resolved-nodes)
  (let ((cohesion (field group 'cohesion)))
    (if (not cohesion)
        (make-soft-cost 0 0)
        (let ((layout (field group 'layout))
              (weight (cohesion-weight cohesion)))
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
                (if (< gap 0)
                    (make-soft-cost weight 0)
                    (make-soft-cost 0 (* weight gap))))))
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
      (area . ,(field group 'area))
      (cohesion-weight . ,(and (field group 'cohesion)
                               (cohesion-weight (field group 'cohesion))))
      (members . ,members)
      (row . ,row)
      (col . ,col)
      (rowSpan . ,(- bottom row))
      (colSpan . ,(- right col))
      (soft-cost . ,(resolved-group-soft-cost group resolved-nodes)))))

(define* (lt:solve entries #:key screen-rows screen-cols)
  (unless (list? entries)
    (error "Topological layout input must be a list" entries))
  (unless (every (lambda (entry)
                   (memq (field entry 'kind) '(node alignment group)))
                 entries)
    (error "Invalid topological layout IR entry" entries))
  (let ((nodes (filter (lambda (entry) (eq? (field entry 'kind) 'node))
                       entries))
        (alignments
         (filter (lambda (entry) (eq? (field entry 'kind) 'alignment))
                 entries))
        (groups (filter (lambda (entry) (eq? (field entry 'kind) 'group))
                        entries)))
  (validate-node-ids! nodes)
  (validate-groups! groups nodes)
  (let ((area-groups (filter (lambda (group) (field group 'area)) groups)))
    (when (or screen-rows screen-cols (not (null? area-groups)))
      (unless (and screen-rows screen-cols)
        (error "Logical screen rows and columns are both required"
               screen-rows screen-cols))
      (unless (and (integer? screen-rows) (exact? screen-rows)
                   (> screen-rows 0)
                   (integer? screen-cols) (exact? screen-cols)
                   (> screen-cols 0))
        (error "Logical screen dimensions must be positive exact integers"
               screen-rows screen-cols))))
  (let* ((sizes (map (lambda (node)
                       (cons (field node 'id) (node-size node)))
                     nodes))
         ;; Phase 1: authoritative hard validation and earliest hard solution.
         (hard-columns
          (solve-area-axis nodes alignments groups sizes 'horizontal
                           screen-cols '()))
         (hard-rows
          (solve-area-axis nodes alignments groups sizes 'vertical
                           screen-rows '()))
         ;; Phase 2: finite soft optimization among hard-valid solutions.
         (columns
          (optimize-soft-axis nodes alignments groups sizes
                              'horizontal screen-cols hard-columns))
         (rows
          (optimize-soft-axis nodes alignments groups sizes
                              'vertical screen-rows hard-rows))
         (resolved-nodes
          (map
           (lambda (node)
             (let* ((id (field node 'id))
                    (size (assoc-ref sizes id)))
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
          (map (lambda (group) (resolved-group group resolved-nodes))
               groups))
         (soft-groups
          (filter (lambda (group) (field group 'cohesion))
                  resolved-groups))
         (total-soft-cost
          (fold (lambda (group total)
                  (add-soft-cost total (field group 'soft-cost)))
                (make-soft-cost 0 0)
                soft-groups)))
    (append resolved-nodes
            resolved-groups
            (if (null? soft-groups)
                '()
                (list
                 `((kind . solver-metadata)
                   (soft-cost . ,total-soft-cost))))))))
