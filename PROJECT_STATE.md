# JUCE Plugin Generator - Project State

## Goal

Generatore di plugin JUCE scritto in Guile/Scheme.

La specifica Scheme descrive:
- componenti GUI;
- parametri DAW/APVTS;
- semantica DSP tramite role;
- layout;
- proprietà grafiche KineticLookAndFeel.

Il generatore produce il progetto C++ JUCE completo.

## Working method

Procedere incrementalmente.

Una modifica per volta:
1. definire il comportamento;
2. modificare il generatore;
3. rigenerare il plugin;
4. compilare;
5. provare;
6. approvare;
7. commit Git.

Non inserire manualmente nel plugin generato codice che dovrebbe appartenere al generatore.

## Main files

Main Scheme generator:

    generator-app/code-generator.scm

Main generated JUCE files include:

    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
    Source/KineticLookAndFeel.cpp
    Source/KineticLookAndFeel.h

## Architecture

    Scheme specification
            |
            v
    component/model registration
            |
            v
    intermediate model
            |
            +---- GUI emitters
            +---- APVTS emitters
            +---- DSP emitters
            +---- layout information
            |
            v
    generated JUCE C++

Future layout architecture:

    semantic layout constraints
            |
            v
    layout solver
            |
            v
    row/col/rowSpan/colSpan
            |
            v
    C++/JSON emitter

For now layout solver is postponed.
Rows, columns, spans and margins are explicitly specified.

## Component roles

Semantic role is independent from graphical component type.

Currently defined roles:

    input-gain
    output-gain
    wet-dry
    bypass
    dsp-bypass
    oversampling
    input-meter
    output-meter
    scope

Role uniqueness must be validated for roles that may occur only once.

Lookup:

    find-component-by-role

## Component hierarchy

    <component>
    ├── <label>
    │   ├── <header>
    │   ├── <footer>
    │   ├── <link>
    │   └── <palette-label>
    ├── <selector>
    │   └── <palette-selector>
    ├── <button>
    │   ├── <text-button>
    │   └── <toggle-button>
    │       ├── <normal-toggle-button>
    │       └── <switch>
    │           └── <bypass-switch>
    ├── <slider>
    │   ├── <rotary-slider>
    │   └── <linear-slider>
    ├── <meter>
    └── <scope>

Base <component> contains role.

component->model base method emits common properties.
Specialized methods extend it using next-method.

## Parameterized component families

Do NOT special-case only bypass-switch.

Boolean/button parameter family:

    toggle-button
    normal-toggle-button
    switch
    bypass-switch

Slider parameter family:

    rotary-slider
    linear-slider

Helpers:

    button-parameter-type?
    slider-parameter-type?
    parameter-component-type?

These are used by:

    model->attachment-declaration
    model->attachment-code
    model->parameter-code
    model->dparams-code
    model->getparams-code
    model->valueparams-code
    model->destroy-code

## DSP semantics

Hard bypass:

    role = bypass

OFF:
    normal processing

ON:
    processBlock returns immediately.
    Input buffer remains untouched.
    Entire DSP/infrastructure pipeline is skipped.

DSP bypass:

    role = dsp-bypass

OFF:
    myplugin->render(buffer) executes

ON:
    only central DSP processing is bypassed.
    Input/output gain, meters, scope etc. may continue.

Current desired pipeline:

    HARD BYPASS
        |
    INPUT GAIN
        |
    INPUT METER
        |
    DRY COPY             [future wet/dry]
        |
    DSP BYPASS
        |
    OVERSAMPLING         [future]
        |
    myplugin->render()
        |
    DOWNSAMPLING         [future]
        |
    WET/DRY MIX          [future]
        |
    OUTPUT GAIN
        |
    OUTPUT METER
        |
    SCOPE

Gain parameters are dB.

JUCE buffer.applyGain() must receive linear gain:

    juce::Decibels::decibelsToGain(value_inputGain)
    juce::Decibels::decibelsToGain(value_outputGain)

## DSP generation

Generated processor block:

    /// PROCESS START

    generated code

    /// PROCESS END

generate-process-code currently composes:

    generate-process-bypass
    generate-process-input-gain
    generate-process-input-meter
    generate-process-dsp
    generate-process-output-gain
    generate-process-output-meter
    generate-process-scope

generate-process-dsp checks role dsp-bypass.

If dsp-bypass does not exist:

    myplugin->render(buffer);

If it exists:

    if (value_DSPBypass < 0.5f)
        myplugin->render(buffer);

Next DSP additions:

1. wet-dry
2. oversampling

These will require declarations/setup in addition to PROCESS code.
Do not allocate audio buffers dynamically in processBlock.

## GUI bypass feedback

Generated editor block:

    /// PAINT_OVER_CHILDREN START

    generated code

    /// PAINT_OVER_CHILDREN END

Hard bypass:
- dark overlay;
- large "BYPASSED";
- other children disabled.

DSP bypass:
- plugin remains usable;
- separate visible "DSP BYPASSED" feedback;
- must not behave like hard bypass.

## Slider properties

The Scheme model already defines properties including:

    title
    value-type
    suffix
    show-value
    show-ticks
    show-labels
    tick-count
    tick-mode
    tick-labels

These MUST remain semantic properties of the component.
Do not replace them by hardcoded behaviour in the generator.

slider-kinetic-properties->cpp already emits:

    title
    valueType
    suffix
    showValue
    showTicks
    showLabels
    tickCount
    tickMode
    tickLabels

KineticLookAndFeel must interpret these properties.

formatMetric(value, type) already formats:
- gain
- freq/hz
- generic values

The long raw numeric values previously visible beside sliders came
from JUCE Slider's standard TextBox, not formatMetric.

The generated constructor should therefore use:

    slider.setTextBoxStyle(
        juce::Slider::NoTextBox,
        false,
        0,
        0);

because KineticLookAndFeel draws the formatted value itself.

IMPORTANT:
Properties still have to be managed correctly.
Do not remove or bypass valueType/suffix/showValue/etc.
They define how KineticLookAndFeel renders a component.

## Layout

Automatic semantic layout solver already exists as prototype but
integration is postponed.

For now use explicit:

    row
    col
    row-span
    col-span
    margin-tb
    margin-lr

Current JSON grid key is:

    cols

NOT:

    columns

## Generated block markers

Canonical form:

    /// INTERFACE START
    /// INTERFACE END

    /// VALUEPARAMS START
    /// VALUEPARAMS END

    /// PROCESS START
    /// PROCESS END

    /// PAINT_OVER_CHILDREN START
    /// PAINT_OVER_CHILDREN END

No '*' character belongs in emitted markers.

## UUID / VST3 CID

Plugin UUID/CID must remain stable when regenerating the same project.

A new UUID is generated only when creating a genuinely new project.

Deleting and regenerating a project must NOT silently assign a new
plugin identity if it represents the same plugin.

## Current work

Current milestone:

    generated DSP pipeline

Already addressed:
- hard bypass
- input gain
- input meter
- DSP bypass
- output gain
- output meter
- scope
- generic APVTS support for switches/buttons/sliders

Immediate tasks:

1. verify NoTextBox generation for all sliders
2. finish graphical feedback for bypass / dsp-bypass
3. verify slider properties remain correctly interpreted
4. generate wet-dry DSP
5. generate oversampling DSP
6. later integrate automatic layout solver
