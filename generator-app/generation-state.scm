(define-module (generator-app generation-state)
  #:use-module (generator-app globals)
  #:export (generation-components
            generation-image-sets
            generation-screen
            generation-grid
            prepend-generation-component!
            prepend-generation-image-set!
            set-generation-screen!
            set-generation-grid!
            reset-generation-state!))

(define (generation-components)
  *components*)

(define (generation-image-sets)
  *image-sets*)

(define (generation-screen)
  *screen*)

(define (generation-grid)
  *grid*)

(define (prepend-generation-component! component)
  (set! *components* (cons component *components*))
  component)

(define (prepend-generation-image-set! image-set)
  (set! *image-sets* (cons image-set *image-sets*))
  image-set)

(define (set-generation-screen! screen)
  (set! *screen* screen)
  screen)

(define (set-generation-grid! grid)
  (set! *grid* grid)
  grid)

(define (reset-generation-state!)
  (reset-components!))
