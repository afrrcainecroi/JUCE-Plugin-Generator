# JUCE Plugin Generator — LLM Development Guide

## 1. Mission

Modify JUCE-Plugin-Generator Release 1.0 at the smallest responsible layer while preserving its frozen architecture. Prove current behavior from source and tests before editing. Prefer focused validation and generation tests before project regeneration or C++ builds. Never broaden scope silently.

This is an operational guardrail. Use the focused manuals for full syntax, topology, DSP, generator, and interface-authoring detail.

## 2. Source-of-truth order

Use this precedence for implementation claims:

1. current authoritative source;
2. current tests;
3. `docs/ARCHITECTURE_DECISIONS.md`;
4. the focused Release 1.0 manuals;
5. generated output as evidence;
6. README or historical notes only when consistent with current source.

Authority map:

- Generator: `generator.scm`, `generator-app/*.scm`.
- Generic JUCE/template: `YATemplate/Source/*`, `YATemplate/JX11.jucer`.
- Developer DSP: `YATemplate/Source/PluginDSP.h`.
- Generated projects, including pppbuttavia: output/evidence, not authority.

Never “fix” a generator defect only in pppbuttavia. Trace wrong output back to its Scheme emitter or authoritative YATemplate source.

## 3. First classify the change

Before broad inspection or edits, state the classification:

| Request | Classification |
|---|---|
| New graphical widget | TYPE |
| Generic input-gain behavior | ROLE |
| Scope `tap-points` | PROPERTY |
| PRE/POST scope FIFOs | RESOURCE |
| Reverb depth | ordinary APVTS parameter + PluginDSP, normally no ROLE |
| New meter colour | generic renderer/property, not DSP ROLE |
| New spatial relation | topological/layout feature |
| New parameter representation | parameter-family feature |
| Packaging or identity behavior | project/release tooling |

TYPE is graphical identity. ROLE is generator-owned semantics. PROPERTY configures an instance. RESOURCE is runtime state and is not a GOOPS base class. Also identify requests which are developer-DSP-only or generic renderer changes.

## 4. Repository ownership map

- DSL classes/models: `generator-app/dsl-model.scm`, `genera-classi.scm`.
- Validation/registration: `validation.scm`, `registration.scm`.
- State/protocols: `generation-state.scm`, `globals.scm`, `generation-protocols.scm`.
- GUI/APVTS emission: `cpp-generation.scm`, `cpp-generation-common.scm`.
- DSP/resource emission: `dsp-generation.scm`.
- Metrics/topology: `ui-metrics.scm`, `topological-normalizer.scm`, `topological-layout.scm`, `generation-orchestration.scm`, `layout.scm`.
- Project resources/tooling: `resources.scm`, `tools.scm`, `generator.scm`.
- Generic visuals: authoritative `YATemplate/Source/KineticLookAndFeel.h/.cpp`.
- Effect algorithm: developer-owned `YATemplate/Source/PluginDSP.h`.

Existing-project regeneration synchronizes only the two Kinetic files. Do not mirror the template broadly or overwrite PluginDSP.

## 5. Mandatory architectural invariants

| MUST preserve | MUST NOT |
|---|---|
| TYPE != ROLE | invent a ROLE for styling |
| PROPERTY != RESOURCE | invent a TYPE for semantics |
| generated output != authority | hard-code component IDs in generic code |
| validate before C++ generation | allocate or lock in realtime processing |
| topology solver remains in Scheme | access GUI objects from DSP |
| canonical metrics come from `ui-metrics.scm` | normalize dual scope traces independently |
| groups are flat | nest groups |
| areas are non-exclusive anchors/bounds | assume areas prevent overlap |
| exact adjacency differs from partial order | weaken contradiction detection |
| fixed DSP stage order | reorder stages casually |
| meters represent plugin I/O | use a meter as a DSP analyzer |
| scope represents PRE/POST DSP observation | let Output Gain affect scope |
| PRE/POST use one scale/time axis | create separate normalization |
| hard bypass != DSP bypass | collapse bypass meanings |
| fixed host latency remains fixed | change host latency at runtime |
| developer latency works without FFT/OS | gate latency support on FFT/OS roles |
| FFT precedes oversampling | move FFT into oversampled domain silently |
| YATemplate owns generic rendering | patch only a generated Kinetic copy |
| PluginDSP remains developer-owned | overwrite it during regeneration |
| reference generation explicitly uses topological mode | assume legacy and topology are equivalent |
| explicit UTF-8 expressions stay expressions | quote `cpp-utf8-string` output again |
| BPM sync remains developer DSP in 1.0 | assume generic tempo-sync semantics exist |
| `fft-size` uniqueness is only a convention today | assume current validation enforces it |

