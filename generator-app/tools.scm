(define-module (generator-app tools)
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
  #:use-module (ice-9 local-eval)
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
  #:use-module (generator-app globals)
  )

(define cpp-keywords
  '("alignas" "alignof" "and" "and_eq" "asm"
    "atomic_cancel" "atomic_commit" "atomic_noexcept"
    "auto" "bitand" "bitor" "bool" "break"
    "case" "catch" "char" "char8_t" "char16_t" "char32_t"
    "class" "compl" "concept" "const" "consteval"
    "constexpr" "constinit" "const_cast" "continue"
    "co_await" "co_return" "co_yield"
    "decltype" "default" "delete" "do" "double"
    "dynamic_cast" "else" "enum" "explicit" "export"
    "extern" "false" "float" "for" "friend" "goto"
    "if" "inline" "int" "long" "mutable" "namespace"
    "new" "noexcept" "not" "not_eq" "nullptr"
    "operator" "or" "or_eq" "private" "protected"
    "public" "reflexpr" "register" "reinterpret_cast"
    "requires" "return" "short" "signed" "sizeof"
    "static" "static_assert" "static_cast" "struct"
    "switch" "synchronized" "template" "this"
    "thread_local" "throw" "true" "try" "typedef"
    "typeid" "typename" "union" "unsigned" "using"
    "virtual" "void" "volatile" "wchar_t" "while"
    "xor" "xor_eq"))

(define (logical-id->string id)
  (cond
   ((string? id) id)
   ((symbol? id) (symbol->string id))
   (else
    (error "Logical identifier must be a string or symbol" id))))

(define (identifier-char? c)
  (or (char-alphabetic? c)
      (char-numeric? c)))
