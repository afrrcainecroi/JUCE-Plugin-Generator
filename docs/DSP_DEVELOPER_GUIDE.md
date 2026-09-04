# JUCE Plugin Generator — DSP Developer Guide

## 1. Purpose

This is the normative Release 1.0 manual for implementing an effect’s time-domain and spectral algorithm in a project created by JUCE-Plugin-Generator.

It defines:

- file ownership and regeneration boundaries;
- the exact `RealPlugin` and `FFTProcessor` APIs;
- preparation, processing, reset, and latency contracts;
- parameter and host-transport access;
- generator-managed FFT, oversampling, wet/dry, bypass, meters, scope, and fixed timing;
- mandatory realtime rules.

The Scheme DSL is documented in `DSL_REFERENCE.md`. Frozen architecture decisions are in `ARCHITECTURE_DECISIONS.md`. Frozen `YAEnhancerR1`, post-freeze `YASaturatorR1`, and historical pppbuttavia are generated evidence, not generator authority.

## 2. DSP ownership model

### Generator-owned

The generator owns:

- Scheme DSL registration and validation;
- APVTS parameter declarations and per-block value loading;
- generated `processBlock` orchestration;
- input/output gain;
- hard bypass and DSP bypass;
- meter and scope resources/taps;
- FFT/STFT and oversampling infrastructure;
- wet/dry and fixed-latency buffers;
- content between generated START/END markers.

The primary source is `generator-app/dsp-generation.scm`, with parameter code in `generator-app/cpp-generation.scm` and orchestration in `generator.scm`.

Do not edit generated `PluginProcessor.cpp`, `PluginProcessor.h`, `MyPlugin.cpp`, or `MyPlugin.h` to change these behaviours. Regeneration replaces their marked regions.

### YATemplate-owned generic infrastructure

`YATemplate/Source` supplies the project skeleton and generic infrastructure, including:

- `PluginProcessor.h/.cpp`;
- `MyPlugin.h/.cpp`;
- `Synth.h` and generated STFT insertion point;
- `KineticLookAndFeel.h/.cpp`;
- editor and support code.

For existing projects, `generator.scm:synchronize-generator-support-files` synchronizes only `Source/KineticLookAndFeel.h` and `.cpp`. It does not mirror the whole template.

### DSP-developer-owned

The explicitly developer-owned file is:

```text
YATemplate/Source/PluginDSP.h
```

For an individual generated project, edit that project’s `Source/PluginDSP.h`. For a reusable algorithm intended for future new projects, maintain the authoritative template copy deliberately.

`MakeNewProject` excludes every path ending in `/Source/PluginDSP.h` from project-name replacement, and existing-project support synchronization does not include it. No other file has the same explicit Release 1.0 developer-owned status.

The developer owns implementations inside `RealPlugin` and `FFTProcessor`, not the pipeline around them.

## 3. Generated DSP pipeline

`generator-app/dsp-generation.scm:generate-process-code` concatenates the normal path in this exact order:

```text
HOST INPUT
 -> INPUT METER
 -> HARD BYPASS decision
 -> INPUT GAIN
 -> PRE-DSP SCOPE TAP
 -> dry capture
 -> FFT processing when generated/enabled
 -> time-domain RealPlugin at selected factor
 -> wet-path fixed-latency compensation
 -> dry-path fixed-latency compensation
 -> linear wet/dry mix or DELTA (aligned wet - aligned dry)
 -> POST-DSP SCOPE TAP
 -> OUTPUT GAIN
 -> optional sample-peak SAFETY LIMITER
 -> OUTPUT METER
 -> HOST OUTPUT
```

Relevant generators are:

- `generate-process-input-meter`;
- `generate-process-bypass`;
- `generate-process-input-gain`;
- `generate-process-scope-tap`;
- `generate-process-wetdry-prefix`;
- `generate-process-dsp` and `generate-process-dsp-body`;
- `generate-process-wet-latency-code`;
- `generate-process-dry-latency-code`;
- `generate-process-wetdry-postfix`;
- `generate-process-output-gain`;
- `generate-process-safety-limiter`;
- `generate-process-output-meter`.

FFT is at host sample rate and precedes oversampling. The developer does not reproduce this orchestration in `PluginDSP.h`. Reordering stages is a generator architecture change.

## 4. Developer-owned file anatomy

`PluginDSP.h` contains:

1. forward declaration of `JX11AudioProcessor`;
2. `AudioPrepareContext`;
3. `AudioProcessContext`;
4. `FFTPrepareContext`;
5. `FFTProcessContext`;
6. developer class `RealPlugin`;
7. developer class `FFTProcessor`.

Both classes receive and retain a `JX11AudioProcessor*` in their constructors. Contexts do not contain a processor pointer.

The current file includes `<JuceHeader.h>` and `<vector>`. Add standard/JUCE includes there only when the developer implementation requires them. Do not move effect code into KineticLookAndFeel or editor code.

