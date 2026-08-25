# JUCE Plugin Generator — DSL Reference

## 1. Purpose

This is the normative syntax and usage reference for the JUCE-Plugin-Generator Release 1.0 Scheme DSL. It describes declarations accepted by the current implementation and the generated consequences relevant to an interface author. Architectural rationale belongs in `ARCHITECTURE_DECISIONS.md`.

Examples assume `generator.scm` has loaded the public generator facade and its DSL classes.

## 2. Minimal generation example

Reference/topological generation must request topological mode explicitly:

```scheme
(MakeNewProject
  "plugin-name"
  InterfaceFunction
  #:layout-mode 'topological
  #:topology-declarations topology-definition)
```

A minimal interface and topology:

```scheme
(define (Minimal-interface dst-folder project-name)
  (make <screen> #:width 800 #:ratio 1.5)
  (make <grid> #:rows 18 #:cols 30 #:show-grid #f)

  (make <header>
    #:id "title"
    #:text project-name)

  (make <rotary-slider>
    #:id "amount"
    #:parameter-id "amount"
    #:parameter-name "Amount"
    #:processor-reference "amount"
    #:title "AMOUNT"
    #:min 0.0 #:max 1.0 #:default 0.5 #:interval 0.01)

  (make <normal-toggle-button>
    #:id "enabled"
    #:text "ENABLED"
    #:parameter-id "enabled"
    #:parameter-name "Enabled"
    #:processor-reference "enabled"))

(define topology-definition
  (list
    (lt:place-in-area 'title 'top)
    (lt:group 'main-controls
      #:layout 'horizontal
      #:gap 1
      #:cross-align 'center
      #:area 'center
      'amount 'enabled)))
```

`dst-folder` is supplied by the generator and may be unused. Logical IDs in topology are symbols corresponding losslessly to component `#:id` strings.

Legacy mode remains supported by `#:layout-mode 'legacy` and is the function default. It emits authored legacy row/column fields; it must not be used as proof that a topological interface solves correctly.

## 3. Common component model

Every concrete UI component inherits `<component>`:

| Keyword | Accepted value | Default | Meaning |
|---|---|---:|---|
| `#:id` | logical ID, normally nonempty string or symbol | `#f` | Required stable identity; duplicate IDs are rejected. It is normalized to a safe unique C++ identifier. |
| `#:role` | symbol or `#f` | `#f` | Optional semantic generator behavior. Only documented roles have built-in consequences. |
| `#:row` | integer or `#f` | `#f` | Legacy row; retained in the model. When present during topology normalization it is a hard integer anchor. |
| `#:col` | integer or `#f` | `#f` | Legacy column; retained and treated as a hard topology anchor when present. |
| `#:row-span` | number | `1` | Legacy span retained in the model. Topological mode replaces it with the canonical metric-derived span. |
| `#:col-span` | number | `1` | Same for columns. |
| `#:margin-tb` | number | `0` | Top/bottom margin passed to generated Grid layout. |
| `#:margin-lr` | number | `0` | Left/right margin passed to generated Grid layout. |

Registration requires a non-`#f` ID and rejects duplicates. The component validator does not comprehensively type-check every common layout field; the topological layer requires authored `row`/`col` anchors to be integers. Use positive spans and nonnegative sensible margins.

In topological mode, final row, column and spans come from canonical metrics plus topology constraints, followed by exact rational refinement. Do not set legacy spans to choose a topological size.

## 4. TYPE / ROLE / PROPERTY overview

- **TYPE** is graphical: `<rotary-slider>`, `<meter>`, `<scope>`.
- **ROLE** requests existing semantic generator behavior: a `<rotary-slider>` may have role `input-gain`; a `<meter>` may have role `input-meter`.
- **PROPERTY** configures an instance: a `<scope>` uses `#:tap-points '(pre-dsp post-dsp)`.
- **RESOURCE** is a generated runtime consequence such as an atomic meter value or scope FIFO. It is not a normal authored DSL class.

Do not invent a TYPE for a signal function, or a ROLE for visual styling.

## 5. Parameter binding model

| DSL family | Generated parameter | Attachment |
|---|---|---|
| `<rotary-slider>`, `<linear-slider>` | `juce::AudioParameterFloat` | `SliderAttachment` |
| `<normal-toggle-button>`, `<switch>`, `<bypass-switch>` | `juce::AudioParameterBool` | `ButtonAttachment` |
| bound `<selector>` / `<palette-selector>` | `juce::AudioParameterChoice` | `ComboBoxAttachment` |
| labels, meters, scope, text-button | none | none |

Binding fields:

| Keyword | Type | Default | Generated effect |
|---|---|---:|---|
| `#:parameter-id` | nonempty string | `#f` | JUCE `ParameterID` and APVTS lookup key. |
| `#:parameter-name` | nonempty string | `#f` | Host-visible parameter name. |
| `#:processor-reference` | nonempty C++-identifier-compatible string | `#f` | Generates `param_<reference>` and block value `value_<reference>`. |
| `#:version-hint` | integer | `1` | JUCE parameter version hint. |

For sliders and toggle/switch families, current registration classifies every instance as parameter-generating. Validation requires all three binding fields to be nonempty strings; omitting any field is rejected before generation.

Selector binding is genuinely optional. With no `#:parameter-id`, it is a UI-only ComboBox. With one, validation requires nonempty items, nonempty ID/name/reference, and `#:default-index >= 1`.

ComboBox item IDs and `#:default-index` are one-based: 1..N; 0 means no selection for an unbound selector. `AudioParameterChoice` is zero-based internally, so generation emits `default-index - 1`.

## 6. Complete component reference

The following are the concrete registerable UI classes. `<component>`, `<button>`, `<toggle-button>`, and `<slider>` are bases; `<header-footer>` and `<palette>` are legacy composite conveniences rather than UI TYPEs.

## `<rotary-slider>`

### Purpose

Rotary continuous or stepped parameter control.

### Inheritance

`<component>` -> `<slider>` -> `<rotary-slider>`.

### Constructor syntax

```scheme
(make <rotary-slider> #:id "mix" BINDING-AND-SLIDER-KEYWORDS ...)
```

### Slots/properties

All common component slots; `#:parameter-id`, `#:parameter-name`, `#:processor-reference`, `#:version-hint`; `#:title`, `#:min`, `#:max`, `#:default`, `#:interval`, `#:scale`, `#:value-type`, `#:suffix`, `#:show-value`, `#:show-ticks`, `#:show-labels`, `#:tick-count`, `#:tick-mode`, `#:tick-labels`; and rotary-only `#:icon-type`, `#:morph-icon`, `#:icon-set`. Sliders do **not** inherit `#:tooltip` or `#:enabled` in Release 1.0.

### Defaults

Binding `#f/#f/#f`, version 1; title `""`; range 0.0..1.0; default 0.0; interval 0.0; scale `'linear`; value-type `'default`; suffix `""`; show-value `#t`; show-ticks/show-labels `#f`; tick-count 0; tick-mode `'all`; tick-labels `()`; icon-type -1; morph-icon `#f`; icon-set `""`.

### Validation

Requires a complete nonempty binding tuple, min < max, default within range, and scale `linear` or `logarithmic`; logarithmic min/max must be positive. Tick/value/icon vocabularies are emitted with limited validation.

