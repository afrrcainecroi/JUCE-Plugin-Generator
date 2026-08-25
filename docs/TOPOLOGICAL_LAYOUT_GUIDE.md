# JUCE Plugin Generator — Topological Layout Guide

## 1. Purpose

This is the normative Release 1.0 guide to the Scheme topological layout system. It explains how interface authors write constraints and how generator developers understand their exact implementation.

Component syntax belongs in `DSL_REFERENCE.md`; architecture invariants belong in `ARCHITECTURE_DECISIONS.md`. This guide covers relationships, solving, exact coordinates, refinement, and final layout emission. Current source and tests—not historical README prose—are authoritative.

## 2. Why topological layout exists

Legacy layout requires authors to assign every component a row, column, and spans. Topological layout instead states durable relationships: a meter is next to a gain, controls form a strip, a scope is centred in a screen area, or several nodes share an edge.

The generator obtains sizes from canonical UI metrics, solves relationships in Scheme, preserves exact rational geometry, refines only when needed, and supplies integer geometry to the existing JUCE Grid emitter. It never infers topology from component roles or names.

## 3. Generation pipeline

The implemented pipeline is:

```text
registered component alist models
 -> normalize-topological-model-layout
 -> nodes + alignments + groups + node-area placements
 -> lt:solve validation
 -> independent horizontal and vertical difference-constraint solves
 -> exact rational resolved geometry
 -> refine-topological-grid
 -> integer grid and component layout models
 -> generate-grid-code
 -> existing generated JUCE Grid layout
```

Exact boundaries:

1. `generator-app/topological-normalizer.scm`
   - `normalize-topological-model` maps a registered component model to an `lt:node`.
   - `normalize-topological-model-layout` validates declarations, attaches `lt:constrain` relations, and builds normalized IR.
   - `solve-normalized-topological-layout` invokes `lt:solve` with the registered grid dimensions.
2. `generator-app/topological-layout.scm`
   - `lt:solve` validates IR, solves hard constraints, resolves areas, optimizes cohesion wishes, and reports nodes and group bounding boxes.
3. `generator-app/generation-orchestration.scm`
   - `build-topological-shadow` normalizes, solves, and compares legacy geometry.
   - `prepare-generation-layout` selects legacy or topological output.
   - `refine-topological-grid` makes rational geometry discrete.
   - `generate-selected-grid-code` calls the established emitter.
4. `generator-app/layout.scm`
   - `generate-grid-code` emits the component map and grid/component JSON consumed by generated C++.

The solver runs entirely in Scheme. Generated C++ receives only resolved `row`, `col`, `rowSpan`, and `colSpan`.

## 4. Logical coordinates and UI metrics

### Canonical footprints

`generator-app/ui-metrics.scm` is authoritative. Profiles are `compact`, `standard`, and `extended`, corresponding to visual-min, preferred, and useful-max where represented.

| Type/variant | Compact | Preferred/standard | Useful-max/extended |
|---|---:|---:|---:|
| rotary slider | 5×5 | 7×7 | 9×9 |
| horizontal linear slider | 10×3 | 14×4 | 18×5 |
| vertical linear slider | 3×10 | 4×14 | 5×18 |
| vertical segmented meter | 1×10 | 1×14 | 2×18 |
| scope | 8×6 | 18×10 | 18×10 |

Dimensions are width × height in logical units, not pixels.

`dsl-model->metric-type` uses an explicit TYPE mapping. `component-metric-variant` derives horizontal/vertical linear-slider variants and segmented-vertical/segmented-horizontal/analog meter variants. `preferred-metric-profile` selects the declared preferred profile, normally `standard`.

`normalize-topological-model` deliberately ignores legacy `rowSpan` and `colSpan`; node spans come from metrics. Authored legacy `row` and `col`, if present, remain hard anchors.

## 5. Nodes

### Low-level API

```scheme
(lt:node id type profile
  #:variant variant-or-#f
  #:row integer-or-omitted
  #:col integer-or-omitted
  #:constraints (list positional-constraint ...))
```