## 5. RealPlugin contract

Exact public API:

```cpp
explicit RealPlugin(JX11AudioProcessor* processorToUse);

void ButtonCallback(int num, juce::String name);

void prepare(const AudioPrepareContext& context);

void reset();

void processAudio(
    juce::dsp::AudioBlock<float>& block,
    const AudioProcessContext& context);

int getLatencySamples() const noexcept;
```

### Constructor

Generated `MyPlugin` creates four instances:

```cpp
realPlugin1x = std::make_unique<RealPlugin>(processor);
realPlugin2x = std::make_unique<RealPlugin>(processor);
realPlugin4x = std::make_unique<RealPlugin>(processor);
realPlugin8x = std::make_unique<RealPlugin>(processor);
```

The constructor should store the processor pointer and initialize cheap object state. Resource sizing should wait for `prepare`.

### `ButtonCallback`

`MyPlugin::ButtonCallback` forwards an event to all four instances. It is optional and currently takes the button number by value and name by value. Do not use it as a substitute for APVTS parameter polling, and do not assume it is called on the audio thread.

### `prepare`

Called once for each instance from generated `MyPlugin::prepare` after construction. Allocation and initialization are allowed. Store effective sample rate, size buffers for `maximumBlockSize`, configure coefficients, then return promptly.

The generator calls all four prepares regardless of the currently selected oversampling mode.

### `reset`

Called for all four instances at the end of generated `MyPlugin::prepare`, and again when the processor’s JUCE `reset()` is invoked. Clear histories without allocating: delay contents, filter memory, phase, envelopes, and state machines.

Changing hard/DSP bypass or oversampling selection does not itself call `reset()`.

### `processAudio`

Runs on the audio processing path for the currently selected factor. Process the supplied block in place. No allocation, locks, blocking work, UI access, or exceptions intended to escape.

### `getLatencySamples`

Called after all four instances are prepared to determine the maximum developer contribution, and per block to compute the active natural latency. It must be deterministic, non-blocking, `noexcept`, and return latency in **host samples**.

## 6. AudioPrepareContext

Exact fields:

```cpp
struct AudioPrepareContext
{
    double sampleRate = 44100.0;
    int maximumBlockSize = 0;
    int numChannels = 0;
    int oversamplingFactor = 1;
};
```

| Field | Meaning |
|---|---|
| `sampleRate` | Effective rate for this instance: host rate × factor, in Hz. |
| `maximumBlockSize` | Prepared maximum sample count for this instance: host maximum block × factor. |
| `numChannels` | Maximum of processor input/output channels, clamped to at least 1. |
| `oversamplingFactor` | Exactly 1, 2, 4, or 8 for this instance. |

Generated values:

| Instance | sample rate | maximum block | factor |
|---|---:|---:|---:|
| 1x | host rate | host max | 1 |
| 2x | host rate ×2 | host max ×2 | 2 |
| 4x | host rate ×4 | host max ×4 | 4 |
| 8x | host rate ×8 | host max ×8 | 8 |

Derive coefficients and time constants from `context.sampleRate`. Do not cache the host rate and reuse it for every factor.

## 7. AudioProcessContext and AudioBlock

Exact process context:

```cpp
struct AudioProcessContext
{
    double sampleRate = 44100.0;
    int oversamplingFactor = 1;
};
```

The generated wrapper sets `sampleRate = processor->value_info_sampleRate * factor` and selects the matching instance. It contains no block size, channel count, parameter bundle, transport data, or processor reference.

Obtain current dimensions from the block:

```cpp
const auto channels = block.getNumChannels();
const auto samples  = block.getNumSamples();
```

The exact block type is:

```cpp
juce::dsp::AudioBlock<float>&
```

It is a non-owning view of either the host `AudioBuffer<float>` at 1x or JUCE’s oversampler output at 2x/4x/8x. Process it in place through `getChannelPointer`, `getSample`/`setSample`, or bounded AudioBlock operations.

Do not resize it, retain pointers after return, or assume the same address/block length on the next callback. Mono and stereo are the officially supported Release 1.0 layouts. When the algorithm is naturally channel-independent, iterate `block.getNumChannels()` and avoid hard-coded stereo; this policy does not imply that 5.1/7.1 bus topology is implemented.

## 8. Separate oversampling state

Each factor owns a separate `RealPlugin` object. Therefore:

- state is not shared automatically;
- all four are prepared;
- only the selected instance processes a block;
- factor switching selects another already-prepared state;
- inactive state freezes until that instance is selected again;
- seamless state continuity across a factor change is not guaranteed.

If an algorithm needs continuity, design a realtime-safe cross-instance strategy explicitly. Do not introduce locks or allocation during switching.

## 9. FFTProcessor contract

Exact API:

```cpp
explicit FFTProcessor(JX11AudioProcessor* processorToUse);

void prepareFFT(const FFTPrepareContext& context);

void resetFFT();

void processFFT(
    std::vector<float>& spectrum,
    const FFTProcessContext& context);
```

FFT infrastructure is generated only when a registered component has semantic role `fft-size`.

Generated `MyPlugin` owns six separate processors:

```text
fftProcessor256
fftProcessor512
fftProcessor1024
fftProcessor2048
fftProcessor4096
fftProcessor8192
```

It also owns one `GeneratedStft` per size. Developer spectral state is therefore size-specific. It is not shared unless the developer creates an explicit safe shared mechanism.

### `prepareFFT`

Called once for each size during `MyPlugin::prepare`. Allocate masks/tables/history here. Every instance receives host sample rate and channel count.

### `resetFFT`

Called for all six instances by generated `MyPlugin::reset`. Clear spectral histories without allocating.

### `processFFT`

Called once per completed frame per channel for the selected size. Modify the supplied preallocated vector in place. It is on the audio path.

## 10. FFT contexts and representation

Exact prepare context:

```cpp
struct FFTPrepareContext
{
    int fftSize = 0;
    double sampleRate = 44100.0;
    int numChannels = 0;
};
```

Exact process context:

```cpp
struct FFTProcessContext
{
    int fftSize = 0;
    double sampleRate = 44100.0;
    int channel = 0;
};
```

`sampleRate` is always host rate because FFT precedes oversampling. `channel` is the zero-based channel currently being transformed.

`GeneratedStft` allocates `spectrum` as a vector of `2 * fftSize` floats, calls JUCE `performRealOnlyForwardTransform`, invokes `processFFT`, and then passes the same storage to `performRealOnlyInverseTransform`.

The API contract calls this JUCE’s real-FFT representation. Release 1.0 does not wrap it in a typed bin view or document a generator-specific packing. Consult the exact JUCE version’s FFT contract before indexing complex bins. Do not assume a conventional interleaved layout merely from the vector length.

## 11. FFT processing

Control mapping:

| APVTS value | Mode |
|---:|---|
| 0 | Off |
| 1 | 256 |
| 2 | 512 |
| 3 | 1024 |
| 4 | 2048 |
| 5 | 4096 |
| 6 | 8192 |

`GeneratedStft::prepare` sets `hopSize = fftSize / 2`: 50% overlap. It creates matching analysis and synthesis windows whose samples are `sqrt(Hann)`; their product is Hann for overlap-add.

Processing is causal and block-size independent:

1. for each output sample position, emit and clear the output-ring value;
2. append the current host input to the analysis FIFO;
3. after N input samples exist, transform the first N-sample frame;
4. schedule its N synthesized samples beginning at the next output position;
5. retain N−N/2 samples for the next frame.

The first processed sample cannot be scheduled until N inputs have arrived, and it begins at the next output position after those N emissions. Consequently `GeneratedStft::getLatencySamples()` correctly returns N host samples. Subsequent frames use hop N/2 without changing this causal offset.

FFT runs before `processSamplesUp`; moving it into the oversampled domain would change rate interpretation, latency, CPU cost, and the developer API.

### Conservative FFT skeleton

This is API-correct but intentionally does not guess packed-bin indexing:

```cpp
class FFTProcessor
{
public:
    explicit FFTProcessor(JX11AudioProcessor* p) : processor(p) {}

    void prepareFFT(const FFTPrepareContext& context)
    {
        preparedSize = context.fftSize;
        preparedRate = context.sampleRate;
    }

    void resetFFT() {}

    void processFFT(
        std::vector<float>& spectrum,
        const FFTProcessContext& context)
    {
        jassert(context.fftSize == preparedSize);
        jassert(spectrum.size()
                >= static_cast<std::size_t>(2 * context.fftSize));

        // Use the exact JUCE real-only FFT packing contract for the
        // repository's JUCE version before reading or changing bins.
        // No resize, push_back, allocation, or lock here.
    }

private:
    JX11AudioProcessor* processor = nullptr;
    int preparedSize = 0;
    double preparedRate = 0.0;
};
```

A fully bin-manipulating example would require asserting a JUCE-version-specific packed representation not formalized by this generator API; this manual intentionally stops at that boundary.

## 12. Oversampling

Current modes and selector values:

| Value | Mode |
|---:|---|
| 0 | Off / 1x |
| 1 | 2x |
| 2 | 4x |
| 3 | 8x |

When the oversampling role exists, `generate-oversampling-prepare-code` creates three `juce::dsp::Oversampling<float>` objects with 1, 2, and 3 stages. All use:

```cpp
juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR
isMaxQuality = false
useIntegerLatency = true
```

Release 1.0 runtime generation does not select the old FIR alternative.

For 2x/4x/8x:

```text
host AudioBlock
 -> selected oversampler.processSamplesUp
 -> factor-specific RealPlugin::processAudio
 -> selected oversampler.processSamplesDown
 -> host-rate AudioBlock
```

At 1x, the host buffer is wrapped directly and sent to `realPlugin1x`.

JUCE reports each oversampler’s host-domain latency through `getLatencyInSamples()`. Generation rounds the active contribution with `juce::roundToInt`; maximum fixed latency uses the rounded 8x value.

## 13. Parameter access

The generated path is:

```text
DSL binding
 -> APVTS AudioParameterFloat/Bool/Choice
 -> parameters.getRawParameterValue(parameter-id)
 -> std::atomic<float>* param_<processor-reference>
 -> value_<processor-reference> = param_->load() once per processBlock
 -> public processor cached field
 -> developer reads processor->value_<processor-reference>
```

Relevant functions:

- `model->parameter-code`;
- `model->getparams-code`;
- `model->valueparams-code`;
- `model->dparams-code`.

Example DSL:

```scheme
(make <rotary-slider>
  #:id 'reverb-depth
  #:parameter-id "reverbDepth"
  #:parameter-name "Reverb Depth"
  #:processor-reference "reverbDepth"
  #:min 0.0 #:max 1.0 #:default 0.35)
```

Developer access inside `RealPlugin`:

```cpp
const float depth = processor->value_reverbDepth;
```

The processor pointer is the constructor-stored member; it is not in either context. Values are cached once near the start of each host `processBlock`, before generated DSP stages.

Custom parameters such as reverb depth and persistence are ordinary bound slider/selector parameters. They do not require new semantic roles.

This is coupling by generated field names, not a typed DSP parameter registry. Keep `#:processor-reference` C++-identifier-compatible and verify the generated name.

## 14. Host transport access

`PluginProcessor.h` exposes these current public runtime fields:

| Field | Type/meaning |
|---|---|
| `value_info_BPM` | `juce::Optional<double>`, beats per minute; initialized to 120 before first host update |
| `value_info_timeInSeconds` | optional elapsed seconds |
| `value_info_ppqPosition` | optional pulses/quarter-note position |
| `value_info_isPlaying` | bool from host position |
| `value_info_timeInSamples` | `juce::Optional<long int>`, sample position |
| `value_info_timeSignature` | optional `AudioPlayHead::TimeSignature` |
| `value_info_loopPoints` | optional `AudioPlayHead::LoopPoints` |
| `value_info_barCount` | optional `int64_t` |
| `value_info_ppqPositionOfLastBarStart` | optional PPQ |
| `value_info_frameRate` | optional `AudioPlayHead::FrameRate` |
| `value_info_editOriginTime` | optional seconds |
| `value_info_hostTimeNs` | optional nanoseconds |
| `value_info_isRecording` | bool from host position |
| `value_info_isLooping` | bool from host position |
| `value_info_totalNumInputChannels` | current buffer channel count |
| `value_info_totalNumOutputChannels` | processor output count |
| `value_info_sampleRate` | current host rate, float |
| `value_info_inverseSampleRate` | reciprocal host rate |
| `value_info_max_samplesPerBlock` | prepared maximum initially; overwritten in each block with current block sample count |

At each process block, `PluginProcessor.cpp` asks `getPlayHead()->getPosition()` and copies fields when position exists. Hosts may omit any optional value.

Caveat: `isPlaying`, `isRecording`, and `isLooping` are plain booleans and the current header provides no separate “position valid” flag. They are assigned only when a playhead position is returned. Do not assume their value is meaningful before a successful host update. Optional fields must be tested before dereference.

Developer access uses the stored processor pointer, for example:

```cpp
double bpm = 120.0;
if (processor->value_info_BPM)
    bpm = *processor->value_info_BPM;
```

There is no transport context object or transport-aware parameter DSL in Release 1.0.

## 15. Tempo-synchronised DSP

A GUI choice parameter can represent `1/2`, `1/4`, `3/4`, and `5/8`, but the generator does not interpret it musically. The developer must map the cached APVTS choice value and host BPM.

For fraction n/d of a whole note:

```text
quarterNoteSeconds = 60 / BPM
wholeNoteSeconds   = 4 * quarterNoteSeconds
durationSeconds    = (n / d) * wholeNoteSeconds
```

Inside a particular `RealPlugin`:

```text
durationSamples = durationSeconds * context.sampleRate
```

Use the effective context rate because the algorithm processes samples at 1x/2x/4x/8x. For the same physical duration, an 8x instance needs eight times the internal sample count.

Source-consistent mapping:

```cpp
static std::pair<int, int> subdivision(int choice) noexcept
{
    switch (choice)
    {
        case 0: return { 1, 2 };
        case 1: return { 1, 4 };
        case 2: return { 3, 4 };
        case 3: return { 5, 8 };
        default: return { 1, 4 };
    }
}

double durationSamples(int choice, double bpm, double effectiveRate)
{
    const auto [n, d] = subdivision(choice);
    const double wholeSeconds = 4.0 * 60.0 / juce::jmax(1.0, bpm);
    return (static_cast<double>(n) / d)
         * wholeSeconds
         * effectiveRate;
}
```

BPM alone is enough for note-value duration. Bar-relative behavior may also require time signature, PPQ, and last-bar information, all of which can be absent.

Do not resize a delay buffer when BPM changes. Allocate a maximum in `prepare`, then smoothly move/interpolate the read position during processing.

## 16. Wet/dry

Wet/dry is generator-managed:

1. `generate-process-wetdry-prefix` copies the post-input-gain/pre-DSP buffer into preallocated `dryBuffer`;
2. DSP produces the wet path in `buffer`;
3. fixed timing aligns wet and dry when FFT/oversampling infrastructure exists;
4. `generate-process-wetdry-postfix` normalizes the parameter to 0..1 and performs:

```text
output = wet * wetMix + dry * (1 - wetMix)
```

This is a linear law, not equal-power mixing.

Developer `RealPlugin` normally processes only the wet path. Do not add another generic wet/dry stage unless the effect algorithm specifically needs an internal blend distinct from the plugin’s role-driven wet/dry control.

Under DSP bypass, central FFT/oversampling/RealPlugin execution is skipped. The pre-DSP buffer continues through generator timing and wet/dry; actual DSP latency is forced to zero and padded to the fixed maximum.

### Delta, Auto Gain, and Safety Limiter

When `delta-monitor` exists, the generator captures the same dry reference used by Wet/Dry. Delta ON produces aligned wet minus aligned dry and ignores the Wet/Dry amount; Delta OFF uses the normal mix.

Auto Gain is a standard-shell-placed plugin-defined parameter. Its current compensation law is implemented in the reference plugins' `PluginDSP.h`, not in `dsp-generation.scm`; do not assume a universal generator formula.

Safety Limiter is generator-owned optional final protection after Output Gain and before Output Meter. It defaults OFF. CEILING is `-6.0 .. 0.0 dB`, default `-0.5 dB`, step `0.1 dB`; release is fixed internally at 100 ms. The generator normalizes JUCE Limiter's internal threshold/makeup behavior so final sample peak follows CEILING. This is sample-peak limiting, not True Peak.

## 17. Fixed latency contract

For every generated plugin, `generate-latency-prepare-code` computes:

```text
maximum latency
  = maximum FFT contribution
  + maximum oversampling contribution
  + maximum developer contribution
```

Current terms:

```text
maximum FFT             = 8192 host samples when fft-size role exists
maximum oversampling    = round(oversampling8x.getLatencyInSamples())
maximum developer       = max(getLatencySamples() from 1x, 2x, 4x, 8x)
```

During `prepareToPlay` the processor:

- allocates wet/dry delay buffers of maximum + host block + 1;
- clears them and resets write positions;
- calls `setLatencySamples(generatedMaximumLatencySamples)` once.

At runtime it computes actual selected FFT + selected oversampler + selected developer latency, then delays wet by `maximum - actual`. If wet/dry exists, dry is delayed by the full maximum. Under DSP bypass, actual central DSP latency is zero, so wet is padded by the full maximum. Hard bypass uses the dry delay buffer to return host input delayed by the maximum.

Runtime parameter changes do not change host-reported latency.

### Developer latency units

`RealPlugin::getLatencySamples()` must return **host samples for every factor-specific instance**. The generator adds the value directly to host-rate FFT and JUCE oversampler latency and compares it against one global host-rate maximum; it does not divide by factor.

Example:

```text
algorithm delay inside 8x instance = 800 oversampled samples
reported developer latency         = 800 / 8 = 100 host samples
```

For a non-divisible internal delay, choose a design whose host latency is unambiguous and consistent with actual signal timing. Underreporting makes fixed padding too short and breaks wet/dry/host alignment. Overreporting adds unnecessary delay and may also misstate active natural latency. Negative values are invalid by contract even though the current method return type is plain `int`.

Do not add a second manual compensation delay inside `RealPlugin` for latency already handled by the generator.

## 18. Bypass semantics

### Hard bypass

After the input meter, hard bypass:

- skips input gain;
- skips PRE and POST scope taps;
- skips dry capture, FFT, oversampling, `RealPlugin`, wet/dry/Delta, output gain, and Safety Limiter;
- preserves the fixed host delay when FFT/oversampling infrastructure requires it;
- updates output meter from the actual returned buffer;
- returns.

Developer DSP state is untouched for that block. Scope intentionally freezes its last snapshot. Toggling bypass does not call developer `reset()`.

### DSP bypass

DSP bypass occurs inside the normal chain:

