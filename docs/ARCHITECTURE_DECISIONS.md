# JUCE Plugin Generator — Architecture Decisions

## Purpose

This document is the normative architectural constitution of JUCE-Plugin-Generator Release 1.0. It records decisions that extensions must preserve unless a later, explicit ADR supersedes them. It is written for maintainers, DSP developers, and automated agents.

## Scope

The decisions cover the Scheme DSL and registered model, validation, APVTS generation, topological layout, generated DSP ordering and resources, YATemplate ownership, regeneration, and architecture-sensitive tests. They describe current Release 1.0 behavior, not historical intent or a feature roadmap.

## Architectural vocabulary

- **TYPE**: graphical/component class, such as `<rotary-slider>`, `<meter>`, or `<scope>`.
- **ROLE**: semantic behavior assigned to an instance, such as `input-gain` or `bypass`.
- **PROPERTY**: configuration of one instance, such as a range, orientation, or scope tap list.
- **RESOURCE**: runtime state or machinery used to implement behavior. It is an architectural category, not currently a GOOPS base class.
- **Registered model**: validated alist produced from a DSL component and retained in generation state.
- **YATemplate**: authoritative generic JUCE project skeleton and visual/runtime support source.
- **Generated project**: disposable/regenerable output used to build and verify a plugin.

The central rule is: **TYPE != ROLE != PROPERTY != RESOURCE**.

## Source-of-truth hierarchy

When sources disagree, use this order:

1. Current generator implementation and validation under `generator-app/`, plus the `generator.scm` orchestration entry point.
2. Current authoritative files under `YATemplate/Source/`, with `PluginDSP.h` specifically developer-owned.
3. Current regression tests under `tests/` as executable contracts.
4. Generated output, including YAEnhancerR1, YASaturatorR1, and historical pppbuttavia, as evidence of consequences only.
5. README files, historical projects, comments, caches, and old generated artifacts as non-normative material.

## ADR-001 — TYPE Is Not ROLE

### Decision

TYPE identifies graphical construction; ROLE selects semantic behavior. `<rotary-slider>` is a TYPE. `input-gain`, `output-gain`, `wet-dry`, `bypass`, `dsp-bypass`, `oversampling`, `input-meter`, `output-meter`, `scope`, `delta-monitor`, `safety-limiter`, and `safety-limiter-ceiling` are semantic roles. `fft-size` is a role-like DSP selector in the current implementation.

### Context

Multiple visual types can carry parameter semantics, while one visual type can serve unrelated DSP purposes. Coupling the two creates one-off components and ID-dependent C++.

### Rationale

Orthogonality keeps rendering reusable and lets DSP behavior be selected without multiplying graphical classes.

### Consequences

Component construction dispatches by TYPE; DSP generation discovers models by ROLE. `registration.scm` enforces global uniqueness for its `*unique-semantic-roles*`. Current nuance: `dsp-generation.scm:fft-model` consumes `fft-size`, but `fft-size` is not in that uniqueness list; Release 1.0 therefore treats uniqueness for it as a convention, not an enforced guarantee.

### Invariants

A TYPE does not imply a DSP stage. A ROLE does not define appearance.

### Allowed extensions

Add a ROLE when genuinely new generator-level semantic behavior is required and define compatible TYPEs and validation explicitly.

### Forbidden shortcuts

Do not invent a graphical TYPE merely for a semantic function. Do not invent a ROLE merely to change styling. Do not hard-code component IDs as semantic dispatch.

### Authoritative implementation

`generator-app/dsl-model.scm:component->model`; `generator-app/registration.scm:*unique-semantic-roles*, register-component!, role-model`; `generator-app/dsp-generation.scm` role lookups.

### Relevant tests

`tests/topological-shadow-integration-test.scm`; `tests/scope-tap-points-test.scm`; `tests/hard-bypass-output-meter-test.scm`.

## ADR-002 — PROPERTY Configures an Instance

### Decision

Properties configure an instance without redefining its semantic identity. The canonical case is TYPE `scope` with PROPERTY `tap-points`: `'(pre-dsp)`, `'(post-dsp)`, or `'(pre-dsp post-dsp)`.

### Context

The same component can support bounded configuration variants without new classes or roles.

### Rationale

Properties preserve a small type vocabulary and make validation and generation data-driven.

### Consequences

There are no `pre-dsp-scope` or `post-dsp-scope` types. Other examples include slider range, scale, title, ticks and labels; meter style, orientation, range and segments; selector items, default index and binding.

### Invariants

A property may affect emitted configuration or conditional resources, but does not silently change TYPE or invent semantic identity.

### Allowed extensions

Add a validated property when configuration is intrinsic to an existing TYPE and has a bounded, coherent meaning.

### Forbidden shortcuts

