# JUCE Plugin Generator — Current Project State

This file is the authoritative technical snapshot of the current Release 1.0 working tree. Future work belongs in `NEXT.md`.

## Release identity and references

- Release tag: `v1.0.0`.
- Primary architectural reference: `YAEnhancerR1`, frozen; post-freeze changes require a demonstrated bug.
- Reuse proof: `YASaturatorR1`, the first new plugin after the freeze, created without Generator changes and limited to DRIVE, SHAPE, and developer-owned waveshaping.
- `pppbuttavia` is historical/example material, not the current primary reference.

## Implemented architecture

```text
Scheme/GOOPS DSL -> validated registered component models
-> APVTS and standard-shell generation
-> LogicalTopology and topological normalization -> PhysicalLayout
-> DiscreteGridLayout v2 -> generation adapter -> JUCE Grid/runtime project
```

TYPE, ROLE, PROPERTY, and RESOURCE are distinct. Graphical TYPE does not imply semantic ROLE. Effect-specific controls normally use ordinary APVTS bindings and are interpreted by developer-owned `PluginDSP.h`. Parameter generation supports float sliders, bool toggle/switch controls, and choice selectors; binding validation occurs before C++ generation.

## Standard shell and configuration

Every per-plugin component config entry follows:

```scheme
(component-id
 (enabled . #t)
 (display-name . "...")
 (tooltip . "...")
 (profile . #f)
 (width-scale . 1)
 (height-scale . 1))
```

Plugin config decides what exists and how it appears. The shell decides semantic placement and standard integration. `display-name` is visual metadata and does not change `id`, `role`, `parameter-id`, or `processor-reference`.

The contract is uniform, but its visible effect is TYPE-dependent: meter and scope do not expose title/tooltip properties in the current base DSL, and a selector has no title field. Unsupported presentation fields are not silently promoted into logical identity.

Implemented optional standard capabilities are input/output gain and meters; PRE/POST scope; Wet/Dry; oversampling 1x/2x/4x/8x; Auto Gain control/placement, with compensation implemented in reference-plugin `PluginDSP.h`; Delta Monitor; DSP Bypass; Hard Bypass; Safety Limiter and CEILING; and theme/title/footer/link infrastructure.

## Current audio pipeline

```text
HOST INPUT -> INPUT METER -> HARD BYPASS GUARD -> INPUT GAIN
-> PRE-DSP SCOPE -> DRY REFERENCE CAPTURE
-> FFT / DEVELOPER DSP with optional standard oversampling wrapper
-> LATENCY ALIGNMENT -> WET/DRY or DELTA -> POST-DSP SCOPE
-> OUTPUT GAIN -> SAFETY LIMITER -> OUTPUT METER -> HOST OUTPUT
```

Stages are conditional. FFT runs at host sample rate before oversampling. Four separately prepared `RealPlugin` instances cover 1x, 2x, 4x, and 8x; FFT processors are separate per supported size.

DSP Bypass skips central FFT/developer/oversampling execution, not the surrounding standard pipeline. Hard Bypass uses the current early-return branch, skips the normal effect chain, preserves fixed timing when required, and updates I/O meters according to current implementation.

Delta produces aligned wet minus aligned dry and replaces the normal Wet/Dry result while active. Auto Gain is not a generator formula: the shell places its plugin-defined control and the reference plugins consume it in developer DSP.

## Safety Limiter

Safety Limiter is optional and OFF by default. CEILING has range `-6.0 .. 0.0 dB`, default `-0.5 dB`, and step `0.1 dB`; release is fixed internally at 100 ms. It is a host-rate sample-peak limiter, not a True Peak limiter. Because JUCE's `Limiter::setThreshold` is not itself a final-output ceiling control, generated processing normalizes the limiter domain and scales the result so the final sample peak follows CEILING.

## Layout state

LogicalTopology carries relations, stacks, area placement, alignment, profile, and logical scaling. PhysicalLayout resolves exact rectangles using screen dimensions, base unit, UI scale/size, UI metrics, and standard-shell domains. DiscreteGridLayout v2 derives sorted unique physical boundaries, emits variable tracks, and verifies exact reconstruction. Legacy and earlier logical-grid topological modes remain compatibility paths.

## Ownership and regeneration

- Scheme and marked generated sections are Generator-owned.
- Generic runtime/rendering belongs to YATemplate.
- `PluginDSP.h` is developer-owned.
- Generated projects are evidence, not source authority.
- Realtime process functions allocate no memory and take no locks.

After initial project creation, `JX11.jucer` is considered immutable. A normal Projucer resave may change its hash, but that automatic churn is not an intentional plugin modification and should not normally be included.

## Channel policy and limits

Release 1.0 officially supports mono and stereo. Developer DSP should avoid hard-coded stereo when naturally channel-independent and iterate `AudioBlock::getNumChannels()`.

5.1, 7.1, semantic channel roles, multichannel meters/scope/routing, immersive layouts, generic modulation, and arbitrary routing are roadmap work. The repository records Linux Standalone/VST3 evidence but no Windows/macOS certification or True Peak behavior.

Roadmap items are architectural directions and experimental plugin concepts, not Release 1.0 capabilities.
