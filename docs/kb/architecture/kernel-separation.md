---
title: PSD3 Kernel Separation Architecture
category: architecture
status: active
tags: [WASM, performance, kernels, force-simulation, multi-backend]
source: docs/KERNEL-SEPARATION-ARCHITECTURE.md
created: 2025-01-10
summary: Architecture for pluggable force simulation kernels (D3, WASM, native, distributed) with unified PureScript coordination layer.
---

# PSD3 Kernel Separation Architecture

## Overview

This document outlines the architecture for separating PSD3's force simulation into pluggable kernels, enabling different performance/platform tradeoffs while maintaining a unified PureScript coordination layer.

## Motivation

The successful implementation of the WASM force kernel demonstrated:

1. **3.4x speedup** over D3.js at 10,000 nodes using Rust/WASM
2. **Zero overhead** from PureScript adapter layer (validated via three-way benchmark)
3. **Visual parity** between implementations (same algorithm, same results)

This validates a broader architectural pattern: PureScript as a **coordination layer** that orchestrates high-performance kernels written in platform-optimal languages.

## Architecture

### Current State

```
psd3-simulation
├── ForceEngine/
│   ├── Core.purs        ← D3 FFI bindings
│   ├── Simulation.purs  ← Simulation wrapper
│   ├── WASM.purs        ← WASM FFI bindings (new)
│   └── WASMEngine.purs  ← WASM adapter (new)
└── Scene/
    ├── Engine.purs      ← EngineAdapter interface
    └── Handle.purs      ← High-level API
```

### Target State

```
psd3-simulation-core          ← Types, interfaces, scene orchestration
├── psd3-d3-kernel            ← D3.js implementation (JavaScript target)
├── psd3-wasm-kernel          ← Rust/WASM implementation (all JS targets)
├── psd3-native-kernel        ← C++ implementation (future: desktop apps)
└── psd3-distributed-kernel   ← Erlang implementation (future: large-scale)
```

## Core Interface

All kernels implement the `EngineAdapter` interface:

```purescript
type EngineAdapter node =
  { getNodes            :: Effect (Array node)
  , capturePositions    :: Array node -> PositionMap
  , interpolatePositions :: PositionMap -> PositionMap -> Number -> Effect Unit
  , updatePositions     :: PositionMap -> Effect Unit
  , applyRulesInPlace   :: Array (NodeRule node) -> Effect Unit
  , reinitializeForces  :: Effect Unit
  , reheat              :: Effect Unit
  }
```

## Performance Comparison

| Nodes | D3.js (ms/tick) | WASM (ms/tick) | Speedup |
|-------|-----------------|----------------|---------|
| 100 | 0.65 | 0.28 | 2.3x |
| 1,000 | 1.51 | 1.28 | 1.2x |
| 5,000 | 8.2 | 3.1 | 2.6x |
| 10,000 | 41.8 | 12.2 | 3.4x |

## Migration Path

- Phase 1: Extract Core ✅
- Phase 2: Separate Packages (pending) → See [detailed plan](../plans/kernel-separation-phase2.md)
- Phase 3: Expand Kernels
- Phase 4: Build Tooling

## Phase 2 Summary

The detailed Phase 2 plan covers:
1. **psd3-simulation-core**: Kernel-agnostic types, EngineAdapter interface, tick-based animation
2. **psd3-d3-kernel**: D3.js force implementation with all FFI bindings
3. **psd3-wasm-kernel**: Rust/WASM force implementation

Key insight: `EngineAdapter` provides the abstraction boundary. Code written against `EngineAdapter` works with any kernel.
