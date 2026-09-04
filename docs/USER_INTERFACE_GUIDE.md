# JUCE Plugin Generator — User Interface Guide

## 1. Purpose

This guide teaches how to design a complete Release 1.0 plugin interface with JUCE-Plugin-Generator. It is for interface authors, DSP developers exposing controls, and LLMs translating a product description into valid Scheme DSL.

This is a design workflow, not the exhaustive syntax reference. Consult `DSL_REFERENCE.md` for every constructor and slot, `TOPOLOGICAL_LAYOUT_GUIDE.md` for solver semantics, `ARCHITECTURE_DECISIONS.md` for invariants, and `DSP_DEVELOPER_GUIDE.md` for effect implementation.

## 2. Interface-design mental model

Translate each requirement through the same sequence:

```text
USER REQUIREMENT
  -> graphical TYPE
  -> semantic ROLE, only if Release 1.0 provides generic behavior
  -> PROPERTY configuration
  -> APVTS binding, when state/automation is required
  -> canonical logical metric
  -> topological relationships
  -> developer DSP meaning, when effect-specific
```

- **TYPE** answers “what graphical control is this?”
- **ROLE** answers “does the generator itself give it generic signal/runtime meaning?”
- **PROPERTY** configures this instance.
- **RESOURCE** is a runtime consequence such as an atomic peak or scope FIFO. Interface authors normally do not instantiate resources directly.

Examples:

```text
“input gain”
  -> <rotary-slider> or <linear-slider>
  -> role input-gain
  -> dB range/display properties
  -> bound AudioParameterFloat

“dual analyzer”
  -> <scope>
  -> role scope
  -> tap-points '(pre-dsp post-dsp)
  -> PRE/POST resources generated automatically

“reverb depth”
  -> <rotary-slider>
  -> no generic reverb-depth role
  -> ordinary bound float parameter
  -> PluginDSP interprets the cached value
```

This classification prevents the two most common design errors: inventing semantic TYPES and inventing ROLEs for ordinary effect parameters.

## 3. From natural language to DSL

For every requested item, ask:

1. Is it visual/informational only?
2. Does Release 1.0 define a semantic ROLE for it?
3. Is the variation only a PROPERTY of an existing TYPE?
4. Must the host save or automate it?
5. Does its actual meaning belong in developer DSP?
6. Is the request only about layout?

| Requirement | TYPE | ROLE | Parameter/property | DSP responsibility |
|---|---|---|---|---|
| Input gain | slider | `input-gain` | bound float, dB range | none; generator applies it |
| Output gain | slider | `output-gain` | bound float, dB range | none; generator applies it |
| Input meter | meter | `input-meter` | meter display properties | none |
| Output meter | meter | `output-meter` | meter display properties | none |
| Dual scope | scope | `scope` | `tap-points` PRE+POST | none for observation |
| Wet/dry | slider | `wet-dry` | bound float | developer outputs wet signal |
| Hard bypass | toggle/switch | `bypass` | bound bool | generator bypasses chain |
| DSP bypass | toggle/switch | `dsp-bypass` | bound bool | generator skips central DSP |
| Oversampling | stepped slider | `oversampling` | bound 0..3 integer-like float | DSP must be oversampling-safe |
| FFT size | stepped slider | `fft-size` | bound 0..6 integer-like float | `FFTProcessor` implements spectral work |
| Theme | palette-selector | none | palette items/default | none |
| Reverb depth | slider | none | ordinary bound float | PluginDSP |
| Reverb persistence | slider | none | ordinary bound float | PluginDSP |
| Tempo subdivision | selector/stepped slider | none | ordinary bound choice/float | PluginDSP combines it with BPM |

Do not invent a ROLE because a user uses a semantic noun. A ROLE is warranted only when the generator owns generic behavior.

## 4. Choosing TYPE

- Use `<rotary-slider>` for compact continuous values and small stepped sets where circular interaction is appropriate.
- Use `<linear-slider>` when direction, range, or comparison benefits from an explicit axis; set `#:orientation` to `'horizontal` or `'vertical`.
- Use `<selector>` for discrete choices whose text must remain unambiguous.
- Use `<normal-toggle-button>` for a compact binary control with its own title.
- Use `<switch>` for a switch-style binary presentation.
- Use `<bypass-switch>` only for the current bypass-oriented visual subtype; the ROLE—not TYPE—still determines hard-bypass behavior.
- Use `<meter>` for observed audio level. A meter is not editable and creates no parameter.
- Use `<scope>` for waveform/DSP-stage observation, not parameter editing or frequency-spectrum display.
- Use `<label>`, `<header>`, `<footer>`, `<link>`, and `<palette-label>` for information, hierarchy, navigation, and theme-aware text.
- Use `<palette-selector>` for runtime Kinetic palette choice.

The complete property lists are in `DSL_REFERENCE.md`. Choose TYPE from interaction and display needs before choosing semantics.