### Supported semantic roles

Commonly `input-gain`, `output-gain`, `wet-dry`, `oversampling`, or `fft-size`; custom effect parameters normally have no role.

### APVTS behavior

Always float parameter + SliderAttachment; range uses interval and logarithmic midpoint skew where requested.

### Runtime/DSP consequences

Only a documented semantic role creates generic DSP behavior. An ordinary bound rotary only exposes a parameter for developer DSP.

### Preferred logical metric

7x7.

### Compact/useful-max metrics

5x5 / 9x9.

### Generated JUCE type

`juce::Slider`, `RotaryHorizontalVerticalDrag`, no JUCE text box; KineticLookAndFeel draws title/value/ticks/icons.

### Minimal example

```scheme
(make <rotary-slider>
  #:id "amount" #:parameter-id "amount" #:parameter-name "Amount"
  #:processor-reference "amount")
```

### Full example

```scheme
(make <rotary-slider>
  #:id "input-gain" #:role 'input-gain
  #:parameter-id "inputGain" #:parameter-name "Input Gain"
  #:processor-reference "inputGain" #:version-hint 1
  #:title "INPUT GAIN" #:min -24.0 #:max 24.0 #:default 0.0
  #:interval 0.1 #:scale 'linear #:value-type 'gain #:suffix " dB"
  #:show-value #t #:show-ticks #t #:show-labels #t
  #:tick-count 5 #:tick-mode 'all
  #:tick-labels '("-24" "-12" "0" "+12" "+24")
  #:icon-type -1 #:morph-icon #f #:icon-set "")
```

### Common mistakes

Omitting binding fields; using zero/negative bounds with logarithmic scale; inventing `#:step` instead of `#:interval`; using `#:tooltip` or `#:enabled`; expecting title/tick labels to define DSP semantics.

## `<linear-slider>`

### Purpose

Horizontal or vertical continuous/stepped parameter control.

### Inheritance

`<component>` -> `<slider>` -> `<linear-slider>`.

### Constructor syntax

```scheme
(make <linear-slider> #:id "level" #:orientation 'vertical ...)
```

### Slots/properties

All common and slider fields listed for rotary, plus `#:orientation`. No rotary icon fields; no slider tooltip/enabled slots.

### Defaults

Slider defaults above; orientation `'horizontal`.

### Validation

Slider validation plus orientation exactly `'horizontal` or `'vertical`.

### Supported semantic roles

`input-gain`, `output-gain`, `wet-dry`; role use is not limited by class validation, but only documented roles have generator effects.

### APVTS behavior

Float parameter + SliderAttachment.

### Runtime/DSP consequences

Role-dependent; otherwise developer parameter only.

### Preferred logical metric

Horizontal 14x4; vertical 4x14.

### Compact/useful-max metrics

Horizontal 10x3 / 18x5; vertical 3x10 / 5x18.

### Generated JUCE type

`juce::Slider`, `LinearHorizontal` or `LinearVertical`, no standard text box.

### Minimal example

```scheme
(make <linear-slider>
  #:id "mix" #:parameter-id "mix" #:parameter-name "Mix"
  #:processor-reference "mix")
```

### Full example

```scheme
(make <linear-slider>
  #:id "output-gain" #:role 'output-gain
  #:parameter-id "outputGain" #:parameter-name "Output Gain"
  #:processor-reference "outputGain" #:orientation 'vertical
  #:title "OUTPUT GAIN" #:min -24.0 #:max 24.0 #:default 0.0
  #:interval 0.1 #:value-type 'gain #:suffix " dB"
  #:show-value #t #:show-ticks #t #:show-labels #t
  #:tick-count 5 #:tick-labels '("-24" "-12" "0" "+12" "+24"))
```

### Common mistakes

Using `vertical-slider` as a TYPE; using an invalid orientation; omitting APVTS binding; attempting rotary icon properties.

## `<label>`

### Purpose

General single-line fitted text.

### Inheritance

`<component>` -> `<label>`.

### Constructor syntax

```scheme
(make <label> #:id "caption" #:text "CAPTION" ...)
```

### Slots/properties

Common slots plus `#:text`, `#:font-size`, `#:font-style`, `#:justification`, `#:text-colour`, `#:minimum-horizontal-scale`, `#:tooltip`.

### Defaults

Text `""`; font 12.0; style `'plain`; justification `'centred`; colour `'default`; minimum scale 0.7; tooltip `""`.

### Validation

Text must be a string. Emitter-supported font styles are `plain`, `bold`, `italic`; justifications are `centred`, `centred-left`, `centred-right`, `left`, `right`, `top-left`, `top-right`, `bottom-left`, `bottom-right`; colours are `default`, `grey`, `white`, `black`, `neon-white`. Invalid emitter vocabularies fail generation.

### Supported semantic roles

None built in.

### APVTS behavior

None.

### Runtime/DSP consequences

None.

### Preferred logical metric

12x3.

### Compact/useful-max metrics

8x2 / 16x4.

### Generated JUCE type

`juce::Label`; text uses explicit `juce::String::fromUTF8` bytes.

### Minimal example

```scheme
(make <label> #:id "caption" #:text "LEVEL")
```

### Full example

```scheme
(make <label> #:id "caption" #:text "OUTPUT LEVEL"
  #:font-size 14.0 #:font-style 'bold #:justification 'centred
  #:text-colour 'neon-white #:minimum-horizontal-scale 0.7
  #:tooltip "Final output level")
```

### Common mistakes

Using a label role to create DSP behavior; unsupported justification/colour symbols; expecting arbitrary multiline layout.

## `<header>`

### Purpose

Prominent label-like header/title.

### Inheritance

`<component>` -> `<label>` -> `<header>`.

### Constructor syntax

```scheme
(make <header> #:id "title" #:text project-name ...)
```

### Slots/properties

Exactly all common and label slots.

### Defaults

Label defaults.

### Validation

Label validation/emitter vocabularies.

### Supported semantic roles

None.

### APVTS behavior

None.

### Runtime/DSP consequences

None.

### Preferred logical metric

24x3.

### Compact/useful-max metrics

16x2 / 32x4.

### Generated JUCE type

`juce::Label`, explicit UTF-8 text.

### Minimal example

```scheme
(make <header> #:id "title" #:text "MY EFFECT")
```

### Full example

```scheme
(make <header> #:id "title" #:text "MY EFFECT"
  #:font-size 26.0 #:font-style 'bold #:justification 'centred
  #:text-colour 'neon-white #:minimum-horizontal-scale 0.7)
```

### Common mistakes

Treating header as a semantic plugin-name resource or relying on legacy spans in topological mode.

## `<footer>`

### Purpose

Label-like footer text.

### Inheritance

`<component>` -> `<label>` -> `<footer>`.

### Constructor syntax

```scheme
(make <footer> #:id "copyright" #:text "© 2026 Example" ...)
```

### Slots/properties

All common and label slots.

### Defaults

Label defaults.

### Validation

Label validation/emitter vocabularies.

### Supported semantic roles

None.

### APVTS behavior

None.

### Runtime/DSP consequences

None.

### Preferred logical metric

24x3.

### Compact/useful-max metrics

16x2 / 32x4.

### Generated JUCE type

`juce::Label`, explicit UTF-8 text.

