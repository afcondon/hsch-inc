# Decomposition Meets Architectural Enforcement

**Category**: Plan
**Status**: Draft
**Created**: 2026-03-07
**Related**: `minard-architectural-enforcement.md`, `release-plan-2026.md`
**Context**: Built structural decomposition view in Minard frontend (2026-03-07 session). This plan connects it to the planned architectural enforcement features.

## Core Insight

Layers and biconnected components are complementary views of the same dependency graph:

- **Layers** are *prescriptive*: "this is how we intend the architecture" (human-defined, downward-only deps)
- **Decomposition** is *descriptive*: "this is how the code actually interconnects" (algorithmically discovered)

A clean layered architecture with downward-only dependencies is a DAG. Every layer violation (upward import) creates a cycle, which merges biconnected components. Therefore:

- **Treelikeness = architectural health.** A DAG has treelikeness ~100%. minard-frontend has 4.1%.
- **Each violation reduces treelikeness** by merging blocks that should be separate.
- **Removing violations should increase treelikeness** — measurably, predictably.
- **The block-cut tree reveals natural layer boundaries** even without a config file.

## What Exists Today

Built in the 2026-03-07 session, in `minard/frontend/src/`:

| File | What |
|------|------|
| `Data/Decomposition.purs` | Full decomposition library (biconnected components, articulation points, bridges, bipartiteness, block-cut tree, metrics). Copied from hylograph-graph with `SimpleGraph` inlined. Includes `importsToSimpleGraph` converter and `analyzeGraph` unified analysis. |
| `Component/StructuralDecompViz.purs` | Halogen component: scope filter (Workspace / All / per-package), annotated graph with block-cut tree layout, before/after adjacency matrices, metrics panel, block list. |
| `Scene.purs` | `StructuralDecomp` scene added |
| `Component/SceneCoordinator.purs` | Wired: nav button, slot, scene rendering, theme |

Current metrics on minard-frontend (50 modules):
- 6 biconnected components, 4 articulation points, 5 bridges
- Largest block: 43 nodes (sparse, 118 edges)
- Treelikeness: 4.1%
- One massive interconnected core + 5 small satellite blocks

## Plan: Three Features

### Feature A: Layer Coloring in Decomposition View

**What**: When `architecture.yml` exists and layer data is available via the API, color nodes by their architectural layer instead of (or in addition to) their biconnected component.

**Why**: The decomposition view currently colors by block. Coloring by layer reveals whether blocks respect layer boundaries. A block that spans multiple layers = structural coupling across intended boundaries.

**Implementation**:

1. Fetch layer data from `/api/v2/architecture/layers` (once enforcement feature ships)
2. Add a color toggle to the decomposition view: "Color by: Block | Layer"
3. In layer mode:
   - Node fill = layer color from config
   - Block boundary circles remain (showing structural grouping)
   - Violation edges highlighted in red (from `/api/v2/architecture/violations`)
4. Mixed-layer blocks get a warning indicator — a block that contains modules from 3+ layers is architecturally confused

**Key visual**: nodes colored by layer, grouped by block. If layers and blocks align, you see clean monochrome clusters. If they don't, you see rainbow blocks — the structural reality doesn't match the architectural intent.

**Depends on**: Architectural enforcement features (steps 1-5 from `minard-architectural-enforcement.md`). But the decomposition view UI can be built now with a stub/mock.

**Effort**: ~half day once enforcement API exists. The decomposition view already has the block layout; this is just a color source swap.

### Feature B: "What-If" Mode — Edge Removal Analysis

**What**: A mode that lets you hypothetically remove edges (especially violation edges) and instantly see how the decomposition changes.

**Why**: This answers the architectural question "if we fixed violation X, how much would the structure improve?" Concretely:
- Remove a violation edge → does the big block split into two smaller ones?
- Remove all violations → what's the treelikeness of the "intended" architecture?
- Which single violation, if fixed, produces the largest treelikeness improvement?

**Implementation**:

1. **Baseline vs. clean comparison**: compute decomposition twice — once on the actual graph, once on the graph with violation edges removed. Show side by side or as a toggle.
   - Metrics diff: "Treelikeness: 4.1% → 38.2% (without violations)"
   - Block count diff: "6 blocks → 14 blocks"
   - This alone is a compelling fitness metric.

2. **Per-edge impact**: for each violation edge, compute treelikeness-if-removed. Rank violations by impact. The violation that merges the most blocks when present is the highest-priority fix.
   - This is O(V * E_violations) — for each violation, remove it and rerun decomposition. With <100 modules and <10 violations, this is instant.

3. **Interactive edge removal** (stretch): click an edge in the graph to toggle it off. Decomposition recomputes live. Watch blocks split and merge as you remove/restore edges.

**Key visual**: two matrices side by side — "Current" and "Without Violations". The second matrix should show dramatically more diagonal structure. The diff IS the cost of the violations.

**Depends on**: Feature A (layer data to identify which edges are violations). But a simpler version works without layers — let the user click any edge to remove it and see the impact.

**Effort**: ~1-2 days. The decomposition algorithms are already fast enough for interactive use at this scale. The main work is UI (toggle, diff display, per-edge ranking).

### Feature C: Decomposition-Guided Layer Discovery