## 5. Choosing ROLE

Release 1.0 generic semantic roles are:

```text
input-gain output-gain wet-dry bypass dsp-bypass oversampling
input-meter output-meter scope delta-monitor safety-limiter
safety-limiter-ceiling fft-size
```

Most are global/unique. `fft-size` is consumed semantically but is not currently in the same uniqueness-enforced list; authors should still declare one at most.

Use a ROLE when the generator must place a value or observer in its fixed signal pipeline. Leave `#:role` absent for ordinary effect controls. A “drive” knob, “reverb depth” knob, or “mode” selector normally needs APVTS state and PluginDSP interpretation, not a new role.

## 6. Choosing PROPERTY

Properties refine an instance without redefining its identity:

- slider range, interval, scale, title, suffix, value display, ticks, and labels;
- meter style, orientation, range, scale, segments, and glow/sharpness;
- scope grid style, glow/sharpness, and `tap-points`;
- selector items, default index, text, enablement, and optional binding;
- label text, font, colour, and justification.

The dual analyzer is one `<scope>` with `#:tap-points '(pre-dsp post-dsp)`, not two new scope TYPES. A visual styling request normally becomes a supported property or generic LookAndFeel behavior, not a semantic role.

## 7. Parameters and APVTS binding

Every rotary slider, linear slider, normal toggle, switch, and bypass-switch requires the complete nonempty binding tuple:

```scheme
#:parameter-id "drive"
#:parameter-name "Drive"
#:processor-reference "drive"
```

Sliders generate `AudioParameterFloat`; toggle/switch families generate `AudioParameterBool`. Selectors are genuinely optional: omit all binding fields for a UI-only selector, or provide the complete tuple to generate `AudioParameterChoice`.

Parameter IDs must remain stable after release because hosts store automation/state by identity. The display name may be human-readable. `processor-reference` determines generated cached-value naming and must be a usable nonempty string.

Selector UI/default indices are one-based: item 1 is the first choice. Bound selectors require nonempty items and `#:default-index` of at least 1. APVTS converts that to its zero-based choice index internally.

## 8. Standard plugin infrastructure

Normal plugins start from `standard-plugin-interface` and configure each standard element with:

```scheme
(component-id
 (enabled . #t)
 (display-name . "...")
 (tooltip . "...")
 (profile . #f)
 (width-scale . 1)
 (height-scale . 1))
```

Plugin config decides **what exists and how it appears**. The shell decides **where it belongs semantically and how it is integrated**. `display-name` never changes `id`, `role`, `parameter-id`, or `processor-reference`.

Visible support is TYPE-dependent. Labels/sliders/buttons expose tooltip, selectors expose tooltip/enablement but no title, and meter/scope do not currently expose display-title or tooltip slots. Profile and width/height scales participate in layout for every component.

A rich general effect may contain:

- plugin title;
- theme label and palette selector;
- input meter and input gain;
- dual PRE/POST scope;
- output gain and output meter;
- wet/dry when parallel blending is meaningful;
- oversampling when nonlinear DSP benefits;
- FFT size only for spectral processing;
- hard bypass and DSP bypass;
- Auto Gain, Delta Monitor, and optional Safety Limiter/CEILING;
- site link and copyright footer.

This is a menu, not a requirement. A distortion commonly benefits from oversampling but may need no FFT. A spectral processor needs FFT. A utility gain plugin needs neither. Reverb often benefits from wet/dry but does not automatically require spectral processing.

Include only infrastructure whose semantic consequence is wanted and implemented.

## 9. Input/output gain design

Both gain controls are bound slider-family components with dB-oriented properties.

Input Gain uses role `input-gain`. The input meter remains before it:

```text
HOST INPUT -> INPUT METER -> INPUT GAIN -> PRE SCOPE -> DSP
```

Raising Input Gain therefore leaves the input meter unchanged, raises the PRE/POST scope signal, and drives downstream DSP harder.

Output Gain uses role `output-gain`. The output meter follows it:

```text
POST SCOPE -> OUTPUT GAIN -> optional SAFETY LIMITER -> OUTPUT METER -> HOST OUTPUT
```

Raising Output Gain leaves both scope traces unchanged and raises the output meter. A coherent visual flow places `input-meter -> input-gain` on the left and `output-gain -> output-meter` on the right.

## 10. Meter design

Meters represent plugin I/O:

- `input-meter`: host input before Input Gain;
- `output-meter`: final host-bound output after Output Gain.

Both remain active during hard bypass; the output meter observes the actual delayed bypass-return buffer. They do not generate APVTS parameters.

Use segmented vertical meters for narrow channel-like level displays, segmented horizontal meters for a wide level bar, and analog meters when a larger traditional presentation fits the product. Current preferred logical footprints are vertical segmented `1x14`, horizontal segmented `14x3`, and analog `9x7`.

