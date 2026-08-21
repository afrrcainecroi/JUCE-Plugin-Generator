(define-module (generator-app globals)
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
  )
;;
;;La funzione globale per generare i nomi, unici. delle variabili
(define-public g::gen-var #f) ;;per generare le variabili quando serviranno
;;
(define-public old-project-name "YATemplate")
(define-public template-name (string-append "Generator/" old-project-name))
(define-public workspace-path "/volume1/sources/NEW_DEVS/DEPLOYED/MUSIC/JUCE/Development/")
(define-public projucer-path "/volume1/sources/NEW_DEVS/DEPLOYED/MUSIC/JUCE/Projucer")
;;
(define-syntax-public define-constant-blocks
  (lambda (x)
    (syntax-case x ()
      ((_ name ...)
       (let* ((raw-names (syntax->datum #'(name ...)))
              
              ;; Nuova funzione per creare i simboli: 
              ;; Aggiunge automaticamente '*' all'inizio e alla fine
              (make-sym (lambda (base suffix)
                          (string->symbol 
                           (string-append "*" (symbol->string base) suffix "*"))))
              
              ;; Generiamo i tre set di simboli
              (base-syms  (map (lambda (n) (make-sym n "")) raw-names))
              (start-syms (map (lambda (n) (make-sym n "::START")) raw-names))
              (end-syms   (map (lambda (n) (make-sym n "::END")) raw-names))
              
              ;; Stringhe per i valori (conterrano "INTERFACE" pulito, es: "///[ \t]*INTERFACE START")
              (start-vals (map (lambda (n) (string-append "///[ \\t]*" (symbol->string n) " START")) raw-names))
              (end-vals   (map (lambda (n) (string-append "///[ \\t]*" (symbol->string n) " END"))   raw-names)))

         (with-syntax (((s-base ...)  (map (lambda (s) (datum->syntax x s)) base-syms))
                       ((s-start ...) (map (lambda (s) (datum->syntax x s)) start-syms))
                       ((s-end ...)   (map (lambda (s) (datum->syntax x s)) end-syms))
                       ((v-start ...) start-vals)
                       ((v-end ...)   end-vals)
                       (init-func     (datum->syntax x 'InitializeConstants)))
           
           #'(begin
               ;; 1. Definisce il simbolo base (es. *INTERFACE*) inizializzato a ""
               (define-public s-base "") ...
               
               ;; 2. Definisce i simboli START ed END
               (define-public s-start v-start) ...
               (define-public s-end v-end) ...

               ;; 3. Definisce la funzione che resetta solo il simbolo base
               (define-public (init-func)
                 (begin
                   (set! s-base "") ...)
                 #t))))))))


(eval-when (expand load eval compile)
  (define-constant-blocks
    INTERFACE
    GRID
    RESIZED
    FOOTER_MOUSE
    FOOTER_TIMER
    DECLARATIONS
    PARAMS
    DPARAMS
    GETPARAMS
    VALUEPARAMS
    SCREENSIZE
    DESTROY
    BACKGROUND
    OVERSAMPLING_PPC
    OVERSAMPLING_PPCPB
    OVERSAMPLING_PPCRR
    OVERSAMPLING_PPH
    WETDRY_PPC_PREFIX
    WETDRY_PPC_POSTFIX
    PROCESS
    PAINT_OVER_CHILDREN
    IMAGE_RESOURCES
    TIMER
    DSP_RUNTIME_MEMBERS
    FFT_INFRASTRUCTURE
    FFT_MYPLUGIN_MEMBERS
    MYPLUGIN_FFT_INIT
    MYPLUGIN_PROCESS_AUDIO_BUFFER
    MYPLUGIN_PROCESS_AUDIO_BLOCK
    MYPLUGIN_PREPARE
    MYPLUGIN_RESET
    ))
;;
;; (define-public *OVERSAMPLING_PPC* "")
;; (define-public *OVERSAMPLING_PPC::START* "///[ \t]*OVERSAMPLING_PPC START")
;; (define-public *OVERSAMPLING_PPC::END* "///[ \t]*OVERSAMPLING_PPC END")
;; ;;
;; (define-public *OVERSAMPLING_PPCPB* "")
;; (define-public *OVERSAMPLING_PPCPB::START* "///[ \t]*OVERSAMPLING_PPCPB START")
;; (define-public *OVERSAMPLING_PPCPB::END* "///[ \t]*OVERSAMPLING_PPCPB END")
;; ;;
;; (define-public *OVERSAMPLING_PPCRR* "")
;; (define-public *OVERSAMPLING_PPCRR::START* "///[ \t]*OVERSAMPLING_PPCRR START")
;; (define-public *OVERSAMPLING_PPCRR::END* "///[ \t]*OVERSAMPLING_PPCRR END")
;; ;;
;; (define-public *OVERSAMPLING_PPH* "")
;; (define-public *OVERSAMPLING_PPH::START* "///[ \t]*OVERSAMPLING_PPH START")
;; (define-public *OVERSAMPLING_PPH::END* "///[ \t]*OVERSAMPLING_PPH END")
;; ;;
;;Altre definizioni
(define-public *OVERSAMPLING-ENABLED* #f)
(define-public *OVERSAMPLING-FILTER* 'filterHalfBandPolyphaseIIR)
(define-public *OVERSAMPLING-isMaxQuality* #f)
(define-public *OVERSAMPLING-useIntegerLatency* #t)
(define-public *components* '())
(define-public *image-sets* '())
(define-public *screen* #f)
(define-public *grid* #f)

(define-public (reset-components!)
  (set! *components* '())
  (set! *image-sets* '())
  (set! *screen* #f)
  (set! *grid* #f)
  #t)
;; (define-public (find-component id)
;;   (find
;;    (lambda (component)
;;      (equal? (assoc-ref component 'id) id))
;;    *components*))
;; (define-public (find-component-by-cpp-id cpp-id)
;;   (find
;;    (lambda (component)
;;      (equal? (assoc-ref component 'var) cpp-id))
;;    *components*))
;; (define (component-id-used? id)
;;   (any
;;    (lambda (component)
;;      (equal? (assoc-ref component 'id) id))
;;    *components*))

;; (define-public CODICE-PER-PALETTE
;;   "
;;     // HEADER
;;     lblPalette.setText(!{title}, juce::dontSendNotification);
;;     lblPalette.setJustificationType(juce::Justification::centredRight);
;;     addAndMakeVisible(lblPalette);

;;     paletteSelector.addItem(\"Cyan (Cyberpunk)\", 1);
;;     paletteSelector.addItem(\"Plasma (Purple)\", 2);
;;     paletteSelector.addItem(\"Gold (Amber)\", 3);
;;     paletteSelector.addItem(\"Matrix (Green)\", 4);
;;     paletteSelector.addItem(\"Fire (Red)\", 5);
;;     paletteSelector.addItem(\"Ocean (Blue)\", 6);
;;     paletteSelector.addItem(\"Toxic (Lime)\", 7);
;;     paletteSelector.addItem(\"Radon (Pink)\", 8);
;;     paletteSelector.addItem(\"White (Mono)\", 9);
;;     paletteSelector.addItem(\"Midnight (Dark)\", 10);
;;     paletteSelector.addItem(\"Sunset (Orange)\", 11);
;;     paletteSelector.addItem(\"Mint (Teal)\", 12);
;;     paletteSelector.addItem(\"Vaporwave (Pink)\", 13);
;;     paletteSelector.addItem(\"Amber (Amber)\", 14);
;;     paletteSelector.addItem(\"Crimson (Red)\", 15);
;;     paletteSelector.addItem(\"Voltage (Yellow)\", 16);
;;     paletteSelector.addItem(\"Ultraviolet (Violet)\", 17);
;;     paletteSelector.addItem(\"Stealth (Grey)\", 18);

;;     paletteSelector.setSelectedId(${default});

;;     // FIX 3: Disabilita cattura tastiera del ComboBox
;;     paletteSelector.setWantsKeyboardFocus(false);

;;     paletteSelector.onChange = [this]
;;     {
;;         KineticLookAndFeel::PaletteType type;
;;         switch (paletteSelector.getSelectedId())
;;         {
;;         case 1:
;;             type = KineticLookAndFeel::PaletteType::Cyan;
;;             break;
;;         case 2:
;;             type = KineticLookAndFeel::PaletteType::Plasma;
;;             break;
;;         case 3:
;;             type = KineticLookAndFeel::PaletteType::Gold;
;;             break;
;;         case 4:
;;             type = KineticLookAndFeel::PaletteType::Matrix;
;;             break;
;;         case 5:
;;             type = KineticLookAndFeel::PaletteType::Fire;
;;             break;
;;         case 6:
;;             type = KineticLookAndFeel::PaletteType::Ocean;
;;             break;
;;         case 7:
;;             type = KineticLookAndFeel::PaletteType::Toxic;
;;             break;
;;         case 8:
;;             type = KineticLookAndFeel::PaletteType::Radon;
;;             break;
;;         case 9:
;;             type = KineticLookAndFeel::PaletteType::White;
;;             break;
;;         case 10:
;;             type = KineticLookAndFeel::PaletteType::Midnight;
;;             break;
;;         case 11:
;;             type = KineticLookAndFeel::PaletteType::Sunset;
;;             break;
;;         case 12:
;;             type = KineticLookAndFeel::PaletteType::Mint;
;;             break;
;;         case 13:
;;             type = KineticLookAndFeel::PaletteType::Vaporwave;
;;             break;
;;         case 14:
;;             type = KineticLookAndFeel::PaletteType::Amber;
;;             break;
;;         case 15:
;;             type = KineticLookAndFeel::PaletteType::Crimson;
;;             break;
;;         case 16:
;;             type = KineticLookAndFeel::PaletteType::Voltage;
;;             break;
;;         case 17:
;;             type = KineticLookAndFeel::PaletteType::Ultraviolet;
;;             break;
;;         case 18:
;;             type = KineticLookAndFeel::PaletteType::Stealth;
;;             break;

;;         default:
;;             type = KineticLookAndFeel::PaletteType::Cyan;
;;             break;
;;         }
;;         kineticLNF.animatePaletteChange(type, 2000);
;;         repaint();
;;     };

;;     paletteSelector.setWantsKeyboardFocus(true);

;;     paletteSelector.onChange = [this]
;;     {
;;         KineticLookAndFeel::PaletteType type;
;;         switch (paletteSelector.getSelectedId())
;;         {
;;         case 1:
;;             type = KineticLookAndFeel::PaletteType::Cyan;
;;             break;
;;         case 2:
;;             type = KineticLookAndFeel::PaletteType::Plasma;
;;             break;
;;         case 3:
;;             type = KineticLookAndFeel::PaletteType::Gold;
;;             break;
;;         case 4:
;;             type = KineticLookAndFeel::PaletteType::Matrix;
;;             break;
;;         case 5:
;;             type = KineticLookAndFeel::PaletteType::Fire;
;;             break;
;;         case 6:
;;             type = KineticLookAndFeel::PaletteType::Ocean;
;;             break;
;;         case 7:
;;             type = KineticLookAndFeel::PaletteType::Toxic;
;;             break;
;;         case 8:
;;             type = KineticLookAndFeel::PaletteType::Radon;
;;             break;
;;         case 9:
;;             type = KineticLookAndFeel::PaletteType::White;
;;             break;
;;         case 10:
;;             type = KineticLookAndFeel::PaletteType::Midnight;
;;             break;
;;         case 11:
;;             type = KineticLookAndFeel::PaletteType::Sunset;
;;             break;
;;         case 12:
;;             type = KineticLookAndFeel::PaletteType::Mint;
;;             break;
;;         case 13:
;;             type = KineticLookAndFeel::PaletteType::Vaporwave;
;;             break;
;;         case 14:
;;             type = KineticLookAndFeel::PaletteType::Amber;
;;             break;
;;         case 15:
;;             type = KineticLookAndFeel::PaletteType::Crimson;
;;             break;
;;         case 16:
;;             type = KineticLookAndFeel::PaletteType::Voltage;
;;             break;
;;         case 17:
;;             type = KineticLookAndFeel::PaletteType::Ultraviolet;
;;             break;
;;         case 18:
;;             type = KineticLookAndFeel::PaletteType::Stealth;
;;             break;

;;         default:
;;             type = KineticLookAndFeel::PaletteType::Cyan;
;;             break;
;;         }
;;         kineticLNF.animatePaletteChange(type, 2000);
;;         repaint();
;;     };
;;     paletteSelector.setWantsKeyboardFocus(true);
;;     addAndMakeVisible(paletteSelector);
;; ")

(export CODICE-PER-PALETTE)
