# JUCE Plugin Generator — Release 1.0

## 1. Release status

This document defines the intended JUCE-Plugin-Generator Release 1.0 feature, behavior, verification, and documentation baseline.

**Current status: release-ready baseline pending final tag.** Repository HEAD is on `main`; no Git tag exists at the time of this document’s creation. This document does not claim that `v1.0.0` has been created or published.

Release readiness means the scoped implementation and focused regression baseline described below are present and verified. Final tracking, README linkage, commit, tag, and distribution remain release actions.

## 2. Scope

Release 1.0 provides:

- a Scheme/GOOPS DSL for JUCE interface and semantic declarations;
- validated APVTS parameter generation;
- legacy and explicit topological layout generation;
- a fixed generator-owned DSP orchestration around developer DSP;
- meters and single/dual PRE/POST waveform scope observation;
- wet/dry, FFT, oversampling, bypass, and fixed-latency infrastructure;
- KineticLookAndFeel palettes and generic rendering;
- project creation, identity persistence during regeneration, and focused support-file synchronization;
- developer contracts and normative manuals for humans and LLM agents.

Release 1.0 is a constrained generator architecture, not an arbitrary audio-routing, widget, or layout framework.

## 3. Architectural baseline

The frozen baseline is:

- TYPE, ROLE, PROPERTY, and RESOURCE remain distinct concepts;
- GOOPS components become validated registered alist models; there is no separate persistent semantic-IR class hierarchy;
- representable DSL errors are rejected in Scheme before C++ generation;
- topological normalization, solving, and exact refinement execute in Scheme;
- YATemplate owns generic JUCE rendering;
- generated projects are output/evidence, not implementation authority;
- `PluginDSP.h` is developer-owned;
- normal DSP stage order is a contract;
- host latency uses a fixed prepare-time maximum;
- topological groups are flat;
- areas constrain/anchor bounds but are not exclusive regions.

`ARCHITECTURE_DECISIONS.md` is normative for full rationale, consequences, and extension boundaries.

## 4. Supported DSL/UI surface

Concrete Release 1.0 component TYPES are:

```text
rotary-slider       linear-slider
label               header              footer
link                palette-label
selector            palette-selector
text-button         normal-toggle-button
switch              bypass-switch
meter               scope
```

Abstract/internal family classes such as component, slider, button, and toggle-button support inheritance and generation but are not additional recommended leaf TYPES. Non-component declarations include screen, grid, and image-set resources.

The exhaustive constructor, slot, default, and validation reference is `DSL_REFERENCE.md`.

## 5. Supported semantic roles

Generator-recognized roles are:

```text
input-gain          output-gain
wet-dry             bypass             dsp-bypass
oversampling        input-meter        output-meter
scope               fft-size
```

Registration enforces uniqueness for all listed roles except `fft-size`. `fft-size` is semantically consumed but is not present in the current uniqueness-enforced list; Release authors must treat one instance as the supported convention.

Effect-specific controls normally remain ordinary APVTS parameters interpreted by PluginDSP. Arbitrary custom role symbols do not acquire generator behavior.

## 6. Parameter/APVTS support

Generated parameter families are:

| Component family | APVTS parameter | GUI attachment |
|---|---|---|
| rotary/linear slider | `AudioParameterFloat` | `SliderAttachment` |
| toggle/switch/bypass-switch | `AudioParameterBool` | `ButtonAttachment` |
| bound selector/palette-selector | `AudioParameterChoice` | `ComboBoxAttachment` |

Every slider and toggle/switch-family instance requires these three nonempty string fields:

```scheme
#:parameter-id
#:parameter-name
#:processor-reference
```

Selectors may legitimately remain UI-only. A bound selector requires nonempty choices and a complete binding tuple. ComboBox item IDs and DSL defaults are one-based; generated `AudioParameterChoice` defaults are zero-based.

Raw APVTS atomics are acquired during processor initialization and loaded into generated cached values once per block.

## 7. DSP pipeline

The frozen normal order is:

