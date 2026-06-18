# Refactoring Difficulty Visualization

**Category**: Plan
**Status**: Draft
**Created**: 2026-03-08
**Related**: `decomposition-meets-enforcement.md`, `release-plan-2026.md`
**Context**: Built structural complexity heat map and declaration-level structure views in Minard (2026-03-08 session). This document analyzes what the current metrics capture, where they fall short, and plans visualizations that can identify the same refactoring concerns a human reader would.

## Motivation

PureScript/Haskell compilers make refactoring *safe* (type errors catch breakage) but can't predict how *difficult* a refactoring will be. An LLM agent reading the code can identify decomposition candidates, but this requires full source reading — expensive, slow, and non-visual. We want Minard to show humans (and eventually agents) where refactoring is needed and why, at a glance.

## What We Built (2026-03-08)

### 1. Backend: `/api/v2/module-structural-complexity`

SQL query over function call graph. Per-module metrics:
- `internalCalls` — function calls within the module
- `crossModuleCalls` — calls to/from other modules
- `internalDensity` — calls per declaration (tangledness proxy)
- `couplingScore` — composite: `min(internal/decls, 3) * 10 + cross * 0.5 + maxFanIn * 2.0`

### 2. Frontend: Coupling Score Heat Map (C key peek)

Module treemap cells colored green → amber → red by coupling score. "No data" shown in gray for registry packages (no call graph analysis). Works at package treemap level.

### 3. Frontend: Declaration Structure View (Structure button at module level)

Per-module call graph decomposition: biconnected components, articulation points, bridges, treelikeness, shape classification (flat/tree/tangled/mixed), cross-module coupling list, refactoring difficulty rating.

## Case Study: SceneCoordinator

SceneCoordinator (CE2.Component.SceneCoordinator) scores 279 — the hottest module in the CE2 application. AI-generated annotations identify it as a decomposition candidate. Comparing what the annotations say vs. what the metrics show:

### What the annotations identify

| Concern | Detail |
|---------|--------|
| Size | 2089 LOC, largest module |
| Branching | `handleAction` has 25+ case branches spanning ~900 lines |
| State sprawl | State record has 25+ fields mixing navigation, data caching, UI mode flags, transition state, hover tracking, search |
| Mixed responsibilities | Orchestration + lazy data loading + graph algorithms (reachability BFS, cluster computation) + search typeahead + keyboard shortcuts |
| Suggested splits | Extract lazy-loading into cache manager; split search typeahead into sub-component; group analysis state (reachability, clusters, git status) into sub-record; extract graph algorithms to Data.Graph module |

### What the current metrics show

| Metric | Value | Assessment |
|--------|-------|------------|
| Coupling score | 279 | **Correct**: identifies it as the hottest module |
| Declarations | 7 | **Misleading**: 7 enormous functions, not 7 small ones |
| Internal calls | 331 | **Correct direction**: high volume of internal coupling |
| Cross-module calls | 498 | **Correct**: confirms it touches many external modules |
| Shape | Tree (100% treelikeness) | **Technically correct, practically misleading**: 7-node tree tells you nothing about the 25+ case branches within each node |
| Refactoring difficulty | Moderate | **Under-estimates**: the real difficulty is concern separation within giant declarations, not splitting the 7-node tree |
| High-coupling declarations | renderScene (35), prepareSceneData (20), renderHeaderBar (19) | **Useful**: correctly identifies the functions with highest external surface area |
| Cross-module coupling list | Ord (48), Eq (44), Maybe (34), Array (30) | **Noise**: Prelude usage, not architectural coupling |

### Gap analysis

The coupling score works as a **triage filter** — it finds the right modules to look at. But the structural decomposition view adds almost nothing for modules like SceneCoordinator where:

1. **Complexity is sub-declaration.** The 25+ case branches in `handleAction` are the real structure. Our analysis treats it as one node.
2. **State record sprawl is invisible.** Which fields are read/written by which actions is the key to separating concerns, but we don't track it.
3. **Cross-module coupling is undifferentiated.** Calls to `Prelude.Ord` and calls to `ModuleTreemapEnrichedViz.component` are equally weighted, but only the latter is architecturally significant.

## Plan: Visualizations That Show Real Refactoring Concerns

### Tier 1: Sub-Declaration Analysis (highest impact)

**Goal**: Treat case branches within large pattern matches as pseudo-declarations, revealing the internal structure of God functions.

**Data source**: The PureScript CST parser (already available in `minard-cst/`). Parse the module source, find top-level `case ... of` expressions in action handlers, extract each branch as a named node (e.g., `handleAction/Initialize`, `handleAction/NavigateTo`, `handleAction/ToggleGitMode`).

**Call graph construction**: For each case branch, determine:
- Which other branches it can trigger (via `handleAction` recursive calls)
- Which State fields it reads and writes
- Which external modules it calls

**Visualization**: Same block-cut tree layout, but with 25+ nodes (one per action branch) instead of 7. This would reveal the real biconnected component structure — which actions are tangled together vs. which are independent.

