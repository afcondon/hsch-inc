---
title: Kernel Separation Phase 2 - Separate Packages
category: plan
status: active
tags: [WASM, D3, kernel, separation, packages]
created: 2026-01-12
summary: Detailed implementation plan for separating psd3-simulation into three packages (core, d3-kernel, wasm-kernel).
---

# Kernel Separation Phase 2: Separate Packages

## Overview

This document details the implementation plan for Phase 2 of kernel separation: extracting the monolithic `psd3-simulation` library into three separate packages with clean dependency boundaries.

## Current State Analysis

### Module Structure (psd3-simulation)

```
src/PSD3/
├── Scene/
│   ├── Types.purs         ← Core types (kernel-agnostic)
│   ├── Engine.purs        ← EngineAdapter interface (kernel-agnostic)
│   ├── Handle.purs        ← High-level API (D3-coupled)
│   └── Rules.purs         ← Rule application (D3-coupled)
├── Transition/
│   └── Tick.purs          ← Tick-based animation (pure, no FFI)
├── ForceEngine/
│   ├── Types.purs         ← Force configs (ForceSpec is D3-specific)
│   ├── Core.purs + .js    ← D3 force FFI
│   ├── Simulation.purs + .js  ← D3 simulation wrapper
│   ├── Links.purs + .js   ← D3 link helpers
│   ├── Render.purs + .js  ← D3 rendering
│   ├── Registry.purs + .js ← D3 force registry
│   ├── Events.purs        ← D3 callbacks
│   ├── Setup.purs         ← D3 setup helpers
│   ├── Demo.purs          ← D3 demo code
│   ├── WASM.purs + .js    ← WASM FFI
│   └── WASMEngine.purs + .js  ← WASM adapter
├── Simulation/
│   └── Scene.purs + .js   ← D3 scene rules
├── Config/
│   ├── Apply.purs         ← D3 force config
│   ├── Force.purs         ← D3 force config
│   └── Scene.purs         ← D3 scene config
└── ForceEngine.purs       ← Re-export module
```

### Key Dependencies

1. **`Handle.purs`** imports:
   - `PSD3.ForceEngine.Core` (D3 FFI)
   - `PSD3.ForceEngine.Simulation` (D3 wrapper)
   - `PSD3.Simulation.Scene` (D3 rules)
   - `PSD3.Scene.Engine` (generic)
   - `PSD3.Scene.Types` (generic)

2. **`WASMEngine.purs`** imports:
   - `PSD3.ForceEngine.WASM` (WASM FFI)
   - `PSD3.Scene.Engine` (for EngineAdapter)
   - `PSD3.Scene.Types` (for PositionMap, NodeRule)

## Target Package Structure

### 1. psd3-simulation-core

**Purpose**: Kernel-agnostic types, interfaces, and orchestration.

**Modules**:
```
PSD3.Simulation.Core.Types
  - Position, PositionMap
  - NodeRule
  - SceneConfig, TransitionState
  - EngineMode

PSD3.Simulation.Core.Engine
  - EngineAdapter type
  - createEngine, tick, transitionTo
  - SceneEngine type

PSD3.Simulation.Core.Tick
  - Progress, TickDelta, Transitioning
  - tickProgressMap, tickTransitions
  - Interpolation (lerp, lerpClamped)
  - Easing functions

PSD3.Simulation.Core.Node
  - SimulationNode type alias (id, x, y, vx, vy, fx, fy)
  - PositionMap utilities
```

**Dependencies**: prelude, effect, refs, foreign-object, ordered-collections

**No FFI** - entirely pure PureScript.

### 2. psd3-d3-kernel

**Purpose**: D3.js force simulation implementation.

