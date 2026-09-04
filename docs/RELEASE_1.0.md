# JUCE Plugin Generator — Release 1.0

## 1. Status and authority

Release 1.0 is tagged as `v1.0.0`. This document describes capabilities supported by the current working tree; it does not claim certification that has not been executed. Source and focused tests override obsolete historical prose.

`YAEnhancerR1` is the frozen architectural reference. After freeze it changes only for demonstrated bugs. `YASaturatorR1` is the first post-freeze plugin and proves reuse without Generator modification; its plugin-specific surface is DRIVE, SHAPE, and waveshaping. It does not replace YAEnhancerR1. pppbuttavia is historical/example material.

## 2. Implemented Release 1.0 capabilities

- Scheme/GOOPS DSL and validated registered component models;
- graphical TYPE separated from semantic ROLE, PROPERTY, and RESOURCE;
- APVTS float, bool, and choice parameters, attachments, and binding validation;
- standard plugin shell and per-plugin optional standard configuration;
- `display-name`, `tooltip`, `profile`, `width-scale`, and `height-scale` configuration;
- LogicalTopology and topological normalization;
- PhysicalLayout and DiscreteGridLayout v2;
- variable-track JUCE Grid emission/runtime;
- input/output gain and meters;
- PRE/POST waveform scope;
- Wet/Dry;
- oversampling Off/1x, 2x, 4x, and 8x;
- Auto Gain control/placement with reference-plugin DSP compensation;
- Delta Monitor;
- DSP Bypass and Hard Bypass;
- Safety Limiter with real sample-peak CEILING semantics;
- developer-owned `PluginDSP.h`;
- separate `RealPlugin` time-domain instances for 1x/2x/4x/8x;
- separate `FFTProcessor` spectral instances per supported FFT size;
- fixed latency discovery, reporting, and wet/dry/bypass alignment;
- KineticLookAndFeel themes, title/footer/link, and standard visual infrastructure.

Release 1.0 is a constrained generator architecture, not an arbitrary routing, modulation, bus-topology, widget, or packing framework.

## 3. Standard config contract

```scheme
(component-id
 (enabled . #t)
 (display-name . "...")
 (tooltip . "...")
 (profile . #f)
 (width-scale . 1)
 (height-scale . 1))
```

Plugin config decides **what exists and how it appears**. The standard shell decides **where it belongs semantically and how it is integrated**. `display-name` is presentation metadata and does not change `id`, `role`, `parameter-id`, or `processor-reference`.

The config shape is common, while visual consumption remains TYPE-specific. Labels/sliders/buttons support tooltip; selectors support tooltip/enablement but no title; meter/scope do not currently expose tooltip/title fields. Layout profile and scales are common component data.

Built-in shell elements are created by the shell. Auto Gain, Delta Monitor, Safety Limiter, and CEILING are optional plugin-defined controls placed through the same contract. Delta and limiter processing are generated. Auto Gain compensation remains developer DSP in the current reference plugins.

## 4. Audio pipeline and bypass

```text
HOST INPUT -> INPUT METER -> HARD BYPASS GUARD -> INPUT GAIN
-> PRE-DSP SCOPE -> DRY REFERENCE CAPTURE
-> FFT / DEVELOPER DSP with optional standard oversampling wrapper
-> LATENCY ALIGNMENT -> WET/DRY or DELTA -> POST-DSP SCOPE
-> OUTPUT GAIN -> SAFETY LIMITER -> OUTPUT METER -> HOST OUTPUT
```

Stages are emitted conditionally. FFT operates at host sample rate before time-domain oversampling. Delta produces aligned wet minus aligned dry and supersedes Wet/Dry while active.

DSP Bypass skips central FFT, oversampling, and `RealPlugin` execution. Input Gain, dry/timing/mix or Delta, scopes, Output Gain, optional limiter, meters, and UI remain in their normal roles.

Hard Bypass takes the generated early-return path after input metering. It skips input gain, scopes, dry capture, central DSP, mix/Delta, output gain, and limiter; it preserves fixed host timing when required and updates Output Meter from the actual returned buffer.

## 5. Safety Limiter

Safety Limiter is optional and OFF by default. CEILING is `-6.0 .. 0.0 dB`, default `-0.5 dB`, step `0.1 dB`. Release is internal and fixed at 100 ms.

