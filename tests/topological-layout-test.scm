(use-modules (srfi srfi-1)
             (generator-app topological-layout))

(define (check label predicate)
  (unless predicate
    (error "Topological layout test failed" label)))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(define (resolved-node resolved id)
  (let loop ((nodes resolved))
    (cond ((null? nodes) #f)
          ((eq? (field (car nodes) 'id) id) (car nodes))
          (else (loop (cdr nodes))))))

(define (resolved-kind resolved kind)
  (find (lambda (entry) (eq? (field entry 'kind) kind)) resolved))

(define (rejected? thunk)
  (catch #t
    (lambda () (thunk) #f)
    (lambda args #t)))

(define (soft-cost=? entry order-violations positive-gap)
  (let ((cost (field entry 'soft-cost)))
    (and (= (field cost 'order-violations) order-violations)
         (= (field cost 'positive-gap) positive-gap))))

;; compact scope is 8x6, so adjacency produces columns 1, 9 and 17.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact
                        #:constraints (list (lt:next-right-of 'a)))
               (lt:node 'c 'scope 'compact
                        #:constraints (list (lt:next-right-of 'b)))))))
  (check 'next-right-chain
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (= (field (resolved-node resolved 'c) 'col) 17))))

;; compact scope height is 6, so adjacency produces rows 1, 7 and 13.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact
                        #:constraints (list (lt:next-below 'a)))
               (lt:node 'c 'scope 'compact
                        #:constraints (list (lt:next-below 'b)))))))
  (check 'next-below-chain
         (and (= (field (resolved-node resolved 'a) 'row) 1)
              (= (field (resolved-node resolved 'b) 'row) 7)
              (= (field (resolved-node resolved 'c) 'row) 13))))

;; An inequality accepts an explicitly anchored gap larger than adjacency.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact #:col 1)
               (lt:node 'b 'scope 'compact #:col 12
                        #:constraints (list (lt:right-of 'a)))))))
  (check 'right-of-free-space
         (= (field (resolved-node resolved 'b) 'col) 12)))

;; B may reference A before A appears in the input IR.
(let* ((resolved
        (lt:solve
         (list (lt:node 'b 'scope 'standard
                        #:constraints (list (lt:next-right-of 'a)))
               (lt:node 'a 'scope 'compact)))))
  (check 'forward-reference
         (= (field (resolved-node resolved 'b) 'col) 9)))

(check 'missing-reference
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact
                          #:constraints (list (lt:right-of 'missing))))))))

(check 'impossible-cycle
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact
                          #:constraints (list (lt:next-right-of 'b)))
                 (lt:node 'b 'scope 'compact
                          #:constraints (list (lt:next-right-of 'a))))))))

(check 'contradictory-hard-anchors
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact #:col 1)
                 (lt:node 'b 'scope 'compact #:col 12
                          #:constraints (list (lt:next-right-of 'a))))))))

;; Exercise the four inverse relations and verify their exact/inequality form.
(let* ((resolved
        (lt:solve
         (list (lt:node 'centre 'scope 'standard #:row 20 #:col 30)
               (lt:node 'left 'scope 'compact
                        #:constraints (list (lt:next-left-of 'centre)))
               (lt:node 'above 'scope 'compact
                        #:constraints (list (lt:next-above 'centre)))
               (lt:node 'far-left 'scope 'compact #:col 10
                        #:constraints (list (lt:left-of 'centre)))
               (lt:node 'far-above 'scope 'compact #:row 5
                        #:constraints (list (lt:above 'centre)))
               (lt:node 'below 'scope 'compact
                        #:constraints (list (lt:below 'centre)))))))
  (check 'inverse-relations
         (and (= (+ (field (resolved-node resolved 'left) 'col) 8) 30)
              (= (+ (field (resolved-node resolved 'above) 'row) 6) 20)
              (<= (+ (field (resolved-node resolved 'far-left) 'col) 8) 30)
              (<= (+ (field (resolved-node resolved 'far-above) 'row) 6) 20)
              (>= (field (resolved-node resolved 'below) 'row) 28))))

(let ((node (car (lt:solve (list (lt:node 'a 'scope 'extended))))))
  (check 'resolved-ir-shape
         (and (= (field node 'row) 1)
              (= (field node 'col) 1)
              (= (field node 'rowSpan) 10)
              (= (field node 'colSpan) 16))))

;; Alignment declarations are global IR entries. The first id is the common
;; reference; every remaining id is equated to it independently.
(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'scope 'standard)
              (lt:node 'c 'scope 'extended)
              (lt:align-left 'a 'b 'c)))))
  (check 'align-left-three
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 1)
              (= (field (resolved-node resolved 'c) 'col) 1))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'rotary-slider 'compact)
              (lt:align-right 'a 'b)))))
  (check 'align-right-different-widths
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 4)
              (= (+ (field (resolved-node resolved 'a) 'col) 8)
                 (+ (field (resolved-node resolved 'b) 'col) 5)))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'toggle-button 'compact)
              (lt:align-top 'a 'b)))))
  (check 'align-top
         (= (field (resolved-node resolved 'a) 'row)
            (field (resolved-node resolved 'b) 'row))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'toggle-button 'compact)
              (lt:align-bottom 'a 'b)))))
  (check 'align-bottom-different-heights
         (and (= (field (resolved-node resolved 'a) 'row) 1)
              (= (field (resolved-node resolved 'b) 'row) 4)
              (= (+ (field (resolved-node resolved 'a) 'row) 6)
                 (+ (field (resolved-node resolved 'b) 'row) 3)))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'scope 'standard)
              (lt:align-center-x 'a 'b)))))
  (check 'align-center-x-integer
         (and (= (field (resolved-node resolved 'a) 'col) 3)
              (= (field (resolved-node resolved 'b) 'col) 1)
              (= (+ (field (resolved-node resolved 'a) 'col) 4)
                 (+ (field (resolved-node resolved 'b) 'col) 6)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'rotary-slider 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:align-center-x 'a 'b))))
       (a-col (field (resolved-node resolved 'a) 'col))
       (b-col (field (resolved-node resolved 'b) 'col)))
  (check 'align-center-x-half
         (and (= a-col 5/2)
              (= b-col 1)
              (exact? a-col)
              (= (denominator a-col) 2)
              (= (+ a-col 5/2) (+ b-col 4)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:align-center-y 'a 'b))))
       (a-row (field (resolved-node resolved 'a) 'row))
       (b-row (field (resolved-node resolved 'b) 'row)))
  (check 'align-center-y-half
         (and (= a-row 5/2)
              (= b-row 1)
              (exact? a-row)
              (= (denominator a-row) 2)
              (= (+ a-row 3/2) (+ b-row 3)))))

;; The alignment may precede every referenced node in the input.
(let ((resolved
       (lt:solve
        (list (lt:align-left 'a 'b 'c)
              (lt:node 'c 'scope 'extended)
              (lt:node 'b 'scope 'standard)
              (lt:node 'a 'scope 'compact)))))
  (check 'alignment-forward-references
         (every (lambda (id) (= (field (resolved-node resolved id) 'col) 1))
                '(a b c))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'scope 'compact
                       #:constraints (list (lt:next-right-of 'a)))
              (lt:align-top 'a 'b)))))
  (check 'alignment-with-compatible-next
         (and (= (field (resolved-node resolved 'a) 'row)
                 (field (resolved-node resolved 'b) 'row))
              (= (field (resolved-node resolved 'b) 'col) 9))))

(check 'alignment-with-incompatible-anchors
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact #:col 1)
                 (lt:node 'b 'scope 'compact #:col 2)
                 (lt:align-left 'a 'b))))))

(check 'alignment-missing-reference
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact)
                 (lt:align-right 'a 'missing))))))

(check 'single-node-alignment
       (rejected? (lambda () (lt:align-center-x 'a))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'rotary-slider 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:align-center-x 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'exact-coordinates-and-integer-spans
         (and (exact? (field a 'row))
              (exact? (field a 'col))
              (exact? (field b 'row))
              (exact? (field b 'col))
              (integer? (field a 'rowSpan))
              (integer? (field a 'colSpan))
              (integer? (field b 'rowSpan))
              (integer? (field b 'colSpan)))))

;; Variant-aware metric lookup remains part of the same lt:node API.
(let ((node (car (lt:solve (list (lt:node 's 'scope 'standard))))))
  (check 'nonvariant-scope-standard
         (and (not (field node 'variant))
              (= (field node 'colSpan) 12)
              (= (field node 'rowSpan) 8))))

(let ((node (car (lt:solve
                  (list (lt:node 'm 'meter 'standard #:variant 'analog))))))
  (check 'meter-analog-standard
         (and (eq? (field node 'type) 'meter)
              (eq? (field node 'variant) 'analog)
              (eq? (field node 'profile) 'standard)
              (= (field node 'colSpan) 9)
              (= (field node 'rowSpan) 7))))

(let ((node
       (car (lt:solve
             (list (lt:node 'm 'meter 'standard
                            #:variant 'segmented-horizontal))))))
  (check 'meter-segmented-horizontal-standard
         (and (= (field node 'colSpan) 14)
              (= (field node 'rowSpan) 4))))

(let ((node
       (car (lt:solve
             (list (lt:node 'm 'meter 'compact
                            #:variant 'segmented-vertical))))))
  (check 'meter-segmented-vertical-compact
         (and (= (field node 'colSpan) 3)
              (= (field node 'rowSpan) 10))))

(check 'unknown-meter-variant
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'm 'meter 'standard #:variant 'unknown))))))

(check 'scope-radar-is-not-metric-variant
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 's 'scope 'compact #:variant 'radar))))))

(check 'unknown-profile-in-valid-variant
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'm 'meter 'unknown #:variant 'analog))))))

(check 'unknown-metrics-type
       (rejected?
        (lambda ()
          (lt:solve (list (lt:node 'x 'unknown-type 'compact))))))

(let ((resolved
       (lt:solve
        (list (lt:node 'scope 'scope 'compact)
              (lt:node 'meter 'meter 'standard #:variant 'analog
                       #:constraints (list (lt:next-right-of 'scope)))))))
  (check 'variant-to-nonvariant-position
         (and (= (field (resolved-node resolved 'scope) 'col) 1)
              (= (field (resolved-node resolved 'meter) 'col) 9)
              (= (field (resolved-node resolved 'meter) 'colSpan) 9))))

(let ((resolved
       (lt:solve
        (list (lt:node 'analog 'meter 'standard #:variant 'analog)
              (lt:node 'horizontal 'meter 'standard
                       #:variant 'segmented-horizontal)
              (lt:align-right 'analog 'horizontal)))))
  (check 'alignment-between-meter-variants
         (= (+ (field (resolved-node resolved 'analog) 'col) 9)
            (+ (field (resolved-node resolved 'horizontal) 'col) 14))))

;; Width 9 aligned with width 14 requires an exact half-unit coordinate.
(let* ((resolved
        (lt:solve
         (list (lt:node 'analog 'meter 'standard #:variant 'analog)
               (lt:node 'horizontal 'meter 'standard
                        #:variant 'segmented-horizontal)
               (lt:align-center-x 'analog 'horizontal))))
       (analog (resolved-node resolved 'analog))
       (horizontal (resolved-node resolved 'horizontal)))
  (check 'variant-center-remains-exact-rational
         (and (= (field analog 'col) 7/2)
              (= (field horizontal 'col) 1)
              (exact? (field analog 'col))
              (= (denominator (field analog 'col)) 2)
              (= (+ (field analog 'col) 9/2)
                 (+ (field horizontal 'col) 7))
              (integer? (field analog 'rowSpan))
              (integer? (field analog 'colSpan))
              (integer? (field horizontal 'rowSpan))
              (integer? (field horizontal 'colSpan)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:node 'c 'scope 'compact)
               (lt:group 'horizontal-group #:layout 'horizontal 'a 'b 'c))))
       (group (resolved-node resolved 'horizontal-group)))
  (check 'horizontal-group-three
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (= (field (resolved-node resolved 'c) 'col) 17)))
  (check 'horizontal-group-bounds
         (and (eq? (field group 'kind) 'group)
              (equal? (field group 'members) '(a b c))
              (= (field group 'row) 1)
              (= (field group 'col) 1)
              (= (field group 'rowSpan) 6)
              (= (field group 'colSpan) 24)
              (not (field group 'cross-align)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:node 'c 'scope 'compact)
               (lt:group 'vertical-group #:layout 'vertical 'a 'b 'c))))
       (group (resolved-node resolved 'vertical-group)))
  (check 'vertical-group-three
         (and (= (field (resolved-node resolved 'a) 'row) 1)
              (= (field (resolved-node resolved 'b) 'row) 7)
              (= (field (resolved-node resolved 'c) 'row) 13)))
  (check 'vertical-group-bounds
         (and (equal? (field group 'members) '(a b c))
              (= (field group 'row) 1)
              (= (field group 'col) 1)
              (= (field group 'rowSpan) 18)
              (= (field group 'colSpan) 8))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'scope 'scope 'compact)
               (lt:node 'rotary 'rotary-slider 'compact)
               (lt:node 'wide 'scope 'standard)
               (lt:group 'mixed-sizes #:layout 'horizontal
                         'scope 'rotary 'wide))))
       (group (resolved-node resolved 'mixed-sizes)))
  (check 'group-different-member-sizes
         (and (= (field (resolved-node resolved 'scope) 'col) 1)
              (= (field (resolved-node resolved 'rotary) 'col) 9)
              (= (field (resolved-node resolved 'wide) 'col) 14)
              (= (field group 'rowSpan) 8)
              (= (field group 'colSpan) 25))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'scope 'scope 'standard)
               (lt:node 'analog 'meter 'standard #:variant 'analog)
               (lt:node 'segments 'meter 'compact
                        #:variant 'segmented-horizontal)
               (lt:group 'variant-members #:layout 'horizontal
                         'scope 'analog 'segments))))
       (group (resolved-node resolved 'variant-members)))
  (check 'group-variant-aware-members
         (and (= (field (resolved-node resolved 'scope) 'col) 1)
              (= (field (resolved-node resolved 'analog) 'col) 13)
              (= (field (resolved-node resolved 'segments) 'col) 22)
              (= (field group 'colSpan) 31)
              (= (field group 'rowSpan) 8))))

(let ((resolved
       (lt:solve
        (list (lt:group 'forward-group #:layout 'horizontal 'a 'b 'c)
              (lt:node 'c 'scope 'extended)
              (lt:node 'b 'scope 'standard)
              (lt:node 'a 'scope 'compact)))))
  (check 'group-forward-reference
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (= (field (resolved-node resolved 'c) 'col) 21)
              (equal? (field (resolved-node resolved 'forward-group) 'members)
                      '(a b c)))))

(check 'group-missing-member
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:group 'g #:layout 'horizontal 'a 'missing)
                 (lt:node 'a 'scope 'compact))))))

(check 'group-duplicate-member
       (rejected?
        (lambda ()
          (lt:group 'g #:layout 'horizontal 'a 'a))))

(check 'group-single-member
       (rejected?
        (lambda ()
          (lt:group 'g #:layout 'vertical 'a))))

(check 'group-invalid-layout
       (rejected?
        (lambda ()
          (lt:group 'g #:layout 'radial 'a 'b))))

(check 'duplicate-group-id
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact)
                 (lt:node 'b 'scope 'compact)
                 (lt:group 'g #:layout 'horizontal 'a 'b)
                 (lt:group 'g #:layout 'vertical 'a 'b))))))

(check 'group-id-node-id-collision
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'g 'scope 'compact)
                 (lt:node 'b 'scope 'compact)
                 (lt:group 'g #:layout 'horizontal 'g 'b))))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact)
              (lt:node 'b 'rotary-slider 'compact)
              (lt:node 'c 'scope 'standard)
              (lt:group 'aligned-group #:layout 'horizontal 'a 'b 'c)
              (lt:align-top 'a 'b 'c)))))
  (check 'horizontal-group-compatible-alignment
         (and (= (field (resolved-node resolved 'a) 'row) 1)
              (= (field (resolved-node resolved 'b) 'row) 1)
              (= (field (resolved-node resolved 'c) 'row) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (= (field (resolved-node resolved 'c) 'col) 14))))

(check 'group-incompatible-positional-constraint
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact)
                 (lt:node 'b 'scope 'compact
                          #:constraints (list (lt:next-left-of 'a)))
                 (lt:group 'g #:layout 'horizontal 'a 'b))))))

(check 'vertical-group-incompatible-anchors
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'scope 'compact #:row 1)
                 (lt:node 'b 'scope 'compact #:row 10)
                 (lt:group 'g #:layout 'vertical 'a 'b))))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'scope 'scope 'compact)
               (lt:node 'analog 'meter 'standard #:variant 'analog)
               (lt:group 'vertical-mixed #:layout 'vertical
                         'scope 'analog))))
       (group (resolved-node resolved 'vertical-mixed)))
  (check 'vertical-mixed-group-bounding-box
         (and (= (field (resolved-node resolved 'analog) 'row) 7)
              (= (field group 'row) 1)
              (= (field group 'col) 1)
              (= (field group 'rowSpan) 13)
              (= (field group 'colSpan) 9))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-horizontal-start #:layout 'horizontal
                         #:cross-align 'start 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b))
       (group (resolved-node resolved 'cross-horizontal-start)))
  (check 'group-cross-align-horizontal-start
         (and (= (field a 'row) 1)
              (= (field b 'row) 1)
              (= (field b 'col) (+ (field a 'col) (field a 'colSpan)))
              (eq? (field group 'cross-align) 'start))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-horizontal-center #:layout 'horizontal
                         #:cross-align 'center 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'group-cross-align-horizontal-center-exact
         (and (= (field a 'row) 1)
              (= (field b 'row) 3/2)
              (= (+ (field a 'row) (/ (field a 'rowSpan) 2))
                 (+ (field b 'row) (/ (field b 'rowSpan) 2)))
              (exact? (field b 'row))
              (not (integer? (field b 'row))))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-horizontal-end #:layout 'horizontal
                         #:cross-align 'end 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'group-cross-align-horizontal-end
         (= (+ (field a 'row) (field a 'rowSpan))
            (+ (field b 'row) (field b 'rowSpan)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-vertical-start #:layout 'vertical
                         #:cross-align 'start 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'group-cross-align-vertical-start
         (and (= (field a 'col) 1)
              (= (field b 'col) 1)
              (= (field b 'row) (+ (field a 'row) (field a 'rowSpan))))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-vertical-center #:layout 'vertical
                         #:cross-align 'center 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'group-cross-align-vertical-center-exact
         (and (= (field a 'col) 1)
              (= (field b 'col) 5/2)
              (= (+ (field a 'col) (/ (field a 'colSpan) 2))
                 (+ (field b 'col) (/ (field b 'colSpan) 2)))
              (exact? (field b 'col))
              (not (integer? (field b 'col))))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-vertical-end #:layout 'vertical
                         #:cross-align 'end 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'group-cross-align-vertical-end
         (= (+ (field a 'col) (field a 'colSpan))
            (+ (field b 'col) (field b 'colSpan)))))

(check 'group-invalid-cross-align
       (and (rejected?
             (lambda ()
               (lt:group 'g #:layout 'horizontal
                         #:cross-align 'baseline 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'g #:layout 'horizontal
                         #:cross-align 1 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'g #:layout 'horizontal 'a 'b
                         #:cross-align)))))

(check 'group-duplicate-cross-align
       (rejected?
        (lambda ()
          (lt:group 'g #:layout 'horizontal
                    #:cross-align 'start #:cross-align 'end 'a 'b))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-area #:layout 'horizontal
                         #:cross-align 'center #:area 'center 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b))
       (group (resolved-node resolved 'cross-area)))
  (check 'group-cross-align-with-area
         (and (= (field group 'col) 13/2)
              (= (field group 'row) 11/2)
              (= (field group 'colSpan) 13)
              (= (field group 'rowSpan) 6)
              (= (+ (field a 'row) (/ (field a 'rowSpan) 2))
                 (+ (field b 'row) (/ (field b 'rowSpan) 2))))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'rotary-slider 'compact)
               (lt:group 'cross-soft #:layout 'horizontal
                         #:cross-align 'end #:cohesion 'strong 'a 'b))))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b))
       (group (resolved-node resolved 'cross-soft)))
  (check 'group-cross-align-with-soft-cohesion
         (and (= (field b 'col) (+ (field a 'col) (field a 'colSpan)))
              (= (+ (field a 'row) (field a 'rowSpan))
                 (+ (field b 'row) (field b 'rowSpan)))
              (soft-cost=? group 0 0)
              (eq? (field group 'cross-align) 'end))))

;; Omitting cohesion preserves the original hard adjacency contract.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:group 'hard-default #:layout 'horizontal 'a 'b))))
       (group (resolved-node resolved 'hard-default)))
  (check 'group-without-cohesion-remains-hard
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (not (field group 'cohesion))
              (not (field group 'cohesion-weight))
              (soft-cost=? group 0 0)
              (not (resolved-kind resolved 'solver-metadata)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:node 'c 'scope 'compact)
               (lt:group 'soft-horizontal #:layout 'horizontal
                         #:cohesion 'strong 'a 'b 'c))))
       (group (resolved-node resolved 'soft-horizontal))
       (metadata (resolved-kind resolved 'solver-metadata)))
  (check 'soft-strong-horizontal-zero-gaps
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (= (field (resolved-node resolved 'c) 'col) 17)
              (eq? (field group 'cohesion) 'strong)
              (soft-cost=? group 0 0)
              (soft-cost=? metadata 0 0))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:node 'c 'scope 'compact)
               (lt:group 'soft-vertical #:layout 'vertical
                         #:cohesion 'medium 'a 'b 'c))))
       (group (resolved-node resolved 'soft-vertical)))
  (check 'soft-vertical-zero-gaps
         (and (= (field (resolved-node resolved 'a) 'row) 1)
              (= (field (resolved-node resolved 'b) 'row) 7)
              (= (field (resolved-node resolved 'c) 'row) 13)
              (soft-cost=? group 0 0))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact #:col 1)
               (lt:node 'b 'scope 'compact #:col 20)
               (lt:group 'forced-gap #:layout 'horizontal
                         #:cohesion 'strong 'a 'b))))
       (group (resolved-node resolved 'forced-gap)))
  (check 'hard-anchor-forces-soft-gap
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 20)
              (soft-cost=? group 0 33)
              (soft-cost=? (resolved-kind resolved 'solver-metadata)
                           0 33))))

(let ((resolved
       (lt:solve
        (list (lt:node 'a 'scope 'compact #:col 1)
              (lt:node 'b 'scope 'compact
                       #:constraints (list (lt:right-of 'a)))
              (lt:group 'right-of-cohesion #:layout 'horizontal
                        #:cohesion 'weak 'a 'b)))))
  (check 'right-of-with-cohesion-minimizes-distance
         (and (= (field (resolved-node resolved 'b) 'col) 9)
              (soft-cost=? (resolved-node resolved 'right-of-cohesion)
                           0 0))))

;; With no hard relation, both overlapping and adjacent placements are hard
;; valid. Cohesion selects the adjacent zero-gap configuration.
(let* ((hard-only
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact))))
       (soft
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:group 'choice #:layout 'horizontal
                         #:cohesion 'medium 'a 'b)))))
  (check 'soft-selects-lower-cost-hard-solution
         (and (= (field (resolved-node hard-only 'b) 'col) 1)
              (= (field (resolved-node soft 'b) 'col) 9)
              (soft-cost=? (resolved-node soft 'choice) 0 0))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:group 'strong-group #:layout 'horizontal
                         #:cohesion 'strong 'a 'b)
               (lt:group 'medium-group #:layout 'horizontal
                         #:cohesion 'medium 'a 'b)
               (lt:group 'weak-group #:layout 'horizontal
                         #:cohesion 'weak 'a 'b))))
       (strong (resolved-node resolved 'strong-group))
       (medium (resolved-node resolved 'medium-group))
       (weak (resolved-node resolved 'weak-group)))
  (check 'cohesion-weight-order
         (and (= (field strong 'cohesion-weight) 3)
              (= (field medium 'cohesion-weight) 2)
              (= (field weak 'cohesion-weight) 1)
              (> (field strong 'cohesion-weight)
                 (field medium 'cohesion-weight))
              (> (field medium 'cohesion-weight)
                 (field weak 'cohesion-weight)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact #:col 1)
               (lt:node 'b 'scope 'compact #:col 20)
               (lt:node 'c 'scope 'compact #:col 40)
               (lt:group 'shared-strong #:layout 'horizontal
                         #:cohesion 'strong 'a 'b)
               (lt:group 'shared-medium #:layout 'horizontal
                         #:cohesion 'medium 'b 'c))))
       (strong (resolved-node resolved 'shared-strong))
       (medium (resolved-node resolved 'shared-medium))
       (metadata (resolved-kind resolved 'solver-metadata)))
  (check 'overlapping-soft-groups-summed-cost
         (and (soft-cost=? strong 0 33)
              (soft-cost=? medium 0 24)
              (soft-cost=? metadata 0 57))))

;; Coincident anchors make B overlap A. The old max(0, gap) objective
;; incorrectly reported this as the same zero cost as exact adjacency.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact #:col 1)
               (lt:node 'b 'scope 'compact #:col 1)
               (lt:group 'overlap #:layout 'horizontal
                         #:cohesion 'strong 'a 'b))))
       (group (resolved-node resolved 'overlap))
       (metadata (resolved-kind resolved 'solver-metadata)))
  (check 'overlap-has-order-violation-cost
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 1)
              (soft-cost=? group 3 0)
              (soft-cost=? metadata 3 0))))

;; A hard inversion remains authoritative and is diagnosed, not rejected.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact #:col 20)
               (lt:node 'b 'scope 'compact #:col 1)
               (lt:group 'forced-inversion #:layout 'horizontal
                         #:cohesion 'medium 'a 'b))))
       (group (resolved-node resolved 'forced-inversion)))
  (check 'hard-anchor-forced-inversion-is-preserved
         (and (= (field (resolved-node resolved 'a) 'col) 20)
              (= (field (resolved-node resolved 'b) 'col) 1)
              (soft-cost=? group 2 0))))

;; Put the weaker reverse wish first: with the old scalar objective both
;; directions cost zero and its edge-count tie-break retained the weak wish.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:group 'weak-reverse #:layout 'horizontal
                         #:cohesion 'weak 'b 'a)
               (lt:group 'strong-forward #:layout 'horizontal
                         #:cohesion 'strong 'a 'b))))
       (weak (resolved-node resolved 'weak-reverse))
       (strong (resolved-node resolved 'strong-forward))
       (metadata (resolved-kind resolved 'solver-metadata)))
  (check 'strong-order-wins-over-weak-order
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (soft-cost=? strong 0 0)
              (soft-cost=? weak 1 0)
              (soft-cost=? metadata 1 0))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact)
               (lt:node 'b 'scope 'compact)
               (lt:group 'medium-reverse #:layout 'horizontal
                         #:cohesion 'medium 'b 'a)
               (lt:group 'strong-forward #:layout 'horizontal
                         #:cohesion 'strong 'a 'b))))
       (medium (resolved-node resolved 'medium-reverse))
       (strong (resolved-node resolved 'strong-forward)))
  (check 'strong-order-wins-over-medium-order
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9)
              (soft-cost=? strong 0 0)
              (soft-cost=? medium 2 0))))

;; Contributions from groups sharing B retain and sum both cost components.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'scope 'compact #:col 20)
               (lt:node 'b 'scope 'compact #:col 1)
               (lt:node 'c 'scope 'compact #:col 20)
               (lt:group 'shared-violation #:layout 'horizontal
                         #:cohesion 'strong 'a 'b)
               (lt:group 'shared-gap #:layout 'horizontal
                         #:cohesion 'medium 'b 'c))))
       (violation (resolved-node resolved 'shared-violation))
       (gap (resolved-node resolved 'shared-gap))
       (metadata (resolved-kind resolved 'solver-metadata)))
  (check 'shared-soft-groups-sum-both-components
         (and (soft-cost=? violation 3 0)
              (soft-cost=? gap 0 22)
              (soft-cost=? metadata 3 22))))

(check 'invalid-cohesion-values
       (and (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal
                         #:cohesion 'Strong 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal
                         #:cohesion 3 'a 'b)))))

(let ((resolved
       (lt:solve
        (list (lt:group 'soft-forward #:layout 'horizontal
                        #:cohesion 'strong 'a 'b)
              (lt:node 'b 'scope 'compact)
              (lt:node 'a 'scope 'compact)))))
  (check 'soft-group-forward-references
         (and (= (field (resolved-node resolved 'a) 'col) 1)
              (= (field (resolved-node resolved 'b) 'col) 9))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'analog 'meter 'standard #:variant 'analog)
               (lt:node 'segments 'meter 'compact
                        #:variant 'segmented-horizontal)
               (lt:group 'soft-variants #:layout 'horizontal
                         #:cohesion 'strong 'analog 'segments))))
       (group (resolved-node resolved 'soft-variants)))
  (check 'soft-group-variant-aware-members
         (and (= (field (resolved-node resolved 'analog) 'col) 1)
              (= (field (resolved-node resolved 'segments) 'col) 10)
              (soft-cost=? group 0 0)
              (= (field group 'colSpan) 19))))

;; A compact toggle pair has an 8x3 resolved bounding box. On a 15x24 logical
;; screen, each area aligns that box by its requested edges or center.
(define area-cases
  '((top-left 1 1)
    (top 9 1)
    (top-right 17 1)
    (left 1 7)
    (center 9 7)
    (right 17 7)
    (bottom-left 1 13)
    (bottom 9 13)
    (bottom-right 17 13)))

(for-each
 (lambda (case)
   (let* ((area (list-ref case 0))
          (expected-col (list-ref case 1))
          (expected-row (list-ref case 2))
          (resolved
           (lt:solve
            (list (lt:node 'a 'toggle-button 'compact)
                  (lt:node 'b 'toggle-button 'compact)
                  (lt:group 'area-group #:layout 'horizontal
                            #:area area 'a 'b))
            #:screen-rows 15 #:screen-cols 24))
          (group (resolved-node resolved 'area-group)))
     (check (string->symbol (string-append "area-" (symbol->string area)))
            (and (eq? (field group 'area) area)
                 (= (field group 'col) expected-col)
                 (= (field group 'row) expected-row)
                 (= (field group 'colSpan) 8)
                 (= (field group 'rowSpan) 3)
                 (= (- (field (resolved-node resolved 'b) 'col)
                       (field (resolved-node resolved 'a) 'col))
                    4)))))
 area-cases)

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'text-button 'compact)
               (lt:node 'b 'text-button 'compact)
               (lt:group 'vertical-area #:layout 'vertical
                         #:area 'bottom 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (group (resolved-node resolved 'vertical-area)))
  (check 'area-with-hard-vertical-layout
         (and (= (- (field (resolved-node resolved 'b) 'row)
                    (field (resolved-node resolved 'a) 'row))
                 2)
              (= (field group 'rowSpan) 4)
              (eq? (field group 'area) 'bottom))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact)
               (lt:node 'b 'toggle-button 'compact)
               (lt:group 'soft-area #:layout 'horizontal
                         #:area 'bottom-right #:cohesion 'strong 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (group (resolved-node resolved 'soft-area)))
  (check 'area-with-soft-cohesion
         (and (= (- (field (resolved-node resolved 'b) 'col)
                    (field (resolved-node resolved 'a) 'col))
                 4)
              (soft-cost=? group 0 0)
              (eq? (field group 'area) 'bottom-right))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'meter 'compact
                        #:variant 'segmented-horizontal)
               (lt:node 'b 'meter 'compact
                        #:variant 'segmented-horizontal)
               (lt:group 'variant-area #:layout 'horizontal
                         #:area 'right #:cohesion 'weak 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (group (resolved-node resolved 'variant-area)))
  (check 'area-variant-aware-members
         (and (eq? (field (resolved-node resolved 'a) 'variant)
                   'segmented-horizontal)
              (eq? (field group 'area) 'right)
              (<= (+ (field group 'col) (field group 'colSpan)) 25))))

(let ((resolved
       (lt:solve
        (list (lt:group 'forward-area #:layout 'horizontal
                        #:area 'top-right 'a 'b)
              (lt:node 'b 'toggle-button 'compact)
              (lt:node 'a 'toggle-button 'compact))
        #:screen-rows 15 #:screen-cols 24)))
  (check 'area-group-forward-reference
         (and (= (field (resolved-node resolved 'b) 'col)
                 (+ (field (resolved-node resolved 'a) 'col) 4))
              (eq? (field (resolved-node resolved 'forward-area) 'area)
                   'top-right))))

(check 'invalid-group-area
       (and (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal #:area 'Top 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal #:area #f 'a 'b)))))

(check 'area-requires-screen-dimensions
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'toggle-button 'compact)
                 (lt:node 'b 'toggle-button 'compact)
                 (lt:group 'g #:layout 'horizontal #:area 'top 'a 'b))))))

(check 'invalid-screen-dimensions
       (and (rejected?
             (lambda ()
               (lt:solve '() #:screen-rows 0 #:screen-cols 24)))
            (rejected?
             (lambda ()
               (lt:solve '() #:screen-rows 15 #:screen-cols -1)))
            (rejected?
             (lambda ()
               (lt:solve '() #:screen-rows 15)))))

(check 'area-group-too-large-for-screen
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'header 'extended)
                 (lt:node 'b 'text-button 'compact)
                 (lt:group 'too-wide #:layout 'horizontal
                           #:area 'center 'a 'b))
           #:screen-rows 15 #:screen-cols 24))))

(check 'anchor-incompatible-with-area
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'toggle-button 'compact #:col 1)
                 (lt:node 'b 'toggle-button 'compact)
                 (lt:group 'anchored #:layout 'horizontal
                           #:area 'top-right 'a 'b))
           #:screen-rows 15 #:screen-cols 24))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact #:col 17 #:row 13)
               (lt:node 'b 'toggle-button 'compact)
               (lt:group 'anchored-exactly #:layout 'horizontal
                         #:area 'bottom-right 'a 'b)
               (lt:align-top 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (group (resolved-node resolved 'anchored-exactly)))
  (check 'hard-position-compatible-with-bbox-placement
         (and (= (field group 'col) 17)
              (= (field group 'row) 13)
              (= (+ (field group 'col) (field group 'colSpan)) 25)
              (= (+ (field group 'row) (field group 'rowSpan)) 16))))

;; Translation into the bottom-right third preserves both axis offsets.
(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact)
               (lt:node 'b 'toggle-button 'compact)
               (lt:group 'rigid #:layout 'horizontal
                         #:area 'bottom-right 'a 'b)
               (lt:align-top 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'area-translation-preserves-relative-distances
         (and (= (- (field b 'col) (field a 'col)) 4)
              (= (- (field b 'row) (field a 'row)) 0))))

(define (solve-hierarchical-area path)
  (lt:solve
   (list (lt:node 'a 'toggle-button 'compact)
         (lt:node 'b 'toggle-button 'compact)
         (lt:group 'hierarchy #:layout 'vertical #:area path
                   #:cohesion 'weak 'a 'b)
         (lt:align-left 'a 'b)
         (lt:align-top 'a 'b))
   #:screen-rows 15 #:screen-cols 24))

;; The aligned 4x3 pair reaches every recursive third and retains exact
;; fractional coordinates; its forced soft-order violation is immaterial here.
(let* ((resolved (solve-hierarchical-area '(top-right top-left)))
       (group (resolved-node resolved 'hierarchy)))
  (check 'hierarchical-top-right-top-left
         (and (equal? (field group 'area) '(top-right top-left))
              (= (field group 'col) 17)
              (= (field group 'row) 1))))

(let* ((resolved (solve-hierarchical-area '(top-right top-right)))
       (group (resolved-node resolved 'hierarchy)))
  (check 'hierarchical-top-right-top-right
         (and (= (field group 'col) 21)
              (= (field group 'row) 1)
              (exact? (field group 'col))
              (integer? (field group 'col)))))

(let* ((resolved (solve-hierarchical-area '(top-right bottom-left)))
       (group (resolved-node resolved 'hierarchy)))
  (check 'hierarchical-top-right-bottom-left
         (and (= (field group 'col) 17)
              (= (field group 'row) 3))))

(let* ((resolved (solve-hierarchical-area '(center center)))
       (group (resolved-node resolved 'hierarchy)))
  (check 'hierarchical-center-center
         (and (= (field group 'col) 11)
              (= (field group 'row) 7))))

(let* ((resolved
        (solve-hierarchical-area '(bottom-right top-left center)))
       (group (resolved-node resolved 'hierarchy)))
  (check 'hierarchical-three-level-path
         (and (= (field group 'col) 49/3)
              (= (field group 'row) 31/3)
              (exact? (field group 'col))
              (exact? (field group 'row)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact)
               (lt:node 'b 'toggle-button 'compact)
               (lt:group 'nested-horizontal #:layout 'horizontal
                         #:area '(center center) 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'hierarchical-area-hard-horizontal
         (= (- (field b 'col) (field a 'col)) 4)))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'text-button 'compact)
               (lt:node 'b 'text-button 'compact)
               (lt:group 'nested-vertical #:layout 'vertical
                         #:area '(bottom top) 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (a (resolved-node resolved 'a))
       (b (resolved-node resolved 'b)))
  (check 'hierarchical-area-hard-vertical
         (= (- (field b 'row) (field a 'row)) 2)))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact)
               (lt:node 'b 'toggle-button 'compact)
               (lt:group 'nested-soft #:layout 'horizontal
                         #:area '(top-right bottom-left)
                         #:cohesion 'strong 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (group (resolved-node resolved 'nested-soft)))
  (check 'hierarchical-area-soft-cohesion
         (and (soft-cost=? group 0 0)
              (= (- (field (resolved-node resolved 'b) 'col)
                    (field (resolved-node resolved 'a) 'col))
                 4))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'a 'meter 'compact
                        #:variant 'segmented-horizontal)
               (lt:node 'b 'meter 'compact
                        #:variant 'segmented-horizontal)
               (lt:group 'nested-variant #:layout 'horizontal
                         #:area '(center center) #:cohesion 'weak 'a 'b))
         #:screen-rows 15 #:screen-cols 24))
       (group (resolved-node resolved 'nested-variant)))
  (check 'hierarchical-area-variant-aware
         (and (equal? (field group 'area) '(center center))
              (eq? (field (resolved-node resolved 'a) 'variant)
                   'segmented-horizontal))))

(let ((resolved
       (lt:solve
        (list (lt:group 'nested-forward #:layout 'vertical
                        #:area '(left bottom-right) 'a 'b)
              (lt:node 'b 'text-button 'compact)
              (lt:node 'a 'text-button 'compact))
        #:screen-rows 15 #:screen-cols 24)))
  (check 'hierarchical-area-forward-reference
         (equal? (field (resolved-node resolved 'nested-forward) 'area)
                 '(left bottom-right))))

(check 'invalid-hierarchical-area-paths
       (and (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal #:area 'foo 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal
                         #:area '(top-right foo) 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal #:area '() 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal
                         #:area '(top-right 12) 'a 'b)))
            (rejected?
             (lambda ()
               (lt:group 'bad #:layout 'horizontal
                         #:area '(top-right . bottom-left) 'a 'b)))))

(check 'anchor-incompatible-with-hierarchical-area
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'text-button 'compact #:col 1)
                 (lt:node 'b 'text-button 'compact)
                 (lt:group 'nested-anchor #:layout 'vertical
                           #:area '(top-right top-right) 'a 'b))
           #:screen-rows 15 #:screen-cols 24))))

(check 'oversize-hierarchical-area-group
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'a 'header 'extended)
                 (lt:node 'b 'text-button 'compact)
                 (lt:group 'nested-too-wide #:layout 'horizontal
                           #:area '(center center) 'a 'b))
           #:screen-rows 15 #:screen-cols 24))))

(let* ((baseline
        (lt:solve
         (list (lt:node 'a 'toggle-button 'compact)
               (lt:node 'b 'toggle-button 'compact)
               (lt:group 'base #:layout 'vertical #:cohesion 'weak 'a 'b)
               (lt:align-left 'a 'b)
               (lt:align-top 'a 'b))))
       (nested (solve-hierarchical-area '(bottom-right top-left center)))
       (base-a (resolved-node baseline 'a))
       (base-b (resolved-node baseline 'b))
       (nested-a (resolved-node nested 'a))
       (nested-b (resolved-node nested 'b)))
  (check 'hierarchical-translation-preserves-distances
         (and (= (- (field base-b 'row) (field base-a 'row))
                 (- (field nested-b 'row) (field nested-a 'row)))
              (= (- (field base-b 'col) (field base-a 'col))
                 (- (field nested-b 'col) (field nested-a 'col))))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'single-top 'toggle-button 'compact)
               (lt:place-in-area 'single-top 'top))
         #:screen-rows 15 #:screen-cols 24))
       (node (resolved-node resolved 'single-top)))
  (check 'single-node-area-top
         (and (= (field node 'col) 11)
              (= (field node 'row) 1)
              (= (field node 'colSpan) 4)
              (= (field node 'rowSpan) 3))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'single-center 'toggle-button 'compact)
               (lt:place-in-area 'single-center 'center))
         #:screen-rows 15 #:screen-cols 24))
       (node (resolved-node resolved 'single-center)))
  (check 'single-node-area-center
         (and (= (field node 'col) 11)
              (= (field node 'row) 7))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'single-bottom-right 'toggle-button 'compact)
               (lt:place-in-area 'single-bottom-right 'bottom-right))
         #:screen-rows 15 #:screen-cols 24))
       (node (resolved-node resolved 'single-bottom-right)))
  (check 'single-node-area-bottom-right
         (and (= (field node 'col) 21)
              (= (field node 'row) 13))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'single-hierarchy 'rotary-slider 'standard)
               (lt:place-in-area
                'single-hierarchy '(bottom-right top-left center)))
         #:screen-rows 15 #:screen-cols 24))
       (node (resolved-node resolved 'single-hierarchy)))
  (check 'single-node-hierarchical-area
         (and (= (field node 'col) 89/6)
              (= (field node 'row) 25/3)
              (exact? (field node 'col))
              (exact? (field node 'row)))))

(let* ((resolved
        (lt:solve
         (list (lt:node 'single-compatible 'toggle-button 'compact #:row 1)
               (lt:place-in-area 'single-compatible 'top))
         #:screen-rows 15 #:screen-cols 24))
       (node (resolved-node resolved 'single-compatible)))
  (check 'single-node-area-compatible-hard-anchor
         (and (= (field node 'col) 11)
              (= (field node 'row) 1))))

(check 'single-node-area-incompatible-hard-anchor
       (rejected?
        (lambda ()
          (lt:solve
           (list (lt:node 'single-incompatible 'toggle-button 'compact
                          #:col 1)
                 (lt:place-in-area 'single-incompatible 'bottom-right))
           #:screen-rows 15 #:screen-cols 24))))

(display "topological-layout-test: PASS\n")
