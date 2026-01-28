# HATS Existential Fold Design

**Status**: active
**Created**: 2026-01-27
**Tags**: HATS, existential-types, CPS, heterogeneous-composition, psd3-selection

## Overview

HATS (Hylomorphic Abstract Tree Syntax) uses **existentially-scoped data binding** to enable heterogeneous tree composition. This document explains the design, implementation, and rationale.

## The Problem

The original HATS design parameterized `Tree` by datum type:

```purescript
data Tree a
  = Elem { ..., children :: Array (Tree a) }
  | Fold (FoldSpec a)
  | Empty
```

This prevented composing trees with different datum types:

```purescript
linksLayer :: Tree LinkData
nodesLayer :: Tree HierNode
combined = linksLayer <> nodesLayer  -- Type error!
```

Real visualizations often need this: links bind `{ source, target }`, nodes bind `{ x, y, label }`.

## The Solution: Existential Scoping

**Key insight**: The datum type `a` is only needed *inside* the template function. By capturing values in closures at template time, we can "erase" the type from the outer Tree.

```purescript
-- No type parameter - all trees compose freely
data Tree
  = Elem { elemType, attrs, children, behaviors }
  | MkFold SomeFold
  | Empty

-- Semigroup instance enables composition
instance Semigroup Tree where
  append t1 t2 = siblings [t1, t2]
```

Now this works:

```purescript
linksLayer :: Tree
nodesLayer :: Tree
combined = linksLayer <> nodesLayer  -- Compiles!
```

## CPS-Encoded Existentials

PureScript lacks native existential types (`exists a. T a`). We use CPS (continuation-passing style) encoding:

```purescript
-- Pack: hide the type
newtype SomeFold = SomeFold (forall r. (forall a. FoldSpec a -> r) -> r)

mkSomeFold :: forall a. FoldSpec a -> SomeFold
mkSomeFold spec = SomeFold (\k -> k spec)

-- Unpack: provide polymorphic handler
runSomeFold :: forall r. SomeFold -> (forall a. FoldSpec a -> r) -> r
runSomeFold (SomeFold f) k = f k
```

**Why CPS?**
- Works in standard PureScript (no extensions)
- Type-safe: the `a` can only be used inside the continuation
- No runtime overhead: optimizes to direct calls

## Thunked Attributes and Behaviors

Since `Tree` no longer carries the datum type, attributes and behaviors must capture their values:

```purescript
-- OLD: Parameterized, needs datum at apply time
data Attribute a = DataAttr String (a -> String) | ...

-- NEW: Thunked, value captured at construction time
data Attr
  = StaticAttr String String
  | ThunkedAttr String (Unit -> String)
```

Inside a template, the datum is in scope and captured:

```purescript
forEach "nodes" Circle nodes _.id \node ->
  -- 'node' is captured in these closures:
  elem Circle
    [ thunkedNum "cx" node.x    -- captures node.x
    , thunkedNum "cy" node.y    -- captures node.y
    ] []
```

Similarly for behaviors:

```purescript
data ThunkedBehavior
  = ThunkedMouseEnter (Unit -> Effect Unit)
  | ThunkedMouseLeave (Unit -> Effect Unit)
  | ...

-- Usage: datum captured in handler
withBehaviors [ onMouseEnter (callbacks.onHover node.path) ] $
  elem Circle [...] []
```

## Interpreter Pattern

The interpreter uses `runSomeFold` with a polymorphic continuation:

```purescript
interpretTree :: Document -> Element -> Tree -> Effect SelectionMap
interpretTree doc parent = case _ of
  Empty -> pure Map.empty

  Elem spec -> do
    el <- createElement spec.elemType
    applyAttrs el spec.attrs
    traverse_ (interpretTree doc el) spec.children
    pure Map.empty

  MkFold someFold -> runSomeFold someFold \spec -> do
    -- Everything must happen inside this continuation
    -- to prevent the type variable from escaping
    let items = runEnumeration spec.enumerate
    for_ items \datum -> do
      let subtree = spec.template datum
      interpretTree doc parent subtree
```

**Critical**: All processing of the FoldSpec must occur inside the `runSomeFold` continuation. Extracting values to use outside causes "escaped skolem" errors.

## User-Facing API

The API is clean - users don't see the existential encoding:

```purescript
forEach
  :: forall a
   . String           -- Selection name
  -> ElementType      -- Element type for GUP scoping
  -> Array a          -- Data
  -> (a -> String)    -- Key function
  -> (a -> Tree)      -- Template (datum captured in closures)
  -> Tree             -- Note: no 'a' in return type!

-- Example usage
chart :: Tree
chart =
  linksLayer    -- binds LinkData internally
  <> nodesLayer -- binds NodeData internally
  <> legend     -- binds LegendItem internally
```

## Comparison with D3

| Aspect | D3 | HATS (Existential) |
|--------|----|--------------------|
| Data binding | Runtime, on DOM elements | Compile-time, in closures |
| Type safety | None (JavaScript) | Full (but datum type is scoped) |
| Composition | Manual join management | `<>` operator |
| Heterogeneous data | Natural (no types) | Enabled by existential scoping |

## Trade-offs

**Advantages:**
- Heterogeneous composition with `<>`
- Clean, composable API
- Type-safe inside templates
- No runtime overhead

**Constraints:**
- Can't extract datum type from a Tree (it's existentially hidden)
- Must use thunked attributes inside templates
- Interpreter must be written carefully to avoid skolem escape

## Files

- `PSD3/HATS.purs` - Core types and smart constructors
- `PSD3/HATS/Friendly.purs` - Attribute helpers
- `PSD3/HATS/InterpreterTick.purs` - Tick-driven interpreter

## Related Documents

- `docs/kb/plans/finally-tagless-ast.md` - Earlier design exploration
- `docs/kb/architecture/psd3-interpreter-systems.md` - Interpreter architecture
