# Sugiyama Layered Graph Layout

**Status**: planned
**Category**: plan
**Created**: 2026-01-30
**Tags**: graph-layout, sugiyama, dag, graphviz-alternative, algorithms

## Summary

Implement the Sugiyama algorithm for layered graph drawing in pure PureScript, providing a modern, interactive alternative to Graphviz's `dot` layout.

## Motivation

Graphviz has been the standard for DAG visualization since the early 1990s. While groundbreaking for its time, it has significant limitations:

- **Batch processing**: No interactivity, regenerate entire image for any change
- **Raster/static output**: SVG support is an afterthought
- **No animation**: Can't smoothly transition between states
- **External dependency**: Requires installation, can't run in browser

A pure PureScript implementation would offer:

- **Interactive**: Direct DOM manipulation, hover/click/drag
- **Animated transitions**: Smooth relayout when data changes
- **Browser-native**: No server round-trip, works offline
- **Typed**: Compile-time guarantees about graph structure
- **Composable**: Integrates with Hylograph ecosystem

## The Sugiyama Algorithm

Four phases, each well-defined:

### Phase 1: Cycle Removal

Make the graph acyclic by reversing selected edges.

```purescript
-- Find feedback arc set (edges to reverse)
-- Greedy heuristic: repeatedly remove sources/sinks
removeCycles :: Graph -> { dag :: Graph, reversed :: Set Edge }
```

Simple greedy works well. Can use DFS-based approach.

### Phase 2: Layer Assignment

Assign each node to a horizontal layer (rank).

```purescript
-- Longest path algorithm for initial assignment
-- Then: network simplex for optimization (optional)
assignLayers :: Graph -> Map Node Int
```

Longest-path from sources gives valid layering. Network simplex optimizes for edge length but is complex - start without it.

### Phase 3: Crossing Minimization

Reorder nodes within each layer to minimize edge crossings.

```purescript
-- Barycenter heuristic: position node at mean of neighbors
-- Iterate until stable
minimizeCrossings :: LayeredGraph -> LayeredGraph
```

This is the NP-hard part. Heuristics:
- **Barycenter**: Node position = average of connected nodes in adjacent layer
- **Median**: Node position = median of connected nodes
- **Sifting**: Try moving each node, keep if improves

Barycenter with multiple passes works surprisingly well.

### Phase 4: Coordinate Assignment

Assign actual x/y coordinates.

```purescript
-- Brandeis algorithm or simpler approach
-- Balance: minimize edge length, avoid overlaps, stay compact
assignCoordinates :: LayeredGraph -> PositionedGraph
```

Simpler approach: equal spacing within layers, adjust for node widths.
Advanced: Brandeis algorithm for "straight as possible" edges.

## Implementation Plan

### Phase 1: Minimal Viable Implementation

1. **Data structures**
   ```purescript
   type Node = { id :: String, label :: String, ... }
   type Edge = { source :: String, target :: String, ... }
   type Graph = { nodes :: Array Node, edges :: Array Edge }
   type LayeredGraph = { layers :: Array (Array Node), edges :: Array Edge }
   ```

2. **Cycle removal**: DFS-based, reverse back edges

3. **Layer assignment**: Longest path (simple, correct)

4. **Crossing minimization**: Barycenter, 4 passes

5. **Coordinates**: Equal spacing, fixed layer height

### Phase 2: Refinements

- Network simplex for layer optimization
- Median heuristic option for crossing minimization
- Brandeis coordinate assignment
- Edge routing (orthogonal, splines)
- Port constraints (edges attach at specific points)

### Phase 3: Integration

- HATS rendering with transitions
- Interactive: drag nodes, collapse subgraphs
- Integration with Code Explorer for dependency viz

## Existing Resources

### Academic

- Sugiyama, Tagawa, Toda (1981): Original paper
- Gansner et al. (1993): "A Technique for Drawing Directed Graphs" (Graphviz paper)
- "A Functional Approach to the Sugiyama Algorithm" (2015) - need to locate

### Implementations to Study

- Graphviz `dot` (C) - reference implementation
- dagre (JavaScript) - widely used, readable
- ELK (Java) - Eclipse layout kernel, very complete
- No known pure Haskell/PureScript implementation

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Crossing minimization too slow | Start with barycenter, profile, optimize hot paths |
| Edge routing complex | Start with straight lines, add splines later |
| Large graphs problematic | Implement level-of-detail, clustering |
| Algorithm correctness | Extensive property-based testing |

## Success Criteria

1. Correctly layout DAGs up to ~500 nodes
2. Competitive with dagre quality (visual comparison)
3. < 100ms layout time for typical graphs
4. Animated transitions on data change
5. Works in Code Explorer for module dependencies

## Why This Matters

A pure PureScript Sugiyama implementation would be:

- **First of its kind** in the PureScript/JavaScript FP ecosystem
- **Genuinely useful** for developer tools, documentation, pipelines
- **Proof of capability** that Hylograph can do serious algorithms
- **Freedom from Graphviz** after 30+ years

## Related

- [Code Explorer Architecture](../architecture/code-explorer.md) - primary use case
- [EdgeBundle Module](../../visualisation%20libraries/purescript-hylograph-layout/src/DataViz/Layout/Hierarchy/EdgeBundle.purs) - complementary viz