**What**: Use the block-cut tree to *suggest* an `architecture.yml` for a project that doesn't have one.

**Why**: The enforcement plan requires humans to write `architecture.yml`. But for an existing codebase (like Minard itself), the decomposition already reveals natural structural groups. We can bootstrap the layer config from the actual structure.

**How it works**:

1. **Start from the block-cut tree**. Each biconnected component is a candidate structural unit. The tree topology gives parent-child relationships between units.

2. **Assign depth**. BFS from the root block assigns each block a depth. Modules in deeper blocks depend on modules in shallower blocks — this is a natural layer ordering.

3. **Refine with namespace prefixes**. Modules often have naming conventions (CE2.Viz.*, CE2.Data.*, CE2.Component.*). Cross-reference block membership with namespace prefixes to suggest meaningful layer names.

4. **Identify violations relative to the suggested layers**. Any edge that goes from a deeper block to a shallower block (against the tree direction) is a candidate violation. These are the edges that, if removed, would increase treelikeness.

5. **Generate draft YAML**. Output a suggested `architecture.yml` with:
   - Layers derived from block-cut tree depth + namespace grouping
   - Module patterns from common prefixes within each layer
   - Violations already identified as exceptions to review

**Concrete example for minard-frontend**:

The current decomposition shows:
- Core block (43 nodes): CE2.Component.*, CE2.Viz.*, CE2.Data.*, CE2.Scene, CE2.Types — all in one mass
- Satellites: CirclePackViz+Color, DOMHelpers, SignatureTree, SlideOutPanel, TypeSignature

A suggested layering might be:
```yaml
layers:
  - name: "Types & Data"
    order: 0
    pattern: "CE2\\.Types|CE2\\.Scene|CE2\\.Color"
  - name: "Data Loading"
    order: 1
    pattern: "CE2\\.Data\\..*"
  - name: "Visualization"
    order: 2
    pattern: "CE2\\.Viz\\..*"
  - name: "Components"
    order: 3
    pattern: "CE2\\.Component\\..*"
  - name: "Utilities"
    order: 4
    pattern: "CE2\\.Util\\..*|CE2\\.Browser\\..*|CE2\\.Containers"
  - name: "Entry"
    order: 5
    pattern: "CE2\\.Main"
```

The decomposition would then reveal that Components import from Viz (violation? or expected?), Viz imports from Data (clean), but also that SceneCoordinator imports from everything (articulation point = God module).

**Key output**: a downloadable `architecture.yml` draft, annotated with "N modules matched, M violations detected if this layering is adopted."

**Depends on**: nothing new. Can be built entirely from the existing decomposition + namespace data already in Minard.

**Effort**: ~2-3 days. The algorithm is straightforward; the work is in making the output useful (good namespace heuristics, clear draft YAML, violation preview).

## Implementation Order

| Step | Feature | Depends on | Effort |
|------|---------|-----------|--------|
| **C** | Layer discovery from decomposition | Nothing | 2-3 days |
| **A** | Layer coloring in decomp view | Enforcement API (or mock) | Half day |
| **B** | What-if edge removal | A (for violation identification) | 1-2 days |

**Recommended sequence**: C first, because it doesn't depend on the enforcement pipeline shipping. It produces an `architecture.yml` draft for Minard itself, which then feeds into the enforcement pipeline (steps 1-5 from the enforcement plan). Once enforcement is live, A and B light up.

This means decomposition work *accelerates* the enforcement plan rather than depending on it.

## Connection to Release Plan

From `release-plan-2026.md`, Phase 3 (Minard Release, Week 5-6):
- "Architectural enforcement features (~5-7 days)"
- "Test: ingest ShapedSteer, verify known violations detected"

This plan adds:
- **Before enforcement ships**: use decomposition to draft `architecture.yml` for both Minard and ShapedSteer (Feature C)
- **After enforcement ships**: decomposition view becomes the diagnostic tool for understanding and fixing violations (Features A, B)
- **Ongoing**: treelikeness as a fitness metric tracked alongside violation count in drift tracking

## Metrics That Tell The Story

| Metric | What it means | Current (minard-frontend) |
|--------|--------------|--------------------------|
| Treelikeness | Ratio of bridges to edges. 100% = DAG, 0% = fully cyclic | 4.1% |
| Biconnected components | Number of structurally independent units | 6 |
| Largest block / total nodes | How much of the codebase is one interconnected mass | 43/50 = 86% |
| Articulation points | Critical modules whose removal fragments the graph | 4 |
| Violations (future) | Upward imports that violate intended layer order | TBD |

A healthy codebase should show: high treelikeness, many small blocks, no single dominant block, few articulation points, zero violations.

## Files Reference

| Path | Purpose |
|------|---------|
| `minard/frontend/src/Data/Decomposition.purs` | Algorithms + analysis + SimpleGraph converter |
| `minard/frontend/src/Component/StructuralDecompViz.purs` | Visualization component |
| `minard/frontend/src/Scene.purs` | StructuralDecomp scene |
| `purescript-hylograph-graph/src/Data/Graph/Decomposition.purs` | Canonical algorithm source (pending 0.2.0) |
| `purescript-hylograph-graph/demo-decomposition/` | Standalone demo with 4 chimera styles + Les Mis |
