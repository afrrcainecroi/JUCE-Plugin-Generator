(define-module (generator-app genera-classi)
  #:use-module ((algorithms) #:prefix algo:)
  #:use-module ((f) #:prefix f:)
  #:use-module ((f ports) #:prefix fp:)
  #:use-module (pfds sets)
  #:use-module (mtfa error-handler)
  #:use-module (mtfa utils)
  #:use-module (mtfa serializer)
  #:use-module (mtfa unordered-set)
  #:use-module (mtfa unordered-map)
  #:use-module (mtfa star-map)
  #:use-module (mtfa simple_db)
  #:use-module (mtfa eis)
  #:use-module (mtfa va)
  #:use-module (mtfa extset)
  #:use-module (mtfa umset)
  #:use-module (mtfa web)
  #:use-module (mtfa brg)
  #:use-module (mtfa avl)
  #:use-module (mtfa eqt)
  #:use-module (gnutls)
  #:use-module (scheme kwargs)
  #:use-module (search basic)
  #:use-module (math primes)
  #:use-module (match-bind)
  #:use-module (graph topological-sort)
  #:use-module (rnrs bytevectors)
  #:use-module (rnrs arithmetic bitwise)
  #:use-module (rnrs enums)
  #:use-module ((rnrs io ports) #:prefix ioports::)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-11)
  #:use-module ((srfi srfi-18) #:prefix srfi-18::) ;;thread e mutex
  #:use-module (srfi srfi-19)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-41) ;;streams
  #:use-module (srfi srfi-42) ;;Eager Comprehensions
  #:use-module (srfi srfi-43)
  #:use-module (srfi srfi-45)
  #:use-module (srfi srfi-60)
  #:use-module (srfi srfi-111) ;;Boxes
  #:use-module (srfi srfi-171)
  #:use-module (web uri)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 rdelim)
  #:use-module (ice-9 pretty-print)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 peg)
  #:use-module (ice-9 peg string-peg)
  #:use-module (ice-9 vlist)
  #:use-module (ice-9 q)
  #:use-module (ice-9 binary-ports)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 threads)
  #:use-module (ice-9 hash-table)
  #:use-module (ice-9 control)
  #:use-module (ice-9 match)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 eval-string)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 arrays)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 optargs)
  #:use-module (ice-9 string-fun)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (json)
  #:use-module (system syntax)
  #:use-module (system foreign)
  #:use-module (system foreign-library)
  #:use-module (web server)
  #:use-module (web request)
  #:use-module (web response)
  #:use-module (web uri)
  #:use-module (web client)
  ;;#:use-module (generator-app globals)

  )