- input gain and PRE scope remain active;
- FFT is skipped;
- oversampling up/down is skipped;
- `RealPlugin::processAudio` is skipped;
- actual central DSP latency becomes zero and the wet path is padded to maximum;
- dry latency and linear wet/dry remain active;
- POST scope, output gain, and output meter remain active.
- Safety Limiter remains active when declared and enabled.

No `reset()` call is generated merely because DSP bypass changes. When processing resumes, each developer object continues from its retained state.

## 19. Meter and scope observation

| Observer | Exact point |
|---|---|
| input meter | host input before input gain |
| PRE scope | after input gain, before dry copy and DSP |
| POST scope | after DSP, fixed latency, and wet/dry; before output gain |
| output meter | after output gain and optional Safety Limiter, on final host-bound signal |

Consequences:

- input gain changes PRE and POST scope traces;
- developer DSP changes the PRE/POST relationship;
- output gain changes output meter but neither scope trace;
- hard bypass keeps both I/O meters meaningful but freezes scope;
- DSP bypass keeps PRE/POST observations active.

Do not write UI components from DSP. Generator resources use atomics/preallocated FIFOs and editor-side consumption.

## 20. Realtime safety

Inside `processAudio` and `processFFT`, never perform:

- `new`, `malloc`, or implicit heap allocation;
- `std::vector::resize`, `push_back`, or dynamic container growth;
- mutex locking;
- filesystem access;
- potentially blocking logging;
- UI calls;
- sleeps/waits;
- network access;
- plugin/host scans;
- per-block object construction/destruction with allocation;
- resource preparation.

Allowed operations include:

- stack scalars and small fixed objects;
- arithmetic;
- access to preallocated arrays/vectors;
- in-place AudioBlock operations;
- bounded state updates;
- lock-free/atomic reads where the architecture provides them.

Allocation and coefficient/table construction belong in `prepare` or `prepareFFT`.

`processAudio` and `processFFT` execute on the processor’s audio path. JUCE lifecycle calls such as prepare/reset normally occur outside active block processing, but do not assume more threading guarantees than JUCE’s host contract. Shared state visible to UI/other threads requires explicit realtime-safe synchronization.

## 21. Reset and release lifecycle

Sequence during preparation:

```text
PluginProcessor::prepareToPlay
 -> construct MyPlugin
 -> construct 4 RealPlugin and optionally 6 FFTProcessor objects
 -> MyPlugin::prepare
    -> prepare all RealPlugin instances
    -> prepare all GeneratedStft and FFTProcessor instances
    -> MyPlugin::reset
 -> construct/reset oversamplers
 -> compute/allocate fixed latency
```

`MyPlugin::reset` calls all four `RealPlugin::reset`, all six STFT resets, and all six `FFTProcessor::resetFFT` when FFT exists.

`PluginProcessor::reset` forwards to `MyPlugin::reset`. Program changes call processor reset. `releaseResources` destroys `MyPlugin` and resets generated oversampling objects.

There is no `RealPlugin::release` or `FFTProcessor::releaseFFT` API in Release 1.0. Destructors/member destructors release developer resources when `MyPlugin` is destroyed.

## 22. Minimal RealPlugin example

A bounded soft saturator teaching example:

```cpp
class RealPlugin
{
public:
    explicit RealPlugin(JX11AudioProcessor* p) : processor(p) {}

    void ButtonCallback(int, juce::String) {}

    void prepare(const AudioPrepareContext& context)
    {
        sampleRate = context.sampleRate;
    }

    void reset() {}

    void processAudio(
        juce::dsp::AudioBlock<float>& block,
        const AudioProcessContext& context)
    {
        jassert(context.sampleRate == sampleRate);

        for (std::size_t ch = 0; ch < block.getNumChannels(); ++ch)
        {
            auto* samples = block.getChannelPointer(ch);
            for (std::size_t i = 0; i < block.getNumSamples(); ++i)
                samples[i] = std::tanh(samples[i]);
        }
    }

    int getLatencySamples() const noexcept { return 0; }

private:
    JX11AudioProcessor* processor = nullptr;
    double sampleRate = 44100.0;
};
```

This is an effect algorithm, not a replacement for generator-owned input/output gain.

## 23. Stateful example: one-pole low-pass