Vertical active segments use a theme-independent semantic progression from cyan/green through amber to red near full scale; inactive segments remain subdued. The surrounding UI palette still changes normally.

## 11. Scope/analyzer design

Current valid configurations are:

```scheme
#:tap-points '(pre-dsp)
#:tap-points '(post-dsp)
#:tap-points '(pre-dsp post-dsp)
```

- PRE observes after Input Gain and before developer DSP.
- POST observes after DSP, fixed-latency/wet-dry processing and before Output Gain.
- Dual overlays both in one scope with the same time axis, zero line, and amplitude scale.

The recommended comparative analyzer is:

```scheme
(make <scope>
  #:id "scope-main"
  #:role 'scope
  #:tap-points '(pre-dsp post-dsp)
  #:grid-style 'radar
  #:is-sharp #f
  #:glow-multiplier 1.0)
```

Output Gain does not affect either trace. Hard bypass intentionally freezes the last observation because the DSP stage is not traversed. The preferred scope metric is `18x10`.

Dual observation is useful for saturation, compression, filtering, transient shaping, reverberation, and modulation because it compares what enters and leaves the DSP stage. It is waveform observation, not a frequency-spectrum graph.

## 12. Hard bypass versus DSP bypass

Hard bypass and DSP bypass answer different questions.

**Hard bypass** takes the early-return path, skips the normal processing chain including output gain/limiter, preserves the fixed timing contract, keeps plugin I/O meters meaningful, freezes scope, and activates the global BYPASSED visual feedback.

**DSP bypass** skips the central FFT/oversampling/RealPlugin work while retaining Input Gain, wet/dry or Delta, latency infrastructure, PRE/POST observation, Output Gain, optional Safety Limiter, meters, and a usable GUI.

Both are normally single toggle/switch nodes with their own text and complete bool binding tuple. Do not present them as aliases.

## 13. Wet/dry

Include `wet-dry` when an effect naturally blends unprocessed and processed paths: reverb, delay, chorus, parallel distortion, and spectral effects. It is often unnecessary for utility gain, pure analyzers, or deliberately 100% wet corrective processing.

The generator captures and latency-aligns dry/wet paths and applies the current linear mix. Developer DSP normally produces only the wet result; do not add a second generic wet/dry stage in PluginDSP.

A conventional authoring range is 0..100 with DRY/WET endpoint labels, but effect-specific UI wording may vary.

## Auto Gain, Delta, and Safety Limiter

Auto Gain is an optional plugin-defined toggle placed by the standard shell. Current reference plugins implement its compensation in developer-owned `PluginDSP.h`; it is not a universal generator formula.

Delta Monitor is a role-bound toggle. While active, the generator outputs aligned processed minus aligned dry and ignores Wet/Dry amount. It is a monitoring mode, not another effect algorithm.

Safety Limiter is an optional role-bound toggle, OFF by default, paired with a CEILING slider (`-6.0 .. 0.0 dB`, default `-0.5 dB`, step `0.1 dB`). Release is internal at 100 ms. It protects final sample peaks after Output Gain and before Output Meter; it is not True Peak limiting.

## 15. Oversampling

Current semantic values are:

```text
0 = Off/1x, 1 = 2x, 2 = 4x, 3 = 8x
```

A stepped rotary is compact and source-proven:

```scheme
(make <rotary-slider>
  #:id "oversampling" #:role 'oversampling
  #:parameter-id "oversampling" #:parameter-name "Oversampling"
  #:processor-reference "oversampling"
  #:title "OVERSAMPLING"
  #:min 0.0 #:max 3.0 #:default 0.0 #:interval 1.0
  #:show-value #t #:show-ticks #t #:show-labels #t
  #:tick-count 4 #:tick-mode 'all
  #:tick-labels '("OFF" "2x" "4x" "8x"))
```

Oversampling is valuable for nonlinear saturation, clipping, waveshaping, and nonlinear dynamics. It may be unnecessary for simple gain, already band-limited linear DSP, or spectral work already performed at host rate. Higher factors consume more CPU and are not automatically better.

## 15. FFT controls

Current semantic choices are:

```text
Off, 256, 512, 1024, 2048, 4096, 8192
```

They are represented by a role-bound stepped control with values 0..6 and matching labels. Smaller transforms generally reduce causal latency but provide poorer frequency resolution; larger transforms provide greater frequency resolution with greater latency and cost.

Add `fft-size` only when developer `FFTProcessor` performs spectral work. Presence of the control emits FFT infrastructure. It is not a decorative analyzer setting, and the current scope is not an FFT display.

## 16. Custom effect parameters

Most product controls are ordinary parameters with no ROLE:

```scheme
(make <rotary-slider>
  #:id "drive"
  #:parameter-id "drive" #:parameter-name "Drive"
  #:processor-reference "drive"
  #:title "DRIVE"
  #:min 0.0 #:max 24.0 #:default 0.0 #:interval 0.1
  #:value-type 'gain #:suffix " dB")

(make <rotary-slider>
  #:id "reverb-depth"
  #:parameter-id "reverbDepth" #:parameter-name "Reverb Depth"
  #:processor-reference "reverbDepth"
  #:title "DEPTH"
  #:min 0.0 #:max 1.0 #:default 0.35 #:interval 0.001)

(make <normal-toggle-button>
  #:id "freeze"
  #:text "FREEZE" #:default-state #f
  #:parameter-id "freeze" #:parameter-name "Freeze"
  #:processor-reference "freeze")
```

The same pattern covers persistence, threshold, feedback, tone, modulation rate, diffusion, and modes. PluginDSP reads the generated cached values and gives them effect-specific meaning. No `reverb-depth` or `drive` role is needed.

## 17. Tempo-aware controls

Release 1.0 can represent subdivisions `1/2`, `1/4`, `3/4`, and `5/8` graphically and as APVTS state. It does not provide a generic tempo-sync ROLE or automatically combine the selection with host BPM.

For maximum textual clarity, prefer a bound selector:

```scheme
(make <selector>
  #:id "subdivision"
  #:items '("1/2" "1/4" "3/4" "5/8")
  #:default-index 2
  #:parameter-id "subdivision" #:parameter-name "Subdivision"
  #:processor-reference "subdivision")
```

If rotary interaction is required, use a stepped rotary with range 0..3, interval 1, four ticks, and the same explicit labels. PluginDSP must read host BPM, decode the choice, calculate duration, smooth timing changes, and implement the effect. Host transport availability depends on the host.

## 18. Theme/palette controls

`<palette-selector>` changes the Kinetic theme at runtime. The public catalogue contains 18 choices:

```text
Cyan, Plasma, Gold, Matrix, Fire, Ocean, Toxic, Radon, White,
Midnight, Sunset, Mint, Vaporwave, Amber, Crimson, Voltage,
Ultraviolet, Stealth
```

Use `#:items *kinetic-palettes*` and a one-based `#:default-index`. The theme affects background, text, sliders, toggles, scope, and other Kinetic visuals. Vertical meter active colours intentionally preserve their level semantics.

Treat theme choice as a small utility group near the header or top-right, not as a DSP role or processing parameter.

## 19. Labels, headers, links, and footer

Use hierarchy deliberately:

```scheme
(make <palette-label>
  #:id "plugin-title" #:text new-name
  #:font-size 26.0 #:font-style 'bold #:justification 'centred)

(make <palette-label>
  #:id "theme-label" #:text "THEME"
  #:font-size 12.0 #:justification 'centred)

(make <link>
  #:id "site-link"
  #:text "https://example.org/"
  #:url "https://example.org/"
  #:font-size 10.0 #:justification 'bottom-left)

(make <footer>
  #:id "copyright-footer"
  #:text "© 2026 Example Audio"
  #:font-size 10.0 #:justification 'bottom-right)
```

`#:url` must contain the actual portable URL; visible text alone does not define navigation. Label-like `setText` generation has an explicit UTF-8 path, so © is safe there. Release 1.0 does not claim that every possible C++ textual field uses explicit UTF-8 conversion.

## 20. Logical sizing and metrics

Components have canonical logical footprints. Important preferred examples are:

| TYPE/variant | Preferred logical size |
|---|---:|
| Rotary slider | 7x7 |
| Vertical linear slider | 4x14 |
| Horizontal linear slider | 14x4 |
| Vertical segmented meter | 1x14 |
| Selector/palette-selector | 12x2 |
| Header | 24x3 |
| Scope | 18x10 |

Logical units are not pixels. In physical mode, the normalizer selects the requested/default profile and local scales; PhysicalLayout resolves rectangles from screen dimensions, base unit, UI scale/size, metrics, topology, and shell policy. DiscreteGridLayout v2 converts unique physical boundaries into variable JUCE Grid tracks. Legacy spans do not override that result.

Authors should reason about relationship, hierarchy, and available logical capacity rather than micromanaging final pixel coordinates. Compact/extended profiles exist in the metric registry, but the current high-level normalizer chooses the preferred profile; there is no general per-instance profile keyword in the component DSL.

## 21. Layout composition

Compose the interface from a few readable structures:

- **Input signal strip:** input meter then input gain.
- **Analysis centre:** scope, with enough uninterrupted area for its `18x10` footprint.
- **Processing strip:** flat row of wet/dry, oversampling, FFT, bypass, DSP bypass, and selected custom controls.
- **Output signal strip:** output gain then output meter.
- **Theme utility:** small vertical label/selector group.
- **Branding:** title at top, site/copyright at bottom.

Visual order should reflect signal flow when practical. It lowers cognitive load, especially when meters and PRE/POST analysis reveal different stages.

## 22. Topological design patterns

Use real Release 1.0 declarations:

```scheme
(define effect-topology
  (list
   (lt:place-in-area 'plugin-title 'top)
   (lt:place-in-area 'scope-main '(center top))

   (lt:group 'left-audio-strip
     #:layout 'horizontal #:cross-align 'center #:gap 0 #:area 'left
     'input-meter 'input-gain)

   (lt:group 'right-audio-strip
     #:layout 'horizontal #:cross-align 'center #:gap 0 #:area 'right
     'output-gain 'output-meter)

   (lt:group 'lower-controls
     #:layout 'horizontal #:cross-align 'end #:gap 2 #:area '(bottom top)
     'wet-dry 'oversampling 'fft-size 'bypass 'dsp-bypass)

   (lt:group 'theme-strip
     #:layout 'vertical #:cross-align 'center #:gap 0
     #:area '(top-right top)
     'theme-label 'theme-selector)

   (lt:place-in-area 'site-link 'bottom-left)
   (lt:place-in-area 'copyright-footer 'bottom-right)
   (lt:align-bottom 'site-link 'copyright-footer)))
```

Use `#:gap` for intra-group spacing and `#:cross-align` for the other axis. Exact `next-*` relations mean exact adjacency; flexible `right-of`/`below` relations mean ordered non-overlap.

Groups are flat and cannot contain other groups. Areas are anchors/bounds, not exclusive containers; independently placed groups can overlap unless explicit relationships prevent it. Always generate current reference layouts with `#:layout-mode 'physical`.

## 23. Complete standard interface

The following source-valid interface uses all standard infrastructure. The topology above is its `standard-effect-topology` definition.

```scheme
(define (StandardEffect-interface dst-folder new-name)
  (make <screen> #:ratio 1.45 #:width 980)
  (make <grid> #:rows 32 #:cols 48 #:show-grid #f)

  (make <palette-label>
    #:id "plugin-title" #:text new-name
    #:font-size 26.0 #:font-style 'bold #:justification 'centred)

  (make <palette-label>
    #:id "theme-label" #:text "THEME"
    #:font-size 12.0 #:justification 'centred)
  (make <palette-selector>
    #:id "theme-selector"
    #:items *kinetic-palettes* #:default-index 3)

  (make <meter>
    #:id "input-meter" #:role 'input-meter
    #:style 'segmented #:orientation 'vertical #:scale-type 'db
    #:range-min -48.0 #:range-max 0.0 #:num-segments 24)
  (make <linear-slider>
    #:id "input-gain" #:role 'input-gain
    #:parameter-id "inputGain" #:parameter-name "Input Gain"
    #:processor-reference "inputGain"
    #:orientation 'vertical #:title "INPUT GAIN"
    #:min -24.0 #:max 24.0 #:default 0.0 #:interval 0.1
    #:value-type 'gain #:suffix " dB"
    #:show-ticks #t #:show-labels #t #:tick-count 5
    #:tick-labels '("-24" "-12" "0" "+12" "+24"))

  (make <scope>
    #:id "scope-main" #:role 'scope
    #:tap-points '(pre-dsp post-dsp)
    #:grid-style 'radar #:is-sharp #f #:glow-multiplier 1.0)

  (make <linear-slider>
    #:id "output-gain" #:role 'output-gain
    #:parameter-id "outputGain" #:parameter-name "Output Gain"
    #:processor-reference "outputGain"
    #:orientation 'vertical #:title "OUTPUT GAIN"
    #:min -24.0 #:max 24.0 #:default 0.0 #:interval 0.1
    #:value-type 'gain #:suffix " dB"
    #:show-ticks #t #:show-labels #t #:tick-count 5
    #:tick-labels '("-24" "-12" "0" "+12" "+24"))
  (make <meter>
    #:id "output-meter" #:role 'output-meter
    #:style 'segmented #:orientation 'vertical #:scale-type 'db
    #:range-min -48.0 #:range-max 0.0 #:num-segments 24)

  (make <linear-slider>
    #:id "wet-dry" #:role 'wet-dry
    #:parameter-id "wetDry" #:parameter-name "Wet/Dry"
    #:processor-reference "wetDry"
    #:orientation 'horizontal #:title "WET / DRY"
    #:min 0.0 #:max 100.0 #:default 100.0 #:interval 1.0
    #:suffix " %" #:show-value #f
    #:show-ticks #t #:show-labels #t #:tick-count 5
    #:tick-labels '("DRY" "25" "50" "75" "WET"))

  (make <rotary-slider>
    #:id "oversampling" #:role 'oversampling
    #:parameter-id "oversampling" #:parameter-name "Oversampling"
    #:processor-reference "oversampling"
    #:title "OVERSAMPLING"
    #:min 0.0 #:max 3.0 #:default 0.0 #:interval 1.0
    #:show-ticks #t #:show-labels #t #:tick-count 4
    #:tick-labels '("OFF" "2x" "4x" "8x"))

  (make <rotary-slider>
    #:id "fft-size" #:role 'fft-size
    #:parameter-id "fftSize" #:parameter-name "FFT Size"
    #:processor-reference "fftSize"
    #:title "FFT SIZE"
    #:min 0.0 #:max 6.0 #:default 0.0 #:interval 1.0
    #:show-ticks #t #:show-labels #t #:tick-count 7
    #:tick-labels '("OFF" "256" "512" "1024" "2048" "4096" "8192"))

  (make <normal-toggle-button>
    #:id "bypass" #:role 'bypass #:text "BYPASS"
    #:parameter-id "bypass" #:parameter-name "Bypass"
    #:processor-reference "bypass" #:default-state #f)
  (make <normal-toggle-button>
    #:id "dsp-bypass" #:role 'dsp-bypass #:text "DSP BYPASS"
    #:parameter-id "dspBypass" #:parameter-name "DSP Bypass"
    #:processor-reference "dspBypass" #:default-state #f)

  (make <link>
    #:id "site-link" #:text "https://example.org/"
    #:url "https://example.org/"
    #:font-size 10.0 #:justification 'bottom-left)
  (make <footer>
    #:id "copyright-footer" #:text "© 2026 Example Audio"
    #:font-size 10.0 #:justification 'bottom-right))

(define standard-effect-topology
  (list
   (lt:place-in-area 'plugin-title 'top)
   (lt:place-in-area 'scope-main '(center top))
   (lt:group 'left-audio-strip
     #:layout 'horizontal #:cross-align 'center #:gap 0 #:area 'left
     'input-meter 'input-gain)
   (lt:group 'right-audio-strip
     #:layout 'horizontal #:cross-align 'center #:gap 0 #:area 'right
     'output-gain 'output-meter)
   (lt:group 'lower-controls
     #:layout 'horizontal #:cross-align 'end #:gap 2 #:area '(bottom top)
     'wet-dry 'oversampling 'fft-size 'bypass 'dsp-bypass)
   (lt:group 'theme-strip
     #:layout 'vertical #:cross-align 'center #:gap 0
     #:area '(top-right top)
     'theme-label 'theme-selector)
   (lt:place-in-area 'site-link 'bottom-left)
   (lt:place-in-area 'copyright-footer 'bottom-right)
   (lt:align-bottom 'site-link 'copyright-footer)))

(MakeNewProject
  "standard-effect"
  StandardEffect-interface
  #:layout-mode 'physical
  #:topology-declarations standard-effect-topology)
```