```text
HOST INPUT
 -> INPUT METER
 -> HARD BYPASS
 -> INPUT GAIN
 -> PRE-DSP SCOPE
 -> DRY CAPTURE
 -> FFT
 -> OVERSAMPLING / RealPlugin
 -> LATENCY COMPENSATION
 -> WET/DRY
 -> POST-DSP SCOPE
 -> OUTPUT GAIN
 -> OUTPUT METER
 -> HOST OUTPUT
```

Stages are emitted conditionally where the corresponding role/property requires them. Fixed-latency discovery/state is intentionally available independently of FFT/oversampling roles. Changing stage order is outside a maintenance-level Release 1.0 change.

## 8. Bypass semantics

### Hard bypass

- Input meter remains active.
- Developer DSP, FFT, and oversampling execution are skipped.
- Fixed host timing is preserved by the generated delay path.
- Output meter remains active and observes the actual bypass-return buffer.
- PRE/POST scope freezes its last snapshot because the DSP stage is not traversed.
- The editor presents global BYPASSED feedback.

### DSP bypass

- Input Gain and PRE scope remain active.
- Developer DSP, FFT, and oversampling execution are skipped.
- Actual central-DSP latency is zero and is padded to the fixed maximum.
- Generator wet/dry/fixed-timing infrastructure remains active.
- POST scope, Output Gain, output meter, and GUI remain active.

Hard bypass and DSP bypass are intentionally different contracts.

## 9. Meter and scope semantics

### Meters

- Input meter observes host input before Input Gain.
- Output meter observes final host-bound audio after Output Gain.
- Both remain meaningful during hard bypass.
- Preferred segmented vertical metric is `1x14` logical units.

`tests/hard-bypass-output-meter-test.scm` covers branch ordering and output-meter update. Meter orientation and metrics have focused tests.

### Scope

Supported `tap-points` forms are:

```scheme
'(pre-dsp)
'(post-dsp)
'(pre-dsp post-dsp)
```

Default is `'(post-dsp)`. PRE observes after Input Gain and before developer DSP. POST observes after DSP/fixed-latency/wet-dry and before Output Gain. Dual traces share one time axis, zero line, and amplitude scale; they are not independently normalized. Output Gain does not affect either trace. Hard bypass freezes the last snapshot.

The scope is waveform/time-domain observation, not a spectrum display. Preferred metric is `18x10`.

## 10. FFT support

Supported choices are:

```text
Off, 256, 512, 1024, 2048, 4096, 8192
```

FFT executes at host sample rate before oversampling. Generation supplies one `GeneratedStft` and one developer `FFTProcessor` instance for each of the six sizes. The current 50%-overlap square-root-Hann analysis/synthesis path has verified causal latency `N` for FFT size `N`: it must collect the first N inputs before reconstructed frame sample zero can be scheduled at output offset N. Hop size `N/2` changes later cadence, not initial causal offset.

When FFT infrastructure is present, its fixed maximum contribution is 8192 host samples. Arbitrary FFT sizes are unsupported.

## 11. Oversampling support

Supported modes are:

```text
Off/1x, 2x, 4x, 8x
```

Generated processing uses `juce::dsp::Oversampling<float>` with half-band polyphase IIR filtering and integer-latency behavior. Separate RealPlugin instances are constructed and prepared for 1x, 2x, 4x, and 8x effective sample-rate/block contexts. Runtime mode selection chooses the corresponding prepared state.

State is not automatically shared, and continuity across factor changes is not guaranteed. Obsolete FIR runtime choices are not part of the Release 1.0 supported behavior.

## 12. Wet/dry support

- Dry audio is captured after Input Gain/PRE scope and before developer DSP.
- Developer DSP normally produces the wet path.
- Generator-owned delay state aligns dry and processed wet timing.
- The current mixing law is linear.
- DSP bypass remains fixed-timing aligned and continues through the generator-owned mixing path.

Effect code should not duplicate the generic wet/dry stage unless the algorithm has a distinct, explicitly documented internal mix.

## 13. Fixed-latency contract

The prepare-time maximum is:

```text
maximum FFT contribution
+ maximum oversampling contribution
+ maximum developer RealPlugin latency
```

Final stabilized behavior:

- developer latency is valid with or without FFT/oversampling roles;
- all generated plugins evaluate developer latency during prepare across prepared RealPlugin instances;
- `RealPlugin::getLatencySamples()` is expressed in host samples;
- host latency is reported as one fixed prepare-time maximum;
- runtime parameter changes do not dynamically alter host latency;
- delay audio storage allocates only when maximum > 0;
- realtime delay loops execute only when maximum > 0;
- active wet, dry, hard-bypass, and DSP-bypass paths remain timing-aligned.

`tests/developer-only-latency-generation-test.scm` covers the no-FFT/no-oversampling case, wet/dry, hard bypass, DSP bypass, zero-latency guards, and retained FFT/oversampling contributions. `latency-infrastructure-required?` is deliberately unconditional.

## 14. Host transport

The processor template captures available host runtime information including BPM, seconds, PPQ position, playing/recording/looping, sample position, time signature, loop points, bar information, frame rate, edit origin, host time, channel/sample-rate, and block information.

Availability depends on the host and the optional fields it supplies. Release 1.0 provides runtime transport access to developer DSP; it does not provide a generic tempo-sync/subdivision DSL semantic. PluginDSP must interpret a normal parameter together with BPM/transport state.

## 15. Topological layout

Implemented features include:

- explicit `#:layout-mode 'topological`;
- metric-derived nodes;
- exact adjacency and partial-order relations;
- left/right/top/bottom/center alignments;
- forward references;
- flat horizontal/vertical groups;
- nonnegative exact gaps and cross alignment;
- weak/medium/strong soft cohesion;
- recursive hierarchical-third areas;
- independent horizontal/vertical difference-constraint solving;
- hard contradiction/cycle detection;
- exact rational coordinates;
- independent `dx`/`dy` integer refinement;
- reuse of the established JUCE Grid emitter.

**Areas are anchors/bounds, not exclusive packing regions.** They do not reserve occupancy or create general inter-group collision avoidance. Groups contain component node IDs only and cannot nest.

## 16. UI metrics

`generator-app/ui-metrics.scm` is canonical. Important preferred logical metrics are:

| TYPE/variant | Preferred |
|---|---:|
| rotary slider | `7x7` |
| horizontal linear slider | `14x4` |
| vertical linear slider | `4x14` |
| vertical segmented meter | `1x14` |
| scope | `18x10` |

The registry exposes compact/standard/extended profiles and variant contracts. The high-level Release 1.0 topological normalizer selects the preferred profile; capability metadata is advisory rather than an automatic per-instance profile switch.

## 17. Rendering and theme system

Authoritative generic rendering lives in `YATemplate/Source/KineticLookAndFeel.h/.cpp`. Generated properties configure it without hard-coded reference-plugin IDs.

Release 1.0 includes:

- 18 Kinetic palettes;
- animated palette transition support;
- a subtle procedural palette-derived background;
- generic rotary, linear, toggle/switch, selector, meter, scope, label, link, and button drawing;
- theme-independent semantic colours for active vertical segmented meter levels;
- compact recessed/off and accent/on toggle presentation;
- lower-weight PRE scope and primary POST scope palette differentiation on a common scale.

Exact pixel constants are renderer implementation details unless separately frozen by tests or metrics.

## 18. UTF-8 support

The current safe label-like generation path is:

```text
Scheme Unicode
 -> explicit UTF-8 bytevector
 -> C++ \xHH bytes
 -> juce::String::fromUTF8(...)
```

`tests/utf8-label-generation-test.scm` proves © emits UTF-8 bytes `C2 A9` and that the returned expression is not quoted as a plain C++ literal. Explicit UTF-8 conversion is not yet universal across every textual property/field.

## 19. Project generation and regeneration

`MakeNewProject` creates or updates a destination and delegates marked-region generation to `GenerateC++`.