```cpp
class RealPlugin
{
public:
    explicit RealPlugin(JX11AudioProcessor* p) : processor(p) {}

    void ButtonCallback(int, juce::String) {}

    void prepare(const AudioPrepareContext& context)
    {
        sampleRate = context.sampleRate;
        states.assign(static_cast<std::size_t>(context.numChannels), 0.0f);
        updateCoefficient(1000.0f);
    }

    void reset()
    {
        std::fill(states.begin(), states.end(), 0.0f);
    }

    void processAudio(
        juce::dsp::AudioBlock<float>& block,
        const AudioProcessContext&)
    {
        const auto channels = juce::jmin(
            block.getNumChannels(), states.size());

        for (std::size_t ch = 0; ch < channels; ++ch)
        {
            auto* x = block.getChannelPointer(ch);
            float z = states[ch];

            for (std::size_t i = 0; i < block.getNumSamples(); ++i)
            {
                z += coefficient * (x[i] - z);
                x[i] = z;
            }

            states[ch] = z;
        }
    }

    int getLatencySamples() const noexcept { return 0; }

private:
    void updateCoefficient(float cutoff)
    {
        coefficient = 1.0f
            - std::exp(-2.0f * juce::MathConstants<float>::pi
                       * cutoff / static_cast<float>(sampleRate));
    }

    JX11AudioProcessor* processor = nullptr;
    std::vector<float> states;
    double sampleRate = 44100.0;
    float coefficient = 0.0f;
};
```

Vector allocation occurs only in `prepare`; process updates fixed storage. Each factor derives a different correct coefficient from its effective rate.

## 24. Reverb-style parameter example

DSL parameters `reverb-depth` and `reverb-persistence` remain ordinary APVTS sliders with processor references such as `reverbDepth` and `reverbPersistence`. No roles with those names are needed.

Inside `processAudio`:

```cpp
const float targetDepth = juce::jlimit(
    0.0f, 1.0f, processor->value_reverbDepth);

const float targetPersistence = juce::jlimit(
    0.0f, 1.0f, processor->value_reverbPersistence);

// Smooth these values using preallocated/per-instance state.
// Map depth to internal diffusion/modulation and persistence to
// feedback/decay. Process the supplied wet block in place.
```

A safe skeleton allocates delay lines and diffusion buffers in `prepare`, clears them in `reset`, smooths cached targets per sample/block, and processes without resizing. The generator supplies outer wet/dry; do not duplicate it merely because the effect is a reverb.

## 25. Tempo-sync delay/reverb skeleton

Preparation:

```cpp
void prepare(const AudioPrepareContext& context)
{
    sampleRate = context.sampleRate;
    const double maximumSeconds = 8.0;
    delay.assign(
        static_cast<std::size_t>(maximumSeconds * sampleRate) + 1,
        0.0f);
    writeIndex = 0;
    smoothedDelaySamples = sampleRate * 0.5;
}
```

Per block, read BPM and subdivision choice, then calculate a target in effective samples:

```cpp
double bpm = 120.0;
if (processor->value_info_BPM)
    bpm = juce::jmax(1.0, *processor->value_info_BPM);

const int choice =
    static_cast<int>(processor->value_tempoSubdivision);

const auto [n, d] = subdivision(choice);
const double target =
    (static_cast<double>(n) / d)
    * (4.0 * 60.0 / bpm)
    * sampleRate;
```

Clamp target to the preallocated delay capacity. Smooth/interpolate `smoothedDelaySamples` and use a fractional read to avoid clicks/pitch discontinuities. Do not allocate a replacement buffer when BPM changes.

Choice meanings:

| Choice | n/d whole note |
|---:|---:|
| 0 | 1/2 |
| 1 | 1/4 |
| 2 | 3/4 |
| 3 | 5/8 |

This behavior is developer code. Release 1.0 does not generate tempo synchronization from selector labels.

## 26. Latency-producing example

For a fixed internal delay, allocate by effective samples but report host samples:

```cpp
void prepare(const AudioPrepareContext& context)
{
    factor = context.oversamplingFactor;
    hostLatency = 100;
    internalDelay = hostLatency * factor;

    delay.assign(
        static_cast<std::size_t>(internalDelay + 1)
        * static_cast<std::size_t>(context.numChannels),
        0.0f);
    // Initialize fixed indices here.
}

int getLatencySamples() const noexcept
{
    return hostLatency;
}
```

At 8x this processes an 800-internal-sample delay and reports 100 host samples. The process loop must use the preallocated channel storage and fixed indices. Because every factor reports the same physical delay, switching does not change the developer contribution, although state continuity remains separate.

If an algorithm has factor-dependent physical latency, each instance may report a different host-sample value; fixed maximum uses the largest and active padding uses the selected one.

## 27. Oversampling-safe design checklist

- Use `AudioPrepareContext::sampleRate`, not processor host rate, for coefficients.
- Size per-instance buffers using effective `maximumBlockSize`.
- Expect four independent object states.
- Expect only the selected state to advance.
- Convert internal oversampled latency to host samples.
- Avoid cross-instance raw buffer pointers.
- If parameters change, read cached processor values and smooth locally.
- Do not call oversampler APIs from `RealPlugin`; the generator owns them.

## 28. Common mistakes

