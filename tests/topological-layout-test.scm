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

(define (rejected? thunk)
  (catch #t
    (lambda () (thunk) #f)
    (lambda args #t)))

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

(display "topological-layout-test: PASS\n")