## 6. Change workflows

### Add a TYPE

1. Add GOOPS class, inheritance, slots, and defaults.
2. Add `component-type` and `component->model`.
3. Add validation.
4. Decide registration/parameter family.
5. Add canonical UI metrics and normalizer mapping.
6. Emit C++ member, initialization, and properties.
7. Add APVTS/attachment only if applicable.
8. Put generic visuals in YATemplate.
9. Add focused validation, metric, generation, topology, and documentation updates.

### Add a ROLE

First ask: **Does the generator itself need generic semantic behavior?** If no, use an ordinary APVTS parameter and PluginDSP.

If yes: define compatible TYPES; cardinality/uniqueness; validation; generic parameter consumption; exact process stage; both bypass behaviors; scope/gain relationship; latency; runtime resources; static ordering tests; documentation.

### Add a PROPERTY

Follow: slot/default → model → validation → accessor/export if needed → emitter → renderer/runtime consequence → tests → docs. Scope `tap-points` is the canonical pattern. A PROPERTY may conditionally generate RESOURCES without becoming a ROLE.

### Add a RESOURCE

Specify owner, lifetime, generated versus template ownership, allocation point, reset/release, audio-thread and message-thread access, synchronization, conditional cost, naming, and tests. Allocate during construction/prepare, never `processBlock`.

### Add a parameter family

Update registration predicates, binding validation, parameter and attachment emitters, raw access/caching, GUI lifetime, conversions, tests, and DSL documentation. Do not special-case one ROLE if the parameter semantics are family-generic.

### Add a DSP stage

Before code, specify exact position, hard/DSP-bypass semantics, PRE/POST scope relationship, gain relationship, wet/dry relationship, FFT/oversampling domain, latency contribution, and realtime resources. A stage-order change requires an explicit architecture decision.

### Add topology or rendering behavior

For a relation, define axis, equation/inequality, hard/soft meaning, reverse edge for equality, validation, contradictions, rational behavior, and tests. Keep solving in Scheme.

For generic appearance, emit configuration from Scheme and implement rendering in authoritative KineticLookAndFeel. Never branch on a reference-plugin ID.

### Task execution template

1. Read the relevant normative documents.
2. Inspect current authoritative source and focused tests.
3. State the TYPE/ROLE/PROPERTY/RESOURCE or other classification.
4. Prove and state current behavior.
5. Identify the smallest responsible-layer change.
6. List invariants which must remain unchanged.
7. Implement narrowly and preserve unrelated work.
8. Add or update the smallest focused tests.
9. Run relevant regressions.
10. Regenerate only when generated output is affected.
11. Build when generated C++ changed materially.
12. Report exact files, functions, behavior, tests, and remaining limitations.
13. Do not stage or commit unless explicitly requested.

## 7. DSP and realtime rules

Normal Release 1.0 order is fixed:

```text
HOST INPUT -> INPUT METER -> HARD BYPASS -> INPUT GAIN -> PRE SCOPE
-> DRY CAPTURE -> FFT -> OVERSAMPLING / RealPlugin
-> LATENCY COMPENSATION -> WET/DRY -> POST SCOPE
-> OUTPUT GAIN -> OUTPUT METER -> HOST OUTPUT
```

FFT runs at host sample rate before factor-specific 1x/2x/4x/8x RealPlugin processing. RealPlugin instances are separate. FFTProcessor instances are separate for every supported FFT size.

Fixed maximum latency is:

```text
max FFT contribution
+ max oversampling contribution
+ max developer RealPlugin latency
```

Developer latency is valid without FFT/oversampling roles. Every plugin evaluates it during prepare across prepared RealPlugin instances. `latency-infrastructure-required?` is intentionally unconditional. Delay audio storage and realtime delay loops activate only when maximum > 0. `getLatencySamples()` is in host samples. Call `setLatencySamples(maximum)` at prepare; do not vary it with runtime controls.

