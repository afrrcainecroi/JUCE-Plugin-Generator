;; Visual and functional diagnostic for the bypass-switch TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/bypass-switch-visual-functional-test.scm
;;
;; This test intentionally keeps TYPE and ROLE probes separate.  It defines
;; no normative metrics and does not compensate for runtime behaviour.

(use-modules (oop goops)
             (generator-app code-generator))

;; Normative switch footprints: compact 5x3, standard 7x4, extended 10x5.
(define bypass-switch-profiles
  '(("COMPACT" "Compact" 2 5 3)
    ("STANDARD" "Standard" 25 7 4)
    ("EXTENDED" "Extended" 49 10 5)))

(define (profile-name profile) (list-ref profile 0))
(define (profile-code profile) (list-ref profile 1))
(define (profile-col profile) (list-ref profile 2))
(define (profile-col-span profile) (list-ref profile 3))
(define (profile-row-span profile) (list-ref profile 4))

(define (make-caption case-code caption profile row)
  (make <label>
    #:id (string-append "bypassSwitch" case-code
                        (profile-code profile) "Caption")
    #:text (string-append caption " / " (profile-name profile)
                          " / BYPASS-SWITCH | SWITCH")
    #:justification 'centred
    #:row row
    #:col (profile-col profile)
    #:row-span 1
    #:col-span (+ (* 2 (profile-col-span profile)) 2)
    #:margin-tb 0
    #:margin-lr 0))

(define (make-parameterized-switch class id text state enabled role
                                   row col row-span col-span)
  (apply make
         (append
          (list class
                #:id id
                #:text text
                #:default-state state
                #:enabled enabled
                #:parameter-id id
                #:parameter-name id
                #:processor-reference id
                #:version-hint 1
                #:row row
                #:col col
                #:row-span row-span
                #:col-span col-span
                #:margin-tb 0
                #:margin-lr 0)
          (if role (list #:role role) '()))))

(define (make-comparison-pair case-code caption profile text state enabled band-row)
  (let* ((suffix (profile-code profile))
         (row (- (+ band-row 7) (profile-row-span profile)))
         (col (profile-col profile))
         (width (profile-col-span profile))
         (height (profile-row-span profile)))
    (make-caption case-code caption profile band-row)
    (make-parameterized-switch
     <bypass-switch>
     (string-append "bypassSwitch" case-code suffix)
     text state enabled #f row col height width)
    (make-parameterized-switch
     <switch>
     (string-append "referenceSwitch" case-code suffix)
     text state enabled #f row (+ col width 2) height width)))

(define (make-comparison-triplet case-code caption band-row text state enabled)
  (for-each
   (lambda (profile)
     (make-comparison-pair case-code caption profile text state enabled band-row))
   bypass-switch-profiles))

(define (make-role-probe code caption role col)
  (make <label>
    #:id (string-append "roleProbe" code "Caption")
    #:text caption
    #:justification 'centred
    #:row 51
    #:col col
    #:row-span 1
    #:col-span 18
    #:margin-tb 0
    #:margin-lr 0)
  (make-parameterized-switch
   <bypass-switch>
   (string-append "roleProbe" code)
   "DSP Bypass" #f #t role 53 (+ col 5) 4 7))

(define (bypass-switch-visual-functional-interface dst-folder project-name)
  (make <screen>
    #:ratio (exact->inexact (/ 72 60))
    #:width 1800)
  (make <grid>
    #:rows 60
    #:cols 72
    #:show-grid #t)

  (make-comparison-triplet "AShortText" "A SHORT TEXT" 1 "Bypass" #f #t)
  (make-comparison-triplet "BMediumText" "B MEDIUM TEXT" 8 "DSP Bypass" #f #t)
  (make-comparison-triplet "CLongText" "C LONG TEXT" 15 "Disable Processing" #f #t)
  (make-comparison-triplet "DDefaultOff" "D DEFAULT OFF" 22 "DSP Bypass" #f #t)
  (make-comparison-triplet "EDefaultOn" "E DEFAULT ON" 29 "DSP Bypass" #t #t)
  (make-comparison-triplet "FEnabled" "F ENABLED" 36 "DSP Bypass" #t #t)
  (make-comparison-triplet "GDisabled" "G DISABLED" 43 "DSP Bypass" #t #f)

  ;; Identical 7x4 geometry isolates ROLE semantics from TYPE geometry.
  (make-role-probe "TypeOnly" "TYPE ONLY / NO ROLE" #f 2)
  (make-role-probe "Bypass" "TYPE + ROLE BYPASS" 'bypass 27)
  (make-role-probe "DSPBypass" "TYPE + ROLE DSP-BYPASS" 'dsp-bypass 52))

(MakeNewProject "bypass-switch-visual-functional-test"
                bypass-switch-visual-functional-interface)
