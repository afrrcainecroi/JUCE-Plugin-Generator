;; Visual test matrix for the scope TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/scope-visual-matrix.scm
;;
;; The footprints are diagnostic baselines, not normative metrics.  The DSL
;; does not expose waveform data; only the single ROLE scope specimen receives
;; the existing processor FIFO at runtime.  Every other specimen shows the
;; renderer's zero-initialised state.

(use-modules (oop goops)
             (generator-app code-generator))

(define scope-profiles
  '(("COMPACT" "Compact" 3 8 6)
    ("STANDARD" "Standard" 23 12 8)
    ("EXTENDED" "Extended" 47 16 10)))

(define (make-caption id text row col col-span)
  (make <label>
    #:id id
    #:text text
    #:justification 'centred
    #:row row
    #:col col
    #:row-span 1
    #:col-span col-span
    #:margin-tb 0
    #:margin-lr 0))

(define (make-scope-specimen id row col row-span col-span properties role)
  (apply make
         (append
          (list <scope>
                #:id id
                #:row row
                #:col col
                #:row-span row-span
                #:col-span col-span
                #:margin-tb 0
                #:margin-lr 0)
          (if role (list #:role role) '())
          properties)))

(define* (make-scope-triplet case-code caption band-row properties
                             #:optional (live-profile #f))
  (make-caption (string-append "scopeMatrix" case-code "Caption")
                (string-append case-code " " caption)
                band-row 1 68)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-caption
        (string-append "scopeMatrix" case-code profile-code "Profile")
        (string-append name " "
                       (number->string col-span) "x"
                       (number->string row-span))
        (+ band-row 1) col col-span)
       (make-scope-specimen
        (string-append "scopeMatrix" case-code profile-code)
        (+ band-row 2) col row-span col-span properties
        (and live-profile
             (string=? profile-code live-profile)
             'scope))))
   scope-profiles))

(define (scope-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio 0.55
    #:width 1800)
  (make <grid>
    #:rows 86
    #:cols 70
    #:show-grid #t)

  (make-scope-triplet "A" "RADAR / ZERO STATE" 1
                      '(#:grid-style radar))
  (make-scope-triplet "B" "MINIMAL / ZERO STATE" 13
                      '(#:grid-style minimal))

  ;; is-sharp changes waveform rendering.  At zero state it remains directly
  ;; comparable as a centre-axis trace.
  (make-scope-triplet "C" "RADAR / SHARP TRUE" 25
                      '(#:grid-style radar #:is-sharp #t))

  ;; glow-multiplier is emitted for all scopes and affects only the non-sharp
  ;; waveform passes; grid, axes, labels, background and frame ignore it.
  (make-scope-triplet "D" "RADAR / GLOW 0.0" 37
                      '(#:grid-style radar #:glow-multiplier 0.0))
  (make-scope-triplet "E" "RADAR / GLOW 0.5" 49
                      '(#:grid-style radar #:glow-multiplier 0.5))
  (make-scope-triplet "F" "RADAR / GLOW 2.0" 61
                      '(#:grid-style radar #:glow-multiplier 2.0))

  ;; Only the standard specimen is assigned ROLE scope, so it uses the normal
  ;; realtime-safe processor FIFO without adding diagnostic DSP or DSL data.
  (make-scope-triplet "G" "RADAR / LIVE PROCESSOR FIFO" 73
                      '(#:grid-style radar)
                      "Standard"))

(MakeNewProject "scope-visual-matrix"
                scope-visual-matrix-interface)