The design mirrors signal flow, reserves the centre for analysis, keeps processing controls in one flat lower group, separates theme utilities, and aligns footer endpoints. FFT and oversampling are shown for completeness; omit either role/control when the algorithm does not need it.

## 24. Reverb interface case study

A reverb generally needs input/output monitoring, gain staging, wet/dry, bypasses, depth, and persistence. Dual scope is useful for observing transient smearing and decay. Oversampling is optional and should be justified by nonlinear/modulated internal stages. FFT is optional only if the reverb actually uses spectral processing.

Primary custom controls:

```scheme
(make <rotary-slider>
  #:id "reverb-depth"
  #:parameter-id "reverbDepth" #:parameter-name "Reverb Depth"
  #:processor-reference "reverbDepth"
  #:title "DEPTH"
  #:min 0.0 #:max 1.0 #:default 0.35 #:interval 0.001
  #:show-value #t)

(make <rotary-slider>
  #:id "reverb-persistence"
  #:parameter-id "reverbPersistence" #:parameter-name "Reverb Persistence"
  #:processor-reference "reverbPersistence"
  #:title "PERSISTENCE"
  #:min 0.0 #:max 1.0 #:default 0.60 #:interval 0.001
  #:show-value #t)

(make <selector>
  #:id "subdivision"
  #:items '("1/2" "1/4" "3/4" "5/8") #:default-index 2
  #:parameter-id "subdivision" #:parameter-name "Subdivision"
  #:processor-reference "subdivision"
  #:justification 'centred)
```

A selector is the primary recommendation because fraction text is clearer than crowded rotary ticks. If the product explicitly calls for rotary interaction, replace it with a 0..3 stepped rotary and four labels; the APVTS/DSP boundary remains identical.

The generator creates parameters, attachments, cached values, gain/bypass/meter/scope/wet-dry infrastructure, and optional FFT/oversampling resources. PluginDSP implements reverb topology, maps depth/persistence, decodes subdivision, reads BPM, smooths changes, and manages effect state. No reverb-specific ROLE is created.

## 25. LLM prompt-to-interface case study

Consider:

> Create an interface containing the basic elements: input meter, output meter, scope visualizer, input gain, output main, hard bypass, DSP bypass, oversampling and FFT when necessary. Add a rotary to synchronize at 1/2, 1/4, 3/4, 5/8 with the workstation BPM, a rotary for reverb depth and a rotary for reverb persistence.

Classify it before writing code:

| Phrase | DSL interpretation | DSP boundary |
|---|---|---|
| input meter | `<meter>`, `input-meter` | generator observes host input |
| output meter | `<meter>`, `output-meter` | generator observes host output |
| scope visualizer | `<scope>`, `scope`, dual taps recommended | generated PRE/POST observation |
| input gain | slider, `input-gain`, bound float | generator applies it |
| output main | slider, `output-gain`, bound float | generator applies it |
| hard bypass | normal toggle, `bypass`, bound bool | generator hard bypass |
| DSP bypass | normal toggle, `dsp-bypass`, bound bool | generator skips DSP |
| oversampling | stepped rotary, `oversampling` | generator routes factor |
| FFT when necessary | add `fft-size` only if spectral DSP is planned | developer `FFTProcessor` |
| BPM rotary | stepped rotary, no ROLE | PluginDSP maps choice + host BPM |
| reverb depth | rotary, no ROLE | PluginDSP |
| reverb persistence | rotary, no ROLE | PluginDSP |

The custom part of the resulting DSL is:

```scheme
(make <rotary-slider>
  #:id "tempo-subdivision"
  #:parameter-id "tempoSubdivision" #:parameter-name "Tempo Subdivision"
  #:processor-reference "tempoSubdivision"
  #:title "SUBDIVISION"
  #:min 0.0 #:max 3.0 #:default 1.0 #:interval 1.0
  #:show-value #t #:show-ticks #t #:show-labels #t
  #:tick-count 4 #:tick-mode 'all
  #:tick-labels '("1/2" "1/4" "3/4" "5/8"))

(make <rotary-slider>
  #:id "reverb-depth"
  #:parameter-id "reverbDepth" #:parameter-name "Reverb Depth"
  #:processor-reference "reverbDepth"
  #:title "DEPTH"
  #:min 0.0 #:max 1.0 #:default 0.35 #:interval 0.001)

(make <rotary-slider>
  #:id "reverb-persistence"
  #:parameter-id "reverbPersistence" #:parameter-name "Reverb Persistence"
  #:processor-reference "reverbPersistence"
  #:title "PERSISTENCE"
  #:min 0.0 #:max 1.0 #:default 0.60 #:interval 0.001)
```

Here is the complete compositional result, reusing the source-valid standard definition from Section 23 rather than duplicating it:

```scheme
(define (RequestedReverb-interface dst-folder new-name)
  (StandardEffect-interface dst-folder new-name)

  (make <rotary-slider>
    #:id "tempo-subdivision"
    #:parameter-id "tempoSubdivision"
    #:parameter-name "Tempo Subdivision"
    #:processor-reference "tempoSubdivision"
    #:title "SUBDIVISION"
    #:min 0.0 #:max 3.0 #:default 1.0 #:interval 1.0
    #:show-value #t #:show-ticks #t #:show-labels #t
    #:tick-count 4 #:tick-mode 'all
    #:tick-labels '("1/2" "1/4" "3/4" "5/8"))

  (make <rotary-slider>
    #:id "reverb-depth"
    #:parameter-id "reverbDepth" #:parameter-name "Reverb Depth"
    #:processor-reference "reverbDepth"
    #:title "DEPTH"
    #:min 0.0 #:max 1.0 #:default 0.35 #:interval 0.001)

  (make <rotary-slider>
    #:id "reverb-persistence"
    #:parameter-id "reverbPersistence" #:parameter-name "Reverb Persistence"
    #:processor-reference "reverbPersistence"
    #:title "PERSISTENCE"
    #:min 0.0 #:max 1.0 #:default 0.60 #:interval 0.001))

(define requested-reverb-topology
  (append
   standard-effect-topology
   (list
    (lt:group 'reverb-controls
      #:layout 'horizontal
      #:cross-align 'center
      #:gap 1
      #:area '(center bottom)
      'tempo-subdivision
      'reverb-depth
      'reverb-persistence))))

(MakeNewProject
  "requested-reverb"
  RequestedReverb-interface
  #:layout-mode 'physical
  #:topology-declarations requested-reverb-topology)
```

The standard definition includes FFT to demonstrate the requested optional infrastructure. Remove the `fft-size` component from the interface and lower group when the chosen reverb does not implement spectral processing. The BPM parameter is generated and automatable; its synchronization meaning remains developer DSP behavior.

## 26. Validation and common errors

Validate incrementally:

1. construct declarations;
2. let registration/validation reject bad IDs, roles, binding, ranges, and variants;
3. inspect role and parameter binding decisions;
4. normalize topology with current preferred metrics;
5. solve logical constraints;
6. only then generate a project;
7. build generated C++;
8. inspect interaction and visuals.

