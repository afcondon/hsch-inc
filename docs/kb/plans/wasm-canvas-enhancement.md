# WASM Canvas Enhancement Plan

**Status**: Planned
**Created**: 2026-01-12
**Context**: ForcePlaygroundWASM proof-of-concept is working with Canvas rendering, demonstrating significant performance gains over SVG/TreeAPI. This plan covers productionizing the Canvas support and achieving force-type parity with D3.

## Current State

- ForcePlaygroundWASM works with ~1000+ nodes at good frame rates
- Canvas rendering via inline FFI in `site/website/src/Viz/ForcePlayground/CanvasRenderer.js`
- WASM kernel has 3 forces: many-body, links, center
- No zoom/pan support yet
- GUP (category filtering) works correctly

## Goals

1. Extract Canvas rendering to a reusable library
2. Add zoom/pan with clean PureScript API
3. Add missing D3 force types to Rust WASM kernel

---

## Phase 1: Canvas Library Organization

### Decision: Where does Canvas code live?

**Option A: `purescript-psd3-canvas`** (new package)
- Pros: Clean separation, can be used independently
- Cons: Another package to maintain

**Option B: Part of `purescript-psd3-wasm-kernel`**
- Pros: Co-located with WASM simulation, single package for "fast path"
- Cons: Mixes rendering with simulation concerns

**Option C: Part of `purescript-psd3-selection`**
- Pros: Rendering belongs with selection/DOM concerns
- Cons: Canvas is quite different from D3 selection model

**Recommendation**: Option A (`purescript-psd3-canvas`) - Canvas rendering is a distinct concern that could be useful beyond WASM simulations.

### Tasks

1. Create `visualisation libraries/purescript-psd3-canvas/`
2. Define core types:
   ```purescript
   type CanvasContext  -- Opaque handle
   type Transform = { scale :: Number, translateX :: Number, translateY :: Number }
   ```
3. Core API:
   ```purescript
   -- Lifecycle
   createCanvas :: String -> { width :: Int, height :: Int } -> Effect CanvasContext
   clearCanvas :: CanvasContext -> Effect Unit

   -- Transform (for zoom/pan)
   setTransform :: CanvasContext -> Transform -> Effect Unit
   resetTransform :: CanvasContext -> Effect Unit

   -- Drawing primitives
   drawCircle :: CanvasContext -> { x :: Number, y :: Number, radius :: Number, fill :: String } -> Effect Unit
   drawLine :: CanvasContext -> { x1 :: Number, y1 :: Number, x2 :: Number, y2 :: Number, stroke :: String } -> Effect Unit

   -- Batch drawing (for performance)
   drawCircles :: CanvasContext -> Array CircleSpec -> Effect Unit
   drawLines :: CanvasContext -> Array LineSpec -> Effect Unit
   ```
4. Move FFI from `CanvasRenderer.js` to library
5. Update ForcePlaygroundWASM to use library

---

## Phase 2: Zoom/Pan Support

### Approach

Store transform state in Halogen, apply during render, update via mouse events.

### Types

```purescript
type ViewTransform =
  { scale :: Number      -- 1.0 = 100%, 2.0 = 200%
  , offsetX :: Number    -- Pan offset
  , offsetY :: Number
  }

defaultTransform :: ViewTransform
defaultTransform = { scale: 1.0, offsetX: 0.0, offsetY: 0.0 }
```

### Mouse Event Handling (FFI)

```javascript
// Wheel event for zoom
export function onWheel_(canvas, callback) {
  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? 0.9 : 1.1;  // Zoom in/out
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    callback({ delta, x, y })();
  });
}

// Drag events for pan
export function onDrag_(canvas, onStart, onMove, onEnd) { ... }
```

### PureScript API

```purescript
-- In psd3-canvas
module PSD3.Canvas.Zoom where

type ZoomEvent = { delta :: Number, x :: Number, y :: Number }
type DragEvent = { dx :: Number, dy :: Number }

subscribeZoom :: CanvasContext -> (ZoomEvent -> Effect Unit) -> Effect Unit
subscribeDrag :: CanvasContext -> (DragEvent -> Effect Unit) -> Effect Unit

-- Transform helpers
zoomAt :: ZoomEvent -> ViewTransform -> ViewTransform
pan :: DragEvent -> ViewTransform -> ViewTransform
```

### Integration with ForcePlaygroundWASM

