---
title: CE2 Visualization Architecture Analysis
category: research
status: active
tags: [ce2, visualization, componentization, halogen, psd3]
created: 2026-01-25
summary: Analysis of how well CE2 achieves componentized, parameterizable visualizations and the relationship between PSD3 and Halogen layers.
---

# CE2 Visualization Architecture Analysis

## Overview

This report analyzes the Code Explorer (CE2) visualization architecture to assess how well it achieves the goals of componentized, parameterizable visualizations. It examines the relationship between Halogen components, PSD3 Viz modules, and the underlying PSD3 library primitives.

## Architecture Layers

### Layer Structure

```
Halogen Components (src/Component/*Viz.purs)
  - Lifecycle management (Initialize, Receive, Finalize)
  - Event routing (D3 clicks → Halogen actions → parent Output)
  - Handle caching (simulation handles live in component state)
       ↓
Viz Modules (src/Viz/*.purs)
  - Rendering logic
  - Force simulation configuration
  - Position computation
       ↓
PSD3 Library
  - D3 abstraction (PSD3.Render)
  - Force engine (PSD3.Simulation)
  - Data binding (PSD3.AST)
       ↓
Data Types (src/Types.purs)
  - ViewTheme, ColorMode, BeeswarmScope, CellContents
```

### Halogen Component Pattern

Each visualization component exposes a consistent interface:

```purescript
type Input =
  { data :: Array DataType
  , scope :: BeeswarmScope
  , theme :: ViewTheme
  , colorMode :: ColorMode
  , initialPositions :: Maybe (Array InitialPosition)
  }

data Output = ItemClicked String | ItemHovered (Maybe String)
data Query a = ForceRender a | NoQuery a
```

Components are **thin wrappers** that:
1. Manage lifecycle (Initialize → Receive → Finalize)
2. Route events (D3 callbacks → Halogen subscriptions → parent Output)
3. Coordinate configuration (parent Input → Viz config → render)
4. Cache handles (simulation handles live in component state)

### Viz Module Pattern

Each Viz module exposes:

```purescript
render :: Config -> Array Data -> Effect Handle
renderWithPositions :: Config -> Array Data -> Array Position -> Effect Handle
setScope :: Handle -> Array Data -> Effect Unit      -- GUP for filtering
updateColors :: String -> Theme -> ColorMode -> Effect Unit  -- In-place update
```

Config types are consistent:

```purescript
type Config =
  { containerSelector :: String
  , width :: Number
  , height :: Number
  , theme :: ViewTheme
  , ... visualization-specific fields
  }
```

## Parameterization Analysis

### Orthogonal Parameters

The system achieves excellent orthogonality between independent concerns:

| Parameter | Values | Affects |
|-----------|--------|---------|
| `ViewTheme` | Blueprint, Beige, Paperwhite | Background, stroke colors |
| `ColorMode` | DefaultUniform, ProjectScope, FullRegistryTopo, ProjectScopeTopo, PublishDate | Circle fill colors |
| `BeeswarmScope` | AllPackages, ProjectOnly, ProjectWithDeps, ProjectWithTransitive | Data filtering (GUP) |
| `CellContents` | CellEmpty, CellText, CellCircle, CellModuleCircles, CellBubblePack | Treemap cell rendering |

**Key insight:** 3 themes × 5 color modes = 15 visual combinations with no code duplication.

### Update Efficiency

The architecture supports three update strategies:

| Change Type | Cost | Mechanism |
|-------------|------|-----------|
| Color/Theme only | <1ms | Select-and-modify pattern |
| Scope filter | Medium | D3 General Update Pattern (enter/exit) |
| Data change | Full | Complete re-render |

The `updateColors` function demonstrates the select-and-modify pattern:

```purescript
updateColors containerSelector theme colorMode = do
  void $ runD3 do
    container <- select containerSelector
    groups <- selectAllWithData ".package-group" container
    circles <- selectChildInheriting "circle" groups
    _ <- setAttrs [ Attr.attr "fill" (circleColorFn theme colorMode) idD ] circles
    pure unit
```

## Componentization Assessment

### Scores

| Aspect | Rating | Notes |
|--------|--------|-------|
| Component Isolation | 9/10 | Each owns simulation lifecycle, no cross-component state |
| Input/Output Clarity | 9/10 | Clear types, no implicit coupling |
| Parameterization | 9/10 | Theme, ColorMode, Scope, CellContents are orthogonal |
| Separation of Concerns | 8/10 | Visual logic in Viz, lifecycle in Component |
| Reusability | 8/10 | High for Viz layer (some business logic scattered) |
| Type Safety | 7/10 | Strong coverage (some string-based selectors remain) |
| Extensibility | 8/10 | Easy to add new ColorModes or CellContents |
| Runtime Performance | 9/10 | Color changes ~1ms, scope changes use GUP |

### Strengths

1. **Declarative rendering**: Colors computed via pure functions, not imperative mutation
2. **Composable**: Theme × ColorMode orthogonality would be painful in raw D3
3. **Type-safe**: ViewTheme, ColorMode, CellContents prevent invalid states
4. **Lifecycle-managed**: Halogen handles simulation cleanup automatically
5. **Testable**: `prepareNodes` is pure - can unit test node computation

### Gaps and Opportunities

1. ~~**Scope filtering logic duplicated** across components~~
   - **DONE** (2026-01-25): Extracted to `CE2.Data.Filter` module
   - `filterPackagesByScope`, `filterNodesByScope`, `filterModulesByScope`
   - `ModuleScope` type moved to shared module
   - ~100 lines consolidated from 4 components

2. **Container selectors are string-based** (`"#galaxy-beeswarm-container"`)
   - Recommendation: Use a selector type with compile-time safety

3. **No builder pattern for Config**
   - Recommendation: Add builder functions per Viz module

4. **Event routing could be more type-safe**
   - Currently uses `HS.Listener Action` bridge
   - Recommendation: Church-encoded callbacks

## Is This a Step Up from Raw D3?

**Yes, significantly:**

- **Visual styling fully separated from structure and data** - change colors without touching layout, change scope without touching colors
- **Pure functional core** - `prepareNodes`, `circleColorFn` are testable pure functions
- **Type-driven design** - invalid states are unrepresentable
- **Automatic resource management** - Halogen lifecycle handles cleanup

## Congruent vs Orthogonal Relationship

The PSD3 and Halogen layers are **congruent** rather than orthogonal:

- The Viz module API (`render`, `setScope`, `updateColors`) maps directly to Halogen's `Receive` handler decision tree
- Each Viz module is designed to be wrapped by exactly one Halogen component
- No duplication of logic between layers - they have distinct responsibilities

This congruence is intentional and beneficial: it means the abstraction levels align cleanly with no impedance mismatch.

## Status / Next Steps

**Current status:** Architecture is mature and working well for the CE2 use case.

**Recommended improvements:**
1. Extract scope filtering to shared module
2. Add type-safe container selectors
3. Add Config builder patterns for ergonomics
4. Consider Church-encoded callbacks for type safety

**Future consideration:** As more visualizations are added, validate that the current patterns scale. The Viz module pattern should be documented as the canonical approach for new visualizations.
