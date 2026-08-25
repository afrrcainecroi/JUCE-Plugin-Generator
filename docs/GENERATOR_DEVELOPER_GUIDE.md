# JUCE Plugin Generator — Generator Developer Guide

## 1. Purpose and audience

This is the normative Release 1.0 maintenance and extension guide for JUCE-Plugin-Generator itself. It is for maintainers of the Scheme generator, the authoritative JUCE template, validation, layout, code emitters, and their tests. DSP algorithm authors should instead begin with `DSP_DEVELOPER_GUIDE.md`; interface authors should use `DSL_REFERENCE.md` and `TOPOLOGICAL_LAYOUT_GUIDE.md`.

The governing decisions are in `ARCHITECTURE_DECISIONS.md`. This guide explains how those decisions are embodied in current code and how to extend that code without silently changing them.

## 2. Repository authority model

The repository has four distinct ownership layers.

| Layer | Authoritative locations | Responsibility |
|---|---|---|
| Generator | `generator.scm`, `generator-app/*.scm` | DSL, validation, registered models, layout, C++ emission, project orchestration |
| Generic JUCE template | `YATemplate/JX11.jucer`, `YATemplate/Source/*` | Stable JUCE project skeleton and generic runtime/rendering infrastructure |
| DSP developer | `YATemplate/Source/PluginDSP.h` | Effect-specific `RealPlugin` and `FFTProcessor` implementation |
| Verification output | generated projects such as `pppbuttavia` | Inspectable and buildable consequences of generator/template source |

`tests/*.scm` are the executable contract. `docs/*.md` describes that contract but cannot override source and tests.

Generated projects are not implementation authority. Fix a generation defect in Scheme and a generic rendering defect in authoritative YATemplate. Inspect generated C++ to prove the consequence, then regenerate it; do not make a generated copy the primary fix.

The current Scheme module map is:

| Module/file | Primary responsibility |
|---|---|
| `generator.scm` | Public project entry points, generation-buffer composition, template copying/synchronization, marker replacement orchestration |
| `generator-app/code-generator.scm` | Facade which imports and re-exports the current DSL, registration, layout, emitter, resource, and orchestration APIs |
| `generator-app/dsl-model.scm` | GOOPS component hierarchy, slots/defaults, TYPE mapping, `component->model` |
| `generator-app/genera-classi.scm` | `new-class` class-definition support and accessors used by the DSL |
| `generator-app/generation-protocols.scm` | GOOPS generic protocol declarations |
| `generator-app/validation.scm` | Family-specific pre-generation validation |
| `generator-app/registration.scm` | ID/role checks, C++ identifier allocation, registered alist model creation and queries |
| `generator-app/generation-state.scm`, `globals.scm` | Per-run model/resource/screen/grid state and generated marker buffers |
| `generator-app/cpp-generation.scm`, `cpp-generation-common.scm` | JUCE GUI, APVTS, attachment, cached-value, and common property/string emitters |
| `generator-app/dsp-generation.scm` | DSP-stage composition and generated processor/MyPlugin runtime resources |
| `generator-app/ui-metrics.scm` | Canonical logical metric registry |
| `generator-app/topological-normalizer.scm` | Registered-model to solver-IR adapter |
| `generator-app/topological-layout.scm` | Low-level topology IR, validation, constraints, and solver |
| `generator-app/generation-orchestration.scm` | Model emitter aggregation, shadow comparison, exact refinement, layout-mode selection |
| `generator-app/layout.scm` | Screen/grid DSL registration and final JUCE Grid data emission |
| `generator-app/resources.scm` | Image-set validation, materialization, `.jucer` resource entries, BinaryData wiring |
| `generator-app/tools.scm` | C++ identifier utilities, file replacement, Zenity/Projucer helpers, JSON/string utilities |

For an existing destination, `synchronize-generator-support-files` in `generator.scm` copies only:

- `Source/KineticLookAndFeel.h`
- `Source/KineticLookAndFeel.cpp`

The allow-list is deliberately narrow. It does not copy `PluginDSP.h`, which is developer-owned, or mirror the entire template directory.

## 3. Architectural vocabulary

- **TYPE** is a graphical/component class, represented by GOOPS classes such as `<rotary-slider>`, `<meter>`, and `<scope>`.
- **ROLE** is generator-recognized semantic behavior such as `input-gain`, `output-meter`, or `dsp-bypass`.
- **PROPERTY** configures one instance, such as slider range, meter orientation, or scope `tap-points`.
- **RESOURCE** is a runtime architectural category—not a GOOPS base class—such as an atomic peak, FIFO, delay buffer, oversampler, or STFT object.

For scope, `<scope>` is the TYPE, `tap-points` is a PROPERTY, `scope` is the current semantic role, and the requested PRE/POST arrays plus write indices are generated RESOURCES. For input gain, `<rotary-slider>` is the TYPE, `input-gain` is the ROLE, range/title/display fields are PROPERTIES, and the APVTS parameter, attachment, raw pointer, and cached value are generated consequences.

Never create a graphical TYPE merely to name semantics, a ROLE merely to select styling, or a GOOPS RESOURCE hierarchy merely to formalize the architectural word.

## 4. End-to-end generation pipeline

The current path is:

```text
MakeNewProject
  -> copy or reuse destination
  -> GenerateC++
  -> InitializeConstants / reset-cpp-identifiers! / reset-components!
  -> evaluate interface function
  -> construct GOOPS objects
  -> validate-component!
  -> component->model
  -> validate role/cardinality and allocate C++ identifier
  -> register immutable alist model
  -> prepare layout
       legacy: authored row/col/span
       topological: normalize -> solve -> rational refinement
  -> compose GUI/APVTS/DSP/resource buffers
  -> replace marked YATemplate regions
  -> ResaveProjucerProject
  -> generated JUCE project
```

