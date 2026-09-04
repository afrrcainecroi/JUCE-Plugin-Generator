# JUCE Plugin Generator

JUCE Plugin Generator is a Scheme/GOOPS generator for JUCE audio effects. A declarative DSL describes graphical TYPES, semantic ROLES, instance PROPERTIES, APVTS bindings, and logical topology; the generator emits the standard plugin shell, physical layout, JUCE Grid data, and audio orchestration. Effect algorithms remain in developer-owned `PluginDSP.h`.

## Release 1.0

Release 1.0 is tagged as `v1.0.0`. Its implemented and validated baseline includes:

- Scheme/GOOPS DSL with TYPE distinct from ROLE, PROPERTY, and RESOURCE;
- APVTS float, bool, and choice parameter generation and binding validation;
- a reusable standard shell with per-plugin optional capability configuration;
- configurable `display-name`, `tooltip`, `profile`, `width-scale`, and `height-scale`;
- LogicalTopology, normalization, PhysicalLayout, DiscreteGridLayout v2, and JUCE Grid runtime emission;
- input/output gain and meters, PRE/POST scope, Wet/Dry, 1x/2x/4x/8x oversampling, Auto Gain, Delta Monitor, DSP Bypass, Hard Bypass, and Safety Limiter with sample-peak CEILING;
- developer-owned `PluginDSP.h`, separate 1x/2x/4x/8x `RealPlugin` instances, separate `FFTProcessor` instances, and fixed latency alignment infrastructure;
- KineticLookAndFeel themes, title/footer/link, and standard visual infrastructure.

The normal processing path is:

```text
HOST INPUT -> INPUT METER -> HARD BYPASS GUARD -> INPUT GAIN
-> PRE-DSP SCOPE -> DRY REFERENCE CAPTURE
-> FFT / DEVELOPER DSP, optionally wrapped by standard oversampling
-> LATENCY ALIGNMENT -> WET/DRY or DELTA -> POST-DSP SCOPE
-> OUTPUT GAIN -> SAFETY LIMITER -> OUTPUT METER -> HOST OUTPUT
```

DSP Bypass skips the central developer DSP/FFT/oversampling path but retains the applicable standard pipeline. Hard Bypass takes the current early-return path and skips the normal effect chain while preserving the fixed timing and I/O-meter behavior implemented by the generator.

## Standard shell and plugin config

Each configured standard component uses the common contract:

```scheme
(component-id
 (enabled . #t)
 (display-name . "...")
 (tooltip . "...")
 (profile . #f)
 (width-scale . 1)
 (height-scale . 1))
```

Plugin config decides what exists and how it appears. The standard shell decides where a control belongs semantically and how it is integrated. `display-name` is presentation metadata: it never changes `id`, `role`, `parameter-id`, or `processor-reference`.

Standard controls are optional per plugin. Auto Gain is a shell-placed plugin-defined control whose compensation algorithm is implemented in the reference plugins' developer DSP; Delta and Safety Limiter have generator-owned pipeline behavior.

## Layout architecture

The current physical generation path is:

```text
DSL components -> LogicalTopology -> topological normalization
-> PhysicalLayout -> DiscreteGridLayout v2
-> generation adapter -> JUCE Grid runtime
```

LogicalTopology expresses relations, stacks, areas, alignments, and logical size choices without pixel coordinates. PhysicalLayout resolves them using screen dimensions, base unit, UI scale, UI metrics, and policy. DiscreteGridLayout v2 derives unique physical boundaries and variable tracks while verifying exact geometric reconstruction.

Legacy and earlier logical-grid topological modes remain available for compatibility; Release 1.0 reference plugins use the physical path.

## Reference plugins

`YAEnhancerR1` is the frozen architectural reference for Release 1.0 and validates the standard capability set. After the freeze it should change only for demonstrated bugs.

`YASaturatorR1` is the first plugin developed after that freeze. It demonstrates generator reuse without Generator changes: its plugin-specific surface is DRIVE, SHAPE, and developer-owned waveshaping. It is supporting evidence, not a replacement for the primary reference.

`pppbuttavia` remains useful as a historical/example project but is no longer the primary Release 1.0 reference.

## DSP development

Implement effect-specific time-domain work in a generated project's `Source/PluginDSP.h`. `RealPlugin` receives an `AudioBlock` and should normally iterate `getNumChannels()` rather than hard-code stereo. FFT runs at host sample rate before oversampling. Realtime process functions must not allocate, lock, or block.

Release 1.0 officially supports mono and stereo. Channel Layout / Bus Topology, including 5.1, 7.1, and immersive layouts, is future work rather than a current capability.

## Project generation and JUCER policy

`MakeNewProject` creates the initial project and regenerates generator-owned marked sections. Once created, `JX11.jucer` is treated as immutable project identity/configuration. Projucer may change its hash during an automatic resave, but those incidental changes are not intentional plugin updates and should not normally be included.

`PluginDSP.h` is excluded from normal replacement/synchronization. Generated projects are evidence and build targets; fix generator behavior in Scheme and generic rendering in authoritative YATemplate files.

## Documentation

| Document | Purpose |
|---|---|
| [Project State](PROJECT_STATE.md) | Authoritative current technical snapshot. |
| [Next](NEXT.md) | Future roadmap and experimental plugin concepts. |
| [Release 1.0](docs/RELEASE_1.0.md) | Implemented scope, evidence, and boundaries. |
| [Architecture Decisions](docs/ARCHITECTURE_DECISIONS.md) | Consolidated invariants and ownership rules. |
| [DSL Reference](docs/DSL_REFERENCE.md) | Current constructors, config, roles, and validation. |
| [DSP Developer Guide](docs/DSP_DEVELOPER_GUIDE.md) | PluginDSP, pipeline, realtime, bypass, and latency contracts. |
| [Generator Developer Guide](docs/GENERATOR_DEVELOPER_GUIDE.md) | Generator architecture and safe extensions. |
| [Topological Layout Guide](docs/TOPOLOGICAL_LAYOUT_GUIDE.md) | Logical and physical layout pipeline. |
| [User Interface Guide](docs/USER_INTERFACE_GUIDE.md) | Practical standard-shell and interface authoring. |
| [LLM Development Guide](docs/LLM_DEVELOPMENT_GUIDE.md) | Repository-modifying agent guardrails. |

Roadmap items are architectural directions and experimental plugin concepts, not Release 1.0 capabilities. See [NEXT.md](NEXT.md).

## Current boundaries

- Official channel support is mono/stereo; multichannel bus topology is not implemented.
- Groups/stacks and areas have the limits documented by the current layout engines; no arbitrary packing or audio-routing graph is promised.
- Generic modulation and BPM-synchronised modulation routing are not implemented.
- Safety Limiter is sample-peak protection, not True Peak limiting.
- Linux Standalone and VST3 are the currently recorded Release build targets; no unperformed platform certification is claimed.

JUCE Plugin Generator is licensed under the [MIT License](LICENSE).

Copyright © 2025 Franco Arcieri (`afrrcainecroi`).