**Modules**:
```
PSD3.Kernel.D3.Core + FFI
  - ForceHandle, force creation
  - initializeNodes, initializeForce
  - applyForce, integratePositions
  - Animation loop (requestAnimationFrame)
  - Drag behavior

PSD3.Kernel.D3.Simulation + FFI
  - D3 simulation wrapper
  - setNodes, setLinks, addForce
  - tick, reheat, start, stop
  - Position updates (interpolate, pin/unpin)

PSD3.Kernel.D3.Types
  - ForceSpec, force configs
  - SimNode, SimLink, RawLink

PSD3.Kernel.D3.Links + FFI
PSD3.Kernel.D3.Render + FFI
PSD3.Kernel.D3.Registry + FFI
PSD3.Kernel.D3.Events
PSD3.Kernel.D3.Setup
PSD3.Kernel.D3.Demo

PSD3.Kernel.D3.Scene + FFI
  - applyRulesInPlace (D3-specific mutation)

PSD3.Kernel.D3.Handle
  - SceneHandle (D3-based high-level API)
  - mkAdapter (creates EngineAdapter from D3 simulation)

PSD3.Kernel.D3.Config.Apply
PSD3.Kernel.D3.Config.Force
PSD3.Kernel.D3.Config.Scene
```

**Dependencies**: psd3-simulation-core, d3-force, d3-selection, d3-drag, web-dom

### 3. psd3-wasm-kernel

**Purpose**: Rust/WASM force simulation implementation.

**Modules**:
```
PSD3.Kernel.WASM.FFI + FFI
  - WASMSimulation type
  - initWasm, isWasmReady
  - create, free, setNodeCount
  - Node/link operations
  - Force configuration
  - tick, tickN, reheat

PSD3.Kernel.WASM.Engine + FFI
  - WASMSim type
  - mkAdapter (creates EngineAdapter from WASM sim)
  - Position sync utilities

PSD3.Kernel.WASM.Types
  - SimulationNode (WASM variant)
  - WASMSimConfig
  - Config types (ManyBodyConfig, etc.)
```

**Dependencies**: psd3-simulation-core, aff (for async init), web-dom

## Migration Steps

### Step 1: Create psd3-simulation-core

1. Create new package in `visualisation libraries/purescript-psd3-simulation-core/`
2. Create spago.yaml with minimal dependencies
3. Move/copy modules:
   - `Scene.Types` → `Simulation.Core.Types`
   - `Scene.Engine` → `Simulation.Core.Engine`
   - `Transition.Tick` → `Simulation.Core.Tick`
4. Add `SimulationNode` type to `Simulation.Core.Node`
5. Verify builds with `spago build`

### Step 2: Create psd3-d3-kernel

1. Create new package in `visualisation libraries/purescript-psd3-d3-kernel/`
2. Create spago.yaml with dependency on psd3-simulation-core
3. Move modules with namespace change:
   - `ForceEngine.*` → `Kernel.D3.*`
   - `Simulation.Scene` → `Kernel.D3.Scene`
   - `Config.*` → `Kernel.D3.Config.*`
   - `Scene.Handle` → `Kernel.D3.Handle`
   - `Scene.Rules` → `Kernel.D3.Rules`
4. Move FFI files alongside PureScript modules
5. Update imports to use core package
6. Add `mkAdapter` function that creates `EngineAdapter` from D3 `Simulation`
7. Verify builds

### Step 3: Create psd3-wasm-kernel

1. Create new package in `visualisation libraries/purescript-psd3-wasm-kernel/`
2. Create spago.yaml with dependency on psd3-simulation-core
3. Move modules:
   - `ForceEngine.WASM` → `Kernel.WASM.FFI`
   - `ForceEngine.WASMEngine` → `Kernel.WASM.Engine`
4. Move FFI files
5. Update imports
6. Verify builds

### Step 4: Update Downstream Dependencies

1. Update `psd3-simulation-halogen`:
   - Depend on `psd3-simulation-core` + `psd3-d3-kernel`

2. Update showcase apps:
   - `wasm-force-demo`: Use `psd3-wasm-kernel`
   - Others: Use `psd3-d3-kernel`

### Step 5: Migrate Examples Forward