`MakeNewProject` and `GenerateC++` are in `generator.scm`. GOOPS construction runs the `#:code` hooks declared in `generator-app/dsl-model.scm` and `generator-app/genera-classi.scm`. `register-component!` in `registration.scm` validates, converts, assigns a C++ identifier, and stores a registered alist through `generation-state.scm`.

There is no persistent semantic-IR class hierarchy after registration. The registered alists returned by `component->model`, augmented with `var`, are the semantic/intermediate representation consumed by generation and layout.

## 5. Entry points and lifecycle

### `MakeNewProject`

`(MakeNewProject new-name interface-definitions #:layout-mode mode #:topology-declarations declarations)` is the project-level entry point in `generator.scm`. `mode` defaults to `legacy`; Release/reference topological projects must pass `'topological` explicitly.

For a new destination it:

1. checks `CouldIRun?`;
2. copies YATemplate with `copy-template`/`rsync`;
3. allocates the next project identity from `uuid.txt` using `mtfa-base62`;
4. renames template text while excluding `Source/PluginDSP.h`;
5. calls `GenerateC++`;
6. lets `GenerateC++` resave the `.jucer` project.

For an existing directory it first synchronizes the two allow-listed Kinetic files, then calls `GenerateC++`. It does not replace the developer DSP header.

### `GenerateC++`

`GenerateC++` resets generation buffers and registration state, calls the interface definition, materializes image sets, invokes all generators, replaces marked regions, selects legacy or topological grid emission, and calls `ResaveProjucerProject`.

Legacy mode also calls `run-generation-topological-shadow` as a diagnostic comparison. Its result does not feed the legacy emitter. Topological mode resolves and refines topology at `generate-selected-grid-code`.

### Supporting entry points

- `CouldIRun?` in `tools.scm` checks whether Zenity is usable. This is why scripted workflows must sound the requested warning before an operation that may reach project generation.
- `ResaveProjucerProject` invokes the configured Projucer with `--resave JX11.jucer` and fails on a nonzero status.
- `replace-between-flags` replaces the inclusive text between a start/end marker pair while restoring literal marker lines around generated content.
- `RunProjucer` exists as an interactive helper, but `GenerateC++` uses the noninteractive resave path.

## 6. DSL and GOOPS model

`generator-app/dsl-model.scm` defines the current component hierarchy and most leaf TYPEs. `<component>` owns common identity and legacy layout slots. Families add slots through inheritance: `<label>`, `<selector>`, `<button>`, `<toggle-button>`, `<slider>`, `<meter>`, and `<scope>`, followed by concrete leaves such as `<rotary-slider>`, `<linear-slider>`, `<normal-toggle-button>`, `<switch>`, `<header>`, and `<palette-selector>`.

`generator-app/genera-classi.scm` supplies the `new-class` machinery used to declare GOOPS classes and slot accessors. Its `#:code` form executes registration at construction time.

`component-type` methods map classes to stable semantic TYPE symbols. `component->model` methods flatten inherited slots into alists. Conversion deliberately occurs before generation so emitters do not depend on mutable GOOPS objects or repeat inheritance logic.

Defaults belong in the layer which owns their meaning:

- constructor/DSL defaults belong in class slots, for example scope `tap-points` in `dsl-model.scm`;
- invalid combinations are rejected in `validation.scm`, not silently repaired;
- logical footprints and profiles belong in `ui-metrics.scm`;
- generic pixels, palette use, fonts, and drawing belong in KineticLookAndFeel;
- instance-specific C++ configuration belongs in emitted properties.

## 7. Registration and validation

### Registration

`generator-app/registration.scm` is not a passive container. `register-component!` performs these steps for a GOOPS component:

1. `validate-component!`;
2. `component->model`;
3. require a logical ID;
4. reject duplicate logical IDs;
5. `validate-component-role`;
6. allocate a collision-safe C++ identifier with `allocate-cpp-identifier!`;
7. prepend `((var . cpp-id) ...model...)` to generation state.

The current uniqueness-enforced roles are:

```scheme
input-gain output-gain wet-dry bypass dsp-bypass oversampling
input-meter output-meter scope
```

`fft-size` is semantically consumed by DSP generation but is not in `*unique-component-roles*`; this is a documented Release 1.0 nuance, not permission to assume duplicates are supported correctly.

`slider-parameter-type?`, `button-parameter-type?`, `parameter-component-type?`, `selector-parameter-model?`, and `parameter-component-model?` define current parameter families. Selectors differ: they become parameters only when `parameter-id` is present.

### Validation

`generator-app/validation.scm` dispatches `validate-component!` by GOOPS family. Invalid states which can be detected in Scheme must fail here rather than at C++ compilation.

Important current checks include:

- nonempty string binding tuple `parameter-id`, `parameter-name`, and `processor-reference` for every slider and toggle/switch family instance;
- slider `min < max`, default in range, supported scale, and positive logarithmic bounds;
- valid linear orientation;
- selector item types, index range, and a complete binding tuple plus nonempty items/default index at least 1 when parameterized;
- boolean toggle default and valid toggle style;
- meter style, orientation, scale type, range, and positive segment count;
- scope grid style and a nonempty, unique, ordered subset of PRE/POST taps.