`id`, `type`, and `profile` must be symbols. Variant is a symbol or `#f`. Anchors, when supplied, are integers. Constraints default to empty.

```scheme
(lt:node 'scope-a 'scope 'compact #:row 2 #:col 3)
```

Nodes do not store width/height. `node-size` resolves them from TYPE, variant, and profile during `lt:solve`.

### Normal author usage

Interface authors normally register ordinary UI components and reference their IDs in topology:

```scheme
(make <scope> #:id 'scope-main #:role 'scope)
(define topology
  (list (lt:place-in-area 'scope-main '(center top))))
```

The normalizer derives the node. Direct `lt:node` construction is a public low-level solver API useful in tests and generator development.

String DSL IDs are converted losslessly to symbols for topology matching. The complete IR is collected before validation, so forward references work.

## 6. Relations

Let a node start at `x,y`, with width `w` and height `h`. In `lt:constrain`, the first ID is the target; each constructor names its reference.

### Exact adjacency

Exact relations add both inequalities needed for equality.

#### `next-right-of`

```text
B.x = A.x + A.w
[ A ][ B ]
```

```scheme
(lt:constrain 'b (lt:next-right-of 'a))
```

Horizontal only. Use `right-of` when whitespace may vary.

#### `next-left-of`

```text
B.x + B.w = A.x
[ B ][ A ]
```

```scheme
(lt:constrain 'b (lt:next-left-of 'a))
```

Horizontal only. The target width determines the inverse offset.

#### `next-below`

```text
B.y = A.y + A.h
[ A ]
[ B ]
```

```scheme
(lt:constrain 'b (lt:next-below 'a))
```

Vertical only; it does not align X.

#### `next-above`

```text
B.y + B.h = A.y
[ B ]
[ A ]
```

```scheme
(lt:constrain 'b (lt:next-above 'a))
```

Vertical only.

### Partial order

These add one inequality. The earliest unconstrained solution may happen to be adjacent, but adjacency is not guaranteed.

#### `right-of`

```text
B.x >= A.x + A.w
[ A ] ... [ B ]
```

```scheme
(lt:constrain 'b (lt:right-of 'a))
```

#### `left-of`

```text
B.x + B.w <= A.x
[ B ] ... [ A ]
```

```scheme
(lt:constrain 'b (lt:left-of 'a))
```

#### `below`

```text
B.y >= A.y + A.h
[ A ]
  .
[ B ]
```

```scheme
(lt:constrain 'b (lt:below 'a))
```

#### `above`

```text
B.y + B.h <= A.y
[ B ]
  .
[ A ]
```

```scheme
(lt:constrain 'b (lt:above 'a))
```

### Alignments

Alignment declarations take two or more IDs and add hard equalities:

| Relation | Axis | Equation |
|---|---|---|
| `align-left` | X | `A.x = B.x` |
| `align-right` | X | `A.x+A.w = B.x+B.w` |
| `align-top` | Y | `A.y = B.y` |
| `align-bottom` | Y | `A.y+A.h = B.y+B.h` |
| `align-center-x` | X | `A.x+A.w/2 = B.x+B.w/2` |
| `align-center-y` | Y | `A.y+A.h/2 = B.y+B.h/2` |

```scheme
(lt:align-left 'a 'b 'c)
(lt:align-right 'a 'b)
(lt:align-top 'a 'b)
(lt:align-bottom 'a 'b)
(lt:align-center-x 'a 'b)
(lt:align-center-y 'a 'b)
```

The first ID is the reference and each later ID is independently equated to it. Alignment does not order nodes; equal-sized aligned nodes may overlap.

## 7. Constraint syntax

```scheme
(lt:constrain target positional-relation ...)
```

The target must be a symbol and at least one positional relation is required. Only the eight exact/partial positional constructors are accepted—not alignments.

```scheme
(lt:constrain 'output-meter (lt:next-right-of 'output-gain))

(lt:constrain 'scope-main
  (lt:right-of 'input-gain)
  (lt:above 'wet-dry))
```

Multiple `lt:constrain` declarations for one target are legal; `attach-node-constraints` concatenates them in declaration order.

Forward reference:

```scheme
(define topology
  (list (lt:constrain 'later (lt:next-right-of 'earlier))))
;; Registration/input order of earlier and later is immaterial.
```

A missing target is rejected during normalization; a missing reference is rejected during solve.

## 8. Groups

### Syntax and validation

```scheme
(lt:group group-id
  #:layout 'horizontal-or-vertical
  #:cohesion 'weak-or-medium-or-strong
  #:cross-align 'start-or-center-or-end
  #:gap non-negative-exact-real
  #:area area-symbol-or-path
  member-id member-id ...)
```

Only `#:layout` is required. Defaults are no cohesion, no cross alignment, gap 0, and no area. Enforced rules:

- layout is exactly `horizontal` or `vertical`;
- at least two distinct symbol member IDs;
- every member resolves to a node;
- group IDs are unique and cannot collide with node IDs;
- gap is non-negative, exact, and real: `0`, `2`, and `1/2` are valid; `1.0`, `-1`, symbols, and complex numbers are invalid;
- each keyword may occur once.

Without cohesion, a horizontal group applies:

```text
next.x = previous.x + previous.width + gap
```

A vertical group applies the analogous equality on Y using height.

```scheme
(lt:group 'audio-strip #:layout 'horizontal #:gap 0
  'input-meter 'input-gain)

(lt:group 'theme-strip #:layout 'vertical #:gap 0
  'theme-label 'theme-selector)
```

Ordering does not align the cross axis unless `#:cross-align` or a separate alignment is present.

### Resolved bounding box

Groups are derived objects, not graph vertices. `resolved-group` computes minimum member row/column and maximum member ends, producing `row`, `col`, `rowSpan`, and `colSpan`. Area placement preserves member offsets relative to the first member and positions this derived box.

## 9. Cross alignment

Cross alignment acts perpendicularly to group layout:

| Layout | `start` | `center` | `end` |
|---|---|---|---|
| horizontal | align tops | align Y centres | align bottoms |
| vertical | align lefts | align X centres | align rights |

```scheme
(lt:group 'audio #:layout 'horizontal
  #:cross-align 'center #:gap 0
  'input-meter 'input-gain)

(lt:group 'theme #:layout 'vertical
  #:cross-align 'end #:gap 0
  'theme-label 'theme-selector)
```

All are hard alignments. `baseline` and CSS-style values are not supported.

## 10. Cohesion and soft wishes

Without `#:cohesion`, group spacing is hard and exact. With cohesion, each consecutive primary-axis spacing becomes a soft wish.

Weights from `cohesion-weight`:

| Value | Weight |
|---|---:|
| `weak` | 1 |
| `medium` | 2 |
| `strong` | 3 |

`soft-configurations` considers three states per adjacent pair:

1. exact preferred gap;
2. non-overlap order with another gap;
3. no added ordering edge, permitting overlap or reversal if hard constraints force it.

`better-soft-solution?` minimizes, in order:

1. weighted order violations;
2. weighted absolute positive-gap deviation;
3. then prefers more exact wishes;
4. then more order-only wishes.

Soft wishes never override anchors, positional relations, alignments, area placement, or screen bounds.

```scheme
(lt:group 'controls #:layout 'horizontal
  #:gap 2 #:cohesion 'strong
  'wet-dry 'oversampling 'fft-size)
```

The preferred gap is 2, not a guarantee. Inspect a resolved group’s `soft-cost` when hard constraints force compromise.

## 11. Areas

### Vocabulary and recursion

Each path step is one of:

```text
top-left     top     top-right
left         center  right
bottom-left  bottom  bottom-right
```

A symbol is a one-step path. A nonempty proper list recursively selects thirds:

```scheme
'top
'left
'center
'(top-right top)
'(center top)
'(bottom-right top-left center)
```

Starting bounds are `[1, screen-cols+1]` and `[1, screen-rows+1]`. `select-area-third` divides current bounds exactly into three and selects the area index on each axis.

On a 24×15 screen the first-level boundaries are:

```text
X: [1,9] [9,17] [17,25]
Y: [1,6] [6,11] [11,16]
```

