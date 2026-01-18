# D3 Dependency Reduction Plan

**Status**: In Progress (Phase 6 blocked on design)
**Created**: 2026-01-18
**Updated**: 2026-01-18
**Branch**: `feature/d3-reduction`

**Completed Phases**:
- Phase 1: Dead code removal ✓
- Phase 2: Code Explorer d3-hierarchy removal ✓
- Phase 3: d3-chord removal ✓
- Phase 4: Easing unification ✓
- Phase 5: Transition system unification ✓

**Blocked**:
- Phase 6: Requires unified transition model design (see `docs/kb/architecture/unified-transition-model.md`)

## Executive Summary

PSD3 has evolved beyond its origins as "PureScript bindings for D3". Many D3 modules are now redundant - replaced by pure PureScript implementations or used only through inertia. This plan systematically removes unnecessary D3 dependencies while preserving functionality.

**Goal**: Reduce D3 surface area to the genuine essentials, unify animation systems, and document what remains.

**Risk mitigation**: Work on feature branch, run full showcase suite after each phase.

---

## Current D3 Dependencies (Audit Summary)

| D3 Module | Status | Used In | Action |
|-----------|--------|---------|--------|
| d3-hierarchy | ✓ REMOVED | N/A | Dead code - never imported |
| d3-chord | ✓ REMOVED | N/A | Replaced with DataViz.Layout.Chord |
| d3-ease | ✓ SUPERSEDED | N/A | PSD3.Transition.Tick/Easing now complete |
| d3-transition | In use (tour) | Capabilities.Transition, tour demos | **KEEP** - unified model design in progress |
| d3-selection | ✓ CLEANED | Drag, highlights only | ~20 unused exports removed |
| d3-scale | Essential | Scales, color schemes | **Keep** (for now) |
| d3-force | Essential | Force simulation | **Keep** (WASM alternative exists) |
| d3-drag | Essential | Drag behavior | **Keep** |
| d3-zoom | Essential | Zoom/pan behavior | **Keep** |
| d3-brush | Essential | Brush selection | **Keep** - flag for coordinated interaction design |
| d3-shape | Partially used | Line generator | **Assess** |
| d3-interpolate | Used by scales | Color interpolation | **Keep** (tied to scales) |

---

## Phase 1: Dead Code Removal (Low Risk)

### 1.1 Remove unused d3-hierarchy imports

**Files**: `psd3-selection/src/PSD3/Internal/FFI.js`

Remove imports that are never called:
```javascript
// REMOVE these imports (lines 8-10)
import { hierarchy, cluster, tree, pack, treemap, partition } from "d3-hierarchy";
```

**Note**: `hierarchy` and `pack` ARE used internally in `updateNodeExpansion_` and `drawInterModuleDeclarationLinks_` - these functions are Code Explorer specific and will be addressed in Phase 2.

### 1.2 Remove unused d3-selection FFI exports

**Files**:
- `psd3-selection/src/PSD3/Internal/FFI.purs`
- `psd3-selection/src/PSD3/Internal/FFI.js`

Remove these unused foreign declarations and their JS implementations:
- `d3SelectAllInDOM_`
- `d3SelectFirstInDOM_`
- `d3Append_`
- `d3EnterAndAppend_`
- `d3Data_`
- `d3DataWithKeyFunction_`
- `d3DataWithFunction_`
- `d3GetEnterSelection_`
- `d3GetExitSelection_`
- `d3RemoveSelection_`
- `d3FilterSelection_`
- `d3OrderSelection_`
- `d3RaiseSelection_`
- `d3LowerSelection_`
- `d3SortSelection_`
- `d3SetAttr_`
- `d3SetText_`
- `d3SetHTML_`
- `d3SetProperty_`
- `d3MergeSelectionWith_`
- `d3GetSelectionData_`

### 1.3 Remove unused d3-hierarchy imports (cluster, tree, treemap, partition)

Even if `hierarchy` and `pack` are used, the others are not:
```javascript
// Change from:
import { hierarchy, cluster, tree, pack, treemap, partition } from "d3-hierarchy";
// To:
import { hierarchy, pack } from "d3-hierarchy";
```

### Checkpoint 1
```bash
make libs && make apps && make website
# Run all showcases, verify nothing breaks
```

---

## Phase 2: Code Explorer d3-hierarchy Removal ✓ COMPLETE

### 2.1 Analysis Result