Do not encode a property in an ID, create duplicate types for property values, or accept unvalidated arbitrary values.

### Authoritative implementation

Slots and `component->model` methods in `generator-app/dsl-model.scm`; validators in `generator-app/validation.scm`; property emitters in `generator-app/cpp-generation-common.scm`.

### Relevant tests

`tests/scope-tap-points-test.scm`; `tests/meter-orientation-test.scm`; `tests/ui-metrics-test.scm`.

## ADR-003 — RESOURCE Is a Runtime Architectural Concept

### Decision

RESOURCE names runtime state/machinery. It is not a GOOPS base class in Release 1.0.

### Context

Semantic behavior requires state that is neither graphical identity nor instance configuration.

### Rationale

Keeping runtime machinery separate prevents signal-processing resources from leaking into the UI type system.

### Consequences

Resources include meter peak atomics; PRE/POST scope FIFO arrays and indices; oversampling objects; FFT/STFT and processor instances; dry buffer; wet/dry delay buffers; fixed-latency counters/state; and host transport state.

### Invariants

Resources are generated or supplied only where their behavior requires them, subject to realtime rules.

### Allowed extensions

Introduce a resource independently of a new TYPE or ROLE when existing semantics require new runtime state.

### Forbidden shortcuts

Do not create a GUI TYPE solely to name a buffer, tap, FFT engine, or transport object.

### Authoritative implementation

`generator-app/dsp-generation.scm:generate-dsp-runtime-members-code` and conditional resource emitters; `YATemplate/Source/PluginProcessor.h`; `YATemplate/Source/PluginDSP.h`.

### Relevant tests

`tests/scope-tap-points-test.scm`; `tests/hard-bypass-output-meter-test.scm`.

## ADR-004 — The Registered Model Is the Semantic IR

### Decision

The Release 1.0 semantic pipeline is GOOPS DSL -> `component->model` -> validation/registration -> registered alist model -> generation/layout subsystems. There is no separate persistent semantic-IR class hierarchy.

### Context

GOOPS objects are declaration-facing; emitters and layout operate on registered alists.

### Rationale

The current model is sufficient, explicit, and shared across generators without duplicating object hierarchies.

### Consequences

Documentation and extensions must call the alist model the semantic/intermediate model, not invent a nonexistent layer.

### Invariants

Registered models have validated logical IDs, semantic TYPE, C++ variable identity, properties, and roles before generation.

### Allowed extensions

A richer IR may be introduced only for a demonstrated architectural need while preserving DSL compatibility and tests.

### Forbidden shortcuts

Do not bypass registration by constructing emitter alists ad hoc in production generation.

### Authoritative implementation

`generator-app/dsl-model.scm:component->model`; `generator-app/registration.scm:register-component!`; `generator-app/generation-state.scm`; `generator-app/generation-orchestration.scm`.

### Relevant tests

`tests/topological-normalizer-test.scm`; `tests/topological-shadow-integration-test.scm`.

## ADR-005 — Validate Before Generation

### Decision

Invalid representable states that Scheme can reasonably detect must be rejected before C++ emission.

### Context

C++ compiler errors are late, indirect feedback for DSL mistakes.

### Rationale

Early validation provides deterministic errors close to declarations and prevents invalid generated projects.

### Consequences

Validation covers ranges/defaults, logarithmic constraints, selector items/index/binding, scope taps, duplicate IDs, enforced unique roles, topology references, invalid areas, cycles, and contradictory hard constraints.

### Invariants

Registration validates component models; topology validates collected declarations before solving.

### Allowed extensions

Add focused validation and negative tests with every new property, role, relation, or resource contract.

### Forbidden shortcuts

Do not rely primarily on JUCE assertions or C++ compilation to reject DSL errors. Do not weaken contradiction detection to accommodate an obsolete fixture.

### Authoritative implementation

`generator-app/validation.scm`; `generator-app/registration.scm:register-component!`; `generator-app/topological-layout.scm:lt:solve` and validation helpers.

### Relevant tests

`tests/scope-grid-style-validation-test.scm`; `tests/scope-tap-points-test.scm`; `tests/topological-layout-test.scm`.

## ADR-006 — Topological Solving Belongs to Scheme

### Decision

The path is DSL constraints -> normalization -> Scheme solver -> resolved exact geometry -> rational refinement -> discrete JUCE Grid. Generated C++ contains resolved geometry, never the solver.

### Context

Layout relationships are compile/generation-time semantics.

### Rationale

Scheme can validate globally, solve deterministically, and emit simple runtime layout data.

### Consequences

Horizontal and vertical axes solve independently. Exact adjacency is equality expressed by opposing inequalities; partial orders are one-sided. Alignments, forward references, cycle/contradiction detection, exact rationals, and per-axis refinement are supported.

### Invariants

