# Recursion Schemes as Visualization Primitives

**Status**: active
**Category**: research
**Created**: 2026-01-30
**Tags**: recursion-schemes, theory, visualization, paper-idea

## Abstract

Data visualization fundamentally involves transforming data structures into visual representations. Recursion schemes provide a vocabulary for describing structural transformations. This note explores how different recursion schemes map to visualization concerns, potentially forming a theoretical foundation for declarative visualization libraries.

## Background

Hylograph is named for the **hylomorphism** - the composition of an unfold (anamorphism) followed by a fold (catamorphism). This captures the essence of data visualization:

1. **Unfold**: Transform input data into an intermediate tree structure
2. **Fold**: Collapse that structure into DOM/SVG elements

But hylomorphism is just one recursion scheme. What do the others offer?

## Recursion Schemes and Their Visualization Semantics

### Catamorphism (Fold)
**Structure → Value**

The most basic scheme. Consume a structure, produce a result.

**Viz meaning**: Aggregate statistics, compute scales, derive layout parameters.

```
data → fold → { min, max, mean, extent, ... }
```

### Anamorphism (Unfold)
**Seed → Structure**

Generate structure from initial value.

**Viz meaning**: Generate marks from data points, expand hierarchies, create geometric primitives.

```
dataPoint → unfold → [circle, label, connector, ...]
```

### Hylomorphism (Unfold then Fold)
**Seed → Structure → Value**

The core Hylograph pattern.

**Viz meaning**: Data → intermediate representation → DOM. The intermediate structure is never materialized if fused.

### Paramorphism (Fold with Context)
**Fold where each step sees original substructure, not just recursive result**

**Viz meaning**: Context-aware rendering. When rendering a node:
- See the computed layout info (from recursion)
- AND see the raw data subtree (original structure)

**Use cases**:
- Collapsed tree nodes showing preview of hidden children
- Fisheye distortion where rendering depends on neighborhood
- Tooltips that summarize subtrees
- "N more items" indicators

```purescript
renderNode :: NodeData -> Subtree -> RenderedChildren -> Visual
--                        ^^^^^^^ original subtree available
```

### Apomorphism (Unfold with Early Termination)
**Unfold that can stop before reaching base case**

**Viz meaning**: Lazy/partial rendering. Stop generating when:
- Viewport bounds reached
- Detail threshold hit
- Resource budget exhausted

**Use cases**:
- Virtual scrolling / windowing
- Level-of-detail rendering
- Progressive disclosure
- Infinite scroll (L-systems!)

```purescript
unfoldUntil :: (Partial → Boolean) → Seed → Structure
-- stops when predicate satisfied
```

### Histomorphism (Fold with History)
**Fold where each step sees all previous results, not just immediate children**

**Viz meaning**: Path-dependent visualization. Each frame knows full history.

**Use cases**:
- Animations where frame N depends on frames 0..N-1
- Undo/redo built into the algebra
- Cumulative visualizations (running totals)
- Trail effects (show where things came from)
- Story-based viz that accumulates context

```purescript
renderFrame :: CurrentData -> History [PreviousFrames] -> Visual
```

### Futumorphism (Unfold with Lookahead)
**Unfold that can generate multiple levels at once**

**Viz meaning**: Batch generation, planning ahead.

**Use cases**:
- Level-of-detail: "at this zoom, generate 3 levels of hierarchy"
- Prefetching: generate slightly more than viewport needs
- Smooth scrolling: anticipate scroll direction

### Dynamorphism (Hylomorphism + Memoization)
**Hylomorphism with cached intermediate results**

**Viz meaning**: Efficient updates. Don't recompute unchanged subtrees.

**Use cases**:
- Interactive filtering (most structure unchanged)
- Real-time updates (only diff needs recomputation)
- React-style reconciliation, but principled
- Large dataset visualization with incremental updates

This is perhaps the most practically important for interactive viz.

### Zygomorphism (Parallel Folds)
**Two folds computed simultaneously over same structure**

**Viz meaning**: Multi-concern traversal in single pass.

**Use cases**:
- Compute layout AND color scale simultaneously
- Derive positions AND accessibility labels together
- Calculate bounds AND hit-test regions in one traversal

```purescript
fold₁ × fold₂ :: Structure → (Layout, ColorScale)
```

### Chronomorphism (History + Future)
**Combines histomorphism and futumorphism**

**Viz meaning**: Know past AND plan future.

**Use cases**:
- Smooth animations that ease into destination
- Physics simulations with lookahead
- Transitions that account for velocity/momentum
- "Anticipatory" UI that predicts user action

## Composition Patterns

These schemes compose. Real visualizations might use:

- **Para + Apo**: Context-aware lazy rendering
- **Dyna + Zygo**: Efficient multi-concern updates
- **Histo + Chrono**: Temporal viz with full timeline awareness

## Toward a Visualization Algebra

Could we define a visualization as:

```
Viz = Scheme × Data × (Intermediate → Visual)
```

Where `Scheme` selects the recursion pattern, determining:
- What context is available during rendering
- When computation terminates
- What gets cached/memoized
- How updates propagate

This would make visualization design more principled - choose your scheme based on interaction requirements, not ad-hoc.

## Open Questions

1. **What's the right intermediate representation?** HATS trees? Something more abstract?

2. **Can scheme selection be automatic?** Given viz requirements, infer optimal scheme.

3. **Performance implications?** Some schemes have overhead. When does it matter?

4. **Composition semantics?** How do schemes combine in complex visualizations?

5. **Relation to FRP?** Temporal schemes (histo, chrono) feel related to reactive programming.

## Potential Paper Structure

1. **Introduction**: Visualization as structural transformation
2. **Background**: Recursion schemes primer
3. **The Correspondence**: Each scheme ↔ viz capability
4. **Case Studies**: L-systems (apo), interactive dashboards (dyna), animations (histo)
5. **Implementation**: Hylograph as proof of concept
6. **Evaluation**: Expressiveness, performance, developer experience
7. **Related Work**: FRP, React, D3, visualization grammars
8. **Conclusion**: Toward algebraic visualization

## Related Work to Review

- "Functional Pearl: Recursion Schemes" (Meijer et al.)
- "Bananas, Lenses, Envelopes and Barbed Wire" (classic)
- "A Grammar of Graphics" (Wilkinson) - different formalism, similar goals
- Vega-Lite - declarative viz, no explicit scheme connection
- React Fiber - practical dynamorphism without the theory
- Incremental computation literature (self-adjusting computation)

## Next Steps

1. Implement apomorphism L-systems demo as proof of concept
2. Implement dynamorphism for Code Explorer updates
3. Write up findings
4. Submit to ICFP, JFP, or visualization venue?