The final path step controls bounding-box alignment within the selected bounds:

- left/top index: start aligned;
- centre index: centred;
- right/bottom index: end aligned.

A compact 4×3 toggle resolves as:

| Area | col,row |
|---|---:|
| `top-left` | 1,1 |
| `top` | 11,1 |
| `top-right` | 21,1 |
| `left` | 1,7 |
| `center` | 11,7 |
| `right` | 21,7 |
| `bottom-left` | 1,13 |
| `bottom` | 11,13 |
| `bottom-right` | 21,13 |

These values are asserted in `tests/topological-layout-test.scm`. Recursive widths such as 24/3/3 remain exact rationals.

Invalid areas include `foo`, the empty list, paths with unknown symbols, improper lists, and paths containing non-symbols.

## 12. Areas are not exclusive

> **Release 1.0 invariant: an area is an anchor, not reserved space.**

Area placement computes an exact start for a node/group bounding box and adds whole-screen bounds. It does not:

- reserve or mark cells occupied;
- keep another independently placed box away;
- create inter-group relations;
- provide collision detection or packing.

This declaration can overlap:

```scheme
(list
  (lt:group 'first #:layout 'horizontal #:area 'center 'a 'b)
  (lt:group 'second #:layout 'horizontal #:area 'center 'c 'd))
```

No relationship connects the groups. Add the missing relationship, for example:

```scheme
(lt:constrain 'c (lt:right-of 'b))
```

Different semantic-looking area paths still do not prove non-overlap.

## 13. Place in area

For a node:

```scheme
(lt:place-in-area 'scope-main '(center top))
```

Exact signature: `(lt:place-in-area node-id area)`. The target must exist and each node may have only one such declaration.

Groups use their own area property:

```scheme
(lt:group 'theme-strip #:layout 'vertical
  #:area '(top-right top)
  'theme-label 'theme-selector)
```

`lt:place-in-area` does not target groups: `validate-node-area-placements!` resolves targets against nodes only. Any area placement requires both positive exact integer screen dimensions, normally supplied by the registered `<grid>`.

## 14. Flat group limitation

Groups cannot contain groups. `validate-groups!` resolves every member only against node IDs.

Invalid:

```scheme
(lt:group 'audio #:layout 'horizontal 'meter 'gain)
(lt:group 'whole #:layout 'vertical 'scope 'audio)
```

Valid flat alternative:

```scheme
(lt:group 'audio #:layout 'horizontal 'meter 'gain)
(lt:constrain 'meter (lt:below 'scope))
(lt:align-center-x 'scope 'meter 'gain)
```

Multiple flat groups may share nodes when their combined hard constraints are consistent. Compose larger layouts through relations and alignments, not undocumented nesting.

## 15. Solver model

An edge `(U V W)` means:

```text
V >= U + W
```

`constraint-edges`, `alignment-edges`, `group-edges`, and area placement build these edges. Equalities add the reverse inequality. A synthetic origin supplies one-based lower bounds and exact authored anchors.

Horizontal and vertical axes solve independently:

- width affects X constraints;
- height affects Y constraints;
- X relations do not affect Y, and vice versa.

`solve-area-axis` first obtains an authoritative hard solution, derives exact area placement from it, and solves again with area/screen constraints. `optimize-soft-axis` then tests cohesion configurations without weakening hard constraints.

`solve-axis` repeatedly relaxes the difference graph. Origin bounds plus deterministic input order choose the earliest solution where inequalities leave freedom. A positive-weight cycle is impossible and produces `Contradictory hard positional constraints`.

This is a rectangular constraint solver, not a general packing or semantic-layout engine.

## 16. Contradictions

Typical hard contradictions:

- incompatible exact anchors and adjacency;
- A next-right-of B while B next-right-of A;
- aligned nodes with incompatible hard coordinates;
- area target placement conflicting with an authored anchor;
- placement sending a member outside whole-screen bounds;
- hard group spacing conflicting with another positional relation.

Do not weaken contradiction detection.

### Stabilized recursive-area fixture

Two preferred text buttons have width 8 each. At gap 0 their hard group width is:

```text
8 + 8 = 16
```

For `'(top-right bottom-left)` on 24 columns:

```text
24 / 3 / 3 = 8/3
```

The final horizontal left index anchors the 16-column group at column 17. It would end at 33, beyond the screen end line 25. Exact area anchoring plus screen containment is contradictory.

With the synthetic 144-column grid used by `tests/topological-generated-layout-test.scm`:

```text
144 / 3 / 3 = 16
```

The same group fits exactly. The old 24-column fixture was wrong; the solver was correct.

## 17. Forward references

References may precede node input because the complete IR is assembled first:

```scheme
(define topology
  (list
    (lt:constrain 'b (lt:next-right-of 'a))
    (lt:align-top 'a 'b)))
```

Groups and low-level alignments also support forward references. Missing references do not: a missing `lt:constrain` target fails in `attach-node-constraints`; a missing relation or alignment reference fails in the solver.

## 18. Rational coordinates

Centre alignment, thirds, and odd/even dimensions naturally create fractions. Scheme exact arithmetic is preserved.

The integration fixture centre-aligns an 8-wide text button at column 1 with a 7-wide rotary:

```text
button centre = 1 + 8/2 = 5
rotary col + 7/2 = 5
rotary col = 3/2
```

The result is exact `3/2`. Tests also prove `5/2`, `7/2`, and hierarchical thirds such as `49/3`. Premature rounding would break alignment and proportional placement.

## 19. Refinement

`axis-refinement-factor` takes the least common multiple of coordinate denominators independently:

```text
dx = LCM(all column denominators)
dy = LCM(all row denominators)
```

Implemented transformations:

```text
newCoordinate = 1 + factor * (logicalCoordinate - 1)
newSpan       = factor * logicalSpan
```

`tests/topological-generated-layout-test.scm` yields:

```text
dx = 2
dy = 1
```

Its 144×15 logical grid becomes 288×15. X and Y differ because their rational denominators differ. One-based origin remains 1, and `refine-entry` requires exact integer output.

## 20. Final JUCE Grid

`discrete-layout-components` combines integer geometry with each generated C++ variable and retained margins. `generate-grid-code` receives the refined `rows`, `cols`, `show-grid`, and integer component records.

The resulting component map and JSON use the established generated JUCE Grid path. Topology changes where geometry comes from; it does not generate a C++ solver or a new runtime layout architecture.

## 21. Legacy versus topological mode

Topological generation must be explicit:

```scheme
(MakeNewProject
  "plugin"
  Interface
  #:layout-mode 'topological
  #:topology-declarations topology)
```

Metrics determine spans and topology determines positions. Legacy spans are ignored, though mismatches are reported in normalizer warnings. Legacy row/col values remain hard anchors.

Legacy is the current default:

```scheme
(MakeNewProject "plugin" Interface)
```

Legacy emission uses authored row/col/spans. It also runs `run-generation-topological-shadow` diagnostically, but shadow results never feed the legacy emitter. `tests/topological-shadow-integration-test.scm` verifies byte-identical legacy output.

Passing topology declarations does not select topological emission. Accidentally omitting `#:layout-mode 'topological` can materially change a reference interface.

## 22. Practical patterns

### Input audio strip

```scheme
(lt:group 'left-audio-strip
  #:layout 'horizontal #:cross-align 'center #:gap 0 #:area 'left
  'input-meter 'input-gain)
```

### Output audio strip

```scheme
(lt:group 'right-audio-strip
  #:layout 'horizontal #:cross-align 'center #:gap 0 #:area 'right
  'output-gain 'output-meter)
```

### Vertical theme group

```scheme
(lt:group 'theme-strip
  #:layout 'vertical #:cross-align 'center #:gap 0
  #:area '(top-right top)
  'theme-label 'theme-selector)
```

### Flat lower strip

```scheme
(lt:group 'control-strip
  #:layout 'horizontal #:cross-align 'end #:gap 2
  #:area '(bottom top)
  'wet-dry 'oversampling 'fft-size 'bypass 'dsp-bypass)
```

### Scope and title