(define (split-logical-id str)
  (let loop ((chars (string->list str))
             (current '())
             (words '()))
    (cond
     ((null? chars)
      (reverse
       (if (null? current)
           words
           (cons (list->string (reverse current)) words))))

     ((identifier-char? (car chars))
      (loop (cdr chars)
            (cons (car chars) current)
            words))

     (else
      (loop (cdr chars)
            '()
            (if (null? current)
                words
                (cons (list->string (reverse current))
                      words)))))))

(define (all-upper? str)
  (let ((letters
         (filter char-alphabetic?
                 (string->list str))))
    (and (not (null? letters))
         (every char-upper-case? letters))))
(define (normalize-word str)
  (if (all-upper? str)
      (string-downcase str)
      str))
(define (lower-first str)
  (if (zero? (string-length str))
      str
      (string-append
       (string (char-downcase (string-ref str 0)))
       (substring str 1))))
(define (upper-first str)
  (if (zero? (string-length str))
      str
      (string-append
       (string (char-upcase (string-ref str 0)))
       (substring str 1))))
(define (words->camel-case words)
  (if (null? words)
      ""
      (let* ((normalized (map normalize-word words))
             (first-word
              (lower-first (car normalized)))
             (other-words
              (map upper-first (cdr normalized))))
        (apply string-append
               (cons first-word other-words)))))

(define-public (logical-id->cpp-base id)
  (let* ((logical-name (logical-id->string id))
         (words        (split-logical-id logical-name))
         (base         (words->camel-case words)))

    (when (string-null? base)
      (error "Logical identifier does not contain usable characters"
             logical-name))

    (let* ((with-valid-first-char
            (if (char-numeric? (string-ref base 0))
                (string-append "_" base)
                base))

           (final-name
            (if (any
                 (lambda (keyword)
                   (string=? keyword with-valid-first-char))
                 cpp-keywords)
                (string-append with-valid-first-char "_")
                with-valid-first-char)))

      final-name)))

;; (define *cpp-identifiers* '())
;; (define-public (reset-cpp-identifiers!)
;;   (set! *cpp-identifiers* '())
;;   #t)
;; (define (cpp-identifier-used? id)
;;   (member id *cpp-identifiers*))
;; (define-public (allocate-cpp-identifier! logical-id)
;;   (let* ((base   (logical-id->cpp-base logical-id))
;;          (unique (make-unique-cpp-identifier base)))

;;     (set! *cpp-identifiers*
;;           (cons unique *cpp-identifiers*))

;;     unique))
(define *cpp-identifier-registry* '())
(define-public (reset-cpp-identifiers!)
  (set! *cpp-identifier-registry* '())
  #t)
(define (allocated-cpp-identifiers)
  (map cdr *cpp-identifier-registry*))
(define (cpp-identifier-used? id)
  (member id (allocated-cpp-identifiers)))
(define (logical-id-registered? logical-id)
  (assoc (logical-id->string logical-id)
         *cpp-identifier-registry*))
(define (make-unique-cpp-identifier base)
  (if (not (cpp-identifier-used? base))
      base
      (let loop ((n 2))
        (let ((candidate
               (string-append base (number->string n))))
          (if (cpp-identifier-used? candidate)
              (loop (+ n 1))
              candidate)))))
(define-public (allocate-cpp-identifier! logical-id)
  (let ((logical-name (logical-id->string logical-id)))

    (when (logical-id-registered? logical-name)
      (error "Duplicate logical identifier"
             logical-name))

    (let* ((base
            (logical-id->cpp-base logical-name))

           (unique
            (make-unique-cpp-identifier base)))

      (set! *cpp-identifier-registry*
            (cons
             (cons logical-name unique)
             *cpp-identifier-registry*))

      unique)))
(define-public (logical-id->cpp-id logical-id)
  (let* ((logical-name
          (logical-id->string logical-id))

         (entry
          (assoc logical-name
                 *cpp-identifier-registry*)))

    (if entry
        (cdr entry)
        #f)))
;;Fine nuova gestione degli identificatori logici e C++

(define*-public (AskForOkCancel title question label-ok #:optional (label-cancel #nil))
  (let* ((process (open-pipe* OPEN_READ "zenity"
			      (if (nil? label-cancel) "--info" "--question")
			      (format #f "--title=~a" title)
			      (format #f "--text=~a" question)
			      (format #f "--ok-label=~a" label-ok)
			      (if (nil? label-cancel) "" (format #f "--cancel-label=~a" label-cancel))))
	 ;; (output (read-line process))
	 ;; Read the output from zenity
	 (exit-status (status:exit-val (close-pipe process)))) ;; Get the exit code
    (if (equal? exit-status 0)
	'Ok
	'Ko)))

(define-public (AskForRemoveLeave project)
  (let* ((process (open-pipe* OPEN_READ "zenity"
			      "--question"	
			      (format #f "--title=Attenzione, progetto ~a già rilasciato" project)
			      "--text=Intendi aggiornarlo?"
			      "--ok-label=Aggiornare i file del progetto"
			      "--cancel-label=Terminare il programma"))
	 (output (read-line process)) ;; Read the output from zenity
	 (exit-status (status:exit-val (close-pipe process)))) ;; Get the exit code
    (if (equal? exit-status 0)
	'Update	  ;; OK button clicked
	'Leave)))   ;; Cancel button clicked

(define-public (ChooseFile path)
  (let* ((process (open-pipe* OPEN_READ "zenity"
			      "--file-selection"
			      (format #f "--title=~a" "Select the UI configuration file")))
	 (output (read-line process)) ;; Read the output from zenity
	 (exit-status (status:exit-val (close-pipe process)))) ;; Get the exit code
    (values (eq? exit-status 0) output)))

(define-public (MessageBox title msg)
  (let* ((process (open-pipe* OPEN_READ "zenity"
			      "--question"	
			      (format #f "--title=~a" title)
			      (format #f "--text=~a" msg)))
	 (output (read-line process)) ;; Read the output from zenity
	 (exit-status (status:exit-val (close-pipe process)))) ;; Get the exit code
    #t))

(define-public (ShowNotification message)
  (let* ((process (open-pipe* OPEN_READ "zenity"
			      "--notification"	
			      (format #f "--text=~a" message)))
	 (exit-status (status:exit-val (close-pipe process)))) ;; Get the exit code
    #t))

(define-public (RunProjucer)
  (system projucer-path))

(define-public (ResaveProjucerProject dst-folder)

  (let ((jucer-file
         (string-append dst-folder "/JX11.jucer")))

    (let ((status
           (system*
            projucer-path
            "--resave"
            jucer-file)))

      (unless (zero? status)
        (error "Projucer --resave failed"
               jucer-file
               status))))

  #t)

(define-public (CouldIRun?)
  ;;Check for zenity
  (define (zenity-usable?)
    (zero? (system "zenity --version > /dev/null 2>&1")))

  (if (zenity-usable?)
      #t
      (begin
	(display "Zenity is missing or not working.\nPLease install it!")
	#f)))
;;
(define-public (replace-in-string str old new)
  ;; globally substitute OLD to NEW
  (regexp-substitute/global #f
                            old		; a string regexp
                            str
                            'pre new 'post))  ; 'post makes it recurse globally

(define-public (do-replace-in-file file-name old-project-name new-name)
  ;;legge il file in una stringa
  (let* ((fin (fs-io-to-string file-name))
	 (fou (replace-in-string fin old-project-name new-name)))
    (fs-io-from-string file-name fou)))
;;
(define-public (do-replace-uuid file-name new-name uuid)
  ;;legge il file in una stringa
  (let* ((fin (fs-io-to-string file-name))
	 (fou (replace-in-string fin "pluginCode=\"Ylst\"" (format #f "pluginCode=\"~a\"" uuid))))
    (fs-io-from-string new-name fou)))
;;
;;per sostituire in un file la sottostringa compresa tra due estremi
;; (define-public (replace-between-flags file start-flag end-flag new-text)
;;   (let* ((content (call-with-input-file file get-string-all))
;;          (pattern (string-append start-flag "(.|\n)*" end-flag))
;; 	 ;;Nel replacement, a startflag e endflag devo togliere il patterm matching  [ \n]*
;;          (replacement (string-append "///" (substring start-flag 8) "\n" new-text "\n" "\t///" (substring end-flag 8)))
;;          (new-content (regexp-substitute/global #f
;; 						pattern content 'pre replacement 'post)))
;;     ;; (when (string=? start-flag WETDRY_PPC_PREFIX::START)
;;     ;;   (Show! new-content ))
;;     (call-with-output-file file
;;       (lambda (port) (display new-content port)))))
(define (clean-flag flag)
  (let ((pos (string-contains flag "]*")))
    (if pos
        (string-append "/// "
                       (substring flag (+ pos 2)))
        flag)))
(define-public (replace-between-flags file start-flag end-flag new-text)
  (Show! "******************************************************************************")
  (Show! "******************************************************************************")
  (Show! "Replaces in file: " file " between " start-flag ", " end-flag ": " new-text "\n\n\n")
  (let* ((content (call-with-input-file file get-string-all))
         (pattern (string-append start-flag "(.|\n)*" end-flag))

         (literal-start (clean-flag start-flag))
         (literal-end   (clean-flag end-flag))

         (replacement
          (string-append literal-start
                         "\n"
                         new-text
                         "\n"
                         "\t"
                         literal-end))

         (new-content
          (regexp-substitute/global #f
                                    pattern
                                    content
                                    'pre replacement 'post)))

    (call-with-output-file file
      (lambda (port)
        (display new-content port)))))
;;
;;
;;prende una alist e dichiara in una let ed estrai le variabili e i relativi valori e te li fa usare!
(define-syntax-public use-alist-keys
  (lambda (x)
    (syntax-case x ()
      ((_ alist (key ...) body ...)
       ;; Generiamo i pattern (and (assoc-ref _ 'key) key) per ogni chiave
       (with-syntax (((pattern ...) (map (lambda (k)
                                           #`(and (assoc-ref _ '#,k) #,k))
                                         #'(key ...))))
         #'(match alist
             ((and pattern ...)
              (begin body ...))))))))
;;
(define-syntax-rule (AppendStringTo archive new-string ...)
  (set! archive (string-append archive new-string ...)))
(export-syntax AppendStringTo)
;; Il motore "Pac-Man" che mangia N elementi sequenziali
(define-syntax-public compose-smart-flat
  (syntax-rules (:q :fq)
    ;; 1. Caso base: non c'è più nulla da mangiare
    ((_) "")

    ;; 2. Vede il semaforo :q -> mangia il semaforo e il valore successivo
    ((_ :q val rest ...)
     (string-append (object->string val) (compose-smart-flat rest ...)))

    ;; 3. Vede il semaforo :fq -> mangia il semaforo e il valore successivo
    ((_ :fq val rest ...)
     (string-append (format #f "\"~a\"" val) (compose-smart-flat rest ...)))

    ;; 4. Non vede semafori -> mangia 1 solo elemento (testo o variabile nuda)
    ((_ item rest ...)
     (string-append (format #f "~a" item) (compose-smart-flat rest ...)))))

;; Il Wrapper che aggiorna la variabile
(define-syntax-public Append-Smart!
  (syntax-rules ()
    ((_ archive items ...)
     (set! archive (string-append archive (compose-smart-flat items ...))))))

(define-syntax-public compose-smart-assignements
  (syntax-rules (:q)
    ;; Caso base
    ((_) "\n")

    ((_ (str :q val) rest ...)
     (string-append "\n" (symbol->string 'str) "=" (object->string val) ";" (compose-smart-assignements rest ...)))

    ((_ (:q str :q val) rest ...)
     (string-append "\n" str "=" (object->string val) ";" (compose-smart-assignements rest ...)))

    ((_ (:q str val) rest ...)
     (string-append "\n"  (object->string str) "=" (format #f "~a" val) ";" (compose-smart-assignements rest ...)))

    ((_ (str val) rest ...)
     (string-append "\n"  (symbol->string 'str) "=" (format #f "~a" val) ";" (compose-smart-assignements rest ...)))
    ))
;;
(define-syntax-public GenerateAssignements
  (syntax-rules ()
    ((_ archive pairs ...)
     (set! archive (string-append archive (compose-smart-assignements pairs ...))))))
;;
(define-syntax-public nequal?
  (syntax-rules ()
    ((_ a ...)
     (not (equal? a ...)))))
;;
;;
;;
;;se nella stringa metto ${var} inserisce il valore, se metto !{var} lo quota con doppio quote
(define*-public (f-str str #:optional (env (interaction-environment)))
  (let* ((len (string-length str)))
    (let loop ((i 0)
               (fmt-acc '())
               (exprs '()))
      (if (>= i len)
          ;; Qui usiamo apply per passare la lista di espressioni a format
          (apply format #f (apply string-append (reverse fmt-acc)) (reverse exprs))
          
          (cond
           ;; Escape per $$ -> $
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\$)
                 (char=? (string-ref str (+ i 1)) #\$))
            (loop (+ i 2) (cons "$" fmt-acc) exprs))

           ;; Escape per !! -> !
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\!)
                 (char=? (string-ref str (+ i 1)) #\!))
            (loop (+ i 2) (cons "!" fmt-acc) exprs))

           ;; Gestione !{expr} -> racchiude tra virgolette
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\!)
                 (char=? (string-ref str (+ i 1)) #\{))
            (let loop-brace ((j (+ i 2)))
              (if (>= j len)
                  (loop (+ i 1) (cons "!" fmt-acc) exprs)
                  (if (char=? (string-ref str j) #\})
                      (let* ((expr-str (substring str (+ i 2) j))
                             ;; ATTENZIONE: Qui usiamo eval per valutare l'espressione nel contesto attuale
                             ;;(expr-val (eval (call-with-input-string expr-str read) (interaction-environment)))
			     (expr-val (local-eval (call-with-input-string expr-str read) env))
			     )
                        (loop (+ j 1) (cons "\"~a\"" fmt-acc) (cons expr-val exprs)))
                      (loop-brace (+ j 1))))))

           ;; Gestione ${expr} -> valore nudo
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\$)
                 (char=? (string-ref str (+ i 1)) #\{))
            (let loop-brace ((j (+ i 2)))
              (if (>= j len)
                  (loop (+ i 1) (cons "$" fmt-acc) exprs)
                  (if (char=? (string-ref str j) #\})
                      (let* ((expr-str (substring str (+ i 2) j))
                             ;;(expr-val (eval (call-with-input-string expr-str read) (interaction-environment)))
			     (expr-val (local-eval (call-with-input-string expr-str read) env)))
                        (loop (+ j 1) (cons "~a" fmt-acc) (cons expr-val exprs)))
                      (loop-brace (+ j 1))))))

           (else
            (loop (+ i 1) (cons (string (string-ref str i)) fmt-acc) exprs)))))))


(define-macro (f-str-macro str)
  (let* ((len (string-length str)))
    (let loop ((i 0)
               (fmt-acc '())
               (exprs '()))
      (if (>= i len)
          ;; INVECE DI APPLY/FORMAT, GENERIAMO IL CODICE SCHEME
          `(format #f ,(apply string-append (reverse fmt-acc)) ,@(reverse exprs))
          
          (cond
           ;; Escape per $$ -> $
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\$)
                 (char=? (string-ref str (+ i 1)) #\$))
            (loop (+ i 2) (cons "$" fmt-acc) exprs))

           ;; Escape per !! -> !
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\!)
                 (char=? (string-ref str (+ i 1)) #\!))
            (loop (+ i 2) (cons "!" fmt-acc) exprs))

           ;; Gestione !{expr} -> racchiude tra virgolette
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\!)
                 (char=? (string-ref str (+ i 1)) #\{))
            (let loop-brace ((j (+ i 2)))
              (if (>= j len)
                  (loop (+ i 1) (cons "!" fmt-acc) exprs)
                  (if (char=? (string-ref str j) #\})
                      (let* ((expr-str (substring str (+ i 2) j))
                             ;; LEGGIAMO IL SIMBOLO/ESPRESSIONE MA NON FACCIAMO EVAL
                             (expr-ast (call-with-input-string expr-str read)))
                        (loop (+ j 1) (cons "\"~a\"" fmt-acc) (cons expr-ast exprs)))
                      (loop-brace (+ j 1))))))

           ;; Gestione ${expr} -> valore nudo
           ((and (< (+ i 1) len)
                 (char=? (string-ref str i) #\$)
                 (char=? (string-ref str (+ i 1)) #\{))
            (let loop-brace ((j (+ i 2)))
              (if (>= j len)
                  (loop (+ i 1) (cons "$" fmt-acc) exprs)
                  (if (char=? (string-ref str j) #\})
                      (let* ((expr-str (substring str (+ i 2) j))
                             ;; LEGGIAMO IL SIMBOLO/ESPRESSIONE MA NON FACCIAMO EVAL
                             (expr-ast (call-with-input-string expr-str read)))
                        (loop (+ j 1) (cons "~a" fmt-acc) (cons expr-ast exprs)))
                      (loop-brace (+ j 1))))))

           (else
            (loop (+ i 1) (cons (string (string-ref str i)) fmt-acc) exprs)))))))
(export f-str)

;;
(define-public (to-decibel n)
  (* (log10 n) 20.0))
(define-public (from-decibel n)
  (expt 10.0 (/ n 20.0)))
(define-public (truncate-n-decimals x n)
  (/ (truncate (* x (expt 10 n))) (expt 10 n)))
;;


;;Per la composizione di elementi json<=>alist vector
(define-public (json-prepend-key key scm)
  (Show! "json-prepend-key: " key " " scm)
  (list (cons key scm)))

(define-public (json-build-vector . objects)
  (Show! "json-build-vector: " objects)
  (list->vector objects))