Investigation revealed that `updateNodeExpansion_`, `drawInterModuleDeclarationLinks_`, and related functions were **dead code**:
- Exported from FFI.js but never imported anywhere in the codebase
- Never used by Code Explorer or any other application
- Grep found zero imports across all projects

### 2.2 Removed Functions (656 lines)

- `updateNodeExpansion_` - d3-hierarchy pack layout
- `expandNodeById_` - node expansion
- `drawInterModuleDeclarationLinks_` - inter-module links
- `highlightConnectedNodes_` - highlight dependencies
- `clearHighlights_` - clear highlights
- `filterToConnectedNodes_` - filter nodes
- `unpinAllNodes_` - unpin nodes
- `updateBubbleRadii_` - bubble sizing
- `addModuleArrowMarker_` - SVG markers
- `unsafeSetField_` - field mutation helper
- Related helper functions (declarationColor, categorizeDeclarations, etc.)

### 2.3 Result

- d3-hierarchy import completely removed from FFI.js
- 682 lines removed total (656 JS + 26 PureScript)
- All downstream builds pass (psd3-selection, psd3-simulation, website)
- d3-hierarchy can be removed from package.json

### Checkpoint 2 ✓
```bash
make libs && make website  # All pass
```

---

## Phase 3: d3-chord Removal

### 3.1 Update TreeAPI ChordDiagram example

**File**: `site/website/src/Viz/TreeAPI/ChordDiagram.purs`

Currently uses FFI:
```purescript
let chordData = chordLayoutWithPadAngle_ matrix 0.05
let ribbonGen = ribbonGenerator_ unit
```

Replace with pure PS:
```purescript
import DataViz.Layout.Chord (layoutWithConfig, defaultConfig)
import PSD3.Expr.Path.Generators (genRibbon, genArc)

let chordLayout = layoutWithConfig (defaultConfig { padAngle = 0.05 }) matrix
-- Use genRibbon and genArc for path generation
```

### 3.2 Remove chord FFI

**Files**:
- `psd3-selection/src/PSD3/Internal/FFI.js` - remove chord/ribbon exports
- `psd3-selection/src/PSD3/Internal/FFI.purs` - remove foreign declarations

Functions to remove:
- `chordLayout_`
- `chordLayoutWithPadAngle_`
- `chordGroups_`
- `chordArray_`
- `ribbonGenerator_`
- `ribbonPath_`
- `setRibbonRadius_`

### 3.3 Remove d3-chord dependency

Remove from package.json after FFI removal.

### Checkpoint 3
```bash
make website
# Navigate to chord diagram demo, verify it works
```

---

## Phase 4: Easing Unification

### 4.1 Extend PSD3.Transition.Tick with full easing suite

**File**: `psd3-simulation/src/PSD3/Transition/Tick.purs`

Add missing easing functions (pure math, no FFI):

```purescript
-- Existing
easeInQuad, easeOutQuad, easeInOutQuad
easeInCubic, easeOutCubic, easeInOutCubic

-- Add these
easeInSin, easeOutSin, easeInOutSin       -- sin(t * π/2)
easeInExp, easeOutExp, easeInOutExp       -- 2^(10*(t-1))
easeInCircle, easeOutCircle, easeInOutCircle  -- 1 - sqrt(1-t²)
easeInBack, easeOutBack, easeInOutBack    -- overshoot
easeInElastic, easeOutElastic, easeInOutElastic  -- spring
easeInBounce, easeOutBounce, easeInOutBounce    -- bounce
```

### 4.2 Easing function implementations

```purescript
-- Sinusoidal
easeInSin :: Easing
easeInSin t = 1.0 - cos(t * pi / 2.0)

easeOutSin :: Easing
easeOutSin t = sin(t * pi / 2.0)

-- Exponential
easeInExp :: Easing
easeInExp t = if t == 0.0 then 0.0 else pow 2.0 (10.0 * (t - 1.0))

-- Circular
easeInCircle :: Easing
easeInCircle t = 1.0 - sqrt(1.0 - t * t)

-- Back (overshoot)
easeInBack :: Easing
easeInBack t =
  let c1 = 1.70158
      c3 = c1 + 1.0
  in c3 * t * t * t - c1 * t * t

-- Elastic (spring)
easeOutElastic :: Easing
easeOutElastic t =
  if t == 0.0 then 0.0
  else if t == 1.0 then 1.0
  else pow 2.0 (-10.0 * t) * sin((t * 10.0 - 0.75) * (2.0 * pi / 3.0)) + 1.0

-- Bounce
easeOutBounce :: Easing
easeOutBounce t =
  let n1 = 7.5625
      d1 = 2.75
  in if t < 1.0 / d1 then n1 * t * t
     else if t < 2.0 / d1 then n1 * (t - 1.5 / d1) * (t - 1.5 / d1) + 0.75
     else if t < 2.5 / d1 then n1 * (t - 2.25 / d1) * (t - 2.25 / d1) + 0.9375
     else n1 * (t - 2.625 / d1) * (t - 2.625 / d1) + 0.984375
```

