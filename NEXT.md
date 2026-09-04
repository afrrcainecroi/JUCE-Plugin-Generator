# JUCE Plugin Generator — Roadmap

This file contains future architectural directions and experimental plugin concepts. It is separate from the implemented Release 1.0 state in `PROJECT_STATE.md` and `docs/RELEASE_1.0.md`.

> Roadmap items are architectural directions and experimental plugin concepts, not Release 1.0 capabilities.

## 1. Modulation capability

- free-rate LFO;
- BPM synchronisation;
- waveform selector;
- modulation depth;
- modulation target/routing;
- optional transport/PPQ phase lock.

This requires explicit parameter-modulation, smoothing, transport-fallback, routing, realtime-resource, and UI decisions. None is currently generic Generator behavior.

## 2. Channel Layout / Bus Topology

- 5.1 and 7.1 layouts;
- possible immersive layouts;
- semantic channel roles;
- multichannel meters and scope;
- multichannel routing and validation.

N-channel developer-DSP style is a current coding policy, not implemented multichannel bus negotiation.

## 3. YAModDelayR1

- fractional delay;
- sub-ms to multi-second range;
- feedback;
- free modulation and BPM synchronisation;
- waveform selection.

## 4. YAPolyShaperR1

- configurable polynomial order;
- coefficients;
- even/odd harmonic design;
- normalization and protection.

## 5. YATranscendentalR1

`tanh`, `atan`, `sin`, `exp`, and `log` families for saturation and wavefolding experiments.

## 6. YADifferentialR1

- first discrete difference;
- second discrete difference;
- direct processing;
- possible transient/modulation-source use.

## Roadmap discipline

Before promotion to a capability, define TYPE/ROLE/PROPERTY/RESOURCE boundaries, signal order, bypass/latency semantics, realtime ownership, validation, tests, and compatibility. Do not modify the stable shell or layout architecture merely to prototype a plugin-local idea.