### Minimal example

```scheme
(make <footer> #:id "copyright" #:text "© 2026 Example")
```

### Full example

```scheme
(make <footer> #:id "copyright" #:text "© 2026 Example — all rights reserved"
  #:font-size 10.0 #:font-style 'plain #:justification 'bottom-right
  #:text-colour 'grey #:minimum-horizontal-scale 0.7)
```

### Common mistakes

Using raw `(c)` because UTF-8 is feared; changing topology to move glyphs instead of using bottom justification.

## `<link>`

### Purpose

Interactive label launching a URL in the default browser.

### Inheritance

`<component>` -> `<label>` -> `<link>`.

### Constructor syntax

```scheme
(make <link> #:id "site" #:text "https://example.org/" #:url "https://example.org/")
```

### Slots/properties

All common and label slots plus `#:url`.

### Defaults

Label defaults; URL `""`.

### Validation

Label text must be a string. Current validation does not verify URL syntax; provide an absolute portable URL such as `https://...`.

### Supported semantic roles

None.

### APVTS behavior

None.

### Runtime/DSP consequences

Editor mouse listener/hit area; launches `juce::URL(url).launchInDefaultBrowser()`.

### Preferred logical metric

12x2.

### Compact/useful-max metrics

8x2 / 16x2.

### Generated JUCE type

`juce::Label` plus generated interaction; visible text is explicit UTF-8.

### Minimal example

```scheme
(make <link> #:id "site" #:text "example.org" #:url "https://example.org/")
```

### Full example

```scheme
(make <link> #:id "site-link"
  #:text "https://www.aacf-music.eu/" #:url "https://www.aacf-music.eu/"
  #:font-size 10.0 #:justification 'bottom-left #:text-colour 'grey
  #:minimum-horizontal-scale 0.7 #:tooltip "Open project website")
```

### Common mistakes

Using a filesystem path, omitting URL while setting visible text, or assuming URL syntax is validated.

## `<palette-label>`

### Purpose

Label used with palette/theme UI; visually label-like.

### Inheritance

`<component>` -> `<label>` -> `<palette-label>`.

### Constructor syntax

```scheme
(make <palette-label> #:id "theme-label" #:text "THEME" ...)
```

### Slots/properties

All common and label slots plus `#:enable` and `#:default-theme`.

### Defaults

Label defaults; enable `#t`; default-theme 3.

### Validation

Label text validation. Current validator does not constrain enable/default-theme for this standalone type.

### Supported semantic roles

None.

### APVTS behavior

None.

### Runtime/DSP consequences

No direct palette switching; the palette-selector callback performs switching.

### Preferred logical metric

12x3.

### Compact/useful-max metrics

8x2 / 16x4.

### Generated JUCE type

`juce::Label`, explicit UTF-8 text.

### Minimal example

```scheme
(make <palette-label> #:id "theme-label" #:text "THEME")
```

### Full example

```scheme
(make <palette-label> #:id "theme-label" #:text "THEME"
  #:font-size 15.0 #:justification 'centred
  #:enable #t #:default-theme 3)
```

### Common mistakes

Expecting this label alone to create choices or change the active palette.

## `<selector>`

### Purpose

Unbound UI choice or bound choice parameter.

### Inheritance

`<component>` -> `<selector>`.

### Constructor syntax

```scheme
(make <selector> #:id "mode" #:items '("A" "B") #:default-index 1 ...)
```

### Slots/properties

Common slots; `#:items`, `#:default-index`; optional binding tuple/version; `#:justification`, `#:tooltip`, `#:enabled`, `#:text-when-nothing-selected`, `#:text-when-no-choices`.

### Defaults

Items `()`; index 0; binding `#f/#f/#f`, version 1; justification `'centred-left`; tooltip `""`; enabled `#t`; nothing text `""`; no-choice text `"No choices"`.

### Validation

Items must be a list of strings; index an integer in 0..N. Bound form requires nonempty items/full nonempty binding tuple and index >=1.

### Supported semantic roles

No generic selector role is required. `fft-size` is currently usually a rotary, but semantic discovery is role-based; use the reference representation unless deliberately extending/testing selector compatibility.

### APVTS behavior

None when unbound; `AudioParameterChoice` + ComboBoxAttachment when bound.

### Runtime/DSP consequences

Ordinary bound choice exposes a cached float index to developer DSP; no built-in DSP without a supported role.

### Preferred logical metric

12x2.

### Compact/useful-max metrics

8x2 / 16x2.

### Generated JUCE type

`juce::ComboBox`.

### Minimal example

```scheme
(make <selector> #:id "view" #:items '("A" "B") #:default-index 0)
```

### Full example

```scheme
(make <selector> #:id "mode"
  #:items '("Clean" "Dense" "Wide") #:default-index 2
  #:parameter-id "mode" #:parameter-name "Mode"
  #:processor-reference "mode" #:version-hint 1
  #:justification 'centred-left #:tooltip "Processing mode" #:enabled #t
  #:text-when-nothing-selected "Select mode"
  #:text-when-no-choices "No modes")
```

### Common mistakes

Using zero default for a bound selector; using symbols instead of strings in items; forgetting that default/item IDs are one-based.

## `<palette-selector>`

### Purpose

Selector whose choice changes the current Kinetic palette.

### Inheritance

`<component>` -> `<selector>` -> `<palette-selector>`.

### Constructor syntax

```scheme
(make <palette-selector> #:id "theme" #:items *kinetic-palettes* #:default-index 3)
```

### Slots/properties

Exactly selector slots. `*kinetic-palettes*` is the public catalogue.

### Defaults

Selector defaults; therefore the raw default is empty items/index 0. A useful palette selector must explicitly supply catalogue and 1..18 selection.

### Validation

Selector validation. The palette callback maps IDs 1..18; use the public catalogue in its defined order.

### Supported semantic roles

None; palette behavior belongs to TYPE callback, not a DSP role.

### APVTS behavior

Unbound by default. It may technically use selector binding, but theme automation/state semantics are not a documented Release 1.0 requirement.

### Runtime/DSP consequences

Editor callback animates palette change and repaints; no audio DSP.

### Preferred logical metric

12x2.

### Compact/useful-max metrics

8x2 / 16x2.

### Generated JUCE type

`juce::ComboBox` plus palette callback.

### Minimal example

```scheme
(make <palette-selector>
  #:id "theme-selector" #:items *kinetic-palettes* #:default-index 3)
```

### Full example

```scheme
(make <palette-selector>
  #:id "theme-selector" #:items *kinetic-palettes* #:default-index 3
  #:justification 'centred-left #:enabled #t
  #:text-when-no-choices "No themes" #:tooltip "Visual theme")
```

### Common mistakes

Omitting `#:items`, reordering catalogue entries while relying on fixed callback IDs, or using zero as an active theme.

Current catalogue, IDs 1–18:

1. Cyan (Cyberpunk)
2. Plasma (Purple)
3. Gold (Amber)
4. Matrix (Green)
5. Fire (Red)
6. Ocean (Blue)
7. Toxic (Lime)
8. Radon (Pink)
9. White (Mono)
10. Midnight (Dark)
11. Sunset (Orange)
12. Mint (Teal)
13. Vaporwave (Pink)
14. Amber (Amber)
15. Crimson (Red)
16. Voltage (Yellow)
17. Ultraviolet (Violet)
18. Stealth (Grey)