| Mistake | Correct approach |
|---|---|
| Editing generated `processBlock` | Change generator architecture only when explicitly authorized; effect DSP belongs in `PluginDSP.h`. |
| Editing generated pppbuttavia as authority | Treat it as output/evidence; edit its developer-owned PluginDSP only for that project. |
| Putting DSP in KineticLookAndFeel | LookAndFeel is generic rendering; use RealPlugin/FFTProcessor. |
| Allocating/resizing in process | Preallocate in prepare/prepareFFT. |
| Using host sample rate at every factor | Use context effective sample rate. |
| Reporting oversampled latency | Divide internal delay by factor and report host samples. |
| Adding a second generic wet/dry | Let generator infrastructure mix unless algorithm requires a distinct internal blend. |
| Compensating fixed latency twice | Report natural latency; generator performs external padding. |
| Assuming FFT follows oversampling | FFT is host-rate and precedes oversampling. |
| Assuming one RealPlugin | There are four independent instances. |
| Assuming one FFTProcessor | There are six size-specific instances. |
| Assuming BPM sync is automatic | Map APVTS choice + optional host BPM in developer DSP. |
| Accessing GUI controls from DSP | Read cached processor fields; never touch UI on audio thread. |
| Assuming parameter field spelling | Verify `#:processor-reference` and generated `value_<reference>`. |
| Resetting on bypass assumptions | Bypass changes do not call reset. |
| Dereferencing optional transport blindly | Test optional presence and provide a safe fallback. |
| Assuming area/scope resources are DSP APIs | Scope/meters are generator-managed observation resources. |

## 29. LLM DSP-development rules

```text
- Modify PluginDSP.h for the effect algorithm, not generated processBlock.
- Preserve exact RealPlugin and FFTProcessor signatures.
- Allocate and prepare resources only in prepare/prepareFFT.
- Keep processAudio/processFFT bounded, non-blocking, allocation-free, and lock-free.
- Process the supplied AudioBlock/spectrum in place.
- Read generated parameters through processor->value_<processor-reference>.
- Derive coefficients and internal time from the provided effective sample rate.
- Report RealPlugin latency in host samples.
- Do not alter or duplicate generator fixed-latency compensation.
- FFT runs at host rate before oversampling.
- Four oversampling factors use separate RealPlugin state.
- Six FFT sizes use separate FFTProcessor state.
- Custom effect parameters normally need no new ROLE.
- Implement BPM/subdivision interpretation explicitly in DSP.
- Treat transport fields as host-dependent and optionals as optional.
- Never access UI components from the audio thread.
- Treat YAEnhancerR1 as the frozen reference; do not edit it except for a demonstrated bug.
- Treat YASaturatorR1 and historical pppbuttavia as evidence, not generator authority.
- Prefer N-channel loops for naturally channel-independent DSP; official Release 1.0 support remains mono/stereo.
```

## 30. Release 1.0 limitations

- Developer parameter access is coupled through generated processor field names, not a strongly typed DSP parameter API.
- Generic tempo-sync/subdivision semantics are absent.
- State continuity across oversampling-factor switches is not guaranteed.
- FFT sizes and host-rate-before-oversampling stage order are fixed.
- The FFT callback exposes JUCE’s real-FFT vector without a generator-specific typed bin abstraction.
- Custom routing graphs are not exposed.
- Only the documented fixed-maximum latency contract is supported.
- Developer latency activates the same fixed host-reporting and compensation contract whether or not FFT or oversampling controls exist. Delay buffers allocate during prepare only when the computed maximum is greater than zero.
- Transport availability depends on the host.
- Plain playing/recording/looping booleans lack a separate validity flag when no host position has been received.
- There is no explicit developer release method; destruction releases resources.
- Current wet/dry uses a linear law.

## 31. Authoritative source and verification map

- `YATemplate/Source/PluginDSP.h`: exact contexts and developer APIs.
- `generator-app/dsp-generation.scm:generate-process-code`: pipeline order.
- `generate-process-dsp-body`: FFT-before-oversampling and factor mapping.
- `generate-myplugin-audio-init-code`, `generate-myplugin-prepare-code`, `generate-myplugin-reset-code`: instance lifecycle.
- `generate-fft-infrastructure-code`: STFT buffers, windows, hop, callback, and N-sample latency.
- `generate-myplugin-fft-members-code`: six size-specific resources.
- `generate-oversampling-prepare-code`: current JUCE oversampler configuration.
- `generate-latency-prepare-code`, `generate-process-wet-latency-code`, `generate-process-dry-latency-code`: fixed timing.
- `generator-app/cpp-generation.scm`: APVTS fields and per-block access code.
- `YATemplate/Source/PluginProcessor.h/.cpp`: processor lifecycle and transport storage/update.
- `generator.scm:MakeNewProject`, `synchronize-generator-support-files`: ownership preservation.
- `tests/hard-bypass-output-meter-test.scm`, `tests/scope-tap-points-test.scm`: observation/bypass ordering.
- generated YAEnhancerR1/YASaturatorR1 sources: inspection evidence for current emitted consequences only.