Only exact resolved/discretized coordinates enter generated Grid JSON.

### Allowed extensions

Add solver relations in Scheme with normalization, contradiction, rational-refinement, and emission tests.

### Forbidden shortcuts

Do not generate a C++ constraint solver or repair contradictory layouts at runtime.

### Authoritative implementation

`generator-app/topological-normalizer.scm`; `generator-app/topological-layout.scm:constraint-edges, solve-axis, lt:solve`; `generator-app/generation-orchestration.scm:refine-topological-grid, generate-selected-grid-code`.

### Relevant tests

`tests/topological-layout-test.scm`; `tests/topological-normalizer-test.scm`; `tests/topological-generated-layout-test.scm`; `tests/topological-shadow-integration-test.scm`.

## ADR-007 — Areas Are Anchors, Not Exclusive Regions

### Decision

Area symbols and hierarchical paths constrain placement/bounds. They do not model occupancy, collision avoidance, or non-overlap between independent groups.

### Context

Names such as `top`, `center`, and `bottom-left` can be mistaken for reserved screen partitions.

### Rationale

Release 1.0 areas are deterministic geometric anchors based on recursive thirds, not a packing system.

### Consequences

Two independently placed groups may overlap unless an explicit relationship prevents it.

### Invariants

Area validation and bounds remain hard constraints; exclusivity is absent.

### Allowed extensions

Add exclusivity only as a separate, explicitly designed solver feature.

### Forbidden shortcuts

Do not document or assume implicit occupancy/non-overlap.

### Authoritative implementation

`generator-app/topological-layout.scm:area-symbols, resolve-area-path, area-placement-constraints`.

### Relevant tests

Area cases in `tests/topological-layout-test.scm`; hierarchical-area coverage in `tests/topological-generated-layout-test.scm`.

## ADR-008 — Groups Express Flat Composition

### Decision

Release 1.0 groups contain component node IDs only and are flat. They support horizontal/vertical layout, gap, cross alignment, optional cohesion, and optional area.

### Context

Groups express local composition, not a recursive layout tree.

### Rationale

Flat groups keep validation and two-axis solving explicit.

### Consequences

Without cohesion, along-axis group gaps are hard exact adjacency. Cohesion creates soft wishes weighted weak/medium/strong while preserving hard validity. Cross-align is hard alignment on the other axis.

### Invariants

`validate-groups!` requires every member to be a node; group IDs cannot be members.

### Allowed extensions

Add relations among existing flat groups/nodes. Nested groups require a new ADR and solver design.

### Forbidden shortcuts

Do not simulate nesting through undocumented IDs or assume a group is a node.

### Authoritative implementation

`generator-app/topological-layout.scm:lt:group, group-edges, soft-wishes, validate-groups!, resolved-group`.

### Relevant tests

`tests/topological-layout-test.scm`; `tests/topological-shadow-integration-test.scm`.

## ADR-009 — YATemplate Owns Generic JUCE Visual Behavior

### Decision

The generator owns DSL properties, declarations, configuration, and wiring. YATemplate/KineticLookAndFeel owns generic rendering, palettes, meters, scopes, sliders, toggles, procedural background, and formatting behavior.

### Context

Visual algorithms must have one authoritative source and remain reusable across generated projects.

### Rationale

This prevents generator emitters from becoming renderer implementations and prevents generated copies from drifting.

### Consequences

Existing-project regeneration synchronizes only `Source/KineticLookAndFeel.h` and `.cpp` from YATemplate through `generator.scm:synchronize-generator-support-files`. `PluginDSP.h` is excluded and must not be overwritten.

### Invariants

KineticLookAndFeel remains generic: no component IDs or semantic roles.

### Allowed extensions

Emit generic properties from Scheme and implement their reusable visual interpretation in authoritative YATemplate.

### Forbidden shortcuts

Do not patch only a generated Kinetic copy, hard-code palette names per component, or overwrite developer DSP.

### Authoritative implementation

`YATemplate/Source/KineticLookAndFeel.h/.cpp`; `generator-app/cpp-generation-common.scm`; `generator.scm:synchronize-generator-support-files, MakeNewProject`.

### Relevant tests

`tests/meter-orientation-test.scm`; `tests/scope-tap-points-test.scm`; visual matrix generators.

## ADR-010 — Generated Projects Are Output, Not Authority

### Decision

pppbuttavia and all generated projects are build/verification artifacts. Fixes normally belong in generator source or authoritative YATemplate.

### Context

Regeneration can replace marked regions and synchronized support files.

### Rationale

Fixing authority prevents one generated project from diverging from future output.

### Consequences

Generated C++ may be inspected to prove order, wiring, dimensions, or compilation, but is not the implementation origin.

### Invariants

Every durable generated behavior has an upstream owner.

### Allowed extensions