- A new destination copies YATemplate and allocates a new project/VST3 identity from `uuid.txt` via `mtfa-base62`.
- Regenerating an existing destination preserves its identity.
- Deleting/recreating a destination may allocate a new identity.
- Existing-project synchronization copies only `Source/KineticLookAndFeel.h` and `.cpp` from authoritative YATemplate.
- `PluginDSP.h` is excluded from synchronization and project-name replacement.
- Generated projects remain outputs, not source authority.

Canonical reference generation:

```sh
GUILE_AUTO_COMPILE=0 guile -L . -l generator.scm -c \
  '(MakeNewProject "pppbuttavia" NewGeneric-interface #:layout-mode (quote topological) #:topology-declarations pppbuttavia-topology)'
```

This operation may invoke Zenity and must follow the configured warning procedure.

## 20. Developer extension contract

DSP developers implement the exact `RealPlugin` and optional `FFTProcessor` contracts in developer-owned `PluginDSP.h`. They allocate/prepare outside realtime methods, process supplied blocks in place, report latency in host samples, and avoid blocking/allocation on the audio path.

Generator developers may extend TYPES, ROLEs, PROPERTYs, runtime RESOURCEs, parameter families, metrics, topological relations, and generic rendering through the source-owned workflows documented in `GENERATOR_DEVELOPER_GUIDE.md`.

Release 1.0 does not imply arbitrary pipeline reordering or routing extensibility. Consult `DSP_DEVELOPER_GUIDE.md` for effect work and `GENERATOR_DEVELOPER_GUIDE.md` for generator maintenance.

## 21. LLM and agent support

Release 1.0 includes dedicated documentation for interface authoring, exact DSL syntax, topology, DSP development, generator development, and repository-modifying agents.

Recommended context:

- Interface-authoring LLM: `DSL_REFERENCE.md` + `USER_INTERFACE_GUIDE.md`; add `TOPOLOGICAL_LAYOUT_GUIDE.md` for nontrivial layouts.
- Repository-modifying agent: `LLM_DEVELOPMENT_GUIDE.md` + `ARCHITECTURE_DECISIONS.md` + the focused developer manual for the changed subsystem.

The compact LLM guide is operational guardrail text; it does not replace the normative architecture or focused references.

## 22. Verification matrix

| Feature/contract | Current evidence |
|---|---|
| Mandatory slider/toggle binding tuple; unbound selector | `tests/parameter-binding-validation-test.scm` — PASS in release-definition verification |
| Canonical metrics | `tests/ui-metrics-test.scm` — PASS |
| Meter variants/orientation | `tests/meter-orientation-test.scm` — PASS |
| Topology relations, groups, areas, contradictions | `tests/topological-layout-test.scm` — PASS |
| DSL model → topology IR | `tests/topological-normalizer-test.scm` — PASS |
| Rational refinement and generated grid | `tests/topological-generated-layout-test.scm` — PASS |
| Legacy diagnostic shadow integration | `tests/topological-shadow-integration-test.scm` — PASS |
| Scope defaults, validation, PRE/POST resources/order | `tests/scope-tap-points-test.scm` — PASS |
| Hard-bypass output meter before return | `tests/hard-bypass-output-meter-test.scm` — PASS |
| Developer-only fixed latency and zero guards | `tests/developer-only-latency-generation-test.scm` — PASS |
| Explicit label UTF-8 bytes/expression | `tests/utf8-label-generation-test.scm` — PASS |
| pppbuttavia explicit topological regeneration | PASS in Release 1.0 stabilization pass; generated reference currently present |
| Kinetic authoritative/generated synchronization | `cmp` of both `.h/.cpp` copies — MATCH in this verification |
| Linux Release Standalone | PASS in stabilization clean build; current executable artifact present |
| Linux Release VST3 | PASS in stabilization clean build; current `.so` artifact present |

The 11 focused Scheme tests were rerun while preparing this document and passed. This documentation-only task did not regenerate or rebuild because authoritative implementation was unchanged. No macOS or Windows build is claimed.

## 23. Normative documentation set