```purescript
-- Add to State
type State =
  { ...
  , viewTransform :: ViewTransform
  }

-- Add Actions
data Action
  = ...
  | ZoomCanvas ZoomEvent
  | PanCanvas DragEvent

-- Apply transform when rendering
renderToCanvas transform nodes links = do
  Canvas.setTransform ctx transform
  Canvas.drawLines ctx links
  Canvas.drawCircles ctx nodes
```

---

## Phase 3: Rust Force Parity

### Current Forces (in `force-kernel/src/lib.rs`)

| Force | Status | Notes |
|-------|--------|-------|
| many-body | ✅ | Barnes-Hut O(n log n) |
| links | ✅ | Spring forces |
| center | ✅ | Centroid centering |

### Missing Forces

| Force | Priority | Complexity | Notes |
|-------|----------|------------|-------|
| forceX | High | Low | Pull toward x value |
| forceY | High | Low | Pull toward y value |
| forceCollide | Medium | High | Needs quadtree |
| forceRadial | Low | Medium | Pull toward radius from center |

### Implementation: forceX / forceY

```rust
// Add to Simulation struct
force_x_target: f32,
force_x_strength: f32,
force_y_target: f32,
force_y_strength: f32,
enable_force_x: bool,
enable_force_y: bool,

// Configuration
#[wasm_bindgen]
pub fn configure_force_x(&mut self, target: f32, strength: f32) {
    self.force_x_target = target;
    self.force_x_strength = strength;
}

// Apply force
fn apply_force_x(&mut self) {
    for i in 0..self.n_nodes {
        let dx = self.force_x_target - self.positions[i * 2];
        self.velocities[i * 2] += dx * self.force_x_strength * self.alpha;
    }
}
```

### Implementation: forceCollide (outline)

```rust
// Uses same quadtree as many-body
fn apply_collide_force(&mut self) {
    let radius = self.collide_radius;
    let strength = self.collide_strength;

    // Build quadtree (can reuse from many-body if same tick)
    let tree = Quadtree::from_nodes(&self.positions, self.n_nodes);

    // For each node, find overlapping nodes and push apart
    for i in 0..self.n_nodes {
        tree.visit(|quad, ...| {
            // Check if circles overlap
            // Apply separation force
        });
    }
}
```

### PureScript API Extension

```purescript
-- In PSD3.Kernel.WASM.Simulation
configureForceX :: { target :: Number, strength :: Number } -> Simulation r l -> Effect Unit
configureForceY :: { target :: Number, strength :: Number } -> Simulation r l -> Effect Unit
configureCollide :: { radius :: Number, strength :: Number } -> Simulation r l -> Effect Unit

-- Enable flags
enableForces ::
  { manyBody :: Boolean
  , links :: Boolean
  , center :: Boolean
  , forceX :: Boolean
  , forceY :: Boolean
  , collide :: Boolean
  } -> Simulation r l -> Effect Unit
```

---

## Testing Strategy

1. **Canvas library**: Visual tests in browser, unit tests for transform math
2. **Zoom/pan**: Manual testing with ForcePlaygroundWASM
3. **Rust forces**:
   - Rust unit tests (`cargo test`)
   - Compare output with D3.js for same inputs
   - Visual comparison in ForcePlaygroundWASM

---

## Files to Create/Modify

### New Files
- `visualisation libraries/purescript-psd3-canvas/spago.yaml`
- `visualisation libraries/purescript-psd3-canvas/src/PSD3/Canvas.purs`
- `visualisation libraries/purescript-psd3-canvas/src/PSD3/Canvas.js`
- `visualisation libraries/purescript-psd3-canvas/src/PSD3/Canvas/Zoom.purs`
- `visualisation libraries/purescript-psd3-canvas/src/PSD3/Canvas/Zoom.js`

### Modify
- `showcases/wasm-force-demo/force-kernel/src/lib.rs` (add forces)
- `visualisation libraries/purescript-psd3-wasm-kernel/src/PSD3/Kernel/WASM/FFI.purs` (expose new forces)
- `site/website/src/Component/ForcePlaygroundWASM.purs` (use Canvas library, add zoom)

---

## Success Criteria

- [ ] Canvas rendering extracted to `purescript-psd3-canvas`
- [ ] Zoom/pan working in ForcePlaygroundWASM with clean API
- [ ] forceX and forceY added to Rust kernel
- [ ] forceCollide added to Rust kernel (stretch goal)
- [ ] All forces exposed via PureScript API
- [ ] ForcePlaygroundWASM demonstrates all features