Use generated reference projects for integration/build tests.

### Forbidden shortcuts

Do not ship a generated-only correction or treat pppbuttavia C++ as a template.

### Authoritative implementation

`generator.scm:GenerateC++, MakeNewProject`; marker replacement in `generator-app/tools.scm`; YATemplate marker files.

### Relevant tests

`tests/topological-generated-layout-test.scm`; pppbuttavia regeneration/build verification.

## ADR-011 — Parameter Families Are Generic

### Decision

Sliders map to `AudioParameterFloat`; toggle/switch families to `AudioParameterBool`; bound selectors to `AudioParameterChoice`. Attachments follow the same component families.

### Context

Parameter storage and UI binding are orthogonal to DSP roles.

### Rationale

One generic APVTS path avoids repeated role-specific parameter code.

### Consequences

Roles consume cached parameter values after generic creation. Choice defaults convert DSL/ComboBox one-based IDs to APVTS zero-based indices.

### Invariants

IDs, names, versions, ranges, defaults, and steps come from validated model properties.

### Allowed extensions

Extend a parameter family generically, or add a new family when JUCE semantics fundamentally require it.

### Forbidden shortcuts

Do not duplicate float/bool/choice creation inside role-specific DSP emitters.

### Authoritative implementation

`generator-app/registration.scm` parameter predicates; `generator-app/cpp-generation.scm:model->parameter-code` and attachment/value methods; `cpp-generation-common.scm:slider-normalisable-range->cpp`.

### Relevant tests

Selector and control visual/generation matrices; `tests/scope-tap-points-test.scm` for non-parameter resource separation.

## ADR-012 — DSP Stage Order Is an Architectural Contract

### Decision

Normal processing order is:

```text
HOST INPUT -> INPUT METER -> HARD BYPASS decision -> INPUT GAIN
-> PRE-DSP SCOPE TAP -> dry capture
-> FFT/developer DSP with optional oversampling wrapper -> latency alignment
-> wet/dry mix or Delta -> POST-DSP SCOPE TAP -> OUTPUT GAIN
-> optional SAFETY LIMITER -> OUTPUT METER -> HOST OUTPUT
```

### Context

Tap meaning, bypass, wet/dry, and latency depend on relative stage order.

### Rationale

Freezing order makes observation and DSP behavior predictable.

### Consequences

FFT, when configured, runs at host rate before time-domain DSP. Time-domain DSP runs directly at 1x or through the selected 2x/4x/8x oversampler. Optional stages emit only when relevant roles exist.

### Invariants

Moving a stage is an architectural change, not a cosmetic refactor.

### Allowed extensions

Insert a new stage only with explicit tap, bypass, wet/dry, latency, and test consequences.

### Forbidden shortcuts

Do not reorder to simplify generated text or UI presentation.

### Authoritative implementation

`generator-app/dsp-generation.scm:generate-process-code, generate-process-dsp-body`.

### Relevant tests

`tests/scope-tap-points-test.scm`; `tests/hard-bypass-output-meter-test.scm`.

## ADR-013 — Meters Represent Plugin I/O

### Decision

Input meter observes host input before input gain. Output meter observes final host-bound audio after output gain. In hard bypass both remain active, and output meter observes the actual buffer returned to the host.

### Context

Meters are plugin boundary instrumentation, not arbitrary DSP taps.

### Rationale

Their meaning remains stable across processing and bypass states.

### Consequences

Processor resources are relaxed atomic peaks. The editor timer consumes with `.exchange(0.0f, memory_order_relaxed)`, preventing stale indefinite holds. KineticMeter applies immediate attack and moderate release; exact constants are implementation behavior, not a permanent public API.

### Invariants

Signal sampling belongs to processor/generated DSP; rendering and ballistics belong to KineticLookAndFeel.

### Allowed extensions

Refine bounded ballistics/rendering without moving I/O taps or creating locks.

### Forbidden shortcuts

Do not derive output level from a pre-output-gain stage or leave hard-bypass output stale.

### Authoritative implementation

`dsp-generation.scm:generate-process-code, generate-process-bypass, generate-process-meter, generate-timer-code`; `YATemplate/Source/KineticLookAndFeel.h:KineticMeter::updateLevel`.

### Relevant tests

`tests/hard-bypass-output-meter-test.scm`; `tests/meter-orientation-test.scm`.

## ADR-014 — Scope Represents DSP Observation

### Decision

PRE is after input gain and before DSP. POST is after DSP, latency compensation, and wet/dry, but before output gain. One scope may show either or both. Dual traces share time axis, zero, and amplitude transformation; they are never independently normalized. Hard bypass intentionally freezes the last snapshot.

### Context

The scope compares the signal presented to and produced by the DSP stage, not plugin output loudness.

### Rationale