**Expected insight for SceneCoordinator**: The search actions (SearchInput, SearchKeyDown, SearchDismiss, SearchConfirmIndex) would form an isolated cluster. The peek actions (ReachabilityPeekOn/Off, PurityPeekOn/Off, ComplexityPeekOn/Off) would form another. The scene transition actions would be the tangled core. This directly suggests the annotation's recommended splits.

### Tier 2: State Field Usage Analysis

**Goal**: Show which state fields are touched by which actions, revealing concern groups that could become sub-records or extracted components.

**Data source**: CST parse of the module. For each action handler branch, collect field names from record updates (`H.modify_ _ { field = ... }`) and record reads (`state.field`).

**Visualization options**:
- **Bipartite graph**: Actions on left, state fields on right, edges for read/write. Clusters in this graph = separable concerns.
- **Co-occurrence matrix**: State fields on both axes, cell intensity = number of actions that touch both. Block-diagonal structure = natural grouping.
- **Overlay on sub-declaration call graph**: Color state field groups, show which action nodes participate in each group.

**Expected insight for SceneCoordinator**: Fields like `searchQuery`, `searchResults`, `searchSelectedIndex`, `searchOpen`, `searchSeqId` would cluster tightly (only touched by Search* actions). Fields like `reachabilityData`, `clusterData`, `purityData`, `complexityData` would cluster (analysis peek concerns). This directly supports "group into sub-records."

### Tier 3: Architectural Coupling (filter noise)

**Goal**: Distinguish Prelude/utility imports (Ord, Maybe, Array) from architectural imports (child components, domain modules) in the cross-module coupling analysis.

**Implementation**: Classify target modules by package source:
- **Infrastructure** (registry packages): Prelude, Data.*, Effect.*, Halogen.* — filter out or dim
- **Sibling** (same package): Other CE2.* modules — show as architectural coupling
- **Library** (local packages): PSD3.*, Hylograph.* — show as API surface coupling

**Visualization**: In the cross-module coupling panel, group by category. Only count sibling + library calls in the coupling score. The "Ord (48 calls)" noise disappears; what remains is the real architectural surface area.

### Tier 4: Diff-Aware Refactoring Preview

**Goal**: Let the user (or agent) propose a split and see the consequences before doing it.

**Interaction**: Select a cluster of action branches (from Tier 1 viz) or a state field group (from Tier 2 viz). Minard shows:
- What would move to the new module
- Which imports the new module would need
- Which call sites in the remaining module would become cross-module calls
- The updated coupling scores for both modules
- Whether the split increases or decreases overall treelikeness

**This is the endgame**: the visualization doesn't just identify problems, it lets you preview solutions. An agent could propose a split, the visualization shows its consequences, and the human approves or adjusts.

## Implementation Priority

| Tier | Effort | Value | Dependency |
|------|--------|-------|------------|
| 1. Sub-declaration analysis | Medium — CST parsing exists, need branch extraction + call graph | **High** — transforms the structure view from misleading to insightful | minard-cst parser |
| 2. State field usage | Medium — CST field extraction + bipartite layout | **High** — directly actionable for record/component splits | Tier 1 (shares parse infrastructure) |
| 3. Architectural coupling filter | Small — classify by package source | **Medium** — noise reduction, better scores | None |
| 4. Refactoring preview | Large — what-if analysis, new UI | **Very high** — the killer feature | Tiers 1-3 |

Tier 3 is the quick win — can be done independently. Tiers 1 and 2 share CST parsing infrastructure and should be designed together. Tier 4 builds on all previous tiers.

## Validation Criteria

The test for whether these visualizations work: **can a programmer unfamiliar with SceneCoordinator look at the visualization and independently arrive at the same decomposition suggestions the AI annotations propose?**

Specifically:
- Tier 1 should visually separate search, peek, scene transition, and data loading clusters
- Tier 2 should show the state field groups that correspond to those clusters
- Tier 3 should make the coupling list show `ModuleTreemapEnrichedViz`, `GalaxyBeeswarmViz` etc. instead of `Ord`, `Maybe`
- Tier 4 should let you drag-select the search cluster and see "new SearchTypeahead module: 5 actions, 5 state fields, 3 external calls"

If any tier fails this test, the visualization isn't earning its keep.

## Open Questions

1. **Does this generalize beyond Halogen?** The sub-declaration analysis assumes a `handleAction` case-expression pattern. Other architectures (Elm, Redux, plain functions) have different shapes. The CST approach should work for any pattern match, but the "which branches form clusters" question may need architecture-specific heuristics.

2. **How do we handle `where` clauses?** Many action branches delegate to helper functions defined in `where` blocks. These are sub-declaration but not top-level. The CST parser sees them; the question is whether to inline them into their parent branch or treat them as separate nodes.

3. **Can the coupling score be improved without Tier 1?** Yes — Tier 3 (filtering Prelude noise) is independent and would make the existing score more meaningful. But Tier 1 is where the real insight lives.

4. **Should agents consume these visualizations?** The long-term vision: an agent proposes a refactoring, Minard computes the structural consequences, and the proposal is accepted/rejected based on whether it improves the metrics. This requires machine-readable output from the analysis, not just SVG pictures.