| Document | Purpose |
|---|---|
| `ARCHITECTURE_DECISIONS.md` | Frozen architecture constitution and invariants |
| `DSL_REFERENCE.md` | Exact current DSL syntax, TYPES, ROLEs, properties, validation |
| `TOPOLOGICAL_LAYOUT_GUIDE.md` | Authoring and solver semantics for topology |
| `DSP_DEVELOPER_GUIDE.md` | PluginDSP API, realtime, transport, FFT/OS, latency contract |
| `GENERATOR_DEVELOPER_GUIDE.md` | Generator structure and safe extension workflows |
| `USER_INTERFACE_GUIDE.md` | Practical interface-design workflow and examples |
| `LLM_DEVELOPMENT_GUIDE.md` | Compact operational guardrails for coding agents |
| `RELEASE_1.0.md` | Release scope, status, evidence, boundaries, checklist |

These documents supersede inconsistent historical README claims for their normative subject areas.

## 24. Known limitations

- Topological groups are flat.
- Areas are non-exclusive; no general packing/non-overlap solver exists.
- No arbitrary audio-routing graph is represented.
- No generic BPM-sync/subdivision DSL semantic exists.
- Scope taps are limited to PRE and POST; hard bypass freezes the snapshot.
- `fft-size` uniqueness is not enforced by the current unique-role validator.
- Explicit UTF-8 conversion is not universal across every text field.
- Transport values depend on host availability; not every captured value has a separate validity abstraction exposed to DSP.
- Developer parameter access is coupled to generated names rather than a strongly typed DSP facade.
- State continuity across separately prepared oversampling-factor instances is not guaranteed.
- Kinetic support synchronization is an explicit two-file allow-list.
- Identity persistence depends on retaining the destination directory.
- There is no single canonical all-tests runner.
- Linux is the currently verified Release build platform.

These are intentional Release 1.0 boundaries, not unfixed regressions.

## 25. Non-goals for Release 1.0

Release 1.0 does not promise:

- nested topology groups;
- exclusive/packing layout regions;
- automatic semantic layout inference from ROLE names;
- arbitrary graph/routing editing;
- automatic generic tempo-subdivision conversion;
- arbitrary FFT sizes;
- dynamic host latency changes;
- a universal typed DSP parameter facade;
- cross-platform certification beyond current Linux evidence;
- an explicit Unicode path for every C++ string field.

Future work must not be described as implemented until source, validation, tests, and documentation support it.

## 26. Final release checklist

Status at document creation:

- [x] Repository was clean before adding this expected docs-only file.
- [ ] `docs/RELEASE_1.0.md` tracked in the final release commit.
- [x] Existing normative documents tracked and present.
- [x] Focused core Scheme tests listed in the verification matrix pass.
- [x] Explicit topological pppbuttavia regeneration succeeded in the stabilization pass.
- [x] Generated Kinetic files currently match authoritative YATemplate.
- [x] Generated reference topology/geometry accepted in the stabilization pass.
- [x] Clean Linux Release build passed in the stabilization pass.
- [x] Standalone artifact currently exists.
- [x] VST3 artifact currently exists.
- [x] `git diff --check` passes for this document.
- [ ] README updated to point to the normative document set, if required by release policy.
- [ ] Final version/tag decision confirmed.
- [ ] Final release commit created.
- [ ] Annotated `v1.0.0` tag created only after final verification.
- [ ] Tag/release pushed or published through the chosen release process.

Checked evidence distinguishes this task’s direct verification from retained stabilization evidence. Final release operators should rerun regeneration/build if any authoritative source changes after this baseline.

## 27. Version and tagging notes

Current factual state:

- Branch: `main`.
- HEAD at audit time: `807c6b3` (`Add Release 1.0 LLM development guide`).
- Git tags: none.
- No tag or push was performed by this task.

After all checklist items are satisfied and the final release commit is selected, the intended annotated-tag action is conceptually:

```sh
git tag -a v1.0.0 -m "JUCE Plugin Generator 1.0"
```

Run that only as an explicitly authorized final release action, then verify the tag target before any push. This document does not authorize or perform publication.
