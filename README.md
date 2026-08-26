# JUCE Plugin Generator

JUCE Plugin Generator is a Scheme-based generator for JUCE audio-plugin projects. A declarative GOOPS DSL describes UI components, semantic roles, APVTS parameters, properties, and topological relationships; the generator produces JUCE project wiring and DSP infrastructure while the effect developer implements the algorithm in developer-owned `PluginDSP.h`.

## What it is

The project separates graphical identity from runtime semantics. An interface author chooses a component TYPE, assigns a generator-recognized ROLE only when generic behavior is required, configures instance PROPERTY values, and binds automatable state to APVTS. Runtime RESOURCEs such as meter atomics, scope FIFOs, FFT/STFT objects, oversamplers, and latency buffers are generated as consequences rather than authored as UI types.

The generated project includes GUI declarations and attachments, parameter layout, topological layout data, signal observation, bypass, wet/dry, FFT, oversampling, and fixed-latency orchestration. Generic visuals live in YATemplate’s KineticLookAndFeel. Effect-specific processing belongs in `YATemplate/Source/PluginDSP.h`.

## Release 1.0 highlights

- Scheme/GOOPS interface DSL and JUCE project generation.
- Float, bool, and choice APVTS parameters with JUCE attachments.
- Explicit Scheme-side topological layout solving and exact rational refinement.
- Generator-managed input/output gain and plugin-I/O meters.
- Single or dual PRE/POST DSP waveform scope.
- Distinct hard-bypass and DSP-bypass behavior.
- Generator-owned wet/dry capture, alignment, and linear mixing.
- FFT choices Off, 256, 512, 1024, 2048, 4096, and 8192.
- Oversampling choices Off/1x, 2x, 4x, and 8x.
- Fixed host-latency contract, including developer-only latency without FFT/oversampling controls.
- KineticLookAndFeel, procedural theme background, and 18 palettes.
- Developer DSP extension through separate `RealPlugin` and `FFTProcessor` APIs.
- Normative documentation for interface authors, DSP/generator developers, and LLM agents.

## Quick start

From this repository, the canonical source-first command for the reference interface is:

```sh
GUILE_AUTO_COMPILE=0 \
GUILE_LOAD_COMPILED_PATH="" \
GUILE_LOAD_PATH="$PWD${GUILE_LOAD_PATH:+:$GUILE_LOAD_PATH}" \
guile --no-auto-compile -L . -l generator.scm -c \
'(MakeNewProject
   "pppbuttavia"
   NewGeneric-interface
   #:layout-mode (quote topological)
   #:topology-declarations pppbuttavia-topology)'
```

`MakeNewProject` writes or updates the target project directory in the configured JUCE development workspace, replaces generator-owned marked sections, synchronizes the two Kinetic support files for existing projects, and invokes Projucer to resave the project.

For interfaces authored with topological declarations, always request topological mode explicitly:

```scheme
#:layout-mode 'topological
```

The generator also supports a legacy layout mode, but it is not a substitute for topological resolution and can produce materially different geometry.

## Minimal example

This complete example creates two semantic gain controls and a DSP-bypass toggle. Every slider/toggle supplies the mandatory APVTS binding tuple.

```scheme
(define (Minimal-interface dst-folder new-name)
  (make <screen> #:ratio 1.6 #:width 800)
  (make <grid> #:rows 12 #:cols 24 #:show-grid #f)

  (make <rotary-slider>
    #:id "input-gain"
    #:role 'input-gain
    #:parameter-id "inputGain"
    #:parameter-name "Input Gain"
    #:processor-reference "inputGain"
    #:title "INPUT"
    #:min -24.0 #:max 24.0 #:default 0.0 #:interval 0.1
    #:value-type 'gain #:suffix " dB"
    #:row 2 #:col 2)

  (make <rotary-slider>
    #:id "output-gain"
    #:role 'output-gain
    #:parameter-id "outputGain"
    #:parameter-name "Output Gain"
    #:processor-reference "outputGain"
    #:title "OUTPUT"
    #:min -24.0 #:max 24.0 #:default 0.0 #:interval 0.1
    #:value-type 'gain #:suffix " dB")

  (make <normal-toggle-button>
    #:id "dsp-bypass"
    #:role 'dsp-bypass
    #:text "DSP BYPASS"
    #:default-state #f
    #:parameter-id "dspBypass"
    #:parameter-name "DSP Bypass"
    #:processor-reference "dspBypass"))

(define minimal-topology
  (list
   (lt:group 'main-strip
     #:layout 'horizontal
     #:cross-align 'center
     #:gap 1
     'input-gain
     'output-gain
     'dsp-bypass)))

(MakeNewProject
  "minimal-plugin"
  Minimal-interface
  #:layout-mode 'topological
  #:topology-declarations minimal-topology)
```

The high-level normalizer derives logical component spans from canonical UI metrics. The first component’s `row`/`col` values act as anchors; the flat group determines ordering, one-unit gaps, and cross-axis alignment.

## Core mental model

```text
TYPE      graphical component, for example rotary-slider
ROLE      generator-owned meaning, for example input-gain
PROPERTY  instance configuration such as range, title, or tap-points
RESOURCE  generated runtime state such as a meter atomic or scope FIFO
```

Most effect-specific controls do not need a new ROLE. For example, `reverb-depth` is normally an ordinary bound slider whose cached value is interpreted by PluginDSP.

