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
    SYNTH_H_RP
    PROCESS
    PAINT_OVER_CHILDREN
    IMAGE_RESOURCES
    TIMER
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

(define-public CODICE-PER-FFT "
class SimpleStftStereo
{
public:
    void setFftSize(int N)
    {
        jassert(juce::isPowerOfTwo(N));
        fftSize = N;
        hopSize = N / 2;

        fft.reset(new juce::dsp::FFT((int)std::log2((double)fftSize)));
        // sqrt-Hann tables (COLA con hop=N/2)
        winAna.resize(fftSize);
        winSyn.resize(fftSize);
        for (int n = 0; n < fftSize; ++n)
        {
            const float hann = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * (float)n / (float)(fftSize - 1)));
            const float s = std::sqrt(juce::jmax(0.0f, hann));
            winAna[n] = s;
            winSyn[n] = s;
        }

        for (auto &ch : chans)
        {
            ch.fifo.assign(fftSize, 0.0f);
            ch.fifoFill = 0;
            ch.reim.assign(2 * fftSize, 0.0f);
            ch.ola.assign(fftSize + 2 * hopSize, 0.0f);
            ch.olaAvail = 0;
            ch.olaWrite = 0;
            ch.inBlock.clear();
        }
    }

    void setSampleRate(double sr) { sampleRate = sr; }
    void setWetDry(float wd) { wetMix.store(juce::jlimit(0.0f, 1.0f, wd)); }

    void reset()
    {
        for (auto &ch : chans)
        {
            std::fill(ch.fifo.begin(), ch.fifo.end(), 0.0f);
            ch.fifoFill = 0;
            std::fill(ch.reim.begin(), ch.reim.end(), 0.0f);
            std::fill(ch.ola.begin(), ch.ola.end(), 0.0f);
            ch.olaAvail = 0;
            ch.olaWrite = 0;
            ch.inBlock.clear();
        }
    }

    void process(juce::AudioBuffer<float> &buffer)
    {
        const int numCh = juce::jmin(2, buffer.getNumChannels());
        const int numSm = buffer.getNumSamples();
        for (int c = 0; c < numCh; ++c)
            processChannel(chans[c], buffer.getWritePointer(c), numSm);
    }

    int getLatencySamples() const noexcept { return hopSize; }

    unique_ptr<DoTheFFTJob> doTheFFTJob;
    JX11AudioProcessor *processor;

private:
    struct Channel
    {
        std::vector<float> fifo;
        int fifoFill = 0;
        std::vector<float> reim; // 2N
        std::vector<float> ola;
        int olaAvail = 0;
        int olaWrite = 0;
        std::vector<float> inBlock;
    };

    Channel chans[2];
    std::unique_ptr<juce::dsp::FFT> fft;
    std::vector<float> winAna, winSyn;

    int fftSize = 1024, hopSize = 512;
    double sampleRate = 48000.0;
    std::atomic<float> wetMix{1.0f}; // 1=solo wet, 0=solo dry

    inline void processChannel(Channel &ch, float *io, int numSamples)
    {
        // snapshot dry
        if ((int)ch.inBlock.size() < numSamples)
            ch.inBlock.resize(numSamples);
        std::memcpy(ch.inBlock.data(), io, sizeof(float) * (size_t)numSamples);

        int pos = 0;

        while (pos < numSamples)
        {
            // accumulate input in FIFO
            const int canCopyIn = juce::jmin(fftSize - ch.fifoFill, numSamples - pos);
            std::memcpy(ch.fifo.data() + ch.fifoFill, ch.inBlock.data() + pos, sizeof(float) * (size_t)canCopyIn);
            ch.fifoFill += canCopyIn;

            // process as many frames as possible
            while (ch.fifoFill >= fftSize)
            {
                // analysis buffer + sqrt-Hann
                static thread_local std::vector<float> ana;
                if ((int)ana.size() < fftSize)
                    ana.resize(fftSize);
                std::memcpy(ana.data(), ch.fifo.data(), sizeof(float) * (size_t)fftSize);
                for (int i = 0; i < fftSize; ++i)
                    ana[i] *= winAna[i];

                // pack for JUCE real-only: time-domain in [0..N-1], zero tail
                std::memcpy(ch.reim.data(), ana.data(), sizeof(float) * (size_t)fftSize);
                std::memset(ch.reim.data() + fftSize, 0, sizeof(float) * (size_t)fftSize);

                // forward FFT
                fft->performRealOnlyForwardTransform(ch.reim.data());

                // ----------------------------------------------------------------
                // TODO: spectral processing (modifica i bin)
                //
                // Layout JUCE (real-only):
                // reim[0] = DC, reim[1] = Nyquist,
                // per k=1..N/2-1: reim[2*k] = Re{X[k]}, reim[2*k+1] = Im{X[k]}
                // reim
                doTheFFTJob->doTheFFTJob(processor, fftSize, ch.reim);
                // {
                //     const double fs = processor->value_info_sampleRate;
                //     const int half = fftSize/2;
                //     const int cutoffBin = juce::jlimit(0, half, (int) std::floor (processor->value_cutoff * fftSize / fs + 0.5));
                //     for (int k = cutoffBin + 1; k < half; ++k) {
                //         ch.reim[2*k]=0.0f;
                //         ch.reim[2*k+1]=0.0f;
                //     }
                //     ch.reim[1] = 0.0f; // Nyquist
                // }
                // Esempio LPF (cut a metà banda):
                // const int half = fftSize/2; for (int k = half/2 + 1; k < half; ++k) { reim[2*k]=0; reim[2*k+1]=0; }
                // ----------------------------------------------------------------

                // inverse FFT → time-domain in reim[0..N-1]
                fft->performRealOnlyInverseTransform(ch.reim.data());

                // synthesis buffer (no extra 1/N here; regola se serve per la tua JUCE)
                static thread_local std::vector<float> syn;
                if ((int)syn.size() < fftSize)
                    syn.resize(fftSize);
                std::memcpy(syn.data(), ch.reim.data(), sizeof(float) * (size_t)fftSize);

                // sqrt-Hann synthesis
                for (int i = 0; i < fftSize; ++i)
                    syn[i] *= winSyn[i];

                // OLA at write offset
                jassert(ch.olaWrite + fftSize <= (int)ch.ola.size());
                for (int i = 0; i < fftSize; ++i)
                    ch.ola[ch.olaWrite + i] += syn[i];

                ch.olaAvail += hopSize;
                ch.olaWrite += hopSize;

                // shift FIFO by hop
                std::memmove(ch.fifo.data(), ch.fifo.data() + hopSize, sizeof(float) * (size_t)(fftSize - hopSize));
                ch.fifoFill -= hopSize;
            }

            // emit wet (available) + dry mix
            const int remaining = numSamples - pos;
            int emit = juce::jmin(remaining, ch.olaAvail);

            const float gW = wetMix.load();
            const float gD = 1.0f - gW;

            if (emit > 0)
            {
                for (int i = 0; i < emit; ++i)
                    io[pos + i] = gW * ch.ola[i] + gD * ch.inBlock[pos + i];

                // compact OLA by 'emit'
                const int validLen = juce::jlimit(fftSize, (int)ch.ola.size(), (ch.olaWrite - hopSize) + fftSize);
                std::memmove(ch.ola.data(), ch.ola.data() + emit, sizeof(float) * (size_t)(validLen - emit));
                std::memset(ch.ola.data() + (validLen - emit), 0, sizeof(float) * (size_t)emit);

                ch.olaWrite -= emit;
                if (ch.olaWrite < 0)
                    ch.olaWrite = 0;
                ch.olaAvail -= emit;
                pos += emit;
            }
            else
            {
                // no wet yet → pass dry
                const int copy = juce::jmin(remaining, canCopyIn);
                std::memcpy(io + pos, ch.inBlock.data() + pos, sizeof(float) * (size_t)copy);
                pos += copy;
            }
        }
    }
};

