;; Visual metric matrix for the switch TYPE.
;; Generate from the Generator repository root with:
;;   guile -L . -l generator.scm -s tests/switch-visual-matrix.scm

(use-modules (oop goops)
             (generator-app code-generator))

(define switch-profiles
  '(("COMPACT" "Compact" 7 5 3)
    ("STANDARD" "Standard" 27 7 4)
    ("EXTENDED" "Extended" 46 10 5)))

(define (make-switch-caption logical-code caption profile profile-code row col)
  (make <label>
    #:id (string-append "switchMatrix" logical-code profile-code "Caption")
    #:text (string-append caption " / " profile)
    #:justification 'centred
    #:row row
    #:col (- col 2)
    #:row-span 1
    #:col-span 14
    #:margin-tb 0
    #:margin-lr 0))

(define (make-switch-specimen logical-code caption profile profile-code text state
                              row col row-span col-span)
  (let ((reference (string-append "switchMatrix" logical-code profile-code)))
    (make <switch>
      #:id reference
      #:text text
      #:default-state state
      #:parameter-id reference
      #:parameter-name (string-append caption " " profile)
      #:processor-reference reference
      #:version-hint 1
      #:row row
      #:col col
      #:row-span row-span
      #:col-span col-span
      #:margin-tb 0
      #:margin-lr 0)))

(define (make-switch-triplet logical-code caption band-row text state)
  (for-each
   (lambda (profile)
     (let ((name (list-ref profile 0))
           (profile-code (list-ref profile 1))
           (col (list-ref profile 2))
           (col-span (list-ref profile 3))
           (row-span (list-ref profile 4)))
       (make-switch-caption logical-code caption name profile-code band-row col)
       (make-switch-specimen
        logical-code caption name profile-code text state
        (- (+ band-row 7) row-span) col row-span col-span)))
   switch-profiles))

(define (switch-visual-matrix-interface dst-folder project-name)
  (make <screen>
    #:ratio (exact->inexact (/ 60 35))
    #:width 1800)
  (make <grid>
    #:rows 35
    #:cols 60
    #:show-grid #t)

  (make-switch-triplet "ABaseOff" "A BASE OFF" 1 "" #f)
  (make-switch-triplet "BShortOff" "B SHORT OFF" 8 "POWER" #f)
  (make-switch-triplet "CLongOff" "C LONG OFF" 15 "VERY LONG SWITCH LABEL" #f)
  (make-switch-triplet "DShortOn" "D SHORT ON" 22 "POWER" #t)
  (make-switch-triplet "ELongOn" "E LONG ON" 29 "VERY LONG SWITCH LABEL" #t))

(MakeNewProject "switch-visual-matrix"
                switch-visual-matrix-interface)