It is host-rate sample-peak limiting, not True Peak. JUCE `Limiter::setThreshold` is not treated as the final ceiling control: the generated pre/post scaling normalizes its threshold/makeup behavior so the final sample peak follows CEILING. The limiter follows Output Gain and precedes Output Meter.

## 6. DSP, FFT, oversampling, and latency

`PluginDSP.h` is developer-owned and excluded from normal replacement/synchronization. `RealPlugin::processAudio` works in place on `AudioBlock<float>`; realtime code must not allocate, lock, block, access UI/files/network, or grow containers.

Separate `RealPlugin` objects are prepared for 1x, 2x, 4x, and 8x. Each gets its effective sample rate and block size. State continuity between factors is not automatic. FFT uses separate processors for 256, 512, 1024, 2048, 4096, and 8192 and executes before oversampling at host rate.

Fixed maximum latency is the maximum FFT contribution plus maximum oversampling contribution plus maximum developer latency. It is established and reported during prepare; active paths are padded to it. Developer latency is expressed in host samples and works even without FFT/oversampling roles.

## 7. Layout architecture

```text
DSL components -> LogicalTopology -> topological normalization
-> PhysicalLayout -> DiscreteGridLayout v2
-> generation adapter -> JUCE Grid runtime
```

LogicalTopology expresses relations, stacks, areas, alignments, profiles, and logical scaling without pixel coordinates. PhysicalLayout resolves exact rectangles from physical screen dimensions, base unit, UI scale/size, canonical UI metrics, topology, and shell policy. DiscreteGridLayout v2 derives sorted unique physical boundaries and variable tracks, and verifies exact reconstruction of all component and screen geometry.

Legacy and earlier logical-grid topological modes remain compatibility paths. Groups/areas and physical domains have the exact limits documented in the layout guide; Release 1.0 does not promise arbitrary packing.

## 8. Channel policy

Official Release 1.0 support is mono/stereo. Naturally channel-independent developer DSP should use `AudioBlock::getNumChannels()` rather than hard-code stereo.

Channel Layout / Bus Topology for 5.1, 7.1, immersive formats, semantic channel roles, and multichannel meters/scope/routing is not implemented.

## 9. Ownership and project files

- Generator Scheme owns DSL, validation, layout, and emitted marked sections.
- YATemplate owns stable generic runtime and rendering.
- The DSP developer owns `PluginDSP.h`.
- Generated projects are build/inspection evidence, not generator source authority.

After initial project creation, `JX11.jucer` is considered immutable. Projucer may change its hash during an automatic resave, but such churn is not an intentional plugin update and should not normally be included.

## 10. Evidence and honest limits

The working tree contains focused tests for parameter binding, config/display metadata, topology/physical/discrete layout, DSP stage order, bypass, Delta, Safety Limiter generation and numerics, latency, scope/meters, and generated C++ contracts. Repository release records cover Linux Release Standalone and VST3. This document does not newly certify Windows, macOS, True Peak behavior, or future bus layouts.

Known boundaries include no generic modulation/routing capability, no generic BPM-sync modulation semantic, no arbitrary audio routing graph, no multichannel bus topology, separate state per oversampling factor/FFT size, and TYPE-specific visual metadata support.

## 11. Future roadmap

The future roadmap is maintained in `../NEXT.md` and includes:

- reusable modulation (free LFO, BPM sync, waveform, depth, target/routing, optional PPQ lock);
- Channel Layout / Bus Topology (5.1, 7.1, immersive possibilities, semantic roles, multichannel observation/routing);
- YAModDelayR1;
- YAPolyShaperR1;
- YATranscendentalR1;
- YADifferentialR1.

Roadmap items are architectural directions and experimental plugin concepts, not Release 1.0 capabilities.

## 12. Normative documentation

- `ARCHITECTURE_DECISIONS.md`: invariants and authority.
- `DSL_REFERENCE.md`: syntax, roles, standard config, and validation.
- `DSP_DEVELOPER_GUIDE.md`: DSP/realtime/pipeline contracts.
- `GENERATOR_DEVELOPER_GUIDE.md`: implementation and safe extension.
- `TOPOLOGICAL_LAYOUT_GUIDE.md`: logical-to-physical layout.
- `USER_INTERFACE_GUIDE.md`: practical interface authoring.
- `LLM_DEVELOPMENT_GUIDE.md`: operational guardrails.