Shared scaling makes waveform/amplitude comparison meaningful; excluding output gain preserves DSP-stage semantics.

### Consequences

Input gain changes both traces. DSP changes their relationship. Output gain changes neither. Hard bypass traverses no DSP observation stage, so no scope resource is updated.

### Invariants

TYPE=`scope`, PROPERTY=`tap-points`, resources=selected streams. POST is not an output meter.

### Allowed extensions

Improve rendering or add explicitly designed observation taps while preserving shared-scale semantics.

### Forbidden shortcuts

Do not normalize traces independently, encode tap behavior in IDs, or move POST after output gain.

### Authoritative implementation

`dsl-model.scm:<scope>`; `validation.scm`; `dsp-generation.scm:generate-process-scope-tap`; `KineticLookAndFeel.h:KineticScope`; `KineticLookAndFeel.cpp:drawKineticScope`.

### Relevant tests

`tests/scope-tap-points-test.scm`; `tests/scope-grid-style-validation-test.scm`.

## ADR-015 — Hard Bypass and DSP Bypass Are Different

### Decision

Hard bypass skips the processing chain, preserves required fixed host latency, keeps I/O meters active, does not update scope, and globally indicates BYPASSED. DSP bypass keeps surrounding infrastructure active, skips central FFT/oversampling/developer execution, retains fixed-latency and wet/dry behavior, keeps PRE/POST meaningful, and leaves the GUI usable.

### Context

The two controls serve different operational contracts.

### Rationale

Conflating them would break observation, timing, and UI semantics.

### Consequences

Hard bypass returns early; DSP bypass gates only `generate-process-dsp-body` and sets actual central DSP latency to zero before compensation.

### Invariants

Both bypass paths preserve the fixed host timing contract where infrastructure is present.

### Allowed extensions

Refine their distinct visual feedback or add tests without collapsing execution paths.

### Forbidden shortcuts

Do not implement both through one generic early return.

### Authoritative implementation

`dsp-generation.scm:generate-process-bypass, generate-process-dsp, generate-process-wet-latency-code, generate-paint-over-children-code`.

### Relevant tests

`tests/hard-bypass-output-meter-test.scm`; scope ordering assertions in `tests/scope-tap-points-test.scm`.

## ADR-016 — Realtime Paths Are Bounded and Non-Blocking

### Decision

Audio processing performs no allocation/container resize, mutex acquisition, filesystem/UI operation, or blocking call. Resources are prepared outside realtime.

### Context

JUCE `processBlock` and developer DSP callbacks run on the realtime audio thread.

### Rationale

Unbounded work causes dropouts and nondeterministic failure.

### Consequences

Meters use atomics; scope uses fixed 128-entry atomic rings; delay and dry buffers are prepared; oversamplers/STFT vectors are constructed in prepare; editor copying occurs on its timer.

### Invariants

Per-block/sample loops have bounded memory and synchronization behavior.

### Allowed extensions

Allocate tables/buffers in prepare and use lock-free or bounded observation mechanisms.

### Forbidden shortcuts

No `new`, malloc, vector resize, mutex, I/O, UI calls, or waits in realtime processing.

### Authoritative implementation

`YATemplate/Source/PluginDSP.h` developer contract; generated runtime/prepare/process code in `dsp-generation.scm`.

### Relevant tests

`tests/scope-tap-points-test.scm` static resource/path assertions; generated Release build.

## ADR-017 — Fixed Latency Is an Invariant

### Decision

Maximum latency is established during prepare and reported once. Runtime parameter changes do not change host latency. Maximum is max FFT contribution + max oversampling contribution + max developer latency.

### Context

FFT size, oversampling, bypass, and developer DSP can have different natural delays.

### Rationale

A fixed report prevents host timeline changes and allows wet/dry and bypass alignment.

### Consequences

FFT maximum is 8192. Current `GeneratedStft` causal latency is selected size N: it waits for N inputs, emits the current output slot first, then schedules reconstructed frame sample zero at the next slot, output sample N. The N/2 hop affects later overlap cadence, not initial delay. Wet, dry, DSP-bypass, and hard-bypass paths pad to the prepared maximum.

### Invariants

Developer latency is reported consistently in host samples for 1x/2x/4x/8x instances.

### Allowed extensions

Add latency-producing DSP only by including its maximum/actual contributions and all bypass/mix paths.

### Forbidden shortcuts

Do not call `setLatencySamples` dynamically from parameter changes or omit compensation on a return path.

### Authoritative implementation

`dsp-generation.scm:generate-latency-prepare-code, generate-process-wet-latency-code, generate-process-dry-latency-code, generate-process-bypass`; generated `GeneratedStft` methods.

### Relevant tests

`tests/hard-bypass-output-meter-test.scm`; generated pppbuttavia build/integration verification.