Topology has its own validation in `topological-normalizer.scm` and `topological-layout.scm`: declaration shapes, references, duplicate nodes/groups/placements, group membership, screen dimensions, and contradictory hard constraints.

Some display-oriented values are emitted as generic NamedValueSet properties without exhaustive enum validation. Do not treat that as precedent for semantic or memory-safety-sensitive values; extend validation when adding a closed vocabulary.

## 8. Generation state

`generator-app/generation-state.scm` wraps the mutable per-run globals in `globals.scm`:

- `*components*`
- `*image-sets*`
- `*screen*`
- `*grid*`

It exposes query/set/prepend functions and `reset-generation-state!`, which delegates to `reset-components!`. `GenerateC++` currently calls `InitializeConstants`, `reset-cpp-identifiers!`, and `reset-components!` before evaluating the interface. The first clears all generated marker buffers; the other two clear identifier and DSL registration state.

Component/image-set registration prepends, so generation uses `reverse` to preserve declaration order. A new generator entry point must preserve the same reset discipline or stale components, resources, identifiers, and generated text can leak between runs in one Guile process.

For development, `GUILE_AUTO_COMPILE=0` avoids accidentally observing stale compiled-cache behavior while rapidly editing Scheme. It is a workflow safeguard, not a semantic generator feature.

## 9. Generation protocols

`generator-app/generation-protocols.scm` defines GOOPS generics for registration, validation, model conversion, and emission:

```text
register-image-set!             register-component!
validate-component!             component-type
component->model                component->member-declaration
model->member-declaration       model->constructor-code
model->attachment-declaration   model->attachment-code
model->parameter-code           model->dparams-code
model->getparams-code           model->valueparams-code
model->destroy-code
```

Current code is deliberately mixed: component-family generation is mostly a generic method over registered list models, while DSP generation is function composition and semantic-role lookup. Do not describe or redesign the latter as a generic-method framework unless a real need justifies it.

`generation-orchestration.scm` maps the relevant model method over registered components and concatenates results in source declaration order.

## 10. C++ and GUI generation

`generator-app/cpp-generation.scm` owns model-to-C++ structure:

- member declarations (`juce::Slider`, `juce::ComboBox`, buttons, `KineticMeter`, `KineticScope`, labels);
- constructor initialization and `addAndMakeVisible`;
- attachment declaration/construction;
- APVTS parameter layout entries;
- raw parameter pointer declarations, acquisition, and per-block loads;
- link callback/timer support.

`generator-app/cpp-generation-common.scm` owns reusable formatting and property emitters:

- slider ranges/scales and Kinetic properties;
- meter and scope NamedValueSet properties;
- selector items and palette callback;
- labels, buttons, justifications, colours, and choice arrays;
- C++ escaping and explicit UTF-8 label expressions.

The generator emits data and configuration such as `kinetic.title`, tick labels, meter style, scope taps, and selector contents. KineticLookAndFeel implements generic rendering. A visual change which can be expressed by existing generic properties should not become ID-specific C++ emitted by the generator.

## 11. Parameter/APVTS generation

Current families are:

| Model family | APVTS parameter | Attachment |
|---|---|---|
| rotary/linear slider | `AudioParameterFloat` | `SliderAttachment` |
| toggle/switch/bypass-switch | `AudioParameterBool` | `ButtonAttachment` |
| parameterized selector/palette-selector | `AudioParameterChoice` | `ComboBoxAttachment` |

The path is:

```text
DSL binding slots
 -> registered model
 -> model->parameter-code
 -> model->attachment-declaration / model->attachment-code
 -> model->dparams-code
 -> model->getparams-code
 -> model->valueparams-code
```

`model->parameter-code` emits `ParameterID`, display name, range/choices, and default. `model->getparams-code` calls `parameters.getRawParameterValue`, and `model->valueparams-code` loads the atomic once at the start of each generated block into `value_<processor-reference>`.

ComboBox item IDs and DSL `default-index` are one-based; `AudioParameterChoice` defaults are zero-based, so the emitter subtracts one. An unbound selector is valid and produces no APVTS parameter, attachment, raw pointer, or cached value.

Roles consume these generic cached values. Do not recreate a float/bool/choice parameter path inside `dsp-generation.scm` merely because a role uses it.

## 12. DSP generation

`generator-app/dsp-generation.scm` composes generated processor, editor-observer, MyPlugin, FFT, oversampling, wet/dry, and latency fragments.

`generate-process-code` fixes the normal stage order:

```text
generate-process-input-meter
generate-process-bypass
generate-process-input-gain
generate-process-scope-tap pre-dsp
generate-process-wetdry-prefix
generate-process-dsp
generate-process-wet-latency-code
generate-process-dry-latency-code
generate-process-wetdry-postfix
generate-process-scope-tap post-dsp
generate-process-output-gain
generate-process-output-meter
```

This yields the Release 1.0 contract:

```text
INPUT METER -> HARD BYPASS -> INPUT GAIN -> PRE SCOPE -> DRY CAPTURE
-> FFT at host rate -> RealPlugin at selected 1x/2x/4x/8x
-> fixed-latency padding -> dry alignment -> WET/DRY
-> POST SCOPE -> OUTPUT GAIN -> OUTPUT METER
```

`generate-process-dsp` conditionally wraps the FFT/RealPlugin body in DSP bypass. `generate-process-dsp-body` emits FFT first and oversampling second. Without an oversampling role it calls 1x `processAudio`; with one, the cached integer selects the corresponding prepared instance and JUCE oversampler.

Other important generator families are:

- gains: `generate-process-input-gain`, `generate-process-output-gain`;
- meters: `generate-process-meter`, input/output wrappers, `generate-timer-code`;
- scope: `scope-tap-points`, `generate-process-scope-tap`, runtime members, timer/paint fragments;
- FFT: `generate-fft-infrastructure-code`, MyPlugin FFT members/init;
- oversampling: runtime members, prepare, release;
- developer lifecycle: `generate-myplugin-audio-init-code`, prepare/reset/process methods;
- latency: prepare, runtime members, wet/dry process fragments, developer-latency declaration/definition;
- GUI state: `generate-paint-over-children-code` and editor timer generation.

Role/property predicates control only relevant stages and resources. Fixed-latency support is the deliberate exception described next.

## 13. Fixed latency generation

Developer latency is independent of FFT and oversampling roles. `latency-infrastructure-required?` in `dsp-generation.scm` is therefore unconditionally true in Release 1.0.

`generate-latency-prepare-code`:

1. sets FFT maximum to 8192 only when FFT infrastructure exists;
2. gets the rounded maximum 8x JUCE oversampling latency only when oversampling exists;
3. always queries developer latency across the prepared 1x, 2x, 4x, and 8x `RealPlugin` instances;
4. sums the three maxima;
5. allocates and clears dry/wet delay storage only when the sum is positive;
6. always calls `setLatencySamples(generatedMaximumLatencySamples)`.

At runtime, `generate-process-wet-latency-code` calculates actual FFT, selected oversampling, and active developer contributions and pads the wet path by `maximum - actual`. `generate-process-dry-latency-code` delays the captured dry path by the maximum when wet/dry exists. DSP bypass has actual DSP latency zero and is padded to the maximum. Hard bypass delays the host-bound buffer by the maximum, updates the output meter from the returned buffer, and exits.

At a zero maximum, no delay audio storage is allocated and no delay sample loops run. The remaining cost is small unconditional state plus a counter reset/positive-maximum branch. Do not restore a DSL-role gate: `RealPlugin::getLatencySamples()` is a developer contract discoverable only after prepare.

## 14. Runtime resource generation

Generated runtime state is separate from graphical objects:

| Feature | Generated/runtime resources | Condition |
|---|---|---|
| Input/output meter | `std::atomic<float>` peak per meter | corresponding role |
| Scope | 128-sample atomic array and atomic write index per requested PRE/POST tap | scope role and `tap-points` |
| Oversampling | JUCE 2x/4x/8x `Oversampling<float>` objects | oversampling role |
| FFT | `GeneratedStft<N>` for six sizes and six developer `FFTProcessor` instances | `fft-size` role |
| Wet/dry | captured `dryBuffer` and mix path | wet-dry role |
| Fixed latency | delay buffers, indices, maximum/actual counters | all plugins; storage only if maximum > 0 |
| Host transport | processor/template fields populated from playhead state | template-owned, not a formal DSL resource class |

Meters publish from the audio thread with relaxed atomic stores; the editor consumes with `.exchange(0)` and applies its display ballistic. Scope publishes fixed-size snapshots through lock-free atomics and an index; the editor copies them on its timer. Neither path calls GUI objects from `processBlock`.

Generated state is appropriate when its cardinality or wiring depends on registered semantics/properties. Stable universal infrastructure can belong in YATemplate. In either case, allocate in prepare/construction, reset explicitly, and keep process access bounded and non-blocking.

## 15. Topological normalization

`generator-app/topological-normalizer.scm` is the only adapter between registered DSL models and solver IR.

`dsl-model->metric-type` maps semantic TYPE symbols to metric TYPEs. `component-metric-variant` derives variants such as linear orientation and segmented-meter orientation/style. `preferred-metric-profile` selects the declared preferred profile, or derives the unique profile matching `preferred`. `normalize-topological-model` creates `lt:node` using that metric contract and intentionally ignores legacy `rowSpan`/`colSpan`.

`lt:constrain` represents high-level positional constraints separately from a node declaration. `normalize-topological-model-layout`:

- normalizes all registered models;
- attaches `node-constraints` declarations;
- passes alignment/group/node-area declarations through;
- emits legacy-span mismatch warnings;
- attaches logical screen rows/columns from the registered grid.

`solve-normalized-topological-layout` calls `lt:solve`. This boundary prevents the solver from knowing GOOPS classes, C++ identifiers, or legacy model representation.

## 16. Topological solver

`generator-app/topological-layout.scm` owns low-level IR and solving:

- `lt:node` describes ID, TYPE, variant, profile, optional anchors, and constraints;
- positional constructors describe exact adjacency or partial order;
- alignment constructors create hard multi-node alignments;
- `lt:group` describes flat ordered membership, layout axis, gap, optional cohesion/cross alignment/area;
- `lt:place-in-area` anchors a node to a recursive-third area;
- `lt:solve` validates and resolves nodes and group bboxes.

The solver translates axis-specific relations into difference edges conceptually of the form `V >= U + W`. Exact adjacency/alignment adds reverse constraints to enforce equality. Horizontal and vertical axes solve independently; widths affect horizontal constraints and heights affect vertical constraints.

`build-axis-edges`, `constraint-edges`, `alignment-edges`, `group-edges`, and area-placement helpers construct hard constraints. `solve-area-axis`/`try-solve-axis` reject contradictory hard positional constraints and impossible area bounds. Positive cycles are contradictions, not opportunities to weaken validation.