```scheme
(lt:place-in-area 'scope-main '(center top))
(lt:place-in-area 'plugin-title 'top)
```

### Footer

```scheme
(lt:place-in-area 'site-link 'bottom-left)
(lt:place-in-area 'copyright-footer 'bottom-right)
(lt:align-bottom 'site-link 'copyright-footer)
```

The last alignment explicitly relates the independently placed footer nodes.

## 23. Complete pure-Scheme example

```scheme
(use-modules (oop goops)
             (generator-app code-generator)
             (generator-app topological-layout)
             (generator-app topological-normalizer))

(define example-components
  (list
    (make <header> #:id 'title #:text "EXAMPLE")
    (make <meter> #:id 'input-meter #:role 'input-meter
          #:style 'segmented #:orientation 'vertical)
    (make <scope> #:id 'scope-main #:role 'scope)
    (make <meter> #:id 'output-meter #:role 'output-meter
          #:style 'segmented #:orientation 'vertical)
    (make <label> #:id 'theme-label #:text "THEME")
    (make <palette-selector> #:id 'theme-selector
          #:items '("Gold/Amber" "Toxic/Lime") #:default-index 1)
    (make <link> #:id 'site-link #:text "https://example.org/"
          #:url "https://example.org/")
    (make <footer> #:id 'copyright #:text "© Example")))

(define example-topology
  (list
    (lt:place-in-area 'title 'top)
    (lt:place-in-area 'scope-main '(center top))
    (lt:place-in-area 'input-meter 'left)
    (lt:place-in-area 'output-meter 'right)
    (lt:group 'theme-strip #:layout 'vertical
      #:cross-align 'center #:gap 0 #:area '(top-right top)
      'theme-label 'theme-selector)
    (lt:place-in-area 'site-link 'bottom-left)
    (lt:place-in-area 'copyright 'bottom-right)
    (lt:align-bottom 'site-link 'copyright)))

(define normalized
  (normalize-topological-layout
    example-components example-topology
    #:grid (make <grid> #:rows 30 #:cols 72 #:show-grid #f)))

(define resolved
  (solve-normalized-topological-layout normalized))
```

For generation:

```scheme
(MakeNewProject
  "example"
  ExampleInterface
  #:layout-mode 'topological
  #:topology-declarations example-topology)
```

## 24. pppbuttavia case study

Current `pppbuttavia-topology` in `generator.scm` expresses:

```text
top:                 plugin title
left audio strip:    input meter -> input gain, zero gap
centre/top:           18×10 preferred scope
right audio strip:   output gain -> output meter, zero gap
lower strip:         wet/dry -> oversampling -> FFT size
                     -> hard bypass -> DSP bypass, gap 2
top-right/top:        theme label above selector, zero gap
bottom corners:       site link and copyright, aligned at bottom
```

All groups are flat. Generated coordinates are evidence of a solve, not authority; declarations, metrics, normalizer, and solver are authoritative.

The independently placed audio, scope, controls, theme, and footer groups have no automatic mutual exclusion. Their actual dimensions and explicit constraints determine whether they overlap.

## 25. Debugging topology

Use this order:

1. Verify registered IDs and exact spelling.
2. Verify TYPE-to-metric mapping, variant, and preferred profile.
3. Compute group extent from member metrics and hard gaps.
4. Compute recursive area bounds from the grid.
5. Distinguish exact `next-*` from partial-order relations.
6. Check cross-axis alignment separately.
7. Translate suspected cycles to `V >= U + W`.
8. Solve logical geometry before considering refinement.
9. Inspect cohesive group `soft-cost`.
10. Never weaken contradiction detection to make a fixture pass.

Example:

```text
two standard text buttons = 8 + 8 = 16 columns
24-column recursive third = 24 / 3 / 3 = 8/3
anchored start = 17
end = 17 + 16 = 33 > screen end line 25
result = contradictory horizontal hard constraints
```

## 26. Error reference