### 4.3 Create Easing module with Show/Eq instances

```purescript
module PSD3.Transition.Easing where

data EasingType
  = Linear
  | QuadIn | QuadOut | QuadInOut
  | CubicIn | CubicOut | CubicInOut
  | SinIn | SinOut | SinInOut
  | ExpIn | ExpOut | ExpInOut
  | CircleIn | CircleOut | CircleInOut
  | BackIn | BackOut | BackInOut
  | ElasticIn | ElasticOut | ElasticInOut
  | BounceIn | BounceOut | BounceInOut

toFunction :: EasingType -> Easing
toFunction = case _ of
  Linear -> identity
  QuadIn -> easeInQuad
  -- ... etc
```

### Checkpoint 4
```bash
make psd3-simulation
# Write tests for easing functions against known values
```

---

## Phase 5: Transition System Unification ✓ COMPLETE

### 5.1 Module Structure (Implemented)

```
psd3-simulation/src/PSD3/Transition/
├── Tick.purs          -- Existing: lerp, progress tracking, easing functions
├── Easing.purs        -- Phase 4: EasingType ADT with Show/Eq
├── Interpolate.purs   -- NEW: type-safe value interpolation
└── Engine.purs        -- NEW: unified tick-driven transitions
```

### 5.2 Interpolate Module (Implemented)

- Point interpolation: `lerpPoint`, `lerpPointXY`
- RGB color: `RGB` newtype, `lerpRGB`, `rgbToCSS`, `cssToRGB`
- HSL color: `HSL` newtype, `lerpHSL`, `hslToCSS`
- Color conversions: `hslToRGB`, `rgbToHSL`
- Generic: `Interpolatable` typeclass, `makeInterpolator`

### 5.3 Engine Module (Implemented)

- `TransitionSpec a`: defines from/to, duration, easing, interpolation
- `TransitionState a`: current state of in-flight transition
- `TransitionGroup`: coordinate multiple transitions
- Functions: `start`, `tick`, `currentValue`, `isComplete`, `remaining`
- Framework-agnostic (no dependencies on Halogen/React)

### 5.4 TransitionM Bridge

Deferred to Phase 6. The Engine provides the foundation; integrating with
existing TransitionM requires more invasive changes to psd3-selection.

### Checkpoint 5 ✓
```bash
spago build && spago test  # All pass
```

---

## Phase 6: Transition Unification (Design Required)

**Status**: BLOCKED - requires unified transition model design

**Prerequisite**: Complete design work in `docs/kb/architecture/unified-transition-model.md`

### 6.0 Why This Phase is Blocked

The original plan assumed d3-transition was largely dead code that could be replaced
with our tick-based Engine. Investigation revealed:

1. **Active usage**: d3-transition is used in website tour demos via:
   `TourMotionAnimations → Capabilities.Transition → D3 interpreter → TransitionFFI`

2. **Fundamental incoherence**: d3-transition and tick-based Engine don't compose well.
   This is the same problem D3 itself has - transitions and simulations both want to
   control element attributes (especially position).

3. **Valid use cases for both**:
   - d3-transition: CSS-style attribute animations (opacity, radius, color)
   - Tick engine: Simulation-compatible, framework-agnostic interpolation
   - Neither fully subsumes the other

### 6.1 Design Work Required

Before proceeding, complete the unified transition model design:

1. **Investigate WASM tick flow**: How does wasm-force-demo report ticks to PureScript?
   Document the actual mechanism.

2. **Prototype PositionMode in AST**: Make attribute ownership explicit:
   ```purescript
   data PositionMode
     = StaticPosition          -- Set once, don't touch
     | TransitionPosition      -- Animate position (standalone, no sim)
     | SimulationPosition      -- Physics controls position
     | DataDrivenPosition      -- Layout computes position (tree, etc.)
   ```

3. **Type-level enforcement**: Can phantom types prevent invalid combinations?
   ```purescript
   -- Can't call withTransition on a simulated element
   withTransition :: Element Static datum -> TransitionConfig -> ...
   ```

