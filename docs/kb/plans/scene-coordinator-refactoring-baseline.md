# SceneCoordinator Refactoring Baseline

**Date**: 2026-03-09
**Git**: `0196d89` on `feature/structural-decomp-viz` (CodeExplorer/minard)
**Purpose**: Baseline diagnosis of a 2748-line module, to evaluate whether visualization tools improve refactoring decisions vs. LLM textual analysis alone.

## Module Profile

- **File**: `frontend/src/Component/SceneCoordinator.purs`
- **Lines**: 2748
- **State fields**: ~35
- **Action constructors**: ~40
- **Child component slots**: 17
- **Exported declarations**: 7 (component, Input, Output, Query, Slot, TransitionState, V2Data)
- **Internal declarations**: ~50+ (handleAction branches, helpers, pure computations)

## Diagnosis: Six Concerns in One Module

| # | Concern | Lines (est.) | Nature | Coupling |
|---|---------|-------------|--------|----------|
| 1 | **Types** (State, Action, Slots, Scene) | 250 | Definitions | Foundation for all |
| 2 | **Pure computation** (reachability, clusters, import maps, theme, canonical state) | 400 | Pure functions | Reads data, returns results |
| 3 | **Data loading/caching** (prepareSceneData, ensurePackageDeclarationsLoaded, loadComplexityData, computeAndStore*) | 500 | Effectful (Aff + state writes) | Reads state -> fetches -> writes state |
| 4 | **Search** (typeahead, result navigation) | 80 | Self-contained | Own state fields + actions |
| 5 | **Render** (header, footer, scene dispatch) | 400 | HTML generation | Reads state |
| 6 | **Action routing** (navigation, peek, child output handling, toggles) | 1100 | Effectful dispatch | Touches everything |

## Proposed Extraction

1. `SceneCoordinator.Types` — break circular deps
2. `SceneCoordinator.Computation` — pure functions (zero risk)
3. `SceneCoordinator.DataLoading` — effectful cache management
4. `SceneCoordinator.Search` — self-contained concern
5. `SceneCoordinator` — render + handleAction core (~1200 lines)

**Estimated iterations**: 8-12 edit-compile cycles
**Risk**: Low — structural separation of already-logically-separate code

## What Existing Views Show

- **Treemap**: SceneCoordinator is the largest cell. Shows SIZE but not internal structure.
- **Module (signature map)**: Shows 7 exported declarations (types + component). The arc diagram shows cross-module call density. Indicates a problem exists but not what it is.
- **Declaration call graph**: 7 visible nodes (exported), heavily connected. Doesn't reveal the ~50 internal functions or the concern groupings.
- **Case branch call graph**: Shows all ~100 sub-declarations. Illegible blob — all blue, no grouping. Shows density of coupling but not the separable clusters.

## What the Views Don't Show

1. **Concern groupings**: Which functions serve which purpose (data loading vs computation vs search vs render)
2. **Extraction feasibility**: Which clusters have few boundary-crossing edges (clean extraction) vs many (tangled)
3. **Pure vs effectful**: Which functions are pure (trivial to extract) vs stateful (need careful interface design)
4. **State field usage**: Which state fields are read/written by which concern group — the key signal for separability

## Key Question

Can a visualization surface the concern-separation insight that textual analysis provides? The text "wins massively in clarity" currently. What encoding would change that?

## Evaluation Criteria

When we build improved views, return to this commit and compare:
- Does the view suggest the same 6-concern split?
- Does it reveal extraction feasibility (clean vs tangled boundaries)?
- Does it show information the text CANNOT (e.g., unexpected cross-concern coupling)?
- Is it faster to reach the diagnosis visually than by reading 2748 lines?
