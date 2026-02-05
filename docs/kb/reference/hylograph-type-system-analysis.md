# Hylograph Type System Analysis

**Category**: reference
**Status**: active
**Created**: 2026-02-05
**Tags**: hylograph, types, architecture, finally-tagless, phantom-types

## Overview

Comprehensive analysis of the type system across the Hylograph visualization libraries, documenting patterns, instance coverage, and architectural decisions.

## Codebase Scale

- **118 PureScript modules** across 5 packages (selection, graph, layout, transitions, simulation-core)
- **260+ type declarations** (data, newtype, type aliases)
- **168+ type class instances**
- **12+ custom type classes** defining the finally-tagless expression system

## Core Architectural Patterns

### 1. Finally-Tagless Expression System

The central design pattern. Expression capabilities are defined as type classes, with multiple interpreters providing different semantics.

**Expression Classes** (12+):
- `NumExpr` - Numeric operations
- `StringExpr` - String manipulation
- `BoolExpr` - Boolean logic
- `TrigExpr` - Trigonometric functions
- `DatumExpr` - Data-driven values
- `AnimationExpr` - Animation parameters
- `PathExpr` - SVG path generation
- And more...

**Interpreters** (12-15):
- `Eval` - Direct evaluation to values
- `EvalD` - Evaluation with datum context
- `SVG` - SVG attribute string generation
- `SVGD` - SVG with datum context
- `CodeGen` - PureScript code generation
- `MetaD` - Metadata extraction
- `English` - Human-readable descriptions
- `Mermaid` - Diagram generation
- And more...

**Visualization opportunity**: Interpreter × Expression matrix showing coverage gaps.

### 2. Phantom Type State Machine (Selection)

Core type: `Selection state parent datum` where `state` is a phantom type parameter.

**State Types**:
- `SEmpty` - No elements selected
- `SPending` - Selection in progress
- `SBoundOwns` - Bound selection owning elements
- `SExiting` - Elements being removed

**Implementation**: `SelectionImpl` ADT with 4 constructors matching semantic states.

**Visualization opportunity**: State transition diagram showing valid operations per state.

### 3. HATS (Hylomorphic Abstract Trees)

Unparameterized `Tree` type that composes freely via Semigroup/Monoid.

**Key Types**:
- `Tree` - The composable tree structure
- `SomeFold` - Existential using CPS encoding (datum type hidden but accessible)
- `FoldSpec a` - Specification for data-driven folds
- `Enumeration a` - Enumerable data sources
- `Assembly` - Recursion scheme components

**Visualization opportunity**: Show how existentials are packed/unpacked, data flow through folds.

### 4. Row Polymorphism Patterns

**Field Extension**:
- `SimulationNode r` - Simulation adds fields to user-defined record
- `Link id r` - Links with extensible properties

**Visualization opportunity**: Show how fields flow and extend through types.

## Type Parameter Patterns Summary

| Pattern | Example | Purpose |
|---------|---------|---------|
| Finally-tagless | `repr` parameter | Multiple interpretations |
| Row polymorphism | `SimulationNode r` | Field extension |
| Phantom types | `Selection state parent datum` | Compile-time state tracking |
| Existential packing | `SomeFold` | Heterogeneous composition |

## Instance Coverage Analysis

### Well-Covered Types
- Expression interpreters: Full coverage for core classes (NumExpr, StringExpr, BoolExpr)
- Basic data types: Eq, Show commonly derived

### Under-Specified Types (Missing Obvious Instances)
- `AnimatedValue` - No Show instance (debugging difficult)
- `BrushConfig` - Opaque, no Show
- `DragConfig` - Opaque, no Show
- `ZoomConfig` - Opaque, no Show

### Instance Patterns
- 260 types with 168 instances suggests uneven coverage
- Config types tend to be opaque (no Show/Eq)
- Internal types often lack instances

## Package Breakdown

### purescript-hylograph-selection (Core)
- Selection state machine with phantom types
- HATS tree composition
- Finally-tagless expression system
- Attribute variants (Static, Data-driven, Indexed, Animated, AnimatedCompound)
- Behavior types (mouse, click, drag, zoom, brush)
- 17 easing types

### purescript-hylograph-graph
- `Graph` type with adjacency list storage
- Pathfinding algorithms
- Layout algorithms (force-directed positioning)

### purescript-hylograph-layout
- `HierarchyNode a` - Tree layouts with depth/height
- `ValuedNode a` - Nodes with computed values
- `SankeyNode`/`SankeyLink` - Flow diagram layouts
- Alignment (4 variants), LinkColorMode (4 variants)

### purescript-hylograph-transitions
- `TransitionSpec`/`TransitionState` - Tick-driven state machine
- `TransitionGroup`, `IndexedTransitionGroup` - Coordinated animations
- Interpolators for Number, Point, RGB, HSL
- Progress tracking (0.0 to 1.0)

### purescript-hylograph-simulation (if separate)
- `SimulationNode` as row-polymorphic type
- D3_ID + D3_XY + D3_VxyFxy + custom fields
- Force definitions and tick handlers

## Attribute System Detail

**5 Attribute Variants**:
1. Static - Fixed values
2. Data-driven - Computed from datum
3. Indexed - Uses element index
4. Animated - Transitions over time
5. AnimatedCompound - Complex animated attributes

**Metadata Tracking**: `AttrSource` for introspection of attribute origins.

**Notable**: Contravariant instance (rare in PureScript ecosystem).

## Behavior Types Detail

**8 Behavior Variants**:
- Mouse events (enter, leave, move)
- Click events
- Drag behavior
- Zoom behavior
- Coordinated highlight
- Brush selection

**Supporting Types**:
- `HighlightClass` (6 values)
- `TooltipTrigger` (3 values)

## Key Files

| Purpose | Location |
|---------|----------|
| Core DSL | `Hylograph/Expr/Expr.purs` |
| HATS | `Hylograph/HATS.purs` |
| Selection Types | `Hylograph/Internal/Selection/Types.purs` |
| Interpreters | `Hylograph/Expr/Interpreter/*.purs` |
| English Interpreter | `Hylograph/Interpreter/English.purs` |
| Behaviors | `Hylograph/Internal/Behavior/Types.purs` |
| Animation | `Hylograph/Transition/Engine.purs` |
| Hierarchy Layout | `DataViz/Layout/Hierarchy/Types.purs` |
| Sankey Layout | `DataViz/Layout/Sankey/Types.purs` |

## Observations

1. **Architectural sophistication**: The finally-tagless pattern with multiple interpreters is the core design decision enabling flexibility.

2. **Type safety for state machines**: Phantom types make invalid Selection states unrepresentable.

3. **Composition via existential hiding**: HATS trees of different datum types compose because SomeFold CPS-encodes the type.

4. **Instance gaps suggest improvements**: Many config types could benefit from Show instances for debugging.

5. **Documentation value**: Patterns like SomeFold's CPS encoding and row polymorphism are hard to grasp from source alone - visualization would help.

6. **Educational material**: This codebase demonstrates 5+ advanced FP patterns, excellent for teaching modern PureScript.

## Related Documents

- `docs/kb/architecture/hylograph-architecture.md` (if exists)
- `visualisation libraries/purescript-hylograph-selection/README.md`
- `visualisation libraries/purescript-hylograph-selection/docs/`