Never allocate, resize containers, lock mutexes, access filesystem/UI/network, sleep, perform blocking logging, or construct/destroy objects in `processBlock`, `processAudio`, or `processFFT`. Use prepared fixed buffers, stack state, bounded loops, and existing atomics. Stop if the proposal requires unbounded realtime work.

Parameter families are slider → float, toggle/switch → bool, and bound selector → choice. Sliders and toggle/switch families require nonempty `parameter-id`, `parameter-name`, and `processor-reference`. Selectors may remain UI-only. Roles consume generic cached parameter values; do not duplicate parameter creation.

## 8. Layout rules

- Preferred footprints come from `ui-metrics.scm`; do not copy stale dimensions.
- The normalizer derives solver nodes from registered models and TYPE variants.
- Horizontal and vertical axes solve independently.
- `next-*` is exact adjacency; `right-of`/`left-of`/`above`/`below` is partial ordering.
- Use group `gap`, not dummy spacer nodes.
- Groups contain node IDs only; nesting is unsupported.
- Cohesion is a soft preference and never overrides hard constraints.
- Recursive-third areas constrain/anchor bounds but do not reserve space.
- Exact rational coordinates are intentional.
- Refinement uses independent `dx` and `dy`; final C++ receives integer geometry only.

When a topology test fails, trace metric → normalizer → constraints/area capacity → solver → refinement. Do not weaken contradiction detection to rescue an obsolete fixture. Prove whether the canonical metric/fixture or implementation is wrong.

## 9. Generated-code and rendering rules

Generated plugins are valid for inspecting emitted C++, proving stage order, compiling, visual testing, and measurement. They are not the primary edit target.

Trace defects backward:

```text
generated C++ -> emitter or template -> registered model -> validation/DSL
```

Generic appearance belongs in:

```text
YATemplate/Source/KineticLookAndFeel.h
YATemplate/Source/KineticLookAndFeel.cpp
```

The generator emits generic properties/configuration. Do not put role-specific DSP semantics in the renderer. Regeneration of an existing project synchronizes those two files and excludes PluginDSP.

For label-like UTF-8, `cpp-utf8-string` returns `juce::String::fromUTF8("\xHH...")`, a complete C++ expression. Never wrap it in another quoted literal. Explicit conversion is not universal to every text field.

## 10. Testing rules

Add the smallest focused test first:

| Change | First evidence |
|---|---|
| DSL/validation | pure Scheme validation test |
| DSP stage/order | static generated-code ordering test |
| topology | solver + normalizer + integration test |
| renderer/property | source/static property test, then visual generation if useful |
| latency | generation contract test, then build integration |
| UTF-8 | exact generated-expression/byte test |

Then run relevant regressions. Compilation proves C++ integration, not DSL correctness. Never alter a test merely to conceal a real regression. If an expectation is obsolete, prove the canonical source/metric/architecture change first and update only the minimum fixture.

Regenerate only when generated consequences matter. For reference pppbuttavia use:

```sh
GUILE_AUTO_COMPILE=0 guile -L . -l generator.scm -c \
  '(MakeNewProject "pppbuttavia" NewGeneric-interface #:layout-mode (quote topological) #:topology-declarations pppbuttavia-topology)'
```

This may invoke Zenity; follow the required warning procedure. Accidental legacy generation can produce materially different geometry. Use `GUILE_AUTO_COMPILE=0` during source-first validation to avoid stale Guile cache observations.

## 11. Documentation rules

When intentionally changing frozen behavior, update implementation, focused tests, the relevant normative manual, and compatibility consequences. Do not silently let documentation drift.

- DSL syntax/validation → `DSL_REFERENCE.md`
- layout → `TOPOLOGICAL_LAYOUT_GUIDE.md`
- DSP contract → `DSP_DEVELOPER_GUIDE.md`
- generator internals → `GENERATOR_DEVELOPER_GUIDE.md`
- interface authoring → `USER_INTERFACE_GUIDE.md`
- architectural invariant → `ARCHITECTURE_DECISIONS.md`

Use current source/tests; do not revive README future-work as implemented behavior.

## 12. Stop-and-escalate conditions

Stop before implementation if the request requires:

