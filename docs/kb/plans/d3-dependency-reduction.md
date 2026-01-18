# D3 Dependency Reduction Plan

**Status**: In Progress
**Created**: 2026-01-18
**Updated**: 2026-01-18
**Branch**: `feature/d3-reduction`

**Completed Phases**:
- Phase 1: Dead code removal ✓
- Phase 3: d3-chord removal ✓

## Executive Summary

PSD3 has evolved beyond its origins as "PureScript bindings for D3". Many D3 modules are now redundant - replaced by pure PureScript implementations or used only through inertia. This plan systematically removes unnecessary D3 dependencies while preserving functionality.

**Goal**: Reduce D3 surface area to the genuine essentials, unify animation systems, and document what remains.

**Risk mitigation**: Work on feature branch, run full showcase suite after each phase.

---

## Current D3 Dependencies (Audit Summary)

| D3 Module | Status | Used In | Action |
|-----------|--------|---------|--------|
| d3-hierarchy | Reduced | Code Explorer only (hierarchy, pack) | Pending Phase 2 |
| d3-chord | ✓ REMOVED | N/A | Replaced with DataViz.Layout.Chord |
| d3-ease | Redundant | Transition FFI | **Remove** - add pure PS easing |
| d3-transition | Partially redundant | TransitionM | **Reduce** - unify with Tick engine |
| d3-selection | ✓ CLEANED | Drag, highlights only | ~20 unused exports removed |
| d3-scale | Essential | Scales, color schemes | **Keep** (for now) |
| d3-force | Essential | Force simulation | **Keep** (WASM alternative exists) |
| d3-drag | Essential | Drag behavior | **Keep** |
| d3-zoom | Essential | Zoom/pan behavior | **Keep** |
| d3-brush | Essential | Brush selection | **Keep** |
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

## Phase 2: Code Explorer d3-hierarchy Replacement

### 2.1 Analyze Code Explorer usage

The functions `updateNodeExpansion_` and `drawInterModuleDeclarationLinks_` use:
- `hierarchy(data)` - wraps data into d3 hierarchy node
- `.sum(d => d.value)` - accumulates values up the tree
- `pack().size([w,h]).padding(p)` - creates pack layout
- `packLayout(root)` - applies layout, sets x/y on nodes
- `root.leaves()` - gets leaf nodes with positions

### 2.2 Replace with psd3-layout Pack

The pure PureScript Pack layout in `psd3-layout` provides equivalent functionality:

```purescript
import DataViz.Layout.Hierarchy.Pack (pack, PackConfig)

-- Convert to tree-rose Tree, run pack layout
let tree = mkTree rootData children
let packed = pack config tree
-- Extract positions from packed tree
```

### 2.3 Implementation approach

Option A: Rewrite the JS functions in PureScript
- Move logic to `corrode-expel/ce2-website/src/Viz/`
- Use psd3-layout Pack
- Call from existing code paths

Option B: Keep JS functions but import pack from psd3-layout
- Less invasive
- Still removes d3-hierarchy dependency

**Recommendation**: Option A - Code Explorer needs refactoring anyway, this is a good forcing function.

### 2.4 Remove d3-hierarchy entirely

After Code Explorer migration:
1. Remove all d3-hierarchy imports from FFI.js
2. Remove d3-hierarchy from package.json
3. Verify build

### Checkpoint 2
```bash
make libs && make code-explorer
# Test Code Explorer declaration expansion feature
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

## Phase 5: Transition System Unification

### 5.1 Create unified transition infrastructure

New module structure:
```
psd3-simulation/src/PSD3/Transition/
├── Tick.purs          -- Existing: lerp, progress tracking
├── Easing.purs        -- New: full easing suite (Phase 4)
├── Interpolate.purs   -- New: value interpolation
└── Engine.purs        -- New: unified tick-driven transitions
```

### 5.2 Interpolate module

```purescript
module PSD3.Transition.Interpolate where

-- Numeric interpolation (existing in Tick)
lerp :: Number -> Number -> Progress -> Number

