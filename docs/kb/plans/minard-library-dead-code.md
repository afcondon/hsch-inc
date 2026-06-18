# Minard: Library-Level Dead Code Detection

**Status**: Spec
**Date**: 2026-03-30

## Motivation

During cleanup of `hylograph-selection`, Minard's existing Reachability overlay (R) showed dead code relative to Minard's own entry point — but this is app-specific. What we actually needed was **library-level dead code detection**: which exports from a library are never imported or called by any consumer.

The cleanup removed 744 lines of force/simulation FFI from `hylograph-selection` and an entire dead module (`Config.Apply`) from `hylograph-simulation`. All of this was invisible to the current Reachability overlay because it measures from one app's entry point, not from the library's consumer surface.

## Evidence

- **Before** (hylograph-selection): `cfb1a75^` — 274-line FFI.purs, 496-line FFI.js with 51 force-related foreign imports, all dead within the library
- **After** (hylograph-selection): `cfb1a75` — 25-line FFI.purs, 20-line FFI.js
- **Before** (hylograph-simulation): has `Config/Apply.purs` importing from selection's removed FFI — entire module dead, imported by nothing
- **After** (hylograph-simulation): `Config/Apply.purs` deleted, builds clean

## Proposed Feature: Library Dead Code Overlay

### What it shows

For a selected **library package**, highlight declarations/modules that are:
- **Exported but never imported** by any other package in the workspace
- **Imported but never called** (phantom imports — the module is imported but no functions are used)

### How it differs from Reachability (R)

| | Reachability | Library Dead Code |
|---|---|---|
| **Root** | Single entry point (main/bundle module) | All consumers of the library |
| **Direction** | Forward: what does main transitively reach? | Reverse: what do all consumers transitively use? |
| **Scope** | One app's dependency tree | One library's export surface |
| **Question** | "Is this module used by the app?" | "Is this export used by anyone?" |

### Data requirements

Already in the DB:
- `module_imports` — which modules import which
- `function_calls` — which declarations call which (cross-module)
- `declarations` — which declarations are exported

Needed computation:
1. For library package P, collect all exported declarations across all modules
2. For each export, check if any module in a *different* package imports the containing module AND calls that specific declaration
3. Mark unused exports as dead

### UI

- New overlay mode on the Module Treemap (maybe **W** for "Wanted" or **Dead** toggle)
- Dead exports shown in red/dim, used exports in green/bright
- Tooltip: "0 consumers" / "called by 3 modules in 2 packages"
- Could also show in Module Planet: dead declarations in the dot map

### Implementation notes

- Pure computation from existing DB data — no new API endpoints needed
- The cross-package call data (`function_calls` with `isCrossModule = true`) is the key signal
- Could also detect **internal dead code** (private functions within a module never called by siblings)