## `<text-button>`

### Purpose

Momentary/general text button UI.

### Inheritance

`<component>` -> `<button>` -> `<text-button>`.

### Constructor syntax

```scheme
(make <text-button> #:id "action" #:text "ACTION")
```

### Slots/properties

Common slots plus `#:text`, `#:tooltip`, `#:enabled`.

### Defaults

Text/tooltip `""`; enabled `#t`.

### Validation

Text must be a string.

### Supported semantic roles

None built in.

### APVTS behavior

None.

### Runtime/DSP consequences

No generic processor callback/resource is generated by this TYPE.

### Preferred logical metric

8x3.

### Compact/useful-max metrics

5x2 / 12x4.

### Generated JUCE type

`juce::TextButton`.

### Minimal example

```scheme
(make <text-button> #:id "action" #:text "ACTION")
```

### Full example

```scheme
(make <text-button> #:id "action" #:text "CAPTURE"
  #:tooltip "Capture current state" #:enabled #t)
```

### Common mistakes

Adding parameter binding keywords (not slots) or expecting a host parameter/callback automatically.

## `<normal-toggle-button>`

### Purpose

Compact normal toggle with its own text.

### Inheritance

`<component>` -> `<button>` -> `<toggle-button>` -> `<normal-toggle-button>`; registered model TYPE is `toggle-button`.

### Constructor syntax

```scheme
(make <normal-toggle-button> #:id "enabled" #:text "ENABLED" BINDING ...)
```

### Slots/properties

Common slots; `#:text`, `#:tooltip`, `#:enabled`; `#:default-state`, `#:style`; full binding tuple/version.

### Defaults

Text/tooltip `""`; enabled `#t`; default-state `#f`; style `'normal`; binding unset; version 1.

### Validation

Text string; default-state boolean; style `normal` or `switch`. Binding completeness is required usage but not checked.

### Supported semantic roles

`bypass`, `dsp-bypass`, or no role for an ordinary bool parameter.

### APVTS behavior

Bool parameter + ButtonAttachment.

### Runtime/DSP consequences

Bypass roles generate semantic paths/GUI repaint. No role means developer bool parameter only.

### Preferred logical metric

6x4.

### Compact/useful-max metrics

4x3 / 8x5.

### Generated JUCE type

`juce::ToggleButton`, Kinetic normal-toggle rendering.

### Minimal example

```scheme
(make <normal-toggle-button>
  #:id "enabled" #:text "ENABLED"
  #:parameter-id "enabled" #:parameter-name "Enabled"
  #:processor-reference "enabled")
```

### Full example

```scheme
(make <normal-toggle-button>
  #:id "bypass" #:role 'bypass #:text "BYPASS"
  #:default-state #f #:style 'normal #:enabled #t
  #:tooltip "Hard bypass"
  #:parameter-id "bypass" #:parameter-name "Bypass"
  #:processor-reference "bypass" #:version-hint 1)
```

### Common mistakes

Omitting binding; assuming normal visual style creates bypass semantics without the role; reintroducing a separate title label unnecessarily.

## `<switch>`

### Purpose

Track/thumb switch-style bool control.

### Inheritance

`<component>` -> `<button>` -> `<toggle-button>` -> `<switch>`; construction forces style `'switch`.

### Constructor syntax

```scheme
(make <switch> #:id "enabled" #:text "ENABLED" BINDING ...)
```

### Slots/properties

All normal-toggle slots. `#:style` exists by inheritance but constructor forces it to `switch`.

### Defaults

Toggle defaults, forced switch style.

### Validation

Toggle validation, including the complete nonempty binding tuple.

### Supported semantic roles

`bypass`, `dsp-bypass`, or none for ordinary bool parameter.

### APVTS behavior

Bool + ButtonAttachment.

### Runtime/DSP consequences

Role-dependent only.

### Preferred logical metric

7x4.

### Compact/useful-max metrics

5x3 / 10x5.

### Generated JUCE type

`juce::ToggleButton` with `style="switch"` property.

### Minimal example

```scheme
(make <switch> #:id "enabled" #:text "ENABLED"
  #:parameter-id "enabled" #:parameter-name "Enabled"
  #:processor-reference "enabled")
```

### Full example

```scheme
(make <switch> #:id "dsp-bypass" #:role 'dsp-bypass
  #:text "DSP BYPASS" #:default-state #f #:tooltip "Skip DSP stage"
  #:parameter-id "dspBypass" #:parameter-name "DSP Bypass"
  #:processor-reference "dspBypass" #:version-hint 1)
```

### Common mistakes

Expecting switch appearance to imply bypass; setting `#:style 'normal` and expecting it to survive construction.

## `<bypass-switch>`

### Purpose

Switch visual subtype intended for bypass-style presentation; semantic bypass still requires a role.

### Inheritance

`<component>` -> `<button>` -> `<toggle-button>` -> `<switch>` -> `<bypass-switch>`.

### Constructor syntax

```scheme
(make <bypass-switch> #:id "bypass" #:role 'bypass ...)
```

### Slots/properties

All switch/toggle/common fields.

### Defaults

Switch/toggle defaults.

### Validation

Toggle validation, including the complete nonempty binding tuple.

### Supported semantic roles

Normally `bypass`; `dsp-bypass` is also role-driven. TYPE alone has no hard-bypass audio effect.

### APVTS behavior

Bool + ButtonAttachment.

### Runtime/DSP consequences

Only documented role consequences.

### Preferred logical metric

7x4.

### Compact/useful-max metrics

5x3 / 10x5.

### Generated JUCE type

`juce::ToggleButton` with switch renderer.

### Minimal example

```scheme
(make <bypass-switch> #:id "bypass" #:role 'bypass #:text "BYPASS"
  #:parameter-id "bypass" #:parameter-name "Bypass"
  #:processor-reference "bypass")
```

### Full example

```scheme
(make <bypass-switch> #:id "bypass" #:role 'bypass
  #:text "BYPASS" #:default-state #f #:enabled #t
  #:tooltip "Bypass entire plugin"
  #:parameter-id "bypass" #:parameter-name "Bypass"
  #:processor-reference "bypass" #:version-hint 1)
```

### Common mistakes

Using the TYPE without role and expecting audio bypass; duplicating the unique `bypass` role.

## `<meter>`

### Purpose

Non-parameter signal-level display.

### Inheritance

`<component>` -> `<meter>`.

### Constructor syntax

```scheme
(make <meter> #:id "input-meter" #:role 'input-meter ...)
```

### Slots/properties

Common slots plus `#:style`, `#:orientation`, `#:scale-type`, `#:is-sharp`, `#:glow-multiplier`, `#:range-min`, `#:range-max`, `#:num-segments`, `#:tick-mode`.

### Defaults

Style `'segmented`; orientation `'vertical`; scale `'db`; sharp `#f`; glow 1.0; range -60.0..6.0; segments 20; tick-mode `'all`.

### Validation

Style `segmented` or `analog`; orientation `vertical` or `horizontal`; scale-type `db`, `linear`, or `vu`; range-min < range-max; segments >0. Tick-mode is currently emitted without dedicated validation.

### Supported semantic roles

`input-meter`, `output-meter` (each uniqueness-enforced).

