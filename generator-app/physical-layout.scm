(define-module (generator-app physical-layout)

  #:use-module (srfi srfi-1)
  #:use-module (generator-app ui-metrics)

  #:export (pl:resolve-base-unit
            pl:resolve-ui-scale
            pl:metric-contract
            pl:size-contract
            pl:target-size
            pl:rectangle-overlap?
            pl:validate-rectangle!
            pl:validate-layout-bounds!
            pl:validate-layout-overlaps!
	    pl:stack-size-contract
	    pl:resolve-size-contracts
	    pl:layout-stack
	    pl:layout-stack-recursive
	    pl:allocate-vertical-regions
	    pl:allocate-horizontal-rails
	    pl:required-bottom-reserve
	    pl:allocate-bottom-corners
	    pl:allocate-top-right
	    pl:prepare-topology
	    pl:prepare-physical-model
	    pl:place-preferred-in-area
	    pl:apply-alignment
	    pl:layout-stack-tree
	    pl:make-physical-layout
	    pl:entity-rectangle
	    pl:prepare-relations
	    pl:vertical-feasible-interval
	    pl:choose-coordinate
	    pl:solve-vertical-coordinate
	    pl:solve-y-axis
	    pl:prepare-relations
	    pl:solve-x-axis
	    pl:make-domain
	    pl:domain-rectangle
	    pl:domain-for-entity
	    pl:place-preferred-in-domain
	    pl:merge-axis-layouts
	    pl:solve
	    pl:build-standard-domains
	    
	    ))


;; ======================================================================
;; Helpers
;; ======================================================================

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))


;; ======================================================================
;; BASE PHYSICAL UNIT
;;
;; One UI metric unit corresponds to a fixed number of JUCE logical
;; pixels.
;;
;; It is intentionally independent from:
;;
;;   - screen width
;;   - screen height
;;   - grid rows
;;   - grid columns
;;
;; This is what separates physical component density from grid
;; discretisation.
;; ======================================================================

(define (pl:resolve-base-unit base-unit-px)

  (let ((value
         (cond

          ((not base-unit-px)
           12)

          ((and (number? base-unit-px)
                (exact? base-unit-px))
           base-unit-px)

          ((number? base-unit-px)
           (rationalize
            (inexact->exact base-unit-px)
            1/1000000))

          (else
           (error
            "base-unit-px must be numeric"
            base-unit-px)))))

    (unless (> value 0)
      (error
       "base-unit-px must be > 0"
       value))

    value))


;; ======================================================================
;; GLOBAL DESIRED UI SCALE
;;
;; ui-scale is a PREFERENCE.
;;
;; It affects preferred target size.
;; It does NOT raise visual-min.
;; ======================================================================