4. **Inventory current usage**: Document exactly which attributes are transitioned
   where across all demos and showcases.

### 6.2 Implementation (After Design)

Once the unified model is designed:

1. Implement RAF-based transition runner (if needed)
2. Bridge Engine with existing Capabilities.Transition
3. Decide: replace d3-transition or document coexistence
4. Update all affected demos

### 6.3 Color Interpolation (Already Done)

Phase 5 implemented color interpolation in `PSD3.Transition.Interpolate`:
- `lerpRGB`, `lerpHSL` for color interpolation
- `cssToRGB`, `rgbToCSS`, `hslToCSS` for parsing/formatting
- `hslToRGB`, `rgbToHSL` for conversions

### Checkpoint 6
```bash
# After design is complete and implementation done:
make all
# Full showcase suite
# Verify all animations still work
# Verify tour demos specifically
```

---

## Phase 7: Documentation and Cleanup

### 7.1 Update READMEs

Each library README should document:
- D3 dependencies (if any)
- Pure PureScript alternatives
- Layer in architecture

### 7.2 Update claude-context.md

- Remove psd3-tree references (done)
- Update D3 dependency section
- Document unified transition system

### 7.3 Update architecture diagram

```
PRESENTATION    psd3-music (no D3)
INTERACTION     psd3-selection (d3-scale, d3-drag, d3-zoom, d3-brush)
                psd3-simulation (d3-force OR wasm-kernel)
COMPUTATION     psd3-layout (no D3), psd3-graph (no D3)
FOUNDATION      tree-rose (registry package)
```

### 7.4 Create D3 dependency reference

New file: `docs/kb/reference/d3-dependencies.md`

Document:
- What D3 modules are used
- Why they're essential (or planned for removal)
- Pure PS alternatives where available

---

## Execution Order

| Phase | Risk | Effort | Dependencies | Status |
|-------|------|--------|--------------|--------|
| 1. Dead code removal | Low | Small | None | ✓ Complete |
| 2. Code Explorer hierarchy | Medium | Medium | Phase 1 | ✓ Complete |
| 3. d3-chord removal | Low | Small | Phase 1 | ✓ Complete |
| 4. Easing unification | Low | Medium | None | ✓ Complete |
| 5. Transition unification | Medium | Large | Phase 4 | ✓ Complete |
| 6. Transition design | High | Large | Phase 5 + design | **BLOCKED** |
| 7. Documentation | Low | Medium | All above | Partial |

**Current status**:
- Phases 1-5: Complete
- Phase 6: Blocked on unified transition model design (see `docs/kb/architecture/unified-transition-model.md`)
- Phase 7: Can proceed for completed phases; d3-transition section pending design

---

## Success Criteria

1. **All showcases build and run** after each phase ✓
2. **No d3-hierarchy** in final state ✓
3. **No d3-chord** in final state ✓
4. **No d3-ease** in final state (replaced by pure PS) ✓
5. **d3-transition** - unified transition model designed; coexistence documented
6. **Unified easing** in PSD3.Transition.Easing ✓
7. **Documentation** reflects actual dependencies (in progress)

---

## Rollback Plan

Each phase is independently revertible:
```bash
git checkout main -- <files modified in phase>
```

The feature branch preserves full history for cherry-picking successful phases if others fail.

---

## Notes

- Code Explorer (`corrode-expel`) is explicitly allowed to break temporarily
- WASM force kernel already proves D3-free simulation is possible
- The d3-scale dependency is large but provides significant value - defer removal
- d3-drag/zoom/brush are behavior libraries that would require significant effort to replace - keep for now

---

## Future: Coordinated Interaction Framework

**Status**: Design phase (not part of D3 reduction, but related)

d3-brush represents a broader category: **coordinated interactions between data viz components**. Rather than simply replacing d3-brush, we should design a principled framework for:

- **Brush-and-link**: Select in one view, highlight in others
- **Coordinate Hover**: Existing PSD3 pattern for cross-component hover
- **Synchronized zoom/pan**: Multiple views tracking same data region
- **Shared selections**: Component-agnostic selection state

**Requirements**:
- Framework-agnostic (Halogen and React compatible)
- Component-oriented (composable, not monolithic)
- Declarative state management
- Support for both D3-based and pure PS implementations

**Related existing work**:
- `PSD3.Internal.Behavior.FFI` - brush, zoom, drag FFI
- Coordinate Hover pattern in showcases
- psd3-selection highlighting infrastructure

This is architectural work that should inform future d3-brush decisions.