**Decision:** No backward compatibility layer. Update examples directly:
1. Update `wasm-force-demo` to use `psd3-wasm-kernel`
2. Update `ce-website` and other D3-based examples to use `psd3-d3-kernel`
3. Archive original `psd3-simulation` (or delete once migration complete)
4. Update CLAUDE.md with new package structure

## API Changes

### EngineAdapter Creation

**Before (D3-only, implicit)**:
```purescript
import PSD3.Scene.Handle as Handle

handle <- Handle.create config callbacks nodes links renderFn
```

**After (explicit kernel choice)**:
```purescript
-- D3 kernel
import PSD3.Kernel.D3.Handle as D3Handle
handle <- D3Handle.create config callbacks nodes links renderFn

-- Or WASM kernel
import PSD3.Kernel.WASM.Engine as WASMEngine
import PSD3.Simulation.Core.Engine as Engine

wasmSim <- WASMEngine.create nodes links WASMEngine.defaultConfig
let adapter = WASMEngine.mkAdapter wasmSim
engine <- Engine.createEngine adapter
```

### Portable Scene Orchestration

Code using only `EngineAdapter` works with any kernel:

```purescript
import PSD3.Simulation.Core.Engine as Engine
import PSD3.Simulation.Core.Types (SceneConfig)

runVisualization :: forall node. Engine.EngineAdapter node -> SceneConfig node -> Effect Unit
runVisualization adapter scene = do
  engine <- Engine.createEngine adapter
  Engine.transitionTo scene engine
  -- ...tick loop...
```

## File Moves Summary

| From | To |
|------|-----|
| `psd3-simulation/Scene/Types.purs` | `psd3-simulation-core/Simulation/Core/Types.purs` |
| `psd3-simulation/Scene/Engine.purs` | `psd3-simulation-core/Simulation/Core/Engine.purs` |
| `psd3-simulation/Transition/Tick.purs` | `psd3-simulation-core/Simulation/Core/Tick.purs` |
| `psd3-simulation/ForceEngine/Core.purs` | `psd3-d3-kernel/Kernel/D3/Core.purs` |
| `psd3-simulation/ForceEngine/Simulation.purs` | `psd3-d3-kernel/Kernel/D3/Simulation.purs` |
| `psd3-simulation/ForceEngine/Types.purs` | `psd3-d3-kernel/Kernel/D3/Types.purs` |
| `psd3-simulation/Scene/Handle.purs` | `psd3-d3-kernel/Kernel/D3/Handle.purs` |
| `psd3-simulation/ForceEngine/WASM.purs` | `psd3-wasm-kernel/Kernel/WASM/FFI.purs` |
| `psd3-simulation/ForceEngine/WASMEngine.purs` | `psd3-wasm-kernel/Kernel/WASM/Engine.purs` |

## Verification Checklist

- [ ] `psd3-simulation-core` builds with no FFI dependencies
- [ ] `psd3-d3-kernel` builds and passes existing D3 tests
- [ ] `psd3-wasm-kernel` builds and passes existing WASM tests
- [ ] `wasm-force-demo` works with new kernel package
- [ ] `ce-website` (code explorer) works with D3 kernel
- [ ] Backward-compat re-exports work for gradual migration

## Open Questions

1. **Naming**: `PSD3.Kernel.D3.*` vs `PSD3.D3.*` vs `PSD3.ForceEngine.D3.*`?
2. **Handle location**: Keep `Handle` in D3 kernel or create generic `Handle` in core with kernel-specific adapters?
3. **Type sharing**: Should `SimulationNode` be defined once in core or separately per kernel?

## Next Steps

1. Create `psd3-simulation-core` package skeleton
2. Move core modules and verify builds
3. Create `psd3-d3-kernel` package skeleton
4. Move D3 modules and update imports
5. Create `psd3-wasm-kernel` package skeleton
6. Move WASM modules and update imports
7. Update downstream dependencies
8. Test all showcase apps