class RealPlugin
{
public:
    void ButtonCallback(int num, juce::String name)
    {
        std::cout << \"Clicked button: \" << num << \". Name: \" << name << std::endl;
    }

    RealPlugin(JX11AudioProcessor *processor) : processor(processor)
    {
        prepare();
    }

    int TranslateFFTSize()
    {
        switch (static_cast<int>(processor->value_fftsize))
        {
        case 0:
            return 256;
        case 1:
            return 512;
        case 2:
            return 1024;
        case 3:
            return 2048;
        case 4:
            return 4096;
        case 5:
            return 8192;
        default:
            return 1024;
        }
    }

    void prepare()
    {
        stft.processor = processor;
        stft.doTheFFTJob = make_unique<DoTheFFTJob>();

        oldFFTSize = TranslateFFTSize();
        stft.setFftSize(oldFFTSize); // 256/512/1024/2048...
        stft.setSampleRate(processor->value_info_sampleRate);
        stft.setWetDry(processor->value_wetdry); // per test: solo wet
        stft.reset();
        processor->setLatencySamples(stft.getLatencySamples()); // N/2
    }

    // In case of resampling
    void render(juce::dsp::AudioBlock<float> &buffer)
    {
    }

    void render(juce::AudioBuffer<float> &buffer)
    {
        stft.setWetDry(processor->value_wetdry); // per test: solo wet

        if (oldFFTSize != TranslateFFTSize())
        {
            stft.processor = processor;
            stft.doTheFFTJob.reset();
            stft.doTheFFTJob = make_unique<DoTheFFTJob>();

            oldFFTSize = TranslateFFTSize();
            stft.setFftSize(oldFFTSize); // 256/512/1024/2048...
            stft.setSampleRate(processor->value_info_sampleRate);
            stft.reset();
            processor->setLatencySamples(stft.getLatencySamples()); // N/2
        }
        stft.process(buffer);
    }

private:
    SimpleStftStereo stft;
    int oldFFTSize = 0;

    JX11AudioProcessor *processor = nullptr;
};
")

(define-public CODICE-NON-PER-FFT "
class RealPlugin
{
public:
    void prepare(double sampleRate)
    {
    }
    RealPlugin(JX11AudioProcessor *processor) : processor(processor)
    {
        prepare(processor->value_info_sampleRate);
    }

    void ButtonCallback(int num, juce::String name) {
        std::cout << \"Clicked button: \" << num << \". Name: \" << name << std::endl;
    }

    ~RealPlugin() = default;

    void render(juce::AudioBuffer<float> &buffer) {
    }

    //In case of resampling
    void render(juce::dsp::AudioBlock<float> &buffer) {
    }

private:
    JX11AudioProcessor *processor = nullptr;
};
")

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

(export CODICE-PER-FFT)
(export CODICE-PER-NON-FFT)
(export CODICE-PER-PALETTE)