| Failure | Cause | Correction |
|---|---|---|
| Missing parameter binding | Slider/toggle lacks one or all tuple strings | provide all three nonempty fields |
| Duplicate role | Two instances use a unique semantic role | retain one semantic instance |
| Invalid range/default | `min >= max` or default outside range | correct range/default before generation |
| Selector default error | bound selector uses index 0 or beyond item count | use one-based 1..N default |
| Invalid scope taps | empty, duplicate, unknown, or reversed dual list | use documented PRE/POST forms |
| Impossible topology | exact group/metric dimensions cannot satisfy hard bounds | compute sizes/areas; change relation/area or grid capacity |

Do not use C++ compiler errors as the first DSL validator.

## 27. Visual refinement workflow

Refine one layer at a time:

1. semantic structure and signal meaning;
2. topology and non-overlap relationships;
3. TYPE/variant and canonical metric suitability;
4. supported LookAndFeel properties;
5. fine generic renderer polish.

Do not change DSP semantics to solve a visual problem and do not redesign several unrelated elements in one iteration.

- Scope too small: inspect its canonical metric and topology capacity.
- Meter colour/readability: inspect emitted meter properties and authoritative Kinetic renderer.
- Wrong signal displayed: inspect observation tap/resource and DSP stage order, not layout.
- Footer glyph too high inside a correct rectangle: use internal justification, not a topology move.

Generated projects are evidence; fix authoritative generator/template source.

## 28. What belongs in DSP instead

| Generator semantic infrastructure | PluginDSP algorithm responsibility |
|---|---|
| Input/output gain | Reverb, delay, saturation algorithm |
| Hard and DSP bypass orchestration | Compressor law and detector behavior |
| Input/output meter taps | EQ/filter design |
| PRE/POST scope taps | Spectral transformation in `FFTProcessor` |
| Wet/dry capture, alignment, mix | Tempo subdivision interpretation |
| Oversampling routing | Effect-specific smoothing and state |
| FFT/STFT infrastructure | Depth, persistence, feedback mappings |
| Fixed latency reporting/compensation | Algorithm latency declaration |

Ordinary bound parameters connect the two. A custom effect concept usually needs a normal APVTS control plus PluginDSP code, not generator architecture.

## 29. LLM interface-generation rules

Copy this block into an LLM prompt:

```text
Use only documented JUCE-Plugin-Generator Release 1.0 TYPES and ROLES.
Custom effect controls normally have no ROLE.
Never invent keyword properties.
Every slider/toggle/switch must have nonempty parameter-id,
parameter-name, and processor-reference fields.
Selectors may be UI-only or fully APVTS-bound; bound defaults are one-based.
Respect uniqueness of meter, gain, bypass, wet/dry, oversampling, and scope roles.
Use scope tap-points only as (pre-dsp), (post-dsp), or
(pre-dsp post-dsp). PRE/POST share one scale; Output Gain does not affect them.
Generate current reference layouts explicitly with layout-mode physical.
Keep groups flat. Areas are anchors/bounds, not exclusive containers.
Do not claim BPM synchronization is automatic; implement it in PluginDSP.
Put effect-specific algorithms and parameter interpretation in PluginDSP.
Do not patch generated plugin source as the authoritative implementation.
Validate registration and topology before project generation.
```

For best results, give the LLM this guide and `DSL_REFERENCE.md`; add `TOPOLOGICAL_LAYOUT_GUIDE.md` for nontrivial placement. It normally does not need `GENERATOR_DEVELOPER_GUIDE.md` merely to author an interface.

A useful ready-to-copy prompt is:

```text
Using JUCE Plugin Generator Release 1.0 DSL, create a topological interface
for [effect purpose]. Include [standard infrastructure]. Add these ordinary
effect parameters with ranges/defaults: [list]. Use [visual hierarchy].
Use only documented TYPES, ROLES, properties, and complete binding tuples.
Do not invent semantic roles. Identify every behavior which must be
implemented in PluginDSP, and validate the topology before generation.
```

## 30. Release 1.0 limitations

- Groups cannot nest.
- Areas are non-exclusive and do not provide automatic packing/non-overlap.
- There is no general packing solver.
- There is no generic tempo-sync/BPM subdivision semantic.
- Scope taps are limited to PRE and POST.
- Hard bypass freezes the last scope snapshot.
- Explicit UTF-8 conversion is not universal for all C++ textual fields.
- `fft-size` does not share the current uniqueness enforcement of other global roles.
- Custom DSP parameter meaning remains developer-owned.
- There is no arbitrary audio-routing graph DSL.
- Official Release 1.0 channel support is mono/stereo; 5.1, 7.1, and immersive bus topology are roadmap items.
- Generic LFO/modulation routing is roadmap work, not a current capability.
- Host transport fields can be absent depending on the host.
- Linux Standalone/VST3 is the currently verified Release build platform.

These are honest boundaries, not reasons to invent undocumented syntax. Design within them or make a separate, explicit generator architecture proposal.

Roadmap items are architectural directions and experimental plugin concepts, not Release 1.0 capabilities. See `../NEXT.md`.