- changing a frozen ADR/invariant;
- reordering DSP stages;
- changing fixed-latency or hard-versus-DSP-bypass semantics;
- nested groups, exclusive areas, packing, or arbitrary routing graphs;
- new generic BPM-sync semantics;
- replacement of the registered-alist semantic model;
- project identity rule changes;
- broad template mirroring;
- realtime allocation/blocking;
- uncertain overwrite of developer-owned files.

Report the requested behavior, current invariant, smallest architecture decision required, affected subsystems, compatibility impact, and tests needed. Do not silently broaden scope.

## 13. Common failure patterns

| Symptom | Wrong approach | Correct layer |
|---|---|---|
| Visual styling request | add ROLE | property + Kinetic renderer |
| DSP-specific knob | add ROLE | ordinary APVTS + PluginDSP |
| Scope too small | C++ resize hack | metric/topology |
| Wrong scope signal | renderer hack | DSP tap semantics/resource |
| Meter sticks | drawing-only guess | prove processor observation vs timer consumption vs renderer |
| UTF-8 mojibake | guess another glyph | explicit UTF-8 emitter |
| Topology contradiction | weaken solver | inspect metric, fixture, hard constraints |
| Stale Kinetic result | edit generated copy | authoritative YATemplate + regeneration |
| Developer latency absent | require FFT role | generic fixed-latency contract |
| Tempo subdivision | invent BPM ROLE | parameter + PluginDSP in 1.0 |
| Generated C++ wrong | patch output | trace emitter/template/model |
| Custom state in audio path | allocate/lock | prepare fixed resources |

## 14. Ready-to-copy agent checklist

```text
Read the relevant Release 1.0 normative docs before editing.
Inspect current authoritative source and tests; ignore stale README claims.
Classify the request: TYPE, ROLE, PROPERTY, RESOURCE, DSP, layout,
renderer, parameter family, or tooling.
State current behavior and the smallest responsible layer.
Never patch generated pppbuttavia as the primary fix.
TYPE != ROLE; PROPERTY != RESOURCE.
Do not invent roles for styling or ordinary effect parameters.
Validate representable errors in Scheme before C++ generation.
Preserve generic float/bool/choice APVTS families.
Require complete nonempty binding tuples for sliders/toggles/switches.
Keep the fixed DSP stage order unless an ADR change is explicitly approved.
Meters observe plugin I/O; scope observes PRE/POST DSP.
PRE/POST scope traces share one scale; Output Gain does not affect them.
Hard bypass and DSP bypass are different.
Preserve fixed maximum host latency.
Developer latency must work without FFT or oversampling roles.
FFT runs at host rate before oversampling.
Never allocate, resize, lock, block, or touch UI in realtime processing.
Keep topology solving and rational refinement in Scheme.
Use canonical ui-metrics; do not hard-code historical dimensions.
Exact adjacency is not partial ordering.
Groups are flat; never nest them.
Areas are non-exclusive anchors/bounds, not containers.
Do not weaken contradiction detection to pass a fixture.
Put generic rendering in authoritative YATemplate Kinetic files.
Never hard-code reference-plugin component IDs in generic code.
Keep PluginDSP.h developer-owned and outside support synchronization.
Treat cpp-utf8-string output as a complete C++ expression.
Do not claim generic BPM-sync semantics exist.
Do not assume fft-size uniqueness is enforced.
Add the smallest focused validation/generation/order test first.
Run relevant regressions; compile only as integration evidence.
Regenerate reference projects with explicit topological mode.
Inspect generated output as evidence, not authority.
Update the smallest relevant normative manual when behavior changes.
Stop and report before changing an invariant or broadening architecture.
Do not stage or commit unless explicitly requested.
```

## 15. Release 1.0 known limitations

- Groups are flat; nested groups are unsupported.
- Areas are non-exclusive; no generic packing/non-overlap solver exists.
- No generic BPM-sync/subdivision semantic exists.
- Scope supports PRE and POST taps only; hard bypass freezes its snapshot.
- `fft-size` uniqueness is not enforced like other global roles.
- Explicit UTF-8 conversion is not universal across all textual fields.
- Host transport values are host-dependent.
- DSP parameter access is not a strongly typed developer API.
- State continuity across separate oversampling-factor instances is not guaranteed.
- Existing-project support synchronization uses a two-file allow-list.
- UUID persistence depends on retaining the destination directory.
- No arbitrary routing graph is represented.
- Linux is the currently verified Release build platform.
- There is no single canonical all-tests runner.
