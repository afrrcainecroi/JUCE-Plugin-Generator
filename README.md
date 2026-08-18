# JUCE Plugin Generator

Generatore di plugin JUCE scritto in Guile/Scheme.

Il progetto descrive tramite una DSL Scheme:

- componenti GUI;
- parametri DAW/APVTS;
- proprietà grafiche;
- ruoli semantici;
- pipeline DSP;
- layout esplicito a griglia;
- futura risoluzione automatica del layout.

Il generatore produce un progetto JUCE completo a partire da un template separato, mantenuto nel repository `YATemplate`.

## Architettura

Il flusso generale è:

```text
SPECIFICA SCHEME
      |
      v
REGISTRAZIONE COMPONENTI
      |
      v
MODELLO INTERMEDIO
      |
      +--> GUI emitters
      +--> APVTS emitters
      +--> DSP emitters
      +--> layout data
      |
      v
YATemplate
      |
      v
PROGETTO JUCE GENERATO
```

Il generatore non deve introdurre nel progetto generato logica che può essere espressa e mantenuta nel modello o nel template.

## Repository correlato

Il generatore utilizza un template JUCE separato:

```text
YATemplate
```

Le responsabilità sono separate.

### Generator

Contiene:

- DSL Scheme;
- classi GOOPS;
- modello intermedio;
- validazione;
- naming C++;
- generazione APVTS;
- generazione GUI;
- generazione DSP;
- emissione dei blocchi C++ generati.

### YATemplate

Contiene:

- struttura base del progetto JUCE;
- `PluginProcessor`;
- `PluginEditor`;
- `KineticLookAndFeel`;
- infrastruttura DSP;
- marker per i blocchi generati;
- risorse grafiche.

I progetti plugin prodotti dal generatore sono artefatti di test/output e non costituiscono la sorgente autorevole.

## File principali

Entry point:

```text
generator.scm
```

Sorgenti principali:

```text
generator-app/code-generator.scm
generator-app/genera-classi.scm
generator-app/globals.scm
generator-app/tools.scm
```

Supporto build:

```text
generator-app/Compila.sh
generator-app/Makefile
```

I file `.go` sono bytecode compilato Guile e non fanno parte del repository.

## Modello dei componenti

I componenti grafici sono rappresentati da classi GOOPS.

Gerarchia principale:

```text
<component>
├── <label>
│   ├── <header>
│   ├── <footer>
│   ├── <link>
│   └── <palette-label>
├── <selector>
│   └── <palette-selector>
├── <button>
│   ├── <text-button>
│   └── <toggle-button>
│       ├── <normal-toggle-button>
│       └── <switch>
│           └── <bypass-switch>
├── <slider>
│   ├── <rotary-slider>
│   └── <linear-slider>
├── <meter>
└── <scope>
```

Ogni componente deriva da `<component>` e può possedere un `role` semantico indipendente dal tipo grafico.

## Role semantici

I role attualmente previsti includono:

```text
input-gain
output-gain
wet-dry
bypass
dsp-bypass
oversampling
input-meter
output-meter
scope
```

Il tipo grafico e il ruolo semantico sono concetti distinti.

Esempio:

```scheme
(make <switch>
      #:id "DSP Bypass"
      #:role 'dsp-bypass
      ...)
```

I role che rappresentano funzioni globali univoche del plugin devono essere validati per evitare duplicazioni.

La ricerca semantica dei componenti avviene tramite:

```scheme
find-component-by-role
```

## Parametri DAW/APVTS

Le famiglie di componenti parametrizzati sono gestite genericamente.

### Parametri booleani

```text
toggle-button
normal-toggle-button
switch
bypass-switch
```

### Parametri float

```text
rotary-slider
linear-slider
```

Gli helper utilizzati per classificare i componenti parametrizzati sono:

```scheme
button-parameter-type?
slider-parameter-type?
parameter-component-type?
```

Questi helper vengono usati dagli emitter:

```text
model->attachment-declaration
model->attachment-code
model->parameter-code
model->dparams-code
model->getparams-code
model->valueparams-code
model->destroy-code
```

Gli emitter generano automaticamente:

- dichiarazioni attachment;
- `AudioParameterBool`;
- `AudioParameterFloat`;
- puntatori `std::atomic<float>*`;
- caricamento dei parametri;
- valori correnti;
- distruzione attachment.

Un componente parametrizzato non deve essere gestito tramite casi speciali legati esclusivamente al suo tipo grafico concreto.

## Pipeline DSP

La pipeline DSP viene generata nel blocco:

```cpp
/// PROCESS START

...

/// PROCESS END
```

La struttura prevista è:

```text
HARD BYPASS
    |
INPUT GAIN
    |
INPUT METER
    |
DRY COPY            [wet/dry]
    |
DSP BYPASS
    |
OVERSAMPLING
    |
myplugin->render()
    |
DOWNSAMPLING
    |
WET/DRY MIX
    |
OUTPUT GAIN
    |
OUTPUT METER
    |
SCOPE
```

La funzione principale di composizione è:

```scheme
generate-process-code
```

e attualmente combina logicamente:

```text
generate-process-bypass
generate-process-input-gain
generate-process-input-meter
generate-process-dsp
generate-process-output-gain
generate-process-output-meter
generate-process-scope
```

### Hard bypass

Role:

```text
bypass
```

Semantica:

```text
OFF -> processing normale
ON  -> uscita immediata da processBlock
```

Quando il bypass totale è attivo, il buffer deve uscire invariato e l'intera pipeline deve essere saltata.

Il codice generato è concettualmente:

```cpp
if (value_Bypass >= 0.5f)
    return;
```

### DSP bypass

Role:

```text
dsp-bypass
```

Semantica:

```text
OFF -> DSP attivo
ON  -> solo il DSP centrale viene bypassato
```

Se il componente `dsp-bypass` non esiste:

```cpp
myplugin->render(buffer);
```

Se esiste:

```cpp
if (value_DSPBypass < 0.5f)
{
    myplugin->render(buffer);
}
```

Gain input/output sono espressi in dB e devono essere convertiti prima di `applyGain`:

```cpp
juce::Decibels::decibelsToGain(value_inputGain)
juce::Decibels::decibelsToGain(value_outputGain)
```

Il processor non deve dipendere da componenti GUI come `KineticMeter`.

Meter e scope devono usare dati realtime-safe esposti dal processor, ad esempio atomiche o FIFO.

## Wet/Dry

Il role previsto è:

```text
wet-dry
```

La generazione Wet/Dry verrà inserita nel blocco DSP centrale.

La futura struttura sarà:

```text
copy dry buffer
      |
DSP
      |
wet result
      |
mix dry/wet
```

La copia del buffer dry non deve causare allocazioni dinamiche dentro `processBlock()`.

Gli eventuali buffer necessari devono essere dichiarati e preparati fuori dal realtime path.

## Oversampling

Il role previsto è:

```text
oversampling
```

L'oversampling farà parte del blocco DSP centrale e richiederà generazione anche per:

- dichiarazioni;
- inizializzazione;
- `prepareToPlay`;
- eventuale reset;
- upsampling;
- processing;
- downsampling.

Non deve essere implementato come semplice frammento isolato inserito casualmente nella pipeline.

## GUI bypass feedback

Il feedback grafico generato viene inserito nel blocco:

```cpp
/// PAINT_OVER_CHILDREN START

...

/// PAINT_OVER_CHILDREN END
```

### Hard bypass

Quando `role = bypass` è attivo:

- viene applicato un overlay scuro;
- viene visualizzata la scritta `BYPASSED`;
- gli altri componenti GUI vengono disabilitati;
- il bypass stesso resta utilizzabile.

### DSP bypass

Quando `role = dsp-bypass` è attivo:

- il plugin rimane utilizzabile;
- non viene oscurata l'intera GUI;
- viene mostrato un feedback grafico distinto, ad esempio `DSP BYPASSED`.

Hard bypass e DSP bypass non devono avere lo stesso comportamento grafico.

Il bypass totale ha priorità rispetto al DSP bypass.

## Properties GUI

Le properties fanno parte della DSL e devono essere rispettate dal `KineticLookAndFeel`.

Per gli slider sono previste, tra le altre:

```text
title
value-type
suffix
show-value
show-ticks
show-labels
tick-count
tick-mode
tick-labels
```

Nel modello Scheme vengono trasformate in properties C++ da:

```scheme
slider-kinetic-properties->cpp
```

che genera properties come:

```cpp
slider.getProperties().set("title", ...);
slider.getProperties().set("valueType", ...);
slider.getProperties().set("suffix", ...);
slider.getProperties().set("showValue", ...);
slider.getProperties().set("showTicks", ...);
slider.getProperties().set("showLabels", ...);
slider.getProperties().set("tickCount", ...);
slider.getProperties().set("tickMode", ...);
slider.getProperties().set("tickLabels", ...);
```

Queste properties non devono essere eliminate, duplicate o sostituite con comportamenti hardcoded nel generatore.

Il `KineticLookAndFeel` è responsabile della loro interpretazione grafica.

## Formattazione valori slider

`KineticLookAndFeel::formatMetric()` centralizza la formattazione dei valori.

Sono attualmente gestiti almeno:

```text
gain
freq
hz
default
```

Esempi attesi:

```text
13230 Hz  -> 13.2k
1000 Hz   -> 1k
0 dB      -> 0.0
3.5 dB    -> +3.5
-60 dB    -> -inf
```