## ADR-018 — FFT Precedes Oversampling in Release 1.0

### Decision

FFT processing runs at host sample rate, then time-domain developer DSP runs at 1x/2x/4x/8x.

### Context

Moving FFT across resampling changes signal interpretation and resource cost.

### Rationale

The current developer API, FFT sizes, latency accounting, and CPU model assume host-rate spectral processing.

### Consequences

Oversampling applies only to the time-domain `RealPlugin` path.

### Invariants

FFT size and latency are expressed in host samples.

### Allowed extensions

An oversampled spectral architecture requires a separate explicit design/ADR.

### Forbidden shortcuts

Do not silently move FFT into an oversampled block.

### Authoritative implementation

`dsp-generation.scm:generate-process-dsp-body`; `YATemplate/Source/PluginDSP.h` contexts.

### Relevant tests

Ordering assertions in `tests/scope-tap-points-test.scm`; generated process inspection.

## ADR-019 — Host Transport Is a Resource, Not Yet a DSL Semantic

### Decision

Host transport is template runtime state, not a formal transport-aware parameter DSL in Release 1.0.

### Context

Processor captures BPM, seconds, PPQ, playing, sample position, time signature, loop points, bar information, frame rate, edit origin, host time, recording, looping, channels, sample rate, inverse rate, and block length. Hosts may omit optional values.

### Rationale

Availability of raw transport state does not define musical subdivision, fallback, smoothing, or parameter semantics.

### Consequences

Developer DSP can currently access processor state. Generic BPM/subdivision controls are not a Release 1.0 semantic feature.

### Invariants

Documentation must distinguish captured resource data from supported DSL behavior.

### Allowed extensions

Design tempo-aware properties/roles/resources with fallback and realtime contracts in a future ADR.

### Forbidden shortcuts

Do not claim tempo sync merely because BPM is captured.

### Authoritative implementation

`YATemplate/Source/PluginProcessor.h/.cpp:processBlock`; processor pointer in `PluginDSP.h`.

### Relevant tests

No formal transport DSL test exists in Release 1.0; this absence is part of the limitation.

## ADR-020 — UTF-8 Is Explicit at Required C++ Boundaries

### Decision

Label-like `setText` generation uses Scheme string -> `string->utf8` bytes -> `\xHH` escapes -> `juce::String::fromUTF8(...)`.

### Context

Narrow source literals depend on compiler/source encoding and previously corrupted non-ASCII text.

### Rationale

Explicit bytes make generated label text portable and unambiguous.

### Consequences

Release 1.0 guarantees this for label, header, footer, link, and palette-label `setText`. Other string fields still use narrow literal escaping.

### Invariants

The JUCE expression is emitted as C++ code, never quoted as string content.

### Allowed extensions

Extend explicit UTF-8 to other fields with focused tests.

### Forbidden shortcuts

Do not claim universal UTF-8 coverage or revert label text to raw narrow literals.

### Authoritative implementation

`generator-app/cpp-generation-common.scm:cpp-utf8-string, label-properties->cpp`.

### Relevant tests

`tests/utf8-label-generation-test.scm`.

## ADR-021 — Project Identity Is Stable During Regeneration

### Decision

An existing destination directory preserves UUID/VST3 identity. A new destination receives a new identity. Deleting and recreating a project may produce a new identity.

### Context

Identity allocation is tied to new-project creation, not project-name lookup.

### Rationale

Regeneration must not break host plugin identity, while new projects must not reuse it.

### Consequences

Directory persistence is the Release 1.0 identity persistence mechanism.

### Invariants

Existing-project regeneration does not rerun UUID allocation.

### Allowed extensions

Future external identity registries require an explicit migration decision.

### Forbidden shortcuts

Do not promise name-based recovery after deleting output.

### Authoritative implementation

`generator.scm:MakeNewProject`; `generator-app/tools.scm:do-replace-uuid`; `uuid.txt`.

### Relevant tests

Regeneration/build integration; no dedicated identity test currently exists.

## ADR-022 — UI Metrics Are Canonical Logical Contracts

### Decision

`generator-app/ui-metrics.scm` is authoritative for logical footprints. Profiles are compact, preferred/standard, and useful-max/extended as represented by each current contract.

### Context

Duplicated historical dimensions caused obsolete topology fixtures.

### Rationale

One metric registry keeps normalization, layout, examples, and tests consistent.

### Consequences

Important preferred values include rotary 7x7, segmented vertical meter 1x14, and scope 18x10. Capability rules are advisory unless a current consumer explicitly uses them.

### Invariants

Layout obtains sizes through metric TYPE/variant/profile mapping.

### Allowed extensions

Change metrics deliberately together with affected canonical tests/documentation.

### Forbidden shortcuts

Do not copy old dimensions into solver code or fixtures as independent truth.