Cohesive groups add finite soft wishes. `cohesion-weight` maps weak/medium/strong to 1/2/3; `optimize-soft-axis` enumerates hard-valid configurations and chooses by current soft cost. Soft wishes never override hard constraints.

Groups are flat because `validate-groups!` requires every member to be a node ID. Areas recursively select thirds and constrain placement; they do not reserve occupancy or provide inter-group collision avoidance.

When adding solver behavior, preserve exact arithmetic, independent axes, complete reference validation, hard contradiction detection, deterministic selection, and the separation between normalized DSL and low-level IR.

## 17. Rational refinement and final layout

The solver preserves exact Scheme rational coordinates. `generator-app/generation-orchestration.scm` converts them to an integer grid only after solving.

`axis-refinement-factor` takes the least common multiple of coordinate denominators independently for columns (`dx`) and rows (`dy`). `refine-coordinate` and `refine-span` implement:

```scheme
new-coordinate = 1 + factor * (coordinate - 1)
new-span       = factor * span
```

`refine-topological-grid` scales screen columns/rows, resolved nodes, and model layout fields. The generated-layout test proves that axes can differ, including `dx = 2`, `dy = 1`. Early floating-point conversion or ad-hoc rounding would destroy exact alignment and must not replace this step.

## 18. UI metrics

`generator-app/ui-metrics.scm` is the canonical logical footprint registry. `register-ui-metrics!`, `ui-metrics`, and `ui-profile` expose contracts and profiles. Current vocabulary includes compact, standard/preferred, and extended/useful-max forms, with variants for orientation/style where applicable.

Examples of current preferred contracts are rotary `7x7`, segmented vertical meter `1x14`, and scope `18x10`. Metrics are logical layout dimensions, not pixels.

`ui-capability-profile` provides advisory capability metadata, but current topology normalization selects the preferred profile rather than dynamically applying capability rules. When extending metrics:

1. register the TYPE or variant once;
2. provide unique preferred-profile resolution;
3. update the normalizer mapping if it is a new TYPE/variant;
4. update `ui-metrics-test.scm` and relevant topology tests;
5. update normative docs.

Do not duplicate historical dimensions in fixtures or emitters.

## 19. Layout emission

`generator-app/layout.scm` owns `<screen>`, `<grid>`, registration, screen-size C++, and JUCE Grid data emission.

`generate-grid-code` consumes an integer grid model with `rows`, `cols`, and component layout alists. It emits a component pointer map and JSON containing `grid` and `components`; stable template code interprets that data with the existing JUCE Grid path.

Legacy mode uses `generate-layout-data-components`, preserving authored row/col/span. Topological mode passes refined `grid-model` and `layout-components` through `generate-selected-grid-code`. It reuses the same emitter; no topological solver is generated in C++.

## 20. YATemplate integration

Important authoritative template responsibilities are:

- `PluginProcessor.h/.cpp`: JUCE processor/APVTS skeleton, host transport capture, and marked generated parameter/process/resource regions;
- `PluginEditor.h/.cpp`: editor lifecycle, component layout/background, and marked generated GUI/timer/paint regions;
- `MyPlugin.h/.cpp`: wrapper owning factor-specific `RealPlugin` and size-specific `FFTProcessor` instances, with marked generated wiring;
- `PluginDSP.h`: developer-owned algorithm API and implementation; excluded from rename traversal and support synchronization;
- `KineticLookAndFeel.h/.cpp`: palettes, background, generic components, and rendering;
- `Utils.h/.cpp`: screen/logical-to-pixel support and generated screen constants;
- `Synth.h`: `GeneratedStft` infrastructure through a marked block;
- `Oscillator.h`, `Synth.h`, and utility files: stable template support where actually referenced by the project.

Generated sections are owned by the generator; stable unmarked template code remains template-owned. A change to a marker interface requires coordinated edits in `globals.scm`, `generator.scm`, and the corresponding YATemplate file.

## 21. Marker replacement

`define-constant-blocks` in `globals.scm` creates a content buffer plus regex start/end strings for each marker. Active families are:

```text
INTERFACE GRID RESIZED FOOTER_MOUSE FOOTER_TIMER DECLARATIONS
PARAMS DPARAMS GETPARAMS VALUEPARAMS SCREENSIZE DESTROY BACKGROUND
OVERSAMPLING_PPC OVERSAMPLING_PPCPB OVERSAMPLING_PPCRR OVERSAMPLING_PPH
WETDRY_PPC_PREFIX WETDRY_PPC_POSTFIX PROCESS PAINT_OVER_CHILDREN
IMAGE_RESOURCES TIMER DSP_RUNTIME_MEMBERS FFT_INFRASTRUCTURE
FFT_MYPLUGIN_MEMBERS MYPLUGIN_FFT_INIT MYPLUGIN_PROCESS_AUDIO_BUFFER
MYPLUGIN_PROCESS_AUDIO_BLOCK MYPLUGIN_PREPARE MYPLUGIN_RESET
MYPLUGIN_DEVELOPER_LATENCY
```

`GenerateC++` currently performs replacement for the active template locations. Some buffers remain empty/legacy-compatible, but marker spelling still forms an interface.

For example:

```cpp
/// PROCESS START
old generated content
/// PROCESS END
```

becomes the same literal marker lines enclosing the new `*PROCESS*` buffer. `replace-between-flags` uses regex marker patterns but `clean-flag` restores literal `/// NAME START/END` text. Renaming only one side prevents regeneration from reaching that region.

## 22. Project creation, regeneration, and identity