Il `suffix` viene aggiunto successivamente quando necessario.

Esempi:

```text
13.2k + " Hz" -> 13.2k Hz
0.0   + " dB" -> 0.0 dB
```

I tick utilizzano anch'essi `formatMetric()`.

La visualizzazione dei valori deve quindi essere coerente tra:

- rotary slider;
- linear slider;
- tick labels numeriche.

## JUCE Slider TextBox

Il valore viene disegnato direttamente dal `KineticLookAndFeel`.

Il TextBox standard di `juce::Slider` non deve quindi essere visibile.

Il generatore deve produrre:

```cpp
slider.setTextBoxStyle(
    juce::Slider::NoTextBox,
    false,
    0,
    0);
```

per rotary e linear slider.

Questo evita che il TextBox JUCE mostri valori grezzi come:

```text
13230.100585...
0.000000...
```

sovrapponendoli alla rappresentazione prodotta dal `KineticLookAndFeel`.

La disabilitazione del TextBox non sostituisce la gestione delle properties.

Le properties:

```text
valueType
suffix
showValue
showTicks
showLabels
tickCount
tickMode
tickLabels
```

restano parte fondamentale della DSL grafica.

## Layout

Per ora il layout viene specificato direttamente tramite:

```text
row
col
row-span
col-span
margin-tb
margin-lr
```

Il layout solver automatico esiste come prototipo ma verrà integrato successivamente.

L'architettura futura prevista è:

```text
DSL layout constraints
        |
        v
normalize
        |
        v
semantic layout solver
        |
        v
positioned model
        |
        v
row / col / span
        |
        v
C++ / JSON emitter
```

Il C++ finale non deve contenere l'algoritmo di layout automatico.

La chiave JSON corrente per il numero di colonne è:

```text
cols
```

e non:

```text
columns
```

## Grid debug

La visualizzazione della griglia è una funzionalità di debug della GUI.

Non rappresenta un role semantico del plugin.

Non deve quindi esistere un role come:

```text
grid-onoff
```

La funzione di debug può restare statica nel template e può essere condizionata da una define di compilazione, ad esempio:

```cpp
#if JUCE_DEBUG
    drawDebugGrid(g);
#endif
```

## Marker generati

I marker canonici sono:

```cpp
/// INTERFACE START
/// INTERFACE END

/// VALUEPARAMS START
/// VALUEPARAMS END

/// PROCESS START
/// PROCESS END

/// PAINT_OVER_CHILDREN START
/// PAINT_OVER_CHILDREN END
```

I marker emessi non devono contenere `*`.

Forme errate come:

```cpp
///*INTERFACE START
```

non devono essere generate.

La regex utilizzata per individuare un marker e la stringa letterale emessa nel file devono essere considerate due concetti distinti.

## UUID / VST3 CID

Il UUID/CID del plugin deve rimanere stabile quando viene rigenerato lo stesso progetto.

Un nuovo UUID deve essere creato solo per un progetto realmente nuovo.

Rigenerare un plugin esistente non deve modificarne automaticamente l'identità VST3.

La cancellazione della directory del progetto generato non implica necessariamente che si tratti di un nuovo plugin.

La persistenza del UUID/CID deve essere gestita dal generatore.

## KineticLookAndFeel

`KineticLookAndFeel` appartiene al repository `YATemplate`.

Gestisce tra le altre cose:

- palette;
- rotary slider;
- linear slider;
- meter;
- scope;
- toggle/switch;
- formattazione metrica;
- ticks;
- labels;
- feedback grafici.

La logica grafica generica deve essere mantenuta nel template.

Il Generator deve limitarsi a descrivere i componenti e ad emettere configurazioni/properties appropriate.

## Palette

Il sistema prevede palette selezionabili tramite componenti GUI.

La palette selezionata deve essere coerente tra:

- testo mostrato nel selector;
- stato del selector;
- palette realmente applicata dal `KineticLookAndFeel`.

L'inizializzazione del valore del selector non deve limitarsi a modificare il testo senza applicare effettivamente la palette corrispondente.

Questo punto è ancora da verificare/completare.

## Meter

I meter utilizzano role semantici:

```text
input-meter
output-meter
```

Il processor deve calcolare i livelli senza dipendere dal componente grafico.

Il peak dovrebbe tenere conto di tutti i canali disponibili, non soltanto del channel 0.

Esempio concettuale:

```cpp
float peak = 0.0f;

for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
{
    peak = juce::jmax(
        peak,
        buffer.getMagnitude(
            ch,
            0,
            buffer.getNumSamples()));
}
```

Il valore deve essere trasferito verso l'Editor tramite strutture realtime-safe.

## Scope

Il role semantico è:

```text
scope
```

Il processor può alimentare una FIFO o struttura equivalente.

La GUI legge i dati senza introdurre dipendenze realtime verso componenti grafici.