(define-syntax-public new-class
  (lambda (x)

    ;; ------------------------------------------------------------
    ;; Funzione interna che costruisce l'espansione vera e propria.
    ;; parents-syntax contiene la lista delle superclassi GOOPS.
    ;; ------------------------------------------------------------
    (define (expand-new-class class-name
                              parents-syntax
                              slot-names
                              slot-vals
                              init-body)

      (let* ((raw-slots
              (syntax->datum slot-names))

             (name-str
              (symbol->string
               (syntax->datum class-name)))

             (base-name
              (string-filter
               (lambda (c)
                 (not (member c '(#\< #\>))))
               name-str))

             (make-accessor-name
              (lambda (s)
                (string->symbol
                 (string-append
                  base-name
                  ":"
                  (symbol->string s)))))

             (accessor-syms
              (map make-accessor-name raw-slots)))

        (with-syntax
            (((accessor-name ...)
              (map
               (lambda (s)
                 (datum->syntax class-name s))
               accessor-syms))

             ((s-kw ...)
              (map
               (lambda (s)
                 (datum->syntax
                  class-name
                  (symbol->keyword s)))
               raw-slots))

             ((slot-name ...) slot-names)

             ((slot-val ...) slot-vals)

             ((parent ...) parents-syntax)

             ((init-body ...) init-body)

             (class-name class-name)

             (this
              (datum->syntax class-name 'this))

             (initialize-sym
              (datum->syntax class-name 'initialize))

             (write-sym
              (datum->syntax class-name 'write))

             (display-sym
              (datum->syntax class-name 'display))

             (next-method-sym
              (datum->syntax class-name 'next-method))

             (define-method-sym
              (datum->syntax class-name 'define-method)))

          (with-syntax
              (((slot-definition ...)
                (map
                 (lambda (name val accessor kw)
                   (if (list? (syntax->datum val))

                       #`(#,name
                          #:init-form #,val
                          #:accessor #,accessor
                          #:init-keyword #,kw)

                       #`(#,name
                          #:init-value #,val
                          #:accessor #,accessor
                          #:init-keyword #,kw)))

                 #'(slot-name ...)
                 #'(slot-val ...)
                 #'(accessor-name ...)
                 #'(s-kw ...))))

            #'(begin

                (define-class-public class-name (parent ...)
                  slot-definition ...)

                (export accessor-name ...)

                (define-method-sym
                  (initialize-sym (this class-name) initargs)

                  (next-method-sym)

                  (let ((slot-name
                         (slot-ref this 'slot-name))
                        ...)
                    init-body ...))

                ;; METODO WRITE
                (define-method-sym
                  (write-sym (this class-name) port)

                  (format port "#<~a" 'class-name)

                  (begin
                    (format port
                            " ~a: ~s"
                            'slot-name
                            (accessor-name this)))
                  ...

                  (display ">" port))

                ;; METODO DISPLAY
                (define-method-sym
                  (display-sym (this class-name) port)

                  (format port "#<~a" 'class-name)

                  (begin
                    (format port
                            " ~a: ~s"
                            'slot-name
                            (accessor-name this)))
                  ...

                  (display ">" port)))))))

    ;; ============================================================
    ;; Le due sintassi accettate
    ;; ============================================================

    (syntax-case x ()

      ;; ----------------------------------------------------------
      ;; NUOVA FORMA:
      ;;
      ;; (new-class <child> (<parent> ...)
      ;;   ((slot value) ...)
      ;;   #:code
      ;;   ...)
      ;; ----------------------------------------------------------
      ((_ class-name
          (parent ...)
          ((slot-name slot-val) ...)
          kw-code
          init-body ...)

       (expand-new-class
        #'class-name
        #'(parent ...)
        #'(slot-name ...)
        #'(slot-val ...)
        #'(init-body ...)))


      ;; ----------------------------------------------------------
      ;; FORMA VECCHIA, mantenuta compatibile:
      ;;
      ;; (new-class <foo>
      ;;   ((slot value) ...)
      ;;   #:code
      ;;   ...)
      ;;
      ;; equivale a:
      ;; (new-class <foo> ()
      ;;   ...)
      ;; ----------------------------------------------------------
      ((_ class-name
          ((slot-name slot-val) ...)
          kw-code
          init-body ...)

       (expand-new-class
        #'class-name
        #'()
        #'(slot-name ...)
        #'(slot-val ...)
        #'(init-body ...))))))

;; (define-syntax-public new-class
;;   (lambda (x)
;;     (syntax-case x ()
;;       ((_ class-name ((slot-name slot-val) ...) kw-code init-body ...)
;;        (let* ((raw-slots (syntax->datum #'(slot-name ...)))
;;               (name-str (symbol->string (syntax->datum #'class-name)))
;;               (base-name (string-filter (lambda (c) (not (member c '(#\< #\>)))) name-str))
;;               (make-accessor-name (lambda (s)
;;                                     (string->symbol (string-append base-name ":" (symbol->string s)))))
;;               (accessor-syms (map make-accessor-name raw-slots)))
;;          (with-syntax (((accessor-name ...) (map (lambda (s) (datum->syntax #'class-name s)) accessor-syms))
;;                        ((s-kw ...) (map (lambda (s) (datum->syntax #'class-name (symbol->keyword s))) raw-slots))
;;                        (this (datum->syntax #'class-name 'this))
;;                        (initialize-sym (datum->syntax #'class-name 'initialize))
;;                        (write-sym (datum->syntax #'class-name 'write))
;;                        (display-sym (datum->syntax #'class-name 'display))
;;                        (next-method-sym (datum->syntax #'class-name 'next-method))
;;                        (define-method-sym (datum->syntax #'class-name 'define-method)))
           
;;            (with-syntax (((slot-definition ...) 
;;                           (map (lambda (name val accessor kw)
;;                                  (if (list? (syntax->datum val))
;;                                      #`(#,name #:init-form #,val #:accessor #,accessor #:init-keyword #,kw)
;;                                      #`(#,name #:init-value #,val #:accessor #,accessor #:init-keyword #,kw)))
;;                                #'(slot-name ...) #'(slot-val ...) #'(accessor-name ...) #'(s-kw ...))))
             
;;              #'(begin
;;                  (define-class-public class-name ()
;;                    slot-definition ...)
;;                  (export accessor-name ...)
                 
;;                  (define-method-sym (initialize-sym (this class-name) initargs)
;;                    (next-method-sym)
;;                    (let ((slot-name (slot-ref this 'slot-name)) ...)
;;                      init-body ...))
                 
;;                  ;; METODO WRITE
;;                  (define-method-sym (write-sym (this class-name) port)
;;                    (format port "#<~a" 'class-name)
;;                    (begin
;;                      (format port " ~a: ~s" 'slot-name (accessor-name this))) ...
;;                    (display ">" port))
                 
;;                  ;; METODO DISPLAY
;;                  ;; La logica è espansa inline per bypassare il cycle-detector del C-core
;;                  (define-method-sym (display-sym (this class-name) port)
;;                    (format port "#<~a" 'class-name)
;;                    (begin
;;                      (format port " ~a: ~s" 'slot-name (accessor-name this))) ...
;;                    (display ">" port))))))))))