`copy-template` uses `rsync -a --exclude=.git`. A new destination consumes the numeric counter in repository `uuid.txt`, encodes it with `mtfa-base62`, replaces template `pluginCode="Ylst"` in `JX11.jucer`, and increments the counter. Existing destinations are not recopied and retain their project identity.

The rename traversal changes occurrences of `YATemplate` to the destination name except inside `Source/PluginDSP.h`. Existing regeneration preserves that developer file and synchronizes only Kinetic support files before marker replacement.

Deleting and recreating a destination can allocate a new identity. Identity is directory-persistence based, not name-derived. Concurrent new-project generation also shares the repository counter and mutable/global workflow; Release 1.0 does not claim transactional multi-process generation.

## 23. Binary resource handling

`generator-app/resources.scm` defines the DSL `<image-set>` and these phases:

- `register-image-set!` validates name, source directory, file list, existence, and uniqueness;
- `materialize-image-sets!` copies each declared file to `Resources/<set>/<set>__<file>`;
- `update-jucer-image-resources!` replaces or inserts a generated `.jucer` resource block;
- `generate-image-resource-cpp-code` loads BinaryData images and registers them with KineticLookAndFeel.

The word “resource” here also means binary project assets. Do not confuse that concrete DSL/build subsystem with the broader runtime RESOURCE category used for atomics, FIFOs, delay lines, and transport state.

## 24. Adding a new TYPE

Use this checklist for a hypothetical `<xy-pad>`; it is not implemented in Release 1.0.

1. Decide that this is genuinely a new graphical interaction/component family.
2. Add the GOOPS class and inheritance in `dsl-model.scm`; define exact slots/defaults.
3. Add `component-type` and `component->model` methods.
4. Add family-specific validation in `validation.scm`.
5. Confirm registration/cardinality and C++ identifier behavior.
6. Decide whether it is parameterized and whether it fits an existing APVTS family.
7. Register canonical logical metrics and variants in `ui-metrics.scm`.
8. Add `dsl-model->metric-type`/variant mapping in `topological-normalizer.scm`.
9. Add C++ member and constructor/property emission in `cpp-generation.scm` and common helpers.
10. Add attachment/parameter/raw access only if the family requires them.
11. Put generic rendering in authoritative YATemplate or use an appropriate JUCE component.
12. Add validation, generation, metric, topology, and integration tests.
13. Update DSL, generator, and architecture documentation as appropriate.

Skip a step only when it is demonstrably inapplicable—for example, a display-only TYPE needs no APVTS attachment. Never prototype by hardcoding one reference-plugin ID or patching generated pppbuttavia.

## 25. Adding a new ROLE

Before adding a hypothetical `sidechain-gain`, ask whether an ordinary APVTS parameter consumed in `PluginDSP.h` is sufficient. A semantic noun in a product request does not automatically justify a generator ROLE.

If generic generator behavior is justified:

1. define and document its semantics and exact DSP stage;
2. define compatible TYPE families;
3. choose uniqueness/cardinality and update registration if unique;
4. validate role/type/property expectations;
5. reuse the generic parameter family;
6. add role lookup and runtime/resource consequences;
7. place its process emitter deliberately;
8. define hard- and DSP-bypass behavior;
9. account for latency and observation points;
10. test duplicate/cardinality rules and exact generated ordering;
11. update architecture, DSL, DSP, and generator documents.

`input-gain` and `output-gain` demonstrate a generic slider parameter consumed at two distinct pipeline positions. Do not duplicate their APVTS generation in role-specific code.

## 26. Adding a PROPERTY

Scope `#:tap-points` is the canonical case:

1. add a slot and backward-compatible default to `<scope>`;
2. propagate it through `component->model`;
3. validate type, vocabulary, cardinality, duplicates, and order;
4. export accessors/catalogue data only when callers need them;
5. emit configuration/API wiring;
6. conditionally generate the PRE/POST runtime resources and tap code;
7. adapt Kinetic component/renderer APIs while preserving one scale;
8. test default, each valid form, invalid forms, resources, ordering, and rendering contract;
9. document syntax and semantics.

A PROPERTY may change runtime resource cardinality without becoming a ROLE. PRE and POST did not become component TYPES or role names.

## 27. Adding a runtime RESOURCE

Use meter atomics and scope streams as patterns. Specify:

- owner and lifetime;
- condition for generation;
- construction/prepare allocation;
- audio-thread producer behavior;
- message-thread or DSP consumer behavior;
- atomic/memory-order or other synchronization contract;
- reset and release behavior;
- deterministic generated naming;
- zero/absent-feature cost;
- focused static and runtime/integration tests.

No `new`, allocation-growing container, resize, mutex, filesystem operation, UI call, or blocking work may enter `processBlock`, `processAudio`, or `processFFT`. Prefer template-owned state for universal stable infrastructure and generated state when component/property cardinality controls the resource.

## 28. Adding an APVTS parameter family

For a future parameter type beyond float/bool/choice, review all of:

1. registration family predicates;
2. mandatory binding validation and unbound policy;
3. `model->parameter-code`;
4. attachment declaration and construction;
5. raw pointer/value representation;
6. acquisition and per-block caching;
7. GUI attachment lifetime;
8. default/range/choice conversion rules;
9. pure validation and generated-C++ tests;
10. documentation.

If the semantics are graphical-family generic, implement them once for the family. A role-specific APVTS special case is justified only when the parameter model itself is fundamentally different.

## 29. Adding a DSP pipeline stage

Before code, freeze:

- signal semantics and exact position;
- units/range and runtime trigger;
- hard-bypass and DSP-bypass behavior;
- relation to input/output gain;
- PRE/POST scope observation relationship;
- wet/dry capture/mix relationship;
- FFT host-rate and oversampling-domain relationship;
- actual and maximum latency contribution;
- required realtime resources and lifecycle.

Then add the semantic trigger, members, prepare/reset/release fragments, process emitter, fixed-latency integration, bypass fragments, and focused ordering tests. Inspect generated reference code and compile it only after pure generation tests pass.

Changing the established order is an architectural change. It must not enter as a cosmetic refactor or incidental insertion.

## 30. Extending meter/scope-like observers

Current observers follow:

```text
audio-thread observation
 -> processor atomics/fixed FIFO
 -> editor timer snapshot
 -> Kinetic component local state
 -> KineticLookAndFeel renderer
```

Meters reduce a block to a peak atomic; the editor consumes/reset peaks and controls display decay. Dual scope writes PRE/POST sample snapshots independently, then presents both with a common scale/time axis.

For another observation tap, define its signal-stage meaning first. Decide whether it is another PROPERTY value on an existing observer or genuinely a new semantic ROLE. Generate bounded lock-free resources, keep the GUI on the message thread, and never introduce processor-to-widget calls or GUI-derived DSP state.

## 31. Adding a topological relation

A new relation must specify:

1. affected axis;
2. equation or inequality;
3. hard or soft status;
4. forward and reverse difference edges when equality is intended;
5. public constructor and normalized declaration support if needed;
6. reference and argument validation;
7. contradiction/cycle behavior;
8. satisfiable, contradictory, forward-reference, and rational tests.

Implement it in Scheme in `topological-layout.scm`, with high-level adaptation in `topological-normalizer.scm` only when needed. Do not add solver logic to generated C++.

## 32. Extending groups or areas

Current groups are flat ordered node lists. Current areas are recursive paths through nine named thirds and provide bounding/anchor constraints, not occupancy.

Nested groups, exclusive regions, automatic packing, and general collision avoidance would each change validation, constraint construction, group bbox semantics, soft optimization, failure modes, tests, and documentation. They are architectural features, not parser-only additions. Do not simulate them with undocumented assumptions.

## 33. Extending KineticLookAndFeel

Use this sequence:

1. establish that the change is generic visual behavior;
2. if instance configuration is needed, add a PROPERTY rather than a visual ROLE;
3. emit generic NamedValueSet or API configuration from Scheme;
4. implement rendering in `YATemplate/Source/KineticLookAndFeel.h/.cpp`;
5. regenerate an existing project so allow-list synchronization updates its copy;
6. test multiple component variants, states, sizes, and palettes;
7. never branch on pppbuttavia component IDs.

Kinetic owns palette application, procedural theme background, metric formatting, labels, rotary/linear drawing, toggles/buttons, selectors, meters, and scope drawing. Meter semantic colours, scope primary/secondary palette colours, and toggle states are generic rendering behavior; their semantic signal data still originates in generator/runtime wiring.

## 34. UTF-8 generation

`cpp-utf8-string` in `cpp-generation-common.scm` implements:

```text
Scheme Unicode string
 -> string->utf8 bytevector
 -> concatenated \xHH bytes
 -> juce::String::fromUTF8("...")
```

It returns a complete C++ expression. Callers must not quote that expression again. Label-like `setText` emission uses it, and `tests/utf8-label-generation-test.scm` proves © becomes bytes `C2 A9` without expression quoting.

Release 1.0 does not guarantee this explicit path for every textual field. Extend UTF-8 at a shared emitter boundary when practical rather than fixing individual literals ad hoc.

## 35. Testing strategy

Current test categories include:

| Category | Representative tests |
|---|---|
| DSL/validation | `parameter-binding-validation-test.scm`, scope grid/tap validation |
| Metrics | `ui-metrics-test.scm`, `rotary-metrics-test.scm` |
| Topology core | `topological-layout-test.scm` |
| Normalization | `topological-normalizer-test.scm` |
| Generation/refinement integration | `topological-generated-layout-test.scm`, `topological-shadow-integration-test.scm` |
| DSP ordering/resources | scope taps, `hard-bypass-output-meter-test.scm`, `developer-only-latency-generation-test.scm` |
| UTF-8 | `utf8-label-generation-test.scm` |
| Component/visual generation matrices | rotary, linear, label, selector, switch, button, meter, scope, header/footer/link tests |

Pure validation/static generation tests are the first line of defense: they are fast and prove exact emitted ordering or resources without requiring a project. Generated C++ compilation is integration evidence, not primary DSL validation. Visual matrices may generate projects and are not equivalent to pure tests.

There is no single canonical all-tests runner in Release 1.0. A non-mutating core sequence is:

```sh
GUILE_AUTO_COMPILE=0 guile -L . tests/parameter-binding-validation-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/ui-metrics-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/topological-layout-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/topological-normalizer-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/topological-generated-layout-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/topological-shadow-integration-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/scope-tap-points-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/hard-bypass-output-meter-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/developer-only-latency-generation-test.scm
GUILE_AUTO_COMPILE=0 guile -L . tests/utf8-label-generation-test.scm
```

## 36. Debugging workflow

Use the earliest authoritative boundary which can be wrong:

- **DSL failure:** inspect class slot/default, `component->model`, validation, then registered alist.
- **Layout failure:** inspect metric contract, normalizer TYPE/variant/profile, solver constraints, rational solution, refinement, then grid emitter.
- **DSP failure:** prove role/property detection, generated process order, resource lifecycle, and only then template/runtime behavior.
- **Visual failure:** prove emitted properties/component state, then inspect authoritative Kinetic renderer.
- **Generated-code defect:** fix Scheme or YATemplate; generated output is evidence.
- **Stale result:** verify the edited authority, `GUILE_AUTO_COMPILE=0`, explicit layout mode, actual regeneration, and Kinetic support synchronization.

Never weaken validation or contradiction detection simply to make an obsolete fixture pass. Calculate the current metric/constraint chain and update only the layer which is wrong.

## 37. Release and regeneration workflow

Recommended Release 1.0 procedure:

1. inspect `git status --short` and preserve unrelated/user changes;
2. run the core pure tests above;
3. regenerate reference pppbuttavia explicitly in topological mode;
4. confirm Kinetic allow-list synchronization and inspect generated consequences;
5. clean-build Linux Release;
6. verify both Standalone and VST3 outputs;
7. inspect final diff/status, then commit/tag through the normal human release process.

Canonical regeneration command from this repository:

```sh
GUILE_AUTO_COMPILE=0 guile -L . -l generator.scm -c \
  '(MakeNewProject "pppbuttavia" NewGeneric-interface #:layout-mode (quote topological) #:topology-declarations pppbuttavia-topology)'
```

This operation can invoke Zenity; use the repository-requested audible warning first. The currently verified build path is `pppbuttavia/Builds/LinuxMakefile` with `make clean CONFIG=Release` followed by `make -j2 CONFIG=Release`. Release 1.0 evidence does not establish equivalent builds on every platform.

## 38. Common architectural mistakes

| Wrong approach | Correct layer/solution |
|---|---|
| Patch generated pppbuttavia | Fix Scheme or authoritative YATemplate, regenerate, inspect output |
| Add a ROLE for appearance | Add/reuse a PROPERTY and generic Kinetic rendering |
| Add a TYPE for semantic naming | Reuse a graphical TYPE and add a justified ROLE or ordinary DSP parameter |
| Let invalid DSL reach C++ | Add Scheme validation before registration/generation |
| Duplicate APVTS code for a role | Reuse the generic float/bool/choice component family |
| Hardcode a component ID | Emit generic configuration or use role/property lookup in Scheme |
| Allocate or lock in `processBlock` | Allocate in prepare; use fixed/atomic non-blocking state |
| Access GUI components from DSP | Publish processor state; consume it on editor timer |
| Change DSP stage order casually | Treat order as an architectural contract and test it |
| Change host latency dynamically | Preserve prepare-time fixed maximum and pad actual paths |
| Normalize dual scope traces independently | Use one time axis and common amplitude scale |
| Assume areas reserve space | Add explicit relations; areas are anchors/bounds only |
| Nest groups | Compose multiple flat groups plus relations |
| Modify only generated Kinetic files | Modify authoritative YATemplate, then synchronize/regenerate |
| Forget support synchronization | Regenerate existing destination through `MakeNewProject` |
| Omit slider/toggle binding fields | Supply all three nonempty binding strings; validation requires them |
| Assume `fft-size` uniqueness is enforced | Respect the documented nuance or explicitly add/test enforcement |
| Generate reference UI in legacy mode | Pass `#:layout-mode 'topological` explicitly |
| Quote `cpp-utf8-string` output | Insert its complete `juce::String::fromUTF8(...)` expression |
| Gate developer latency on FFT/OS | Keep unconditional fixed-latency discovery and positive-maximum guards |

## 39. LLM extension rules

Before changing this repository, follow these rules:

1. Identify the authoritative source first.
2. Classify the change as TYPE, ROLE, PROPERTY, and/or RESOURCE.
3. Never patch a generated project as the primary fix.
4. Reject representable invalid states before generation.
5. Preserve generic APVTS parameter families.
6. Preserve DSP stage ordering unless an explicit architecture change is requested.
7. Preserve the fixed maximum latency contract, including developer-only latency.
8. Never allocate or lock on the audio path.
9. Keep topology solving and exact rational refinement in Scheme.
10. Do not assume areas are exclusive.
11. Keep groups flat in Release 1.0.
12. Consume canonical `ui-metrics.scm` values.
13. Put generic visual rendering in authoritative YATemplate Kinetic files.
14. Treat `PluginDSP.h` as developer-owned.
15. Add focused validation/generation/order tests at the changed boundary.
16. Regenerate reference projects with explicit topological mode.
17. Inspect and compile generated output as evidence.
18. Do not silently introduce semantic roles, routing, latency, or bypass behavior.

## 40. Release 1.0 limitations

- Topological groups are flat; nested groups are unsupported.
- Areas are non-exclusive anchors/bounds; there is no general packing or collision-avoidance solver.
- Generic BPM/subdivision semantics are absent.
- Host transport is template/runtime state, not a formal DSL semantic abstraction.
- Explicit UTF-8 generation is not universal across all textual fields.
- `fft-size` uniqueness is not enforced by the current unique-role list.
- Developer parameter access is coupled to generated processor references rather than a strongly typed DSP parameter API.
- State continuity across changes between separately prepared oversampling instances is not guaranteed.
- Generator-owned support synchronization is an explicit two-file allow-list.
- Project identity persists with the destination directory; deletion/recreation can allocate a new identity.
- There is no general audio-routing graph DSL.
- There is no single canonical all-tests runner.
- Linux Release Standalone/VST3 is the currently verified build path.

These boundaries are not invitations to bypass the architecture. A future extension should either fit the rules above or make an explicit, tested architecture decision.