### APVTS behavior

None.

### Runtime/DSP consequences

Role emits processor peak atomic and editor timer wiring. Input observes host input before input gain. Output observes final post-output-gain host-bound signal. Both update in hard bypass; branch output meter sees the actual return buffer.

### Preferred logical metric

Segmented vertical 1x14; horizontal 14x3; analog 9x7.

### Compact/useful-max metrics

Vertical 1x10 / 2x18; horizontal 10x3 / 18x5; analog 6x5 / 12x9.

### Generated JUCE type

`KineticMeter`.

### Minimal example

```scheme
(make <meter> #:id "input-meter" #:role 'input-meter)
```

### Full example

```scheme
(make <meter> #:id "output-meter" #:role 'output-meter
  #:style 'segmented #:orientation 'vertical #:scale-type 'db
  #:is-sharp #f #:glow-multiplier 0.8
  #:range-min -48.0 #:range-max 0.0
  #:num-segments 24 #:tick-mode 'all)
```

### Common mistakes

Adding APVTS fields; inventing an `output-level` role; using `#:scale` rather than `#:scale-type`; assuming analog orientation selects a different metric variant.

## `<scope>`

### Purpose

Single or dual DSP observation display.

### Inheritance

`<component>` -> `<scope>`.

### Constructor syntax

```scheme
(make <scope> #:id "scope" #:role 'scope #:tap-points '(pre-dsp post-dsp) ...)
```

### Slots/properties

Common slots plus `#:grid-style`, `#:is-sharp`, `#:glow-multiplier`, `#:tap-points`.

### Defaults

Grid `'radar`; sharp `#f`; glow 1.0; taps `'(post-dsp)`.

### Validation

Grid `radar` or `minimal`. Taps must be a nonempty list containing only `pre-dsp`/`post-dsp`, with no duplicates, at most two; dual order must be exactly `(pre-dsp post-dsp)`.

### Supported semantic roles

`scope` (uniqueness-enforced).

### APVTS behavior

None.

### Runtime/DSP consequences

Only requested lock-free streams are emitted. PRE is after input gain/before DSP. POST is after DSP, fixed-latency and wet/dry/before output gain. Dual traces share time axis, zero and amplitude scale. Output gain affects neither. Hard bypass freezes the last observation.

### Preferred logical metric

18x10.

### Compact/useful-max metrics

8x6 / 18x10.

### Generated JUCE type

`KineticScope`.

### Minimal example

```scheme
(make <scope> #:id "scope" #:role 'scope)
```

### Full example

```scheme
(make <scope> #:id "scope-main" #:role 'scope
  #:tap-points '(pre-dsp post-dsp)
  #:grid-style 'radar #:is-sharp #f #:glow-multiplier 1.2)
```

### Common mistakes

Using `'(post-dsp pre-dsp)`, duplicates or empty taps; creating separate pre/post scope TYPEs; expecting output gain to change the traces.

## 7. Semantic roles

| Role | Intended family | Uniqueness | Generated consequence |
|---|---|---|---|
| `input-gain` | bound slider | enforced | Applies dB gain after input meter and hard-bypass decision. |
| `output-gain` | bound slider | enforced | Applies dB gain before output meter. |
| `wet-dry` | bound slider | enforced | Allocates/captures dry path and emits linear wet/dry mix. |
| `bypass` | bound toggle/switch | enforced | Hard-bypass early path, fixed delay where required, output metering, GUI overlay. |
| `dsp-bypass` | bound toggle/switch | enforced | Skips central FFT/oversampling/developer DSP while surrounding latency/mix remains active. |
| `oversampling` | stepped bound slider | enforced | Emits 2x/4x/8x oversampling resources and runtime selection. |
| `input-meter` | meter | enforced | Pre-input-gain host-input observation. |
| `output-meter` | meter | enforced | Final host-output observation, including hard bypass. |
| `scope` | scope | enforced | Emits selected PRE/POST observation resources/wiring. |
| `fft-size` | stepped bound slider in reference UI | **not in enforced unique-role list** | Presence emits FFT/STFT infrastructure and size selection. Treat as single-instance convention. |

Arbitrary custom role symbols may be stored but do not trigger generator behavior. Custom effect parameters normally use no role and are read by developer DSP.

## 8. Scope tap-points

Exact forms:

```scheme
#:tap-points '(pre-dsp)
#:tap-points '(post-dsp)
#:tap-points '(pre-dsp post-dsp)
```

Default is `'(post-dsp)`. PRE is immediately after input gain and before central DSP. POST is after developer DSP, fixed-latency compensation and wet/dry, before output gain. Dual mode overlays both on one graph with one scale/time axis. Hard bypass updates neither stream and intentionally freezes the display.

## 9. Meter configuration

Use `#:style 'segmented` with vertical/horizontal orientation, or `#:style 'analog`. Use `#:scale-type` (`db`, `linear`, `vu`), not slider `#:scale`. Range and segment count are renderer configuration; meter roles determine observation semantics. Meters never create host parameters.

Canonical pppbuttavia meter:

```scheme
(make <meter>
  #:id "input-meter" #:role 'input-meter
  #:style 'segmented #:orientation 'vertical #:scale-type 'db
  #:range-min -48.0 #:range-max 0.0 #:num-segments 24
  #:is-sharp #f #:glow-multiplier 0.8 #:tick-mode 'all)
```

## 10. Selector/choice parameters

Unbound:

```scheme
(make <selector>
  #:id "view" #:items '("Wave" "Spectrum") #:default-index 0)
```

Bound choice:

```scheme
(make <selector>
  #:id "quality" #:items '("Low" "Medium" "High") #:default-index 2
  #:parameter-id "quality" #:parameter-name "Quality"
  #:processor-reference "quality")
```

The latter creates an `AudioParameterChoice` with C++ default index 1. Do not supply symbols as choices or use default 0 when bound.

## 11. Slider value/tick formatting

APVTS semantics: `min`, `max`, `default`, `interval`, `scale`. Display-only/Kinetic configuration: `title`, `value-type`, `suffix`, visibility flags, tick count/mode/labels and rotary icons.

DSL-facing `value-type` values proven by `KineticLookAndFeel::formatMetric` are:

- `'gain`: dB-style number; values <= -60 display `-inf`, positives receive `+`.
- `'freq` or `'hz`: integer Hz below 1000, compact `k` form above.
- `'default` (and any unrecognized emitted string): generic integer/one-decimal compact formatting.

`#:tick-mode` renderer meanings are `'all`, `'endpoints`, and `'none`; current Scheme validation does not enforce this vocabulary. Explicit `#:tick-labels` override formatted tick text. Label count should match the intended tick count.

Examples:

```scheme
;; Gain dB rotary
(make <rotary-slider> #:id "gain"
  #:parameter-id "gain" #:parameter-name "Gain" #:processor-reference "gain"
  #:title "GAIN" #:min -60.0 #:max 12.0 #:default 0.0 #:interval 0.1
  #:value-type 'gain #:suffix " dB")

;; Generic 0..1
(make <rotary-slider> #:id "depth"
  #:parameter-id "depth" #:parameter-name "Depth" #:processor-reference "depth"
  #:title "DEPTH" #:min 0.0 #:max 1.0 #:default 0.5 #:interval 0.01)

;; Stepped integer
(make <rotary-slider> #:id "mode"
  #:parameter-id "mode" #:parameter-name "Mode" #:processor-reference "mode"
  #:title "MODE" #:min 0.0 #:max 3.0 #:default 0.0 #:interval 1.0
  #:show-ticks #t #:show-labels #t #:tick-count 4
  #:tick-labels '("A" "B" "C" "D"))

;; Horizontal linear
(make <linear-slider> #:id "mix"
  #:parameter-id "mix" #:parameter-name "Mix" #:processor-reference "mix"
  #:orientation 'horizontal #:min 0.0 #:max 100.0 #:default 100.0
  #:interval 1.0 #:suffix " %")

;; Vertical linear
(make <linear-slider> #:id "trim"
  #:parameter-id "trim" #:parameter-name "Trim" #:processor-reference "trim"
  #:orientation 'vertical #:min -24.0 #:max 24.0 #:default 0.0
  #:interval 0.1 #:value-type 'gain #:suffix " dB")
```

Rotary `#:icon-type` selects built-in vector icon 0–3 or an indexed image from `#:icon-set`; -1 disables. `#:morph-icon #t` derives icon index from the rounded slider value. Image sets must be separately declared.

## 12. Oversampling DSL usage

Release 1.0 represents oversampling with one uniqueness-enforced, role-bound stepped slider. The reference representation authors values and labels explicitly; they are not inferred:

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

Semantic indices are 0=Off/1x, 1=2x, 2=4x, 3=8x. Presence of the role generates the current IIR oversampling resources and selection path. Legacy FIR configuration helpers are not Release 1.0 DSL behavior.

## 13. FFT-size DSL usage

The current FFT control is a role-bound stepped rotary:

```scheme
(make <rotary-slider>
  #:id "fft-size" #:role 'fft-size
  #:parameter-id "fftSize" #:parameter-name "FFT Size"
  #:processor-reference "fftSize"
  #:title "FFT SIZE"
  #:min 0.0 #:max 6.0 #:default 0.0 #:interval 1.0
  #:show-value #t #:show-ticks #t #:show-labels #t
  #:tick-count 7 #:tick-mode 'all
  #:tick-labels '("OFF" "256" "512" "1024" "2048" "4096" "8192"))
```

Indices select Off, 256, 512, 1024, 2048, 4096, or 8192. Presence of role `fft-size` causes FFT/STFT infrastructure generation. Arbitrary sizes are unsupported. FFT runs at host sample rate before oversampling; deeper contracts belong in the DSP developer guide. Use one such role by Release 1.0 convention because uniqueness is not currently enforced.

## 14. Wet/dry DSL usage

The reference control is a float slider with role `wet-dry`, range 0..100, and percent display:

```scheme
(make <linear-slider>
  #:id "wet-dry" #:role 'wet-dry
  #:parameter-id "wetdry" #:parameter-name "Wet Dry"
  #:processor-reference "wetdry"
  #:orientation 'horizontal #:title "WET / DRY"
  #:min 0.0 #:max 100.0 #:default 100.0 #:interval 1.0
  #:suffix " %" #:show-value #f
  #:show-ticks #t #:show-labels #t #:tick-count 5
  #:tick-labels '("DRY" "25" "50" "75" "WET"))
```

It creates an `AudioParameterFloat`; the role activates generator-managed dry capture and the current linear mix. Other numeric ranges are normalized by the generator from the declared min/max, but 0..100 is the Release 1.0 reference convention.

## 15. UI metrics reference

Topological preferred dimensions are canonical logical contracts, not pixels. Source: `generator-app/ui-metrics.scm`.

| TYPE / variant | Compact | Preferred / standard | Useful-max / extended |
|---|---:|---:|---:|
| rotary-slider | 5x5 | 7x7 | 9x9 |
| linear-slider horizontal | 10x3 | 14x4 | 18x5 |
| linear-slider vertical | 3x10 | 4x14 | 5x18 |
| text-button | 5x2 | 8x3 | 12x4 |
| normal-toggle-button / metric TYPE toggle-button | 4x3 | 6x4 | 8x5 |
| switch | 5x3 | 7x4 | 10x5 |
| bypass-switch | 5x3 | 7x4 | 10x5 |
| label | 8x2 | 12x3 | 16x4 |
| palette-label | 8x2 | 12x3 | 16x4 |
| header | 16x2 | 24x3 | 32x4 |
| footer | 16x2 | 24x3 | 32x4 |
| link | 8x2 | 12x2 | 16x2 |
| selector | 8x2 | 12x2 | 16x2 |
| palette-selector | 8x2 | 12x2 | 16x2 |
| meter segmented vertical | 1x10 | 1x14 | 2x18 |
| meter segmented horizontal | 10x3 | 14x3 | 18x5 |
| meter analog | 6x5 | 9x7 | 12x9 |
| scope | 8x6 | 18x10 | 18x10 |

Content/capability rules in the registry are advisory unless an explicit current consumer selects them. Topological normalization currently selects the preferred/standard profile and the orientation/style variant.

## 16. Layout fields

Legacy mode consumes authored `#:row`, `#:col`, `#:row-span`, `#:col-span`, `#:margin-tb`, and `#:margin-lr`. Rows/columns use one-based logical coordinates in generated Grid data.

Topological normalization retains explicit integer row/col as hard anchors but derives spans from the preferred metric for TYPE/variant. Usually leave row/col `#f` and express relationships in topology. Margins still reach generated component Grid items after resolution.

## 17. Topological declarations overview

Low-level `lt:node` syntax exists for solver IR/tests:

```scheme
(lt:node 'id 'rotary-slider 'standard
  #:variant #f #:row #f #:col #f #:constraints '())
```

Normal interface authors do not duplicate registered components as nodes; `topological-normalizer.scm` creates nodes from registered models.

Position constraint declarations use `lt:constrain` (provided by `topological-normalizer.scm`):

```scheme
(lt:constrain 'output (lt:next-right-of 'input))
(lt:constrain 'footer (lt:below 'controls))
```

Relations: `lt:next-right-of`, `lt:next-left-of`, `lt:next-above`, `lt:next-below` are exact adjacency; `lt:right-of`, `lt:left-of`, `lt:above`, `lt:below` are partial orders.

Alignments are separate declarations:

```scheme
(lt:align-left 'a 'b 'c)
(lt:align-right 'a 'b)
(lt:align-top 'a 'b)
(lt:align-bottom 'a 'b)
(lt:align-center-x 'a 'b)
(lt:align-center-y 'a 'b)
```

Area placement:

```scheme
(lt:place-in-area 'scope 'center)
(lt:place-in-area 'theme '(top-right top))
```

Area symbols are `top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom`, `bottom-right`. Lists recursively select thirds. Areas are hard anchors/bounds, **not exclusive occupancy or automatic collision avoidance**.

Groups:

```scheme
(lt:group 'id
  #:layout 'horizontal                 ; or vertical, required
  #:gap 1                              ; exact nonnegative number, default 0
  #:cross-align 'center                ; start, center, end; optional
  #:cohesion 'strong                   ; weak, medium, strong; optional
  #:area 'bottom                       ; symbol/path; optional
  'member-a 'member-b)
```

