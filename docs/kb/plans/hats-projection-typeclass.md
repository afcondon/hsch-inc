# HATS Projection Type Class

**Status**: active
**Category**: plan
**Created**: 2026-01-28
**Tags**: hats, finally-tagless, enumeration, projection, map

## Summary

Extend HATS with a finally tagless `Project` type class that allows any data structure to be enumerated. The killer demo: a single `Map` yields three projections (Keys, Values, Entries) that compose into one diagram.

## Motivation

Current HATS `Enumeration` is a closed sum type:
```purescript
data Enumeration a
  = FromArray (Array a)
  | FromTree { ... }
  | WithContext (Array { datum :: a, ... })
```

This limits what structures can be fed into a hylo. The promise is "pass structure in, get visualization out" — but currently you must convert to Array first.

## Design

### The Project Type Class

```purescript
-- | Project a source structure into an array of target elements.
-- | The fundep ensures each source has a canonical projection.
class Project source target | source -> target where
  project :: source -> Array target

-- Arrays project to their elements (identity)
instance projectArray :: Project (Array a) a where
  project = identity
```

### Multiple Projections via Newtypes

A Map has three natural projections. Use newtypes to select:

```purescript
-- | Project a Map to its keys
newtype MapKeys k v = MapKeys (Map k v)

-- | Project a Map to its unique values
newtype MapValues k v = MapValues (Map k v)

-- | Project a Map to its key-value entries
newtype MapEntries k v = MapEntries (Map k v)

instance projectMapKeys :: Ord k => Project (MapKeys k v) k where
  project (MapKeys m) = Array.fromFoldable (Map.keys m)

instance projectMapValues :: Ord k => Ord v => Project (MapValues k v) v where
  project (MapValues m) = nub $ map snd $ Map.toUnfoldable m

instance projectMapEntries :: Ord k => Project (MapEntries k v) (Tuple k v) where
  project (MapEntries m) = Map.toUnfoldable m
```

### Extended forEach

Add a projection-aware forEach:

```purescript
-- | forEach that works with any Projectable source
forEachP :: forall s t
          . Project s t
         => String           -- fold name
         -> ElementType      -- element type
         -> s                -- source (any Projectable)
         -> (t -> String)    -- key function
         -> (t -> Tree)      -- template
         -> Tree
forEachP name elemType source keyFn template =
  forEach name elemType (project source) keyFn template
```

### The Map Diagram — Clean Version

```purescript
mapDiagramTree :: forall k v. Ord k => Ord v => Show k => Show v
               => MapConfig -> Map k v -> Tree
mapDiagramTree cfg m =
  elem SVG [ ... ]
    [ -- Domain box with key nodes
      forEachP "keys" Group (MapKeys m) show \key ->
        elem Group [ ... ] [ keyNode key ]

    -- Codomain box with value nodes (auto-deduplicated by MapValues)
    , forEachP "values" Group (MapValues m) show \value ->
        elem Group [ ... ] [ valueNode value ]

    -- Arrows connecting keys to values
    , forEachP "arrows" Path (MapEntries m) (\(Tuple k _) -> show k) \(Tuple k v) ->
        elem Path [ arrowPath (keyPos k) (valuePos v) ] []
    ]
```

**The story**: One Map, three projections, one diagram. The finally tagless encoding means anyone can add new projections for their own types.

## Extension Examples

### Set Projection
```purescript
instance projectSet :: Ord a => Project (Set a) a where
  project = Array.fromFoldable
```

### Tree Projections
```purescript
newtype TreeNodes a = TreeNodes (Tree a)
newtype TreeLeaves a = TreeLeaves (Tree a)
newtype TreeEdges a = TreeEdges (Tree a)

instance projectTreeNodes :: Project (TreeNodes a) a where
  project (TreeNodes t) = flatten t

instance projectTreeLeaves :: Project (TreeLeaves a) a where
  project (TreeLeaves t) = leaves t

instance projectTreeEdges :: Project (TreeEdges a) { from :: a, to :: a } where
  project (TreeEdges t) = edges t
```

### Graph Projections
```purescript
newtype GraphNodes a = GraphNodes (Graph a)
newtype GraphEdges a = GraphEdges (Graph a)
```

## Implementation Plan

### Phase 1: Core Type Class
1. Add `Project` class to `PSD3.HATS`
2. Add `projectArray` instance
3. Add `forEachP` combinator
4. Verify existing code still works

### Phase 2: Map Projections
1. Add `MapKeys`, `MapValues`, `MapEntries` newtypes
2. Add their `Project` instances
3. Rewrite MapDiagram example using projections
4. Verify same visual output

### Phase 3: Documentation
1. Update Hylograph Guide to showcase the projection story
2. Add to library documentation
3. Consider moving MapDiagram to a library

## Open Questions

1. **Fundep direction**: `source -> target` means one canonical projection per newtype. Alternative: multi-param without fundep, but then need type annotations.

2. **Context preservation**: Current `WithContext` enumeration adds index/depth info. Should `Project` support this? Maybe:
   ```purescript
   class ProjectWithContext source target where
     projectCtx :: source -> Array { datum :: target, index :: Int, ... }
   ```

3. **Lazy enumeration**: Current design is strict (produces full Array). For large structures, might want streaming/lazy version.

## Success Criteria

- [ ] `forEachP` works with Array (backwards compatible)
- [ ] Map diagram uses three projections from same Map
- [ ] No visual regression in Map diagram output
- [ ] New projection can be added in user code (truly open)
- [ ] Story is clear: "one Map, three views, one diagram"