| Detected condition | Cause | Typical fix |
|---|---|---|
| Missing constrain target | ID absent during normalization | Correct/register target. |
| Missing positional reference | Reference absent at solve | Correct/register reference. |
| Missing alignment reference | Alignment ID absent | Use existing IDs. |
| Duplicate node ID | Repeated logical node | Rename one. |
| Duplicate group ID | Repeated group | Rename one. |
| Group/node ID collision | Same symbol used for both | Use distinct IDs. |
| Duplicate member | Member repeated | List once. |
| Missing member/nested group | Member is not a node | Flatten composition. |
| Too few members | Fewer than two | Add a node or use relations. |
| Invalid/duplicate keyword | Unsupported/repeated option | Use documented options once. |
| Invalid layout | Not horizontal/vertical | Correct orientation. |
| Invalid cross-align | Not start/center/end | Correct value. |
| Invalid cohesion | Not weak/medium/strong | Correct or omit. |
| Invalid gap | Negative/inexact/non-real | Use non-negative exact real. |
| Invalid area/path | Bad vocabulary/path shape | Use hierarchical thirds vocabulary. |
| Duplicate node-area | Node placed twice | Keep one placement. |
| Missing screen dimensions | Area used without rows+cols | Register/provide grid. |
| Oversize target | Bounding box exceeds screen | Reduce footprint/group or enlarge grid. |
| Area/anchor conflict | Exact placements disagree | Remove conflicting hard anchor. |
| Positive cycle | Hard inequalities contradict | Correct topology; keep detection. |
| Unknown metric TYPE | No registry entry/mapping | Use supported TYPE. |
| Bad variant/profile | Missing metrics profile | Let normalizer derive it. |
| Non-exact refinement input | Inexact coordinate introduced | Preserve exact Scheme numbers. |

There is no general collision error. Independent overlaps are accepted unless explicit hard constraints contradict.

## 27. LLM layout-generation rules

```text
- Use registered component IDs exactly.
- Let the normalizer derive nodes and dimensions.
- Use current preferred/standard metrics unless explicitly instructed otherwise.
- Use next-* only for exact adjacency.
- Use right-of/left-of/above/below for flexible ordering.
- Remember each positional relation affects only one axis.
- Use group #:gap, not dummy spacer nodes.
- Use #:cross-align for perpendicular-axis group alignment.
- Keep groups flat; never nest them.
- Do not assume areas reserve space or prevent overlap.
- Compute metrics and recursive area bounds before writing constraints.
- Do not hard-code final integer row/col/spans in topological mode.
- Preserve exact rationals until refinement.
- Do not weaken contradiction detection.
- Keep #:layout-mode 'topological explicit for reference generation.
```

## 28. Release 1.0 limitations

- No nested groups.
- Areas are not exclusive.
- No general packing, occupancy, or non-overlap solver.
- No arbitrary region algebra beyond current hierarchical thirds.
- Two-axis rectangular topology only.
- Soft cohesion is limited to the current weighted finite gap/order preference model.
- Cohesion can permit overlap/reversal when hard constraints force it.
- Legacy and topological modes coexist; legacy is default.
- Rational refinement may enlarge X and Y grid dimensions independently.
- Preferred profiles are selected by the normalizer; no responsive profile selection.
- No semantic layout inference from ROLE or component names.
- No general collision detection.

## 29. Authoritative implementation and tests

- `generator-app/topological-layout.scm`: IR, equations, groups, areas, hard solve, cohesion, bounding boxes.
- `generator-app/topological-normalizer.scm`: component-model mapping and declaration adaptation.
- `generator-app/generation-orchestration.scm`: shadow, mode selection, refinement, selected output.
- `generator-app/ui-metrics.scm`: footprints and variants.
- `generator-app/layout.scm`: grid model and existing emitter.
- `tests/topological-layout-test.scm`: relation, group, area, soft, rational, and error semantics.
- `tests/topological-normalizer-test.scm`: high-level adapter behavior.
- `tests/topological-generated-layout-test.scm`: exact refinement and emitted integers.
- `tests/topological-shadow-integration-test.scm`: diagnostic shadow isolation.
- `generator.scm`: generation mode and `pppbuttavia-topology`.

For intentional post-1.0 changes, update implementation, focused tests, and the applicable architecture decision together.