Without cohesion, along-axis order/gap is hard exact composition. Cohesion turns it into a weighted soft wish. Groups require at least two distinct component node IDs and cannot contain groups: nested groups are unsupported.

Three patterns:

```scheme
;; Left-to-right strip
(lt:group 'audio-strip #:layout 'horizontal #:gap 0
  #:cross-align 'center #:area 'left
  'input-meter 'input-gain)

;; Vertical label/control group
(lt:group 'theme-strip #:layout 'vertical #:gap 0
  #:cross-align 'center #:area 'top-right
  'theme-label 'theme-selector)

;; Centred scope and independent lower strip
(lt:place-in-area 'scope-main 'center)
(lt:group 'lower-controls #:layout 'horizontal #:gap 1
  #:cross-align 'end #:area '(bottom top)
  'wet-dry 'oversampling 'fft-size 'bypass)
```

The last two declarations do not automatically avoid each other or the scope; add explicit relations when non-overlap is required.

## 18. Screen/grid/resource declarations

### `<screen>`

```scheme
(make <screen> #:ratio 1.45 #:width 980)
```

Slots: `#:ratio` default golden ratio `(1+sqrt(5))/2`; `#:width` default 800. Exactly one may be registered. It generates standard pixel width/height and editor ratio; it has no role.

### `<grid>`

```scheme
(make <grid> #:rows 32 #:cols 48 #:show-grid #f)
```

Slots: rows 15, cols 24, show-grid `#t` by default. Exactly one may be registered. Rows/cols define logical solver/Grid dimensions. `show-grid` is retained configuration/debug metadata; current `generate-grid-code` does not emit the previously commented debug flag. It is not plugin semantics.

### `<image-set>`

```scheme
(make <image-set>
  #:name "Waveforms"
  #:source-directory "/absolute/source/resources"
  #:files '("sine.png" "square.png"))
```

This is a public resource declaration, not a UI component and has no role. Name and source directory must be nonempty strings; files must be a string list; each must exist at `source-directory/name/file`; duplicate set names are rejected. Generation copies files into `Resources/name/` with generated names, updates `.jucer` BinaryData resources, loads images, and registers the set with KineticLookAndFeel. It is currently used by rotary `#:icon-set`.

Legacy composites `<header-footer>` and `<palette>` create multiple registered leaf components. Prefer explicit leaf declarations in new topological examples because topology addresses stable leaf IDs.

## 19. Validation rules

| Failure | Invalid | Correct |
|---|---|---|
| Missing/duplicate ID | two `(make <label> #:id "x" ...)` | give each a unique ID |
| Duplicate unique role | two meters with `#:role 'input-meter` | one input-meter; other has no role/different supported role |
| Slider range | `#:min 1 #:max 1` | `#:min 0 #:max 1` |
| Slider default | range 0..1, `#:default 2` | default within 0..1 |
| Log range | `#:scale 'logarithmic #:min 0` | positive min/max |
| Incomplete slider/toggle binding | omit `#:processor-reference` | supply ID, name and reference |
| Selector items | `#:items '(a b)` | `#:items '("A" "B")` |
| Selector index | two items, `#:default-index 3` | 0..2; bound form 1..2 |
| Bound selector empty | binding plus `#:items '()` | supply at least one item |
| Meter style | `#:style 'digital` | `segmented` or `analog` |
| Meter orientation | `#:orientation 'up` | `vertical` or `horizontal` |
| Scope taps empty | `#:tap-points '()` | `'(post-dsp)` |
| Scope taps duplicate | `'(pre-dsp pre-dsp)` | `'(pre-dsp)` |
| Scope dual reversed | `'(post-dsp pre-dsp)` | `'(pre-dsp post-dsp)` |
| Missing topology target | constrain/place unknown ID | declare/register the referenced component |
| Contradiction | exact left and exact right cycle | remove/change the inconsistent hard relation |
| Nested group | group member is another group ID | flatten members or use separate explicit relations |
| Impossible area capacity | group wider than recursive area bounds | enlarge logical grid/area or change valid topology; never weaken solver |

Some emitter vocabularies (label style/justification/colour, tick mode) fail during generation rather than component validation. Use only values documented here.

## 20. Natural-language-to-DSL guidance

Classify a request in this order:

1. Choose an existing graphical TYPE.
2. Decide whether a documented ROLE applies.
3. Add only documented PROPERTY configuration.
4. Bind an APVTS parameter when the control represents host/developer state.
5. Let TYPE/variant select canonical preferred metrics; do not author historical spans.
6. Express placement through flat groups, areas and explicit relations.
7. When no generic role exists, leave effect meaning to `PluginDSP.h` and access the ordinary APVTS parameter.

Examples:

- “input gain” -> rotary or linear slider + role `input-gain` + complete float binding.
- “reverb depth” -> ordinary bound slider, no invented `reverb-depth` role; developer DSP consumes `value_reverbDepth`.
- “dual pre/post analyzer” -> one scope + role `scope` + `#:tap-points '(pre-dsp post-dsp)`.
- “hard bypass” -> normal-toggle-button or switch + role `bypass` + bool binding.
- “tempo subdivision 1/2, 1/4, 3/4, 5/8” -> a stepped slider or bound selector can represent the choice; generic BPM synchronization does **not** exist in Release 1.0 and must be developer/runtime work.

Never invent a role merely because natural language contains a semantic noun.

## 21. Complete reference examples

### Standard effect interface

This example uses only current constructors/keywords and all unique roles once:

```scheme
(define (StandardEffect-interface dst-folder project-name)
  (make <screen> #:width 980 #:ratio 1.45)
  (make <grid> #:rows 32 #:cols 48 #:show-grid #f)

  (make <header> #:id "plugin-title" #:text project-name
    #:font-size 26.0 #:font-style 'bold #:justification 'centred)
  (make <palette-label> #:id "theme-label" #:text "THEME"
    #:font-size 15.0)
  (make <palette-selector> #:id "theme-selector"
    #:items *kinetic-palettes* #:default-index 3)

  (make <meter> #:id "input-meter" #:role 'input-meter
    #:range-min -48.0 #:range-max 0.0 #:num-segments 24)
  (make <linear-slider> #:id "input-gain" #:role 'input-gain
    #:parameter-id "inputGain" #:parameter-name "Input Gain"
    #:processor-reference "inputGain" #:orientation 'vertical
    #:title "INPUT GAIN" #:min -24.0 #:max 24.0 #:default 0.0
    #:interval 0.1 #:value-type 'gain #:suffix " dB")

  (make <scope> #:id "scope-main" #:role 'scope
    #:tap-points '(pre-dsp post-dsp) #:grid-style 'radar
    #:glow-multiplier 1.2)

  (make <linear-slider> #:id "output-gain" #:role 'output-gain
    #:parameter-id "outputGain" #:parameter-name "Output Gain"
    #:processor-reference "outputGain" #:orientation 'vertical
    #:title "OUTPUT GAIN" #:min -24.0 #:max 24.0 #:default 0.0
    #:interval 0.1 #:value-type 'gain #:suffix " dB")
  (make <meter> #:id "output-meter" #:role 'output-meter
    #:range-min -48.0 #:range-max 0.0 #:num-segments 24)

  (make <linear-slider> #:id "wet-dry" #:role 'wet-dry
    #:parameter-id "wetdry" #:parameter-name "Wet Dry"
    #:processor-reference "wetdry" #:orientation 'horizontal
    #:title "WET / DRY" #:min 0.0 #:max 100.0 #:default 100.0
    #:interval 1.0 #:suffix " %" #:show-value #f
    #:show-ticks #t #:show-labels #t #:tick-count 5
    #:tick-labels '("DRY" "25" "50" "75" "WET"))

  (make <rotary-slider> #:id "oversampling" #:role 'oversampling
    #:parameter-id "oversampling" #:parameter-name "Oversampling"
    #:processor-reference "oversampling" #:title "OVERSAMPLING"
    #:min 0.0 #:max 3.0 #:default 0.0 #:interval 1.0
    #:show-ticks #t #:show-labels #t #:tick-count 4
    #:tick-labels '("OFF" "2x" "4x" "8x"))

  (make <rotary-slider> #:id "fft-size" #:role 'fft-size
    #:parameter-id "fftSize" #:parameter-name "FFT Size"
    #:processor-reference "fftSize" #:title "FFT SIZE"
    #:min 0.0 #:max 6.0 #:default 0.0 #:interval 1.0
    #:show-ticks #t #:show-labels #t #:tick-count 7
    #:tick-labels '("OFF" "256" "512" "1024" "2048" "4096" "8192"))

  (make <normal-toggle-button> #:id "bypass" #:role 'bypass
    #:text "BYPASS" #:parameter-id "bypass" #:parameter-name "Bypass"
    #:processor-reference "bypass")
  (make <normal-toggle-button> #:id "dsp-bypass" #:role 'dsp-bypass
    #:text "DSP BYPASS" #:parameter-id "dspBypass"
    #:parameter-name "DSP Bypass" #:processor-reference "dspBypass")

  (make <link> #:id "site-link" #:text "https://example.org/"
    #:url "https://example.org/" #:font-size 10.0
    #:justification 'bottom-left)
  (make <footer> #:id "copyright-footer"
    #:text "© 2026 Example — all rights reserved"
    #:font-size 10.0 #:justification 'bottom-right))

(define StandardEffect-topology
  (list
    (lt:place-in-area 'plugin-title 'top)
    (lt:place-in-area 'scope-main '(center top))
    (lt:group 'left-audio #:layout 'horizontal #:gap 0
      #:cross-align 'center #:area 'left 'input-meter 'input-gain)
    (lt:group 'right-audio #:layout 'horizontal #:gap 0
      #:cross-align 'center #:area 'right 'output-gain 'output-meter)
    (lt:group 'theme-strip #:layout 'vertical #:gap 0
      #:cross-align 'center #:area '(top-right top)
      'theme-label 'theme-selector)
    (lt:group 'lower-controls #:layout 'horizontal #:gap 2
      #:cross-align 'end #:area '(bottom top)
      'wet-dry 'oversampling 'fft-size 'bypass 'dsp-bypass)
    (lt:place-in-area 'site-link 'bottom-left)
    (lt:place-in-area 'copyright-footer 'bottom-right)
    (lt:align-bottom 'site-link 'copyright-footer)))

(MakeNewProject "standard-effect" StandardEffect-interface
  #:layout-mode 'topological
  #:topology-declarations StandardEffect-topology)
```

The 48-column lower group preferred width is 14+2+7+2+7+2+6+2+6 = 48. Areas remain anchors; this example relies on its known canonical geometry, not general collision avoidance.

### Reverb-style LLM example and semantic boundary

Natural request: “Create a reverb interface with input/output meters, dual scope, input/output gain, hard bypass, DSP bypass, oversampling, optional FFT, tempo subdivision 1/2 1/4 3/4 5/8, reverb depth and persistence.”

Use the standard infrastructure declarations above. Add ordinary parameters:

```scheme
(make <rotary-slider>
  #:id "reverb-depth"
  #:parameter-id "reverbDepth" #:parameter-name "Reverb Depth"
  #:processor-reference "reverbDepth"
  #:title "DEPTH" #:min 0.0 #:max 1.0 #:default 0.35 #:interval 0.01)

(make <rotary-slider>
  #:id "reverb-persistence"
  #:parameter-id "reverbPersistence" #:parameter-name "Persistence"
  #:processor-reference "reverbPersistence"
  #:title "PERSISTENCE" #:min 0.1 #:max 20.0 #:default 2.5
  #:interval 0.1 #:scale 'logarithmic #:suffix " s")

(make <selector>
  #:id "tempo-subdivision"
  #:items '("1/2" "1/4" "3/4" "5/8") #:default-index 2
  #:parameter-id "tempoSubdivision" #:parameter-name "Tempo Subdivision"
  #:processor-reference "tempoSubdivision")
```

Add them as ordinary members of an appropriate flat topology group, subject to screen capacity. Do **not** assign invented roles `reverb-depth`, `persistence`, or `tempo-sync`.

Generated today:

- all generic meters/gains/bypasses/scope/oversampling/FFT infrastructure;
- float parameters `reverbDepth` and `reverbPersistence`;
- choice parameter `tempoSubdivision`.

Developer responsibility in `PluginDSP.h`:

- implement reverb audio meaning using the cached parameter values;
- interpret subdivision choice;
- read optional host BPM/transport safely;
- define fallback, timing conversion and smoothing.

Release 1.0 does not automatically synchronize the subdivision parameter to BPM.

## 22. Known Release 1.0 limitations

- Topological groups cannot nest.
- Areas are anchors/bounds, not exclusive regions and do not ensure non-overlap.
- Scope tap vocabulary is limited to PRE and POST DSP.
- Generic tempo-sync/subdivision semantics are absent.
- Explicit UTF-8 conversion is guaranteed for label-like `setText`, not every textual property (button text, choice items, tooltips, parameter strings remain narrow literal paths).
- `fft-size` uniqueness is not enforced like the other global semantic roles.
- Arbitrary audio-routing graphs are not represented by the UI DSL.
- Custom DSP concepts generally remain ordinary APVTS parameters plus developer code in `PluginDSP.h`.
- Tick-mode, several label vocabularies, URL syntax, and some property types are emitter/runtime contracts rather than complete early validation.

## 23. LLM generation rules

Copy this operational checklist into generation prompts:

1. Use only documented concrete TYPEs and exact keyword spellings.
2. Do not invent ROLEs; ordinary effect parameters are bound sliders/selectors with no role.
3. Do not invent convenience keywords such as `#:step`, `#:min-db`, or `#:tap`.
4. Supply complete binding ID/name/reference for every slider and toggle/switch.
5. Preserve one instance of each uniqueness-enforced semantic role; also use only one `fft-size` by Release 1.0 convention.
6. Use `#:layout-mode 'topological` explicitly for reference/topological projects.
7. Use flat groups only; never place a group ID inside another group.
8. Treat areas as anchors/bounds, never exclusive regions; add explicit relations when non-overlap matters.
9. Use scope taps exactly as `'(pre-dsp)`, `'(post-dsp)`, or `'(pre-dsp post-dsp)`.
10. Use canonical metrics indirectly through TYPE/variant; do not copy historical spans.
11. Treat BPM subdivision as a graphical/parameter choice only; synchronization is developer DSP work.
12. Modify generator/YATemplate authority, never generated project output, for durable behavior.