L'implementazione attuale può utilizzare il channel 0 come prima versione, ma l'architettura deve consentire evoluzioni future.

## Modello intermedio

La specifica Scheme non deve essere usata direttamente dagli emitter in modo disordinato.

Il flusso è:

```text
component object
      |
      v
component->model
      |
      v
registered model
      |
      v
emitters
```

Il metodo base:

```scheme
component->model
```

gestisce le proprietà comuni, tra cui:

```text
id
type
role
row
col
rowSpan
colSpan
margin-tb
margin-lr
```

I metodi specializzati aggiungono le proprietà specifiche tramite:

```scheme
(next-method)
```

La registrazione assegna anche un identificatore C++ stabile attraverso:

```scheme
allocate-cpp-identifier!
```

La relazione tra logical id e C++ id è mantenuta separata.

## Naming C++

La DSL usa logical ID leggibili.

Il generatore deve trasformarli in identificatori C++ validi.

Funzioni rilevanti:

```scheme
reset-cpp-identifiers!
allocate-cpp-identifier!
logical-id->cpp-id
```

Collisioni tra identificatori C++ devono essere risolte automaticamente.

Duplicazioni di logical ID devono invece generare errore.

Le relazioni semantiche future del layout dovranno usare logical ID e non identificatori C++.

## Metodo di sviluppo

Procedere per modifiche incrementali.

Workflow:

1. definire il comportamento;
2. modificare il Generator o YATemplate;
3. rigenerare il plugin;
4. compilare;
5. testare;
6. approvare;
7. eseguire commit Git.

Non procedere con molte modifiche indipendenti contemporaneamente.

Una funzionalità deve essere verificata prima di passare alla successiva.

Il codice generato non deve essere corretto manualmente se la modifica appartiene al Generator o al Template.

## Git

Il progetto usa due repository distinti:

```text
Generator
YATemplate
```

### Generator repository

Contiene esclusivamente i sorgenti del generatore e la documentazione.

I file `.go` compilati da Guile non vengono versionati.

### YATemplate repository

Contiene esclusivamente il template JUCE necessario alla generazione.

I progetti JUCE generati non costituiscono repository sorgente autorevoli.

## Strategia .gitignore

Entrambi i repository usano una strategia whitelist.

Concettualmente:

```gitignore
*
!.gitignore
!README.md
...
```

Vengono dichiarati esplicitamente i file che appartengono al progetto.

Questo è preferito rispetto a una blacklist, poiché le directory di sviluppo contengono numerosi:

- backup;
- build;
- file generati;
- esperimenti;
- vecchie versioni;
- file temporanei;
- progetti JUCE di test.

## Stato del progetto

Lo stato architetturale corrente è descritto in:

```text
PROJECT_STATE.md
```

Le attività immediate sono descritte in:

```text
NEXT.md
```

`README.md` descrive l'architettura generale relativamente stabile.

`PROJECT_STATE.md` descrive lo stato corrente dell'implementazione.

`NEXT.md` descrive il punto preciso da cui riprendere lo sviluppo.

## Stato DSP corrente

Sono già stati introdotti o impostati:

```text
hard bypass
input gain
input meter
DSP bypass
output gain
output meter
scope
```

La gestione APVTS è stata generalizzata per slider e toggle parametrizzati.

Le prossime funzionalità DSP previste sono:

```text
wet-dry
oversampling
```

## Attività immediate

La sequenza attuale prevista è:

```text
1. verificare NoTextBox per tutti gli slider
2. completare feedback grafico hard bypass
3. completare feedback grafico DSP bypass
4. verificare tutte le properties slider
5. generare wet/dry
6. generare oversampling
7. integrare successivamente il layout solver automatico
```

Sono volutamente rimandati:

```text
layout automatico
rifinitura grafica meter
sincronizzazione iniziale palette
ulteriori ottimizzazioni grafiche
```

## Principio fondamentale

Il Generator descrive **cosa** rappresenta un componente.

YATemplate e `KineticLookAndFeel` definiscono **come** quel componente viene implementato e rappresentato graficamente.

Il `role` descrive **che funzione semantica** svolge il componente nel plugin.

Questi tre livelli devono restare distinti:

```text
TYPE      -> natura grafica / tecnica del componente
ROLE      -> significato semantico nell'applicazione
PROPERTY  -> configurazione del comportamento/aspetto
```

Esempio:

```scheme
(make <linear-slider>
      #:id "Output Gain"
      #:role 'output-gain
      #:value-type 'gain
      #:suffix " dB"
      ...)
```

dove:

```text
linear-slider -> TYPE
output-gain   -> ROLE
gain / dB     -> PROPERTIES
```

Questa separazione è parte dell'architettura del progetto e deve essere preservata nelle modifiche future.
