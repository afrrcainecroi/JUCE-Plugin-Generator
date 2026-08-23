(use-modules (generator-app topological-layout))

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

(display "topological-layout-test: PASS\n")
