# Finally Tagless AST for PSD3

**Status**: Proposed
**Created**: 2025-01-16
**Branch**: `feature/heterogeneous-ast`

## Problem Statement

PSD3's current AST is a plain ADT with fixed constructors:

```purescript
data Tree datum
  = Node (TreeNode datum)
  | Join { ... }
  | ConditionalRender { ... }
  | LocalCoordSpace { ... }
  -- etc.
```

This means adding new node types (like heterogeneous shapes, tables, custom visualizations) requires modifying the core library. This is:
- **Inflexible** - users can't extend the AST
- **Risky** - changes to core break existing demos
- **Monolithic** - all features bundled together

## The Insight

PSD3 already uses finally tagless for `SelectionM` - the operations typeclass that interpreters implement. This gives us:
- Multiple interpreters (D3, Mermaid, String)
- Extension without modification
- Type safety

We can apply the same pattern to the AST itself.

## Current Architecture

```
User code → builds AST (plain ADT) → renderTree → SelectionM (finally tagless)
            ^^^^^^^^^^^^^^^^^^^^                   ^^^^^^^^^^^^^^^^^^^^^
            Fixed, not extensible                  Extensible via instances
```

## Proposed Architecture

```
User code → builds tree via TreeDSL (finally tagless) → interpreter → SelectionM
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
            Extensible via new typeclasses!
```

## Design Sketch

### Core Tree DSL

```purescript
-- The base tree-building operations
class TreeDSL tree where
  -- Create a named element
  named :: ElementType -> String -> Array (Attribute d) -> tree d

  -- Create an anonymous element
  elem :: ElementType -> Array (Attribute d) -> tree d

  -- Add children
  withChildren :: tree d -> Array (tree d) -> tree d

  -- Data join
  joinData :: String -> String -> Array d -> (d -> tree d) -> tree d

  -- Conditional render (existing chimera support)
  conditionalRender
    :: Array { predicate :: d -> Boolean, spec :: d -> tree d }
    -> tree d
```

### Extension: Shape Specs

```purescript
-- Heterogeneous shape rendering - extends core without modifying it
class TreeDSL tree <= ShapeTreeDSL tree where
  fromSpec
    :: (d -> ShapeSpec d)
    -> (d -> Dimensions)  -- for layout
    -> tree d

-- The shape ADT
data ShapeSpec d
  = CircleSpec { radius :: d -> Number, fill :: d -> Color }
  | RectSpec { width :: d -> Number, height :: d -> Number, fill :: d -> Color }
  | PolygonSpec { points :: d -> String, fill :: d -> Color }
  | TableSpec { rows :: d -> Array (Array String), headerStyle :: d -> Style }
  | GroupSpec { children :: Array (ShapeSpec d) }
```

### Extension: Other Future Features

```purescript
-- 3D support?
class TreeDSL tree <= Tree3DDSL tree where
  mesh :: MeshSpec d -> tree d

-- Animation primitives?
class TreeDSL tree <= AnimationDSL tree where
  tween :: TweenSpec d -> tree d -> tree d

-- Audio/sonification?
class TreeDSL tree <= SonificationDSL tree where
  sonify :: SonificationSpec d -> tree d -> tree d
```

## Benefits

1. **Extensibility without modification** - New features are new typeclasses
2. **Type safety preserved** - Everything still type-checked
3. **Declarative** - Still building data, not executing effects
4. **Composable** - Extensions can depend on each other
5. **Optional** - Use only the features you need
6. **Multiple interpreters** - D3, testing, documentation all work

## Migration Path

1. Define `TreeDSL` typeclass with current AST operations as methods
2. Create `TreeAST` - a free/initial encoding that any `TreeDSL` can interpret
3. Implement `TreeDSL TreeAST` - the "build an AST" interpreter
4. Existing `renderTree` becomes `interpret :: TreeDSL tree => TreeAST d -> tree d`
5. Gradually migrate demos to use `TreeDSL` constraints instead of `TreeAST` directly

## Open Questions

1. **Free vs Tagless** - Do we need a concrete AST type at all, or go pure tagless?
2. **Layout integration** - How does layout work with extensible node types?
3. **Performance** - Does tagless encoding have runtime overhead?
4. **Ergonomics** - Is `TreeDSL tree =>` too noisy in user code?

## Prototype: Optic Menagerie

We built a prototype showcase (`showcases/psd3-optic-menagerie`) that:
- Renders heterogeneous trees (circles, squares, triangles, diamonds, tables)
- Two-tree side-by-side comparison showing optic transformations
- Pure Halogen/SVG rendering (not using PSD3 AST yet)

Next step: Attempt to express this through a finally-tagless AST.

## Related Work

- [Finally Tagless, Partially Evaluated](http://okmij.org/ftp/tagless-final/) - Kiselyov et al.
- [Data types à la carte](http://www.cs.ru.nl/~W.Swierstra/Publications/DataTypesALaCarte.pdf) - Swierstra
- PSD3's existing `SelectionM` typeclass pattern