### Authoritative implementation

`generator-app/ui-metrics.scm`; `topological-normalizer.scm:metric-type-for-dsl-type, metric-contract`.

### Relevant tests

`tests/ui-metrics-test.scm`; `tests/topological-normalizer-test.scm`; `tests/topological-generated-layout-test.scm`.

## ADR-023 — Regeneration Mode Must Be Explicit

### Decision

Current Release/reference projects must pass `#:layout-mode 'physical` and topology declarations explicitly. The older `'topological` path remains available for logical-grid compatibility/tests.

### Context

`MakeNewProject` supports legacy and topological modes; legacy remains the default for compatibility.

### Rationale

Implicit legacy generation can appear successful without exercising the topological solver.

### Consequences

Frozen YAEnhancerR1 and post-freeze YASaturatorR1 use explicit physical generation. Historical pppbuttavia/topological tests remain evidence for the earlier path. Legacy mode may compute a diagnostic shadow but emits legacy geometry.

### Invariants

Validation of a topological interface must consume topologically resolved Grid output.

### Allowed extensions

Continue supporting legacy where current code does, with mode-specific tests.

### Forbidden shortcuts

Do not use legacy output as proof that topology works.

### Authoritative implementation

`generator.scm:GenerateC++, MakeNewProject`; `generation-orchestration.scm:prepare-generation-layout, generate-selected-grid-code`.

### Relevant tests

`tests/topological-generated-layout-test.scm`; `tests/topological-shadow-integration-test.scm`.

## ADR-024 — Tests Are Part of the Architectural Contract

### Decision

Architecture-sensitive behavior requires regression coverage. An intentional invariant change updates implementation, tests, and the governing ADR together.

### Context

Many failures are semantic/order/geometry regressions that compilation alone cannot detect.

### Rationale

Focused tests turn architectural statements into enforceable evidence.

### Consequences

Current examples cover scope taps/resources/order/shared scale, UTF-8 labels, hard-bypass output metering, metrics, topology normalization/solving/refinement/integration.

### Invariants

Tests must reflect canonical current metrics and must not weaken valid rejection merely to pass.

### Allowed extensions

Add pure/static tests where practical and generated build/integration checks where required.

### Forbidden shortcuts

Do not change a fixture blindly, delete a negative test, or treat a successful C++ build as complete semantic coverage.

### Authoritative implementation

`tests/scope-tap-points-test.scm`; `tests/utf8-label-generation-test.scm`; `tests/hard-bypass-output-meter-test.scm`; topology and UI metric test files.

### Relevant tests

The files above are themselves the executable evidence for this decision.

## ADR-025 — Standard Shell and Plugin Config Have Separate Authority

### Decision

The per-plugin standard config decides which standard elements exist and how they appear. The standard shell decides their semantic placement and integration.

Every component entry uses `enabled`, `display-name`, `tooltip`, `profile`, `width-scale`, and `height-scale`. `display-name` is presentation metadata and never changes logical `id`, `role`, `parameter-id`, or `processor-reference`. Visible support remains TYPE-dependent; the uniform config contract does not invent missing meter/scope/title properties.

Optional shell controls include Auto Gain, Delta Monitor, Safety Limiter, and CEILING. Delta and limiter processing are generated capabilities. Auto Gain placement is standardized, while its current compensation is consumed in the reference plugins' developer-owned DSP.

### Invariants

Do not modify the standard shell for plugin-local aesthetics. Do not derive semantics or parameter identity from display text. Do not duplicate a standard stage in PluginDSP.

### Authoritative implementation

`generator-app/standard-plugin-shell.scm`; `generator-app/dsp-generation.scm`; `plugins/YAEnhancerR1.scm`; `plugins/YASaturatorR1.scm`.

## ADR-026 — Physical Layout Is the Current Reference Path

### Decision

The current Release 1.0 reference path is:

```text
DSL components -> LogicalTopology -> topological normalization
-> PhysicalLayout -> DiscreteGridLayout v2
-> generation adapter -> JUCE Grid runtime
```

LogicalTopology owns relations, stacks, areas, alignments, and logical sizing. PhysicalLayout resolves exact physical geometry using screen dimensions, base unit, UI scale/size, UI metrics, and policy. DiscreteGridLayout v2 derives unique physical boundaries, variable tracks, and verifies exact reconstruction. Solvers remain in Scheme; generated C++ receives resolved grid data.

Legacy and earlier logical-grid topological modes remain compatibility paths, not evidence that the physical reference path was exercised.

### Authoritative implementation

`generator-app/topological-normalizer.scm`; `physical-layout.scm`; `discrete-grid-layout.scm`; `generation-orchestration.scm`; `layout.scm`.

## ADR-027 — Release References, Channel Policy, and Project Files