See [Architecture Decisions](docs/ARCHITECTURE_DECISIONS.md) for the frozen model and [User Interface Guide](docs/USER_INTERFACE_GUIDE.md) for practical classification and authoring workflows.

## Topological layout

Topological mode derives node dimensions from logical UI metrics, combines them with relations, alignments, flat groups, gaps, cohesion, and hierarchical area anchors, and solves horizontal and vertical axes in Scheme. Exact rational coordinates are refined independently into integer rows/columns before the existing JUCE Grid emitter receives them.

```scheme
(lt:group 'audio-strip
  #:layout 'horizontal
  #:cross-align 'center
  #:gap 0
  'input-meter
  'input-gain)
```

Groups are flat: group IDs cannot be members of other groups. Areas are anchors/bounds, not exclusive containers or automatic collision-avoidance regions. Use explicit relationships when independently placed structures must not overlap.

See the [Topological Layout Guide](docs/TOPOLOGICAL_LAYOUT_GUIDE.md).

## DSP development

The generator owns this processing orchestration:

```text
HOST INPUT
 -> INPUT METER
 -> HARD BYPASS
 -> INPUT GAIN
 -> PRE SCOPE
 -> DRY CAPTURE
 -> FFT
 -> OVERSAMPLING / RealPlugin
 -> LATENCY COMPENSATION
 -> WET/DRY
 -> POST SCOPE
 -> OUTPUT GAIN
 -> OUTPUT METER
 -> HOST OUTPUT
```

The effect developer implements the actual algorithm in:

```text
YATemplate/Source/PluginDSP.h
```

`RealPlugin` implements time-domain processing for separately prepared 1x/2x/4x/8x instances. `FFTProcessor` implements optional spectral processing for separate supported FFT sizes. `PluginDSP.h` is developer-owned and excluded from generator support synchronization.

Do not implement an effect by patching generated `processBlock`. Generated projects are inspection/build artifacts; generator defects belong in Scheme and generic renderer defects belong in authoritative YATemplate.

See the [DSP Developer Guide](docs/DSP_DEVELOPER_GUIDE.md).

## Documentation

| Document | Use it for |
|---|---|
| [Release 1.0](docs/RELEASE_1.0.md) | Release scope, verified evidence, boundaries, and final checklist. |
| [Architecture Decisions](docs/ARCHITECTURE_DECISIONS.md) | Frozen invariants and source-of-truth rules. |
| [DSL Reference](docs/DSL_REFERENCE.md) | Exact constructors, properties, roles, defaults, and validation. |
| [User Interface Guide](docs/USER_INTERFACE_GUIDE.md) | Practical interface design and natural-language-to-DSL workflows. |
| [Topological Layout Guide](docs/TOPOLOGICAL_LAYOUT_GUIDE.md) | Layout declaration syntax and solver semantics. |
| [DSP Developer Guide](docs/DSP_DEVELOPER_GUIDE.md) | PluginDSP APIs, realtime constraints, FFT/oversampling, transport, and latency. |
| [Generator Developer Guide](docs/GENERATOR_DEVELOPER_GUIDE.md) | Generator architecture and safe extension recipes. |
| [LLM Development Guide](docs/LLM_DEVELOPMENT_GUIDE.md) | Compact operational guardrails for repository-modifying agents. |

Recommended reading paths:

- Interface author: User Interface Guide → DSL Reference → Topological Layout Guide as needed.
- DSP developer: DSP Developer Guide → DSL Reference as needed.
- Generator developer: Generator Developer Guide → Architecture Decisions.
- LLM/coding agent: LLM Development Guide → Architecture Decisions → focused manual for the task.

## Reference example

pppbuttavia is the current generated reference/validation plugin. It demonstrates input/output meters and gains, dual PRE/POST scope, wet/dry, oversampling, FFT size, hard/DSP bypass, and palette selection in a substantial topological interface.

It is evidence of generated consequences, not the authoritative implementation source. Do not depend on its resolved coordinates or patch it as the primary generator fix.

## Release status

Release 1.0 is a release-ready baseline pending the final `v1.0.0` tag. No tag exists at the time of this README rewrite.

Verified release evidence currently covers:

- Linux Release Standalone: verified.
- Linux Release VST3: verified.
- Focused Scheme validation, metrics, topology, scope, meter, latency, and UTF-8 regression tests: passing at release-definition verification.

No Windows or macOS release certification is claimed. See [Release 1.0](docs/RELEASE_1.0.md) for the evidence matrix and remaining final-release actions.

## Requirements and verified platform

Repository-proven workflow dependencies are:

- GNU Guile with the Scheme modules used by the generator;
- JUCE modules and Projucer at the paths configured for the workspace;
- `rsync` for initial template copying;
- Zenity for the current project-generation UI checks/notifications;
- a C++ toolchain and platform build tools generated by Projucer.

The repository records no portable minimum-version contract for these dependencies, so none is claimed here. Current release build evidence is Linux Makefile, Standalone, and VST3 only.

## Current boundaries

- Topological groups are flat.
- Areas are non-exclusive; no general packing solver is provided.
- Generic BPM/subdivision synchronization is not a Release 1.0 DSL semantic.
- Scope taps are limited to PRE and POST DSP observation.
- Explicit UTF-8 conversion is not universal across every textual field.
- Linux is the currently verified release-build platform.

The complete limitations and non-goals are in [Release 1.0](docs/RELEASE_1.0.md).

## License and project links

JUCE Plugin Generator is licensed under the [MIT License](LICENSE).

Copyright © 2025 Franco Arcieri (`afrrcainecroi`).
