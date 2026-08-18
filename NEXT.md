# Current task

## Current milestone

Generated DSP pipeline and semantic GUI roles.

## Completed

- component semantic roles
- input-gain
- output-gain
- input-meter
- output-meter
- hard bypass
- dsp-bypass
- scope
- generalized APVTS generation for slider/toggle parameter families
- PROCESS generated block
- PAINT_OVER_CHILDREN generated block
- stable VST3 UUID/CID handling
- grid key normalized to `cols`
- slider properties emitted through `slider-kinetic-properties->cpp`
- `KineticLookAndFeel::formatMetric()` verified

## Immediate work

1. Verify generated `Slider::NoTextBox` for rotary and linear sliders.
2. Verify the displayed values are now produced only by `KineticLookAndFeel`.
3. Complete/fix hard-bypass graphical overlay so `BYPASSED` is fully visible.
4. Complete DSP-bypass graphical feedback (`DSP BYPASSED`).
5. Verify all slider properties are correctly interpreted:
   - valueType
   - suffix
   - showValue
   - showTicks
   - showLabels
   - tickCount
   - tickMode
   - tickLabels
6. Generate wet/dry DSP.
7. Generate oversampling DSP.

## Deferred

- automatic semantic layout solver integration
- meter graphical refinement
- initial palette selector synchronization
- further graphical refinements