(define* (pl:resolve-ui-scale
          ui-scale
          #:optional
          (ui-size #f))

  (ui-resolve-scale
   ui-scale
   ui-size))


;; ======================================================================
;; UI METRIC CONTRACT
;; ======================================================================

(define (pl:metric-contract type variant)

  (let ((metrics
         (ui-metrics type)))

    (unless metrics
      (error
       "Unknown physical-layout UI metric TYPE"
       type))

    (if variant

        (let* ((variants
                (field metrics 'variants))

               (entry
                (and variants
                     (assoc variant variants))))

          (unless entry
            (error
             "Unknown physical-layout UI metric variant"
             type
             variant))

          (cdr entry))

        metrics)))


;; ======================================================================
;; SIZE CONTRACT
;;
;; Output physical sizes are exact JUCE logical pixels.
;;
;; IMPORTANT:
;;
;; visual-min is NOT multiplied by ui-scale.
;;
;; preferred is multiplied by ui-scale because scale expresses the
;; desired visual density.
;;
;; useful-max is also independent from desired scale and acts as a
;; physical upper contract.
;; ======================================================================

;; ======================================================================
;; PHYSICAL SIZE CONTRACT
;;
;; visual-min is an absolute physical floor:
;;
;;   visual-min * base-unit-px
;;
;; preferred follows the requested UI scale:
;;
;;   preferred * base-unit-px * ui-scale
;;
;; useful-max also follows the requested UI scale:
;;
;;   useful-max * base-unit-px * ui-scale
;;
;; If scaled useful-max falls below the absolute visual minimum,
;; visual-min wins.  Therefore every returned contract always satisfies:
;;
;;   min <= preferred <= max
;; ======================================================================

(define (pl:size-contract
         type
         variant
         profile
         base-unit-px
         ui-scale
         width-scale
         height-scale)

  (let* ((unit
          (pl:resolve-base-unit
           base-unit-px))

         (scale
          (pl:resolve-ui-scale
           ui-scale))

         (eff-unit-x (* unit width-scale))
         (eff-unit-y (* unit height-scale))

         (contract
          (pl:metric-contract
           type
           variant))

         (visual-min
          (field contract 'visual-min))

         (useful-max
          (field contract 'useful-max))
          
         (profile-metrics
          (if variant
              (ui-profile type variant profile)
              (ui-profile type profile))))

    (unless visual-min
      (error "UI metric has no visual-min" type variant))
    (unless useful-max
      (error "UI metric has no useful-max" type variant))
    (unless profile-metrics
      (error "UI metric has no matching profile" type variant profile))

    (let* ((min-width
            (* eff-unit-x
               (field visual-min 'width)))

           (min-height
            (* eff-unit-y
               (field visual-min 'height)))

           (scaled-preferred-width
            (* eff-unit-x
               scale
               (field profile-metrics 'width)))

           (scaled-preferred-height
            (* eff-unit-y
               scale
               (field profile-metrics 'height)))

           (scaled-max-width
            (* eff-unit-x
               scale
               (field useful-max 'width)))

           (scaled-max-height
            (* eff-unit-y
               scale
               (field useful-max 'height)))

           ;; visual-min is the absolute physical floor.
           ;; A requested scale may never force useful-max below it.
           (max-width
            (max min-width
                 scaled-max-width))

           (max-height
            (max min-height
                 scaled-max-height))

           (preferred-width
            (min max-width
                 (max min-width
                      scaled-preferred-width)))

           (preferred-height
            (min max-height
                 (max min-height
                      scaled-preferred-height))))

      `((min-width . ,min-width)
        (min-height . ,min-height)
        (preferred-width . ,preferred-width)
        (preferred-height . ,preferred-height)
        (max-width . ,max-width)
        (max-height . ,max-height)))))

(define (pl:target-size
         type
         variant
         profile
         base-unit-px
         ui-scale
         width-scale
         height-scale)

  (let ((contract
         (pl:size-contract
          type
          variant
          profile
          base-unit-px
          ui-scale
          width-scale
          height-scale)))

    (cons
     (field contract 'preferred-width)
     (field contract 'preferred-height))))

(define (pl:resolve-size-contracts
         nodes
         stacks
         base-unit-px
         ui-scale)

  ;; ------------------------------------------------------------
  ;; Real UI nodes first
  ;; ------------------------------------------------------------

  (let ((initial-contracts

         (map

          (lambda (node)

            (cons
             (field node 'id)

             (pl:size-contract
              (field node 'type)
              (field node 'variant)
              (field node 'profile)
              base-unit-px
              ui-scale
              (field node 'width-scale)
              (field node 'height-scale))))

          nodes)))

    ;; ----------------------------------------------------------
    ;; Then resolve stack contracts bottom-up.
    ;; ----------------------------------------------------------

    (let loop ((pending stacks)
               (contracts initial-contracts))

      (if (null? pending)

          contracts

          (let ((resolvable

                 (filter

                  (lambda (stack)

                    (every
                     (lambda (member)
                       (assoc member contracts))
                     (field stack 'members)))

                  pending)))

        (when (null? resolvable)

          (error
           "Cyclic or unresolvable physical stack dependencies"
           pending))

        (let ((new-contracts
               contracts))

          (for-each

           (lambda (stack)

             (set! new-contracts

                   (acons
                    (field stack 'id)

                    (pl:stack-size-contract
                     stack
                     new-contracts
                     base-unit-px)

                    new-contracts)))

           resolvable)

          (loop

           (filter
            (lambda (stack)
              (not (memq stack resolvable)))
            pending)

           new-contracts)))))))


;; ======================================================================
;; TARGET SIZE
;; ======================================================================




;; ======================================================================
;; RECTANGLE GEOMETRY
;;
;; Rectangle format:
;;
;; ((id . ...)
;;  (x . ...)
;;  (y . ...)
;;  (width . ...)
;;  (height . ...))
;; ======================================================================

(define (pl:rectangle-overlap? a b)

  (let ((ax (field a 'x))
        (ay (field a 'y))
        (aw (field a 'width))
        (ah (field a 'height))

        (bx (field b 'x))
        (by (field b 'y))
        (bw (field b 'width))
        (bh (field b 'height)))

    ;; Strict inequalities:
    ;; exact edge touching is valid.

    (and
     (< ax (+ bx bw))
     (< bx (+ ax aw))
     (< ay (+ by bh))
     (< by (+ ay ah)))))


;; ======================================================================
;; SINGLE RECTANGLE VALIDATION
;; ======================================================================

(define (pl:validate-rectangle!
         rectangle
         physical-width
         physical-height)

  (let ((id
         (field rectangle 'id))

        (x
         (field rectangle 'x))

        (y
         (field rectangle 'y))

        (width
         (field rectangle 'width))

        (height
         (field rectangle 'height)))

    (unless
        (and
         (number? x)
         (number? y)
         (number? width)
         (number? height)

         (exact? x)
         (exact? y)
         (exact? width)
         (exact? height))

      (error
       "Physical layout rectangle must use exact numeric coordinates"
       id
       rectangle))

    (unless
        (and
         (>= x 0)
         (>= y 0)
         (> width 0)
         (> height 0)
         (<= (+ x width)
             physical-width)
         (<= (+ y height)
             physical-height))

      (error
       "Physical layout rectangle outside screen"
       id
       rectangle
       physical-width
       physical-height))

    #t))


;; ======================================================================
;; GLOBAL SCREEN VALIDATION
;; ======================================================================

(define (pl:validate-layout-bounds!
         rectangles
         physical-width
         physical-height)

  (for-each

   (lambda (rectangle)

     (pl:validate-rectangle!
      rectangle
      physical-width
      physical-height))

   rectangles)

  #t)


;; ======================================================================
;; GLOBAL OVERLAP VALIDATION
;; ======================================================================

(define (pl:validate-layout-overlaps!
         rectangles)

  (let loop ((remaining rectangles))

    (unless (null? remaining)

      (let ((current
             (car remaining)))

        (for-each

         (lambda (other)

           (when
               (pl:rectangle-overlap?
                current
                other)

             (error
              "Physical layout overlap"
              (field current 'id)
              (field other 'id))))

         (cdr remaining)))

      (loop
       (cdr remaining))))

  #t)

;; ======================================================================
;; STACK SIZE CONTRACTS
;;
;; A stack derives its physical min / preferred / max dimensions
;; from its children.
;;
;; Gaps are currently treated as fixed preferred physical distances.
;; Later the allocator will make them elastic.
;; ======================================================================

(define (pl:stack-size-contract
         stack
         child-contracts
         base-unit-px)

  (let* ((layout
          (field stack 'layout))

         (gap
          (field stack 'gap))

         (unit
          (pl:resolve-base-unit base-unit-px))

         ;; Current semantics:
         ;; lt:stack gap is still expressed in UI metric units.
         ;; Convert it to JUCE logical pixels here.
         (physical-gap
          (* gap unit))

         (members
          (field stack 'members))

         (contracts
          (map
           (lambda (member)

             (let ((entry
                    (assoc member child-contracts)))

               (unless entry
                 (error
                  "Missing physical size contract for stack member"
                  (field stack 'id)
                  member))

               (cdr entry)))

           members)))

    (define (value contract key)
      (field contract key))

    (define (sum key)
      (+ (apply +
                (map
                 (lambda (contract)
                   (value contract key))
                 contracts))

         (* physical-gap
            (- (length contracts) 1))))

    (define (maximum key)
      (apply max
             (map
              (lambda (contract)
                (value contract key))
              contracts)))

    (case layout

      ((horizontal)

       `((min-width .
                    ,(sum 'min-width))

         (min-height .
                     ,(maximum 'min-height))

         (preferred-width .
                          ,(sum 'preferred-width))

         (preferred-height .
                           ,(maximum 'preferred-height))

         (max-width .
                    ,(sum 'max-width))

         (max-height .
                     ,(maximum 'max-height))))

      ((vertical)

       `((min-width .
                    ,(maximum 'min-width))

         (min-height .
                     ,(sum 'min-height))

         (preferred-width .
                          ,(maximum 'preferred-width))

         (preferred-height .
                           ,(sum 'preferred-height))

         (max-width .
                    ,(maximum 'max-width))

         (max-height .
                     ,(sum 'max-height))))

      (else

       (error
        "Invalid physical stack layout"
        (field stack 'id)
        layout)))))

;; ======================================================================
;; RESOLVE NODE + STACK PHYSICAL SIZE CONTRACTS
;;
;; Input:
;;   nodes  = normalized lt:node entities
;;   stacks = flattened first-class lt:stack entities
;;
;; Output:
;;   association list:
;;
;;   ((node-id  . size-contract)
;;    (stack-id . size-contract)
;;    ...)
;;
;; Nested stacks are resolved bottom-up.
;; ======================================================================



  
;; ======================================================================
;; STACK PHYSICAL PLACEMENT
;;
;; Places the direct members of one stack inside a physical rectangle.
;;
;; First implementation:
;;
;;   - uses preferred physical sizes
;;   - gap is still fixed
;;   - supports horizontal / vertical
;;   - supports cross-align start / center / end
;;
;; Output contains rectangles for the DIRECT children.
;;
;; Nested recursion will be added separately.
;; ======================================================================

(define (pl:layout-stack
         stack
         contracts
         base-unit-px
         origin-x
         origin-y)

  (let* ((layout
          (field stack 'layout))

         (cross-align
          (or (field stack 'cross-align)
              'start))

         (gap
          (or (field stack 'gap)
              0))

         (unit
          (pl:resolve-base-unit
           base-unit-px))

         (physical-gap
          (* gap unit))

         (members
          (field stack 'members))

         (stack-entry
          (assoc (field stack 'id)
                 contracts)))

    (unless stack-entry
      (error
       "Missing physical size contract for stack"
       (field stack 'id)))

    (let* ((stack-contract
            (cdr stack-entry))

           (stack-width
            (field stack-contract
                   'preferred-width))

           (stack-height
            (field stack-contract
                   'preferred-height)))

      ;; --------------------------------------------------------
      ;; Helper: preferred dimensions of one child
      ;; --------------------------------------------------------

      (define (child-size member)

        (let ((entry
               (assoc member contracts)))

          (unless entry
            (error
             "Missing physical size contract for stack member"
             (field stack 'id)
             member))

          (let ((contract
                 (cdr entry)))

            (cons
             (field contract 'preferred-width)
             (field contract 'preferred-height)))))

      ;; --------------------------------------------------------
      ;; Cross-axis placement
      ;; --------------------------------------------------------

      (define (cross-position
               child-extent
               stack-extent
               origin)

        (case cross-align

          ((start)
           origin)

          ((center)
           (+ origin
              (/ (- stack-extent
                    child-extent)
                 2)))

          ((end)
           (+ origin
              (- stack-extent
                 child-extent)))

          (else
           (error
            "Invalid stack cross-align"
            (field stack 'id)
            cross-align))))

      ;; --------------------------------------------------------
      ;; Horizontal
      ;; --------------------------------------------------------

      (case layout

        ((horizontal)

         (let loop ((remaining members)
                    (x origin-x)
                    (result '()))

           (if (null? remaining)

               (reverse result)

               (let* ((member
                       (car remaining))

                      (size
                       (child-size member))

                      (width
                       (car size))

                      (height
                       (cdr size))

                      (y
                       (cross-position
                        height
                        stack-height
                        origin-y))

                      (rectangle
                       `((id . ,member)
                         (x . ,x)
                         (y . ,y)
                         (width . ,width)
                         (height . ,height))))

                 (loop
                  (cdr remaining)

                  (+ x
                     width
                     physical-gap)

                  (cons rectangle
                        result))))))

        ;; ------------------------------------------------------
        ;; Vertical
        ;; ------------------------------------------------------

        ((vertical)

         (let loop ((remaining members)
                    (y origin-y)
                    (result '()))

           (if (null? remaining)

               (reverse result)

               (let* ((member
                       (car remaining))

                      (size
                       (child-size member))

                      (width
                       (car size))

                      (height
                       (cdr size))

                      (x
                       (cross-position
                        width
                        stack-width
                        origin-x))

                      (rectangle
                       `((id . ,member)
                         (x . ,x)
                         (y . ,y)
                         (width . ,width)
                         (height . ,height))))

                 (loop
                  (cdr remaining)

                  (+ y
                     height
                     physical-gap)

                  (cons rectangle
                        result))))))

        (else

         (error
          "Invalid physical stack layout"
          (field stack 'id)
          layout))))))

;; ======================================================================
;; RECURSIVE STACK PHYSICAL PLACEMENT
;;
;; Expands nested stacks recursively and returns physical rectangles
;; only for real UI nodes.
;;
;; Stack rectangles are structural and are not emitted as UI components.
;; ======================================================================

(define (pl:layout-stack-recursive
         stack
         stacks
         contracts
         base-unit-px
         origin-x
         origin-y)

  (let ((direct-layout
         (pl:layout-stack
          stack
          contracts
          base-unit-px
          origin-x
          origin-y)))

    (append-map

     (lambda (rectangle)

       (let* ((id
               (field rectangle 'id))

              (nested-entry
               (find
                (lambda (candidate)
                  (eq? (field candidate 'id)
                       id))
                stacks)))

         (if nested-entry

             ;; --------------------------------------------------
             ;; Structural child: recurse using the physical origin
             ;; assigned to this nested stack.
             ;; --------------------------------------------------

             (pl:layout-stack-recursive
              nested-entry
              stacks
              contracts
              base-unit-px
              (field rectangle 'x)
              (field rectangle 'y))

             ;; --------------------------------------------------
             ;; Real UI node.
             ;; --------------------------------------------------

             (list rectangle))))

     direct-layout)))

;; ======================================================================
;; RECURSIVE STACK TREE PHYSICAL PLACEMENT
;;
;; Returns BOTH:
;;
;;   components  -> real UI node rectangles only
;;   structures  -> stack bounding rectangles
;;
;; Stack bboxes are structural and may participate in constraints and
;; alignments, but are never emitted as JUCE components.
;; ======================================================================

(define (pl:layout-stack-tree
         stack
         stacks
         contracts
         base-unit-px
         origin-x
         origin-y)

  (let* ((stack-id
          (field stack 'id))

         (stack-entry
          (assoc stack-id contracts)))

    (unless stack-entry
      (error
       "Missing physical size contract for stack"
       stack-id))

    (let* ((stack-contract
            (cdr stack-entry))

           (stack-rectangle
            `((id . ,stack-id)
              (x . ,origin-x)
              (y . ,origin-y)
              (width .
                     ,(field stack-contract
                             'preferred-width))
              (height .
                      ,(field stack-contract
                              'preferred-height))))

           (direct-layout
            (pl:layout-stack
             stack
             contracts
             base-unit-px
             origin-x
             origin-y)))

      (let loop ((remaining direct-layout)
                 (components '())
                 (structures
                  (list stack-rectangle)))

        (if (null? remaining)

            `((components . ,(reverse components))
              (structures . ,(reverse structures)))

            (let* ((rectangle
                    (car remaining))

                   (id
                    (field rectangle 'id))

                   (nested-stack
                    (find
                     (lambda (candidate)
                       (eq? (field candidate 'id)
                            id))
                     stacks)))

              (if nested-stack

                  (let* ((nested-result
                          (pl:layout-stack-tree
                           nested-stack
                           stacks
                           contracts
                           base-unit-px
                           (field rectangle 'x)
                           (field rectangle 'y)))

                         (nested-components
                          (field nested-result
                                 'components))

                         (nested-structures
                          (field nested-result
                                 'structures)))

                    (loop
                     (cdr remaining)
                     (append
                      (reverse nested-components)
                      components)
                     (append
                      (reverse nested-structures)
                      structures)))

                  (loop
                   (cdr remaining)
                   (cons rectangle components)
                   structures))))))))


;; ======================================================================
;; VERTICAL REGION ALLOCATOR
;;
;; Minimal first global physical allocator.
;;
;; It places three first-class physical entities:
;;
;;   TOP
;;   CENTER
;;   BOTTOM
;;
;; inside the available physical height.
;;
;; Semantics:
;;
;;   top.y    = 0
;;   bottom.y = physical-height - bottom.height
;;
;;   center is vertically centered in the free interval:
;;
;;     [ top.bottom , bottom.top ]
;;
;; Hard invariants:
;;
;;   top.bottom    <= center.top
;;   center.bottom <= bottom.top
;;
;; If the preferred physical sizes cannot fit, this function fails.
;;
;; No size compression is performed yet.
;; No gap elasticity is performed yet.
;; ======================================================================

(define* (pl:allocate-vertical-regions
          physical-width
          physical-height
          top-id
          center-id
          bottom-id
          contracts
          #:key
          (top-reserve 0)
          (bottom-reserve 0))

  ;; ------------------------------------------------------------
  ;; Contract lookup
  ;; ------------------------------------------------------------

  (define (contract-for id)

    (let ((entry
           (assoc id contracts)))

      (unless entry
        (error
         "Missing physical size contract"
         id))

      (cdr entry)))


  (define (preferred-width contract)
    (field contract 'preferred-width))

  (define (preferred-height contract)
    (field contract 'preferred-height))


  ;; ------------------------------------------------------------
  ;; Resolve contracts
  ;; ------------------------------------------------------------

  (let* ((top-contract
          (contract-for top-id))

         (center-contract
          (contract-for center-id))

         (bottom-contract
          (contract-for bottom-id))

         (top-width
          (preferred-width top-contract))

         (top-height
          (preferred-height top-contract))

         (center-width
          (preferred-width center-contract))

         (center-height
          (preferred-height center-contract))

         (bottom-width
          (preferred-width bottom-contract))

         (bottom-height
          (preferred-height bottom-contract))


         ;; -----------------------------------------------------
         ;; Fixed top/bottom anchors
         ;; -----------------------------------------------------

         (top-y
          top-reserve)

         (top-bottom
          (+ top-y
             top-height))

         (bottom-y
          (- physical-height
	     bottom-reserve
             bottom-height))

         (bottom-top
          bottom-y)


         ;; -----------------------------------------------------
         ;; Free interval available to CENTER
         ;; -----------------------------------------------------

         (free-top
          top-bottom)

         (free-bottom
          bottom-top)

         (free-height
          (- free-bottom
             free-top)))


    ;; ----------------------------------------------------------
    ;; First hard feasibility test
    ;; ----------------------------------------------------------

    (when (< free-height
             center-height)

      (error
       "Physical vertical regions do not fit"
       `((physical-height . ,physical-height)

         (top-id . ,top-id)
         (top-height . ,top-height)

         (center-id . ,center-id)
         (center-height . ,center-height)

         (bottom-id . ,bottom-id)
         (bottom-height . ,bottom-height)

         (available-center-height . ,free-height))))


    ;; ----------------------------------------------------------
    ;; Center CENTER inside the remaining free interval.
    ;; ----------------------------------------------------------

    (let* ((center-y
            (+ free-top
               (/ (- free-height
                     center-height)
                  2)))

	   (top-rectangle
	    `((id . ,top-id)
	      (x . ,(/ (- physical-width
			  top-width)
		       2))
	      (y . ,top-y)
	      (width . ,top-width)
	      (height . ,top-height)))

	   (center-rectangle
	    `((id . ,center-id)
	      (x . ,(/ (- physical-width
			  center-width)
		       2))
	      (y . ,center-y)
	      (width . ,center-width)
	      (height . ,center-height)))

	   (bottom-rectangle
	    `((id . ,bottom-id)
	      (x . ,(/ (- physical-width
			  bottom-width)
		       2))
	      (y . ,bottom-y)
	      (width . ,bottom-width)
	      (height . ,bottom-height)))
	   )

      ;; --------------------------------------------------------
      ;; Defensive consistency checks
      ;; --------------------------------------------------------

      (unless
          (<= (+ (field top-rectangle 'y)
				   (field top-rectangle 'height))

				(field center-rectangle 'y))

        (error
         "Vertical allocator violated TOP/CENTER ordering"
         top-rectangle
         center-rectangle))

      (unless
          (<= (+ (field center-rectangle 'y)
				   (field center-rectangle 'height))

				(field bottom-rectangle 'y))

        (error
         "Vertical allocator violated CENTER/BOTTOM ordering"
         center-rectangle
         bottom-rectangle))

      (list
       top-rectangle
       center-rectangle
       bottom-rectangle))))

;; ======================================================================
;; HORIZONTAL SIDE-RAIL ALLOCATOR
;;
;; Places two first-class physical entities:
;;
;;   LEFT RAIL
;;   RIGHT RAIL
;;
;; inside the physical window.
;;
;; Semantics:
;;
;;   left.x  = 0
;;   right.x = physical-width - right.width
;;
;; Both rails are vertically centered in the physical window.
;;
;; Hard invariants:
;;
;;   - both rails remain entirely inside the screen
;;   - left and right rails must not overlap
;;
;; No interaction with TOP/CENTER/BOTTOM is handled here yet.
;; The global overlap validator remains authoritative.
;; ======================================================================

(define (pl:allocate-horizontal-rails
         physical-width
         physical-height
         left-id
         right-id
         contracts)

  (define (contract-for id)

    (let ((entry
           (assoc id contracts)))

      (unless entry
        (error
         "Missing physical size contract"
         id))

      (cdr entry)))


  (define (preferred-width contract)
    (field contract 'preferred-width))

  (define (preferred-height contract)
    (field contract 'preferred-height))


  (let* ((left-contract
          (contract-for left-id))

         (right-contract
          (contract-for right-id))

         (left-width
          (preferred-width left-contract))

         (left-height
          (preferred-height left-contract))

         (right-width
          (preferred-width right-contract))

         (right-height
          (preferred-height right-contract))


         ;; -----------------------------------------------------
         ;; Horizontal anchors
         ;; -----------------------------------------------------

         (left-x
          0)

         (right-x
          (- physical-width
             right-width))


         ;; -----------------------------------------------------
         ;; Vertical centering
         ;; -----------------------------------------------------

         (left-y
          (/ (- physical-height
                left-height)
             2))

         (right-y
          (/ (- physical-height
                right-height)
             2))


         ;; -----------------------------------------------------
         ;; Physical rectangles
         ;; -----------------------------------------------------

         (left-rectangle
          `((id . ,left-id)
            (x . ,left-x)
            (y . ,left-y)
            (width . ,left-width)
            (height . ,left-height)))

         (right-rectangle
          `((id . ,right-id)
            (x . ,right-x)
            (y . ,right-y)
            (width . ,right-width)
            (height . ,right-height))))


    ;; ----------------------------------------------------------
    ;; Hard screen containment
    ;; ----------------------------------------------------------

    (pl:validate-rectangle!
      left-rectangle
      physical-width
      physical-height)

    (pl:validate-rectangle!
      right-rectangle
      physical-width
      physical-height)


    ;; ----------------------------------------------------------
    ;; Side rails themselves must not overlap.
    ;; ----------------------------------------------------------

    (when
        (pl:rectangle-overlap?
          left-rectangle
          right-rectangle)

      (error
       "Physical left/right rails overlap"
       left-id
       right-id))


    (list
      left-rectangle
      right-rectangle)))

;; ======================================================================
;; BOTTOM RESERVED BAND
;;
;; Computes the physical height that must remain free below the
;; standard bottom controls for footer-like components.
;;
;; The reserve is:
;;
;;   max(preferred-height of footer entities)
;;   + preferred physical gap
;;
;; gap is expressed in UI metric units and converted through
;; base-unit-px.
;; ======================================================================

(define (pl:required-bottom-reserve
         ids
         contracts
         base-unit-px
         gap)

  (let* ((unit
          (pl:resolve-base-unit
           base-unit-px))

         (physical-gap
          (* unit gap))

         (heights
          (map

           (lambda (id)

             (let ((entry
                    (assoc id contracts)))

               (unless entry
                 (error
                  "Missing physical size contract for bottom reserved entity"
                  id))

               (let ((height
                      (field
                       (cdr entry)
                       'preferred-height)))

                 (unless height
                   (error
                    "Missing preferred-height for bottom reserved entity"
                    id))

                 height)))

           ids)))

    (+ (if (null? heights)
           0
           (apply max heights))

       physical-gap)))

;; ======================================================================
;; BOTTOM CORNER ALLOCATOR
;;
;; Places two real physical entities:
;;
;;   LEFT  -> bottom-left
;;   RIGHT -> bottom-right
;;
;; Both are bottom-aligned to the physical window.
;;
;; The caller is responsible for reserving enough vertical space above
;; them, typically through pl:required-bottom-reserve.
;; ======================================================================

(define (pl:allocate-bottom-corners
         physical-width
         physical-height
         left-id
         right-id
         contracts)

  (define (contract-for id)

    (let ((entry
           (assoc id contracts)))

      (unless entry
        (error
         "Missing physical size contract"
         id))

      (cdr entry)))


  (let* ((left-contract
          (contract-for left-id))

         (right-contract
          (contract-for right-id))

         (left-width
          (field left-contract 'preferred-width))

         (left-height
          (field left-contract 'preferred-height))

         (right-width
          (field right-contract 'preferred-width))

         (right-height
          (field right-contract 'preferred-height))


         ;; -----------------------------------------------------
         ;; Bottom-left
         ;; -----------------------------------------------------

         (left-rectangle
          `((id . ,left-id)
            (x . 0)
            (y . ,(- physical-height
                     left-height))
            (width . ,left-width)
            (height . ,left-height)))


         ;; -----------------------------------------------------
         ;; Bottom-right
         ;; -----------------------------------------------------

         (right-rectangle
          `((id . ,right-id)
            (x . ,(- physical-width
                     right-width))
            (y . ,(- physical-height
                     right-height))
            (width . ,right-width)
            (height . ,right-height))))


    ;; ----------------------------------------------------------
    ;; Screen containment
    ;; ----------------------------------------------------------

    (pl:validate-rectangle!
      left-rectangle
      physical-width
      physical-height)

    (pl:validate-rectangle!
      right-rectangle
      physical-width
      physical-height)


    ;; ----------------------------------------------------------
    ;; Footer entities themselves must not overlap.
    ;; ----------------------------------------------------------

    (when
        (pl:rectangle-overlap?
          left-rectangle
          right-rectangle)

      (error
       "Physical bottom-corner entities overlap"
       left-id
       right-id))


    (list
      left-rectangle
      right-rectangle)))

;; ======================================================================
;; TOP-RIGHT ALLOCATOR
;;
;; Places one first-class physical entity at the top-right corner.
;; ======================================================================

(define (pl:allocate-top-right
         physical-width
         physical-height
         id
         contracts)

  (let ((entry
         (assoc id contracts)))

    (unless entry
      (error
       "Missing physical size contract"
       id))

    (let* ((contract
            (cdr entry))

           (width
            (field contract 'preferred-width))

           (height
            (field contract 'preferred-height))

           (rectangle
            `((id . ,id)
              (x . ,(- physical-width width))
              (y . 0)
              (width . ,width)
              (height . ,height))))

      (pl:validate-rectangle!
        rectangle
        physical-width
        physical-height)

      rectangle)))


;; ======================================================================
;; PREPARE NORMALIZED TOPOLOGY FOR PHYSICAL LAYOUT
;;
;; Converts the normalized topological IR into the physical-layout
;; structural input.
;;
;; Important:
;;
;; - real nodes are preserved exactly as normalized
;; - inline nested stacks are flattened
;; - nested stack objects inside #:members are replaced by their IDs
;; - area placements, constraints and alignments remain separate
;;
;; No geometry is solved here.
;; No screen/grid dimensions are interpreted here.
;; ======================================================================

(define (pl:prepare-topology normalized)

  (let ((entries
         (field normalized 'entries)))

    (unless entries
      (error
       "Normalized topology has no entries"
       normalized))

    ;; ------------------------------------------------------------
    ;; Canonicalize one stack and recursively extract nested stacks.
    ;;
    ;; Returns:
    ;;
    ;;   (canonical-stack nested-stack ...)
    ;; ------------------------------------------------------------

    (define (flatten-stack stack)

      (let* ((members
              (field stack 'members))

             (nested-stacks
              (filter
               (lambda (member)
                 (and (pair? member)
                      (eq? (field member 'kind)
                           'stack)))
               members))

             (canonical-members
              (map
               (lambda (member)

                 (if (and (pair? member)
                          (eq? (field member 'kind)
                               'stack))

                     (field member 'id)

                     member))

               members))

             (canonical
              `((kind . stack)
                (id . ,(field stack 'id))
                (layout . ,(field stack 'layout))
                (gap . ,(or (field stack 'gap) 0))
                (cross-align .
                             ,(or (field stack 'cross-align)
                                  'start))
                (members . ,canonical-members))))

        (cons
         canonical

         (append-map
          flatten-stack
          nested-stacks))))


    ;; ------------------------------------------------------------
    ;; Top-level normalized entities
    ;; ------------------------------------------------------------

    (let* ((nodes
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'node))
             entries))

           (top-level-stacks
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'stack))
             entries))

           (stacks
            (append-map
             flatten-stack
             top-level-stacks))

           (placements
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'node-area))
             entries))

           (constraints
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'node-constraints))
             entries))

           (alignments
            (filter
             (lambda (entry)
               (eq? (field entry 'kind)
                    'alignment))
             entries)))

      `((nodes . ,nodes)
        (stacks . ,stacks)
        (placements . ,placements)
        (constraints . ,constraints)
        (alignments . ,alignments)))))

;; ======================================================================
;; NORMALIZED TO PHYSICAL MODEL
;;
;; Converts the normalized topological IR into the input model required
;; by PhysicalLayout.
;;
;; No coordinates are assigned here.
;; No topology is solved here.
;; No grid information is used here.
;; ======================================================================



(define* (pl:prepare-physical-model
          normalized
          base-unit-px
          ui-scale
          #:optional
          (ui-size #f))

  (let* ((prepared
          (pl:prepare-topology
           normalized))

         (nodes
          (field prepared 'nodes))

         (stacks
          (field prepared 'stacks))

         (placements
          (field prepared 'placements))

         (constraints
          (field prepared 'constraints))

         (alignments
          (field prepared 'alignments))

         (base-unit
          (pl:resolve-base-unit
           base-unit-px))

         (scale
          (pl:resolve-ui-scale
           ui-scale
           ui-size))

         (contracts
          (pl:resolve-size-contracts
           nodes
           stacks
           base-unit
           scale)))

    `((nodes . ,nodes)
      (stacks . ,stacks)
      (placements . ,placements)
      (constraints . ,constraints)
      (alignments . ,alignments)
      (base-unit-px . ,base-unit)
      (ui-scale . ,scale)
      (ui-size . ,ui-size)
      (contracts . ,contracts))))

;; ======================================================================
;; PLACE PREFERRED RECTANGLE IN PHYSICAL AREA
;;
;; Areas are coarse physical anchors.
;;
;; Supported:
;;
;;   top
;;   bottom
;;   left
;;   right
;;   center
;;   top-left
;;   top-right
;;   bottom-left
;;   bottom-right
;;
;; usable-top / usable-bottom allow reserved physical bands.
;; ======================================================================

(define* (pl:place-preferred-in-area
          id
          area
          contracts
          physical-width
          physical-height
          #:key
          (usable-top 0)
          (usable-bottom physical-height))

  (let ((entry
         (assoc id contracts)))

    (unless entry
      (error
       "Missing physical size contract"
       id))

    (unless (and (number? usable-top)
                 (number? usable-bottom)
                 (<= 0 usable-top)
                 (<= usable-top usable-bottom)
                 (<= usable-bottom physical-height))
      (error
       "Invalid physical usable vertical interval"
       usable-top
       usable-bottom
       physical-height))

    (let* ((contract
            (cdr entry))

           (width
            (field contract 'preferred-width))

           (height
            (field contract 'preferred-height))

           (usable-height
            (- usable-bottom usable-top))

           (center-x
            (/ (- physical-width width) 2))

           (center-y
            (+ usable-top
               (/ (- usable-height height) 2)))

           (right-x
            (- physical-width width))

           (bottom-y
            (- usable-bottom height))

           (position
            (case area

              ((top)
               (cons center-x usable-top))

              ((bottom)
               (cons center-x bottom-y))

              ((left)
               (cons 0 center-y))

              ((right)
               (cons right-x center-y))

              ((center)
               (cons center-x center-y))

              ((top-left)
               (cons 0 usable-top))

              ((top-right)
               (cons right-x usable-top))

              ((bottom-left)
               (cons 0 bottom-y))

              ((bottom-right)
               (cons right-x bottom-y))

              (else
               (error
                "Unsupported physical area"
                area))))

           (rectangle
            `((id . ,id)
              (x . ,(car position))
              (y . ,(cdr position))
              (width . ,width)
              (height . ,height))))

      (pl:validate-rectangle!
       rectangle
       physical-width
       physical-height)

      rectangle)))


;; ======================================================================
;; APPLY ONE PHYSICAL ALIGNMENT
;;
;; The first node is the reference.
;; The remaining nodes are moved without changing their size.
;;
;; Supported:
;;
;;   align-center-x
;;   align-center-y
;;   align-left
;;   align-right
;;   align-top
;;   align-bottom
;; ======================================================================

(define (pl:apply-alignment
         alignment
         rectangles)

  (define (rect-by-id id)

    (let ((rectangle
           (find
            (lambda (rectangle)
              (eq? (field rectangle 'id)
                   id))
            rectangles)))

      (unless rectangle
        (error
         "Physical alignment references missing rectangle"
         id))

      rectangle))


  (define (replace-rectangle id new-rectangle source)

    (map
     (lambda (rectangle)
       (if (eq? (field rectangle 'id)
                id)
           new-rectangle
           rectangle))
     source))


  (define (move rectangle new-x new-y)

    `((id . ,(field rectangle 'id))
      (x . ,new-x)
      (y . ,new-y)
      (width . ,(field rectangle 'width))
      (height . ,(field rectangle 'height))))


  (let* ((relation
          (field alignment 'relation))

         (ids
          (field alignment 'nodes)))

    (unless (and ids
                 (>= (length ids) 2))
      (error
       "Physical alignment requires at least two nodes"
       alignment))

    (let* ((reference-id
            (car ids))

           (reference
            (rect-by-id reference-id))

           (reference-x
            (field reference 'x))

           (reference-y
            (field reference 'y))

           (reference-width
            (field reference 'width))

           (reference-height
            (field reference 'height))

           (reference-right
            (+ reference-x reference-width))

           (reference-bottom
            (+ reference-y reference-height))

           (reference-center-x
            (+ reference-x
               (/ reference-width 2)))

           (reference-center-y
            (+ reference-y
               (/ reference-height 2))))

      (fold

       (lambda (id result)

	 (let* ((rectangle
		 (find
		  (lambda (rectangle)
		    (eq? (field rectangle 'id)
			 id))
		  result)))

	   (unless rectangle
	     (error
	      "Physical alignment references missing rectangle"
	      id))

	   (let* ((x
		   (field rectangle 'x))

		  (y
		   (field rectangle 'y))

		  (width
		   (field rectangle 'width))

		  (height
		   (field rectangle 'height))

		  (new-position
		   (case relation

		     ((align-center-x)
		      (cons
                       (- reference-center-x
			  (/ width 2))
                       y))

		     ((align-center-y)
		      (cons
                       x
                       (- reference-center-y
			  (/ height 2))))

		     ((align-left)
		      (cons reference-x y))

		     ((align-right)
		      (cons
                       (- reference-right width)
                       y))

		     ((align-top)
		      (cons x reference-y))

		     ((align-bottom)
		      (cons
                       x
                       (- reference-bottom height)))

		     (else
		      (error
                       "Unsupported physical alignment"
                       relation))))

		  (new-rectangle
		   (move
		    rectangle
		    (car new-position)
		    (cdr new-position))))

	     (replace-rectangle
	      id
	      new-rectangle
	      result))))

       rectangles
       (cdr ids)))))


;; ======================================================================
;; PHYSICAL LAYOUT IR V1
;;
;; Builds the authoritative physical-layout representation from already
;; solved exact rectangles.
;;
;; components:
;;   real UI nodes only
;;
;; structures:
;;   structural entities such as stack bounding boxes
;;
;; Global bounds and real-component overlap validation are mandatory.
;; Structural rectangles are intentionally excluded from overlap checks
;; because stacks contain their children by design.
;; ======================================================================

(define (pl:make-physical-layout
         physical-width
         physical-height
         base-unit-px
         ui-scale
         components
         structures)

  (let* ((unit
          (pl:resolve-base-unit
           base-unit-px))

         (scale
          (pl:resolve-ui-scale
           ui-scale)))

    ;; ----------------------------------------------------------
    ;; Validate exact physical screen
    ;; ----------------------------------------------------------

    (unless (and (number? physical-width)
                 (exact? physical-width)
                 (> physical-width 0))
      (error
       "Physical screen width must be a positive exact number"
       physical-width))

    (unless (and (number? physical-height)
                 (exact? physical-height)
                 (> physical-height 0))
      (error
       "Physical screen height must be a positive exact number"
       physical-height))

    ;; ----------------------------------------------------------
    ;; Components and structural entities must remain in bounds.
    ;; ----------------------------------------------------------

    (pl:validate-layout-bounds!
     components
     physical-width
     physical-height)

    (pl:validate-layout-bounds!
     structures
     physical-width
     physical-height)

    ;; ----------------------------------------------------------
    ;; Only real UI components participate in overlap validation.
    ;; ----------------------------------------------------------

    (pl:validate-layout-overlaps!
     components)

    `((kind . physical-layout)
      (version . 1)

      (screen .
              ((x . 0)
               (y . 0)
               (width . ,physical-width)
               (height . ,physical-height)))

      (base-unit-px . ,unit)
      (ui-scale . ,scale)

      (components . ,components)
      (structures . ,structures)

      (validation .
                  ((bounds . ok)
                   (real-overlaps . ok))))))

;; ======================================================================
;; PHYSICAL ENTITY LOOKUP
;;
;; A physical relation may reference either:
;;
;;   - a real UI component
;;   - a structural stack bbox
;;
;; IDs must be globally unique across both namespaces.
;; ======================================================================

(define (pl:entity-rectangle
         id
         components
         structures)

  (let* ((component
          (find
           (lambda (rectangle)
             (eq? (field rectangle 'id)
                  id))
           components))

         (structure
          (find
           (lambda (rectangle)
             (eq? (field rectangle 'id)
                  id))
           structures)))

    (when (and component structure)
      (error
       "Duplicate physical entity ID across component and structure namespaces"
       id))

    (or component
        structure
        (error
         "Unknown physical entity"
         id))))


;; ======================================================================
;; PREPARE PHYSICAL RELATIONS
;;
;; Converts normalized LogicalTopology relations into a canonical
;; representation for the future PhysicalLayout solver.
;;
;; No geometry is changed here.
;; ======================================================================

(define (pl:prepare-relations
         constraints
         alignments)

  (let ((inequalities
         (append-map

          (lambda (entry)

            (let ((subject
                   (field entry 'node))

                  (relations
                   (field entry 'constraints)))

              (map

               (lambda (relation)

                 `((kind . inequality)
                   (relation .
                             ,(field relation 'relation))
                   (subject . ,subject)
                   (reference .
                              ,(field relation 'reference))))

               relations)))

          constraints))

        (equalities
         (map

          (lambda (entry)

            (let ((nodes
                   (field entry 'nodes)))

              (unless (and nodes
                           (>= (length nodes) 2))
                (error
                 "Physical alignment requires at least two entities"
                 entry))

              `((kind . equality)
                (relation .
                          ,(field entry 'relation))
                (reference . ,(car nodes))
                (targets . ,(cdr nodes)))))

          alignments)))

    `((inequalities . ,inequalities)
      (equalities . ,equalities))))

;; ======================================================================
;; VERTICAL FEASIBLE INTERVAL
;;
;; Computes the admissible Y interval for one physical entity from
;; already-canonicalized ordering inequalities.
;;
;; An inequality:
;;
;;   subject below reference
;;
;; means:
;;
;;   subject.y >= reference.y + reference.height
;;
;; Therefore, depending on whether TARGET is the subject or reference,
;; the inequality contributes respectively a lower or upper bound.
;;
;; No coordinate is chosen here.
;; ======================================================================



  
(define (pl:vertical-feasible-interval
         id
         inequalities
         components
         structures
         vertical-domain)

  ;; ------------------------------------------------------------
  ;; Backward compatibility:
  ;;
  ;; vertical-domain may still be a positive exact number,
  ;; interpreted as a screen extending from Y=0.
  ;;
  ;; New semantics:
  ;;
  ;; vertical-domain may be a physical domain rectangle.
  ;; ------------------------------------------------------------

  (define domain-y
    (cond

      ((number? vertical-domain)
       0)

      ((pair? vertical-domain)
       (field vertical-domain 'y))

      (else
       (error
        "Invalid vertical physical domain"
        vertical-domain))))


  (define domain-height
    (cond

      ((number? vertical-domain)
       vertical-domain)

      ((pair? vertical-domain)
       (field vertical-domain 'height))

      (else
       (error
        "Invalid vertical physical domain"
        vertical-domain))))


  (unless (and (number? domain-y)
               (exact? domain-y)
               (>= domain-y 0)
               (number? domain-height)
               (exact? domain-height)
               (> domain-height 0))
    (error
     "Vertical physical domain must have exact positive geometry"
     vertical-domain))


  (let* ((target
          (pl:entity-rectangle
           id
           components
           structures))

         (target-height
          (field target 'height))

         (domain-bottom
          (+ domain-y
             domain-height))

         ;; Domain containment establishes the initial interval.
         (initial-lower
          domain-y)

         (initial-upper
          (- domain-bottom
             target-height)))

    (letrec
        ((apply-inequality

          (lambda (inequality interval)

            (let* ((relation
                    (field inequality 'relation))

                   (subject-id
                    (field inequality 'subject))

                   (reference-id
                    (field inequality 'reference))

                   (lower
                    (field interval 'lower))

                   (upper
                    (field interval 'upper)))

              (case relation

                ;; ==================================================
                ;; subject BELOW reference
                ;; ==================================================

                ((below)

                 (cond

                   ((eq? id subject-id)

                    (let* ((reference
                            (pl:entity-rectangle
                             reference-id
                             components
                             structures))

                           (reference-bottom
                            (+ (field reference 'y)
                               (field reference 'height))))

                      `((lower . ,(max lower
                                       reference-bottom))
                        (upper . ,upper))))


                   ((eq? id reference-id)

                    (let* ((subject
                            (pl:entity-rectangle
                             subject-id
                             components
                             structures))

                           (new-upper
                            (- (field subject 'y)
                               target-height)))

                      `((lower . ,lower)
                        (upper . ,(min upper
                                       new-upper)))))


                   (else
                    interval)))


                ;; ==================================================
                ;; subject ABOVE reference
                ;; ==================================================

                ((above)

                 (cond

                   ((eq? id subject-id)

                    (let* ((reference
                            (pl:entity-rectangle
                             reference-id
                             components
                             structures))

                           (new-upper
                            (- (field reference 'y)
                               target-height)))

                      `((lower . ,lower)
                        (upper . ,(min upper
                                       new-upper)))))


                   ((eq? id reference-id)

                    (let* ((subject
                            (pl:entity-rectangle
                             subject-id
                             components
                             structures))

                           (subject-bottom
                            (+ (field subject 'y)
                               (field subject 'height))))

                      `((lower . ,(max lower
                                       subject-bottom))
                        (upper . ,upper))))


                   (else
                    interval)))


                ;; X-only relations do not constrain Y.
                (else
                 interval))))))

      (let ((result
             (fold
              apply-inequality
              `((lower . ,initial-lower)
                (upper . ,initial-upper))
              inequalities)))

        (when (> (field result 'lower)
                 (field result 'upper))

          (error
           "No feasible vertical interval for physical entity"
           id
           result))

        result))))

;; ======================================================================
;; CHOOSE COORDINATE INSIDE FEASIBLE INTERVAL
;;
;; Hard constraints define:
;;
;;   [lower, upper]
;;
;; This function applies only the deterministic placement policy.
;;
;; Supported policies:
;;
;;   start     -> lower
;;   center    -> midpoint
;;   end       -> upper
;;   target    -> clamp explicit target into [lower, upper]
;;
;; No topology semantics are interpreted here.
;; ======================================================================

(define* (pl:choose-coordinate
          interval
          policy
          #:optional
          (target #f))

  (let ((lower
         (field interval 'lower))

        (upper
         (field interval 'upper)))

    (unless (and (number? lower)
                 (exact? lower)
                 (number? upper)
                 (exact? upper)
                 (<= lower upper))
      (error
       "Invalid physical feasible interval"
       interval))

    (case policy

      ((start)
       lower)

      ((center)
       (/ (+ lower upper)
          2))

      ((end)
       upper)

      ((target)

       (unless (and (number? target)
                    (exact? target))
         (error
          "Target coordinate must be an exact number"
          target))

       (min upper
            (max lower
                 target)))

      (else
       (error
        "Unknown physical coordinate policy"
        policy)))))



;; ======================================================================
;; SOLVE ONE VERTICAL COORDINATE
;;
;; Hard inequalities determine the feasible interval.
;; Placement policy chooses one exact coordinate inside that interval.
;;
;; If preferred-target is supplied:
;;
;;   y = clamp(preferred-target, lower, upper)
;;
;; Otherwise the requested fallback policy is used.
;;
;; This function does NOT move rectangles.
;; It only solves one exact Y coordinate.
;; ======================================================================

(define* (pl:solve-vertical-coordinate
          id
          inequalities
          components
          structures
          vertical-domain
          #:key
          (preferred-target #f)
          (fallback-policy 'center))

  (let ((interval
         (pl:vertical-feasible-interval
          id
          inequalities
          components
          structures
          vertical-domain)))

    (if preferred-target

        (pl:choose-coordinate
         interval
         'target
         preferred-target)

        (pl:choose-coordinate
         interval
         fallback-policy))))


;; ======================================================================
;; SOLVE PHYSICAL Y AXIS
;;
;; First implementation:
;;
;; - entities with node-area declarations receive their preferred
;;   area-derived Y coordinate;
;;
;; - entities without a vertical area anchor are solved from ordering
;;   inequalities;
;;
;; - if such inequalities leave a feasible interval, the default
;;   deterministic policy is its midpoint;
;;
;; - usable-top / usable-bottom define the physical vertical domain.
;;
;; This stage solves ROOT entity rectangles only.  Nested stack children
;; are expanded later from the solved structural origins.
;; ======================================================================

(define (pl:solve-y-axis
         ids
         placements
         inequalities
         contracts
         domains
         assignments)

  (define (area-for id)

    (let ((placement
           (find
            (lambda (entry)
              (and
               (eq? (field entry 'kind)
                    'node-area)
               (eq? (field entry 'node)
                    id)))
            placements)))

      (and placement
           (field placement 'area))))


  (define (domain-for id)

    (pl:domain-for-entity
     id
     assignments
     domains))


  (define (preferred-rectangle id)

    (let ((domain
           (domain-for id))

          (area
           (area-for id)))

      (pl:place-preferred-in-domain
       id
       (or area 'center)
       contracts
       domain)))


  (define (with-y rectangle y)

    `((id . ,(field rectangle 'id))
      (x . ,(field rectangle 'x))
      (y . ,y)
      (width . ,(field rectangle 'width))
      (height . ,(field rectangle 'height))))


  ;; ------------------------------------------------------------
  ;; Preferred/root rectangles first.
  ;; Anchored entities already have authoritative Y.
  ;; ------------------------------------------------------------

  (let* ((preferred
          (map preferred-rectangle
               ids))

         (solved
          (map

           (lambda (rectangle)

             (let* ((id
                     (field rectangle 'id))

                    (area
                     (area-for id)))

               (if area

                   rectangle

                   (with-y
                    rectangle

                    (pl:solve-vertical-coordinate
                     id
                     inequalities
                     '()
                     preferred
                     (domain-for id)
                     #:fallback-policy 'center)))))

           preferred)))

    solved))


;; ======================================================================
;; PREPARE PHYSICAL RELATIONS
;;
;; Canonicalizes LogicalTopology relations into two independent sets:
;;
;;   inequalities
;;     order / feasibility constraints
;;
;;   equalities
;;     exact geometric alignments
;;
;; No geometry is solved here.
;; ======================================================================

(define (pl:prepare-relations
         constraints
         alignments)

  ;; ------------------------------------------------------------
  ;; Canonicalize node ordering constraints.
  ;; ------------------------------------------------------------

  (define inequalities

    (append-map

     (lambda (entry)

       (let ((subject
              (field entry 'node))

             (relations
              (field entry 'constraints)))

         (map

          (lambda (relation-entry)

            (let ((relation
                   (field relation-entry 'relation))

                  (reference
                   (field relation-entry 'reference)))

              (unless relation
                (error
                 "Physical constraint has no relation"
                 entry))

              (unless reference
                (error
                 "Physical constraint has no reference"
                 entry))

              `((kind . inequality)
                (relation . ,relation)
                (subject . ,subject)
                (reference . ,reference))))

          relations)))

     constraints))


  ;; ------------------------------------------------------------
  ;; Canonicalize exact alignments.
  ;;
  ;; First node is the reference.
  ;; Remaining nodes are targets.
  ;; ------------------------------------------------------------

  (define equalities

    (map

     (lambda (entry)

       (let ((relation
              (field entry 'relation))

             (nodes
              (field entry 'nodes)))

         (unless relation
           (error
            "Physical alignment has no relation"
            entry))

         (unless (and nodes
                      (>= (length nodes) 2))
           (error
            "Physical alignment requires at least two nodes"
            entry))

         `((kind . equality)
           (relation . ,relation)
           (reference . ,(car nodes))
           (targets . ,(cdr nodes)))))

     alignments))


  `((inequalities . ,inequalities)
    (equalities . ,equalities)))



;; ======================================================================
;; SOLVE PHYSICAL X AXIS
;;
;; First implementation:
;;
;; - each root entity receives an area-derived preferred rectangle;
;; - deterministic X equalities are then applied;
;; - only X is changed;
;; - Y is preserved from the preferred rectangle;
;;
;; Supported equality relations:
;;
;;   align-center-x
;;   align-left
;;   align-right
;;
;; This stage solves ROOT entities only.
;; ======================================================================

(define (pl:solve-x-axis
         ids
         placements
         equalities
         contracts
         domains
         assignments)

  (define (area-for id)

    (let ((placement
           (find
            (lambda (entry)
              (and
               (eq? (field entry 'kind)
                    'node-area)
               (eq? (field entry 'node)
                    id)))
            placements)))

      (and placement
           (field placement 'area))))


  (define (domain-for id)

    (pl:domain-for-entity
     id
     assignments
     domains))


  (define (preferred-rectangle id)

    (pl:place-preferred-in-domain
     id
     (or (area-for id)
         'center)
     contracts
     (domain-for id)))


  (define (rect-by-id id rectangles)

    (let ((rectangle
           (find
            (lambda (rectangle)
              (eq? (field rectangle 'id)
                   id))
            rectangles)))

      (unless rectangle
        (error
         "Missing rectangle in X solver"
         id))

      rectangle))


  (define (with-x rectangle x)

    `((id . ,(field rectangle 'id))
      (x . ,x)
      (y . ,(field rectangle 'y))
      (width . ,(field rectangle 'width))
      (height . ,(field rectangle 'height))))


  (define (replace-rectangle
           id
           replacement
           rectangles)

    (map
     (lambda (rectangle)

       (if (eq? (field rectangle 'id)
                id)

           replacement

           rectangle))

     rectangles))


  (define (apply-equality
           equality
           rectangles)

    (let* ((relation
            (field equality 'relation))

           (reference-id
            (field equality 'reference))

           (target-ids
            (field equality 'targets)))

      ;; Y-only equality: irrelevant here.
      (if (not
           (memq relation
                 '(align-center-x
                   align-left
                   align-right)))

          rectangles

          (let* ((reference
                  (rect-by-id
                   reference-id
                   rectangles))

                 (reference-x
                  (field reference 'x))

                 (reference-width
                  (field reference 'width))

                 (reference-right
                  (+ reference-x
                     reference-width))

                 (reference-center-x
                  (+ reference-x
                     (/ reference-width 2))))

            (fold

             (lambda (target-id result)

               (let* ((target
                       (rect-by-id
                        target-id
                        result))

                      (target-width
                       (field target 'width))

                      (new-x
                       (case relation

                         ((align-center-x)
                          (- reference-center-x
                             (/ target-width 2)))

                         ((align-left)
                          reference-x)

                         ((align-right)
                          (- reference-right
                             target-width))))

                      (moved
                       (with-x
                        target
                        new-x)))

                 (replace-rectangle
                  target-id
                  moved
                  result)))

             rectangles
             target-ids)))))


  (fold
   apply-equality
   (map preferred-rectangle ids)
   equalities))


;; ======================================================================
;; PHYSICAL DOMAIN
;;
;; A domain is an exact rectangular region of the physical screen.
;;
;; Domains are solver policy objects.  They do not correspond to JUCE
;; components and are never emitted.
;; ======================================================================

(define (pl:make-domain
         id
         x
         y
         width
         height)

  (unless (symbol? id)
    (error
     "Physical domain ID must be a symbol"
     id))

  (unless (and (number? x)
               (exact? x)
               (>= x 0)
               (number? y)
               (exact? y)
               (>= y 0)
               (number? width)
               (exact? width)
               (> width 0)
               (number? height)
               (exact? height)
               (> height 0))
    (error
     "Invalid exact physical domain geometry"
     id
     x
     y
     width
     height))

  `((id . ,id)
    (x . ,x)
    (y . ,y)
    (width . ,width)
    (height . ,height)))


(define (pl:domain-rectangle
         id
         domains)

  (let ((domain
         (find
          (lambda (entry)
            (eq? (field entry 'id)
                 id))
          domains)))

    (unless domain
      (error
       "Unknown physical domain"
       id))

    domain))

;; ======================================================================
;; ENTITY -> PHYSICAL DOMAIN
;;
;; Domain membership is explicit solver policy.
;; It must never be inferred from TYPE, ROLE, or graphical class.
;; ======================================================================

(define (pl:domain-for-entity
         id
         assignments
         domains)

  (let ((assignment
         (find
          (lambda (entry)
            (eq? (field entry 'entity)
                 id))
          assignments)))

    (unless assignment
      (error
       "Physical entity has no domain assignment"
       id))

    (let ((domain-id
           (field assignment 'domain)))

      (pl:domain-rectangle
       domain-id
       domains))))




;; ======================================================================
;; PLACE PREFERRED RECTANGLE INSIDE PHYSICAL DOMAIN
;;
;; AREA is interpreted relative to DOMAIN, not relative to the screen.
;; ======================================================================

(define (pl:place-preferred-in-domain
         id
         area
         contracts
         domain)

  (let ((entry
         (assoc id contracts)))

    (unless entry
      (error
       "Missing physical size contract"
       id))

    (let* ((contract
            (cdr entry))

           (width
            (field contract 'preferred-width))

           (height
            (field contract 'preferred-height))

           (domain-x
            (field domain 'x))

           (domain-y
            (field domain 'y))

           (domain-width
            (field domain 'width))

           (domain-height
            (field domain 'height))

           (center-x
            (+ domain-x
               (/ (- domain-width width)
                  2)))

           (center-y
            (+ domain-y
               (/ (- domain-height height)
                  2)))

           (right-x
            (+ domain-x
               (- domain-width width)))

           (bottom-y
            (+ domain-y
               (- domain-height height)))

           (position
            (case area

              ((top)
               (cons center-x domain-y))

              ((bottom)
               (cons center-x bottom-y))

              ((left)
               (cons domain-x center-y))

              ((right)
               (cons right-x center-y))

              ((center)
               (cons center-x center-y))

              ((top-left)
               (cons domain-x domain-y))

              ((top-right)
               (cons right-x domain-y))

              ((bottom-left)
               (cons domain-x bottom-y))

              ((bottom-right)
               (cons right-x bottom-y))

              (else
               (error
                "Unsupported physical area"
                area))))

           (rectangle
            `((id . ,id)
              (x . ,(car position))
              (y . ,(cdr position))
              (width . ,width)
              (height . ,height))))

      rectangle)))


;; ======================================================================
;; MERGE SOLVED X/Y ROOT LAYOUTS
;;
;; X and Y solvers operate independently but preserve identical entity
;; IDs and dimensions.
;;
;; This function produces one authoritative rectangle per root entity:
;;
;;   x      <- X solver
;;   y      <- Y solver
;;   width  <- verified equal on both results
;;   height <- verified equal on both results
;; ======================================================================

(define (pl:merge-axis-layouts
         x-layout
         y-layout)

  (map

   (lambda (x-rectangle)

     (let* ((id
             (field x-rectangle 'id))

            (y-rectangle
             (find
              (lambda (rectangle)
                (eq? (field rectangle 'id)
                     id))
              y-layout)))

       (unless y-rectangle
         (error
          "Y layout is missing physical entity"
          id))

       (let ((x-width
              (field x-rectangle 'width))

             (x-height
              (field x-rectangle 'height))

             (y-width
              (field y-rectangle 'width))

             (y-height
              (field y-rectangle 'height)))

         (unless (= x-width y-width)
           (error
            "X/Y physical width mismatch"
            id
            x-width
            y-width))

         (unless (= x-height y-height)
           (error
            "X/Y physical height mismatch"
            id
            x-height
            y-height))

         `((id . ,id)
           (x . ,(field x-rectangle 'x))
           (y . ,(field y-rectangle 'y))
           (width . ,x-width)
           (height . ,x-height)))))

   x-layout))

;; ======================================================================
;; AUTHORITATIVE PHYSICAL LAYOUT SOLVER
;;
;; Pipeline:
;;
;;   normalized LogicalTopology
;;       ->
;;   physical model / contracts
;;       ->
;;   canonical relations
;;       ->
;;   root X/Y solve
;;       ->
;;   root rectangle merge
;;       ->
;;   recursive stack expansion
;;       ->
;;   global validation
;;       ->
;;   PhysicalLayout IR
;;
;; The discrete grid is NOT involved here.
;; ======================================================================

;; ======================================================================
;; AUTHORITATIVE PHYSICAL LAYOUT SOLVER
;;
;; Input:
;;
;;   normalized LogicalTopology
;;   physical screen dimensions
;;   PhysicalLayout policy
;;
;; Pipeline:
;;
;;   LogicalTopology
;;       ->
;;   physical model / contracts
;;       ->
;;   derive physical domains from policy
;;       ->
;;   canonical relations
;;       ->
;;   root X/Y solve
;;       ->
;;   root rectangle merge
;;       ->
;;   recursive stack expansion
;;       ->
;;   global validation
;;       ->
;;   PhysicalLayout
;; ======================================================================

(define* (pl:solve
          normalized
          physical-width
          physical-height
          policy
          #:key
          (base-unit-px 12)
          (ui-scale #f)
          (ui-size #f))

  (let* ((normalized-scale
          (field normalized 'ui-scale))

         (normalized-size
          (field normalized 'ui-size))

         (requested-scale
          (if ui-scale
              ui-scale
              normalized-scale))

         (requested-size
          (if ui-size
              ui-size
              normalized-size))

         ;; ------------------------------------------------------
         ;; Prepare physical model.
         ;; ------------------------------------------------------

         (physical-model
          (pl:prepare-physical-model
            normalized
            base-unit-px
            requested-scale
            requested-size))

         (contracts
          (field physical-model 'contracts))

         (placements
          (field physical-model 'placements))

         (constraints
          (field physical-model 'constraints))

         (alignments
          (field physical-model 'alignments))

         (stacks
          (field physical-model 'stacks))

         ;; ------------------------------------------------------
         ;; Policy.
         ;; ------------------------------------------------------

         (root-ids
          (field policy 'root-ids))

         (assignments
          (field policy 'domain-assignments))

         ;; ------------------------------------------------------
         ;; Derive domains from contracts + policy.
         ;; ------------------------------------------------------

         (domain-result
          (pl:build-standard-domains
            physical-width
            physical-height
            contracts
            policy
            base-unit-px))

         (domains
          (field domain-result 'domains))

         ;; ------------------------------------------------------
         ;; Canonical relations.
         ;; ------------------------------------------------------

         (relations
          (pl:prepare-relations
            constraints
            alignments))

         (inequalities
          (field relations 'inequalities))

         (equalities
          (field relations 'equalities))

         ;; ------------------------------------------------------
         ;; Solve roots.
         ;; ------------------------------------------------------

         (y-layout
          (pl:solve-y-axis
            root-ids
            placements
            inequalities
            contracts
            domains
            assignments))

         (x-layout
          (pl:solve-x-axis
            root-ids
            placements
            equalities
            contracts
            domains
            assignments))

         (root-layout
          (pl:merge-axis-layouts
            x-layout
            y-layout)))


    ;; ----------------------------------------------------------
    ;; Stack lookup.
    ;; ----------------------------------------------------------

    (define (stack-by-id id)

      (find
        (lambda (stack)
          (eq? (field stack 'id)
               id))
        stacks))


    ;; ----------------------------------------------------------
    ;; Expand solved roots.
    ;; ----------------------------------------------------------

    (let loop ((remaining root-layout)
               (components '())
               (structures '()))

      (if (null? remaining)

          ;; ----------------------------------------------------
          ;; Final authoritative PhysicalLayout.
          ;; ----------------------------------------------------

          (pl:make-physical-layout
            physical-width
            physical-height
            base-unit-px
            (field physical-model 'ui-scale)
            (reverse components)
            (reverse structures))


          (let* ((root-rectangle
                  (car remaining))

                 (root-id
                  (field root-rectangle 'id))

                 (root-stack
                  (stack-by-id root-id)))

            (if root-stack

                ;; ------------------------------------------------
                ;; Stack root.
                ;; ------------------------------------------------

                (let* ((tree
                        (pl:layout-stack-tree
                          root-stack
                          stacks
                          contracts
                          base-unit-px
                          (field root-rectangle 'x)
                          (field root-rectangle 'y)))

                       (tree-components
                        (field tree 'components))

                       (tree-structures
                        (field tree 'structures)))

                  (loop
                    (cdr remaining)

                    (append
                      (reverse tree-components)
                      components)

                    (append
                      (reverse tree-structures)
                      structures)))


                ;; ------------------------------------------------
                ;; Real root component.
                ;; ------------------------------------------------

                (loop
                  (cdr remaining)
                  (cons root-rectangle
                        components)
                  structures)))))))


;; ======================================================================
;; BUILD STANDARD PHYSICAL DOMAINS
;;
;; Derives:
;;
;;   screen-domain
;;   main-domain
;;   footer-domain
;;
;; from:
;;
;;   physical screen size
;;   resolved size contracts
;;   standard physical-layout policy
;;   base-unit-px
;;
;; No plugin-specific physical constants are required.
;; ======================================================================

(define (pl:build-standard-domains
         physical-width
         physical-height
         contracts
         policy
         base-unit-px)

  (let* ((footer-entities
          (field policy 'footer-entities))

         (footer-gap-units
          (field policy 'footer-gap))

         (footer-gap
          (* footer-gap-units
             base-unit-px))

         (footer-heights
          (map

           (lambda (id)

             (let ((contract
                    (assoc id contracts)))

               (unless contract
                 (error
                  "Missing physical size contract for footer entity"
                  id))

               (field
                (cdr contract)
                'preferred-height)))

           footer-entities))

         (footer-content-height
          (if (null? footer-heights)
              0
              (apply max footer-heights)))

         (footer-reserve
          (+ footer-content-height
             footer-gap))

         (main-height
          (- physical-height
             footer-reserve)))

    (unless (> main-height 0)

      (error
       "Footer reserve leaves no space for main physical domain"
       footer-reserve
       physical-height))

    `((domains .
               (,(pl:make-domain
                   'screen
                   0
                   0
                   physical-width
                   physical-height)

                ,(pl:make-domain
                   'main
                   0
                   0
                   physical-width
                   main-height)

                ,(pl:make-domain
                   'footer
                   0
                   main-height
                   physical-width
                   footer-reserve)))

      (footer-reserve . ,footer-reserve))))