-- Color interpolation (new)
lerpColor :: Color -> Color -> Progress -> Color
lerpRGB :: RGB -> RGB -> Progress -> RGB
lerpHSL :: HSL -> HSL -> Progress -> HSL

-- Could add later:
-- lerpPath :: PathData -> PathData -> Progress -> PathData
```

### 5.3 Unified TransitionEngine

```purescript
module PSD3.Transition.Engine where

type TransitionSpec a =
  { duration :: Milliseconds
  , easing :: EasingType
  , from :: a
  , to :: a
  , interpolate :: a -> a -> Progress -> a
  }

-- Tick-driven transition state
type TransitionState a =
  { spec :: TransitionSpec a
  , progress :: Progress
  , current :: a
  }

-- Advance transition by one tick
tick :: TickDelta -> TransitionState a -> TransitionState a

-- Check if complete
isComplete :: TransitionState a -> Boolean
```

### 5.4 Bridge to existing TransitionM

The existing `TransitionM` typeclass can be reimplemented to use the unified engine:

```purescript
-- Current: uses d3-transition FFI
instance TransitionM D3v2Selection_ D3v2M where
  withTransition config sel attrs = ...

-- New: uses PSD3.Transition.Engine + RAF
instance TransitionM D3v2Selection_ D3v2M where
  withTransition config sel attrs = D3v2M do
    let transitions = buildTransitions config sel attrs
    scheduleRAFLoop transitions
```

This is the most invasive change - defer to Phase 6 if risky.

### Checkpoint 5
```bash
make psd3-simulation
# Test unified engine with simple animations
```

---

## Phase 6: d3-transition Replacement (Optional/Future)

### 6.1 Implement RAF-based transition runner

```javascript
// New FFI: requestAnimationFrame loop
export function runTransitions_(transitions, onTick, onComplete) {
  return function() {
    let startTime = null;

    function frame(timestamp) {
      if (!startTime) startTime = timestamp;
      const elapsed = timestamp - startTime;

      const progress = Math.min(elapsed / transitions.duration, 1.0);
      onTick(progress)();

      if (progress < 1.0) {
        requestAnimationFrame(frame);
      } else {
        onComplete();
      }
    }

    requestAnimationFrame(frame);
  };
}
```

### 6.2 Implement color interpolation

For removing d3-interpolate dependency on colors:

```purescript
lerpRGB :: RGB -> RGB -> Progress -> RGB
lerpRGB (RGB r1 g1 b1) (RGB r2 g2 b2) t =
  RGB (lerp r1 r2 t) (lerp g1 g2 t) (lerp b1 b2 t)

-- Parse CSS color strings
parseColor :: String -> Maybe Color
parseColor s = parseHex s <|> parseRGB s <|> parseNamed s
```

### 6.3 Remove d3-transition and d3-ease

After full replacement:
1. Remove imports from Transition/FFI.js
2. Remove from package.json
3. Update documentation

### Checkpoint 6
```bash
make all
# Full showcase suite
# Verify all animations still work
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

| Phase | Risk | Effort | Dependencies |
|-------|------|--------|--------------|
| 1. Dead code removal | Low | Small | None |
| 2. Code Explorer hierarchy | Medium | Medium | Phase 1 |
| 3. d3-chord removal | Low | Small | Phase 1 |
| 4. Easing unification | Low | Medium | None |
| 5. Transition unification | Medium | Large | Phase 4 |
| 6. d3-transition removal | High | Large | Phase 5 |
| 7. Documentation | Low | Medium | All above |

**Recommended approach**:
- Phases 1, 3, 4 can run in parallel (independent)
- Phase 2 after Phase 1
- Phase 5 after Phase 4
- Phase 6 is optional - assess after Phase 5
- Phase 7 ongoing throughout

---

## Success Criteria

1. **All showcases build and run** after each phase
2. **No d3-hierarchy** in final state
3. **No d3-chord** in final state
4. **No d3-ease** in final state (replaced by pure PS)
5. **d3-transition** either removed or documented as essential
6. **Unified easing** in PSD3.Transition.Easing
7. **Documentation** reflects actual dependencies

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