### Decision

`YAEnhancerR1` is the frozen Release 1.0 architectural reference and changes after freeze only for demonstrated bugs. `YASaturatorR1` is the first post-freeze reuse proof and does not replace it. pppbuttavia is historical/example material.

Release 1.0 officially supports mono/stereo. Naturally channel-independent developer DSP should iterate `AudioBlock::getNumChannels()`; 5.1, 7.1, immersive bus topology, semantic channel roles, and multichannel observation/routing are future work.

After initial creation, `JX11.jucer` is treated as immutable. A Projucer resave may change its hash, but incidental resave churn is not an intentional plugin update. `PluginDSP.h` remains developer-owned.

### Forbidden shortcuts

Do not patch a frozen reference for unrelated development, hard-code stereo unnecessarily, claim multichannel buses as implemented, or include automatic JUCER churn as a normal intentional change.

## ADR-028 — Safety Limiter Provides a Sample-Peak Ceiling

### Decision

Safety Limiter is an optional generated capability, OFF by default. CEILING is `-6.0 .. 0.0 dB`, default `-0.5 dB`, step `0.1 dB`; release is internal and fixed at 100 ms. It is sample-peak protection, not True Peak.

JUCE `Limiter::setThreshold` is not treated as the final ceiling control. Generated processing normalizes the limiter domain and scales its output so the final sample peak follows CEILING. The limiter is after Output Gain and before Output Meter; Hard Bypass returns before it, while DSP Bypass does not bypass it.

### Authoritative implementation

`generator-app/dsp-generation.scm`; `tests/safety-limiter-generation-test.scm`; `tests/safety-limiter-dsp-numeric-test.cpp`.

## Release 1.0 invariants

Before changing this repository, verify all of the following:

- TYPE != ROLE; PROPERTY != RESOURCE.
- A generated project is not a source of truth.
- The registered validated alist model is the current semantic IR.
- Invalid DSL/topology is rejected in Scheme before C++ generation.
- The topological solver stays in Scheme; generated C++ receives resolved geometry.
- Areas are anchors/bounds, not exclusive occupancy regions.
- Groups are flat; nested groups are unsupported.
- UI footprints come from `ui-metrics.scm`.
- No allocation, resizing, locks, I/O, UI work, or blocking calls occur in realtime processing.
- Maximum host latency is fixed during prepare and every relevant path preserves it.
- Meters represent plugin input/output boundaries.
- Scope represents PRE/POST DSP observation; both traces share one time axis, zero, and amplitude scale.
- Output gain does not affect scope traces.
- Hard bypass is not DSP bypass.
- Hard bypass keeps I/O meters active and freezes scope observation.
- FFT runs at host sample rate before oversampled time-domain DSP.
- YATemplate/KineticLookAndFeel owns generic visual rendering; it contains no component-ID/role semantics.
- `PluginDSP.h` remains developer-owned.
- Current reference generation passes `#:layout-mode 'physical` explicitly.
- Architectural changes include corresponding tests and ADR updates.

## Extension checklist

1. Identify whether the proposal is a TYPE, ROLE, PROPERTY, RESOURCE, renderer change, or combination.
2. Identify the authoritative source file before editing; never begin with generated output.
3. Define invalid states and Scheme validation first.
4. Check APVTS family reuse before adding parameter special cases.
5. State DSP insertion point and effects on taps, bypasses, wet/dry, oversampling, and latency.
6. Prove realtime bounds and prepare all resources outside processing.
7. For layout, use canonical metrics and explicit relations; do not assume area exclusivity or nested groups.
8. Keep generic visuals in authoritative KineticLookAndFeel and configuration in generated properties/wiring.
9. Add focused negative and positive tests; regenerate explicitly in the intended mode.
10. Inspect generated consequences, run relevant Scheme tests, and clean-build required targets.
11. If a frozen invariant changes, add/supersede an ADR rather than silently redefining Release 1.0.

## Explicit non-goals / known limitations

These are deliberate Release 1.0 boundaries, not defects:

- Groups cannot nest.
- Areas do not guarantee collision avoidance or inter-group non-overlap.
- There is no generic BPM/subdivision semantic DSL; captured BPM alone is not tempo sync.
- Scope supports only PRE and POST DSP taps, singly or together.
- Hard bypass freezes the last scope display.
- Explicit UTF-8 conversion is guaranteed for label-like `setText`, not every C++ textual field.
- UUID persistence is based on retaining the generated project directory; delete/recreate may allocate a new identity.
- Host transport fields depend on what the host supplies.
- Wet/dry uses the current linear mixing law.
- FFT is host-rate and precedes the intentionally fixed 1x/2x/4x/8x time-domain oversampling architecture.
- `fft-size` is consumed semantically but is not included in the current enforced unique-role list.
