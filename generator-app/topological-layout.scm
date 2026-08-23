(define-module (generator-app topological-layout)
  #:use-module (ice-9 optargs)
  #:use-module (srfi srfi-1)
  #:use-module (generator-app ui-metrics)
  #:export (lt:node
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
                  #:key row col (constraints '()))
  (unless (symbol? id)
    (error "Topological layout node id must be a symbol" id))
  (unless (symbol? type)
    (error "Topological layout TYPE must be a symbol" id type))
  (unless (symbol? profile)
    (error "Topological layout profile must be a symbol" id profile))
  (unless (and (or (not row) (integer? row))
               (or (not col) (integer? col)))
    (error "Topological layout anchors must be integers" id row col))
  `((kind . node)
    (id . ,id)
    (type . ,type)
    (profile . ,profile)
    (row . ,row)
    (col . ,col)
    (constraints . ,constraints)))

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
  (let ((size (ui-profile (field node 'type) (field node 'profile))))
    (unless size
      (error "Missing logical UI metrics profile"
             (field node 'id)
             (field node 'type)
             (field node 'profile)))
    (cons (field size 'width) (field size 'height))))

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

(define (build-axis-edges nodes alignments sizes axis origin)
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
    alignments)))

(define (solve-axis nodes alignments sizes axis)
  (let* ((origin (gensym "layout-origin-"))
         (vertices (cons origin (map (lambda (node) (field node 'id)) nodes)))
         (edges (build-axis-edges nodes alignments sizes axis origin))
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

(define (validate-node-ids! nodes)
  (let ((ids (map (lambda (node) (field node 'id)) nodes)))
    (unless (= (length ids) (length (delete-duplicates ids eq?)))
      (error "Duplicate topological layout node id" ids))))

(define (lt:solve entries)
  (unless (list? entries)
    (error "Topological layout input must be a list" entries))
  (unless (every (lambda (entry)
                   (memq (field entry 'kind) '(node alignment)))
                 entries)
    (error "Invalid topological layout IR entry" entries))
  (let ((nodes (filter (lambda (entry) (eq? (field entry 'kind) 'node))
                       entries))
        (alignments
         (filter (lambda (entry) (eq? (field entry 'kind) 'alignment))
                 entries)))
  (validate-node-ids! nodes)
  (let* ((sizes (map (lambda (node)
                       (cons (field node 'id) (node-size node)))
                     nodes))
         (columns (solve-axis nodes alignments sizes 'horizontal))
         (rows (solve-axis nodes alignments sizes 'vertical)))
    (map
     (lambda (node)
       (let* ((id (field node 'id))
              (size (assoc-ref sizes id)))
         `((id . ,id)
           (type . ,(field node 'type))
           (profile . ,(field node 'profile))
           (row . ,(hashq-ref rows id))
           (col . ,(hashq-ref columns id))
           (rowSpan . ,(cdr size))
           (colSpan . ,(car size)))))
     nodes))))
