# How To: Update Visualizations In Place (Select-and-Modify Pattern)

**Category**: howto
**Status**: active
**Created**: 2026-01-24

## Problem

You have a rendered visualization and want to update element attributes (colors, sizes, positions) without recreating the entire SVG. This is essential for:

- Theme switching (changing colors)
- Mode changes (highlighting subsets of data)
- Responsive updates
- Any scenario where full re-render is wasteful

## Solution: The Select-and-Modify Pattern

This is the idiomatic D3/PSD3 approach:

1. **Bind data to elements during creation** using `A.joinData`
2. **Select elements with bound data** using `selectAllWithData` or `selectChildInheriting`
3. **Update attributes** using `setAttrs` with data-dependent attribute functions

## Key Functions

### Creating Elements with Bound Data

Use `A.joinData` in your tree to create elements with `__data__`:

```purescript
buildTree :: Array MyData -> A.Tree MyData
buildTree items =
  A.named SVG "viz" [ width 800.0, height 600.0 ]
  `A.withChildren`
    [ A.named Group "items" []
      `A.withChildren`
        [ A.joinData "item-groups" "g" items $ \d ->
            A.elem Group [ class_ "item" ]
            `A.withChildren`
              [ A.elem Circle
                  [ Attr.attr "cx" (_.x) showNumD
                  , Attr.attr "cy" (_.y) showNumD
                  , Attr.attr "r" (_.radius) showNumD
                  ]
              ]
        ]
    ]
```

The group elements (`<g class="item">`) will have `__data__` bound. Child circles do NOT automatically get data.

### Selecting Elements with Data

**For elements with their own `__data__`:**
```purescript
groups <- selectAllWithData ".item" container
```

**For child elements that need parent's data:**
```purescript
groups <- selectAllWithData ".item" container
circles <- selectChildInheriting "circle" groups
```

`selectChildInheriting` copies the parent's `__data__` to each child element.

### Updating Attributes

```purescript
updateColors :: Theme -> Effect Unit
updateColors theme = void $ runD3 do
  container <- select "#viz-container"

  -- Select groups with data
  groups <- selectAllWithData ".item" container

  -- Select circles, inheriting parent's data
  circles <- selectChildInheriting "circle" groups

  -- Update with data-dependent color function
  _ <- setAttrs [ Attr.attr "fill" (colorFn theme) idD ] circles

  pure unit

colorFn :: Theme -> MyData -> String
colorFn theme d = case theme of
  Light -> if d.active then "#333" else "#999"
  Dark -> if d.active then "#fff" else "#666"
```

## Complete Example: Theme-Aware Treemap

```purescript
-- Data type with all info needed for rendering
newtype PackageData = PackageData
  { name :: String
  , topoLayer :: Int
  , inProject :: Boolean
  , x :: Number, y :: Number
  , width :: Number, height :: Number
  }

-- Build tree with data binding
buildTreemap :: Array PackageData -> A.Tree PackageData
buildTreemap packages =
  A.named SVG "treemap" [...]
  `A.withChildren`
    [ A.joinData "packages" "g" packages $ \d ->
        A.elem Group [ class_ "package" ]
        `A.withChildren`
          [ A.elem Rect [...]
          , A.elem Circle [...]
          ]
    ]

-- Update colors in place
updateTheme :: ViewTheme -> Effect Unit
updateTheme theme = void $ runD3 do
  container <- select "#treemap-container"

  -- Groups have __data__ from joinData
  groups <- selectAllWithData ".package" container

  -- Circles inherit parent's data
  circles <- selectChildInheriting "circle" groups
  _ <- setAttrs [ Attr.attr "fill" (themeColor theme) idD ] circles

  -- Rects also inherit parent's data
  rects <- selectChildInheriting "rect" groups
  _ <- setAttrs [ Attr.attrStatic "fill" (rectFill theme) ] rects

  pure unit
```

## Key Points

1. **Data flows through groups**: Use `A.joinData` on container groups, not leaf elements
2. **Children don't auto-inherit**: Use `selectChildInheriting` to propagate data
3. **Attribute functions access data**: `Attr.attr "fill" (_.color) idD` extracts from bound data
4. **No FFI needed**: This pattern uses pure PSD3, no JavaScript escape hatches

## When to Use This vs Full Re-render

**Use select-and-modify when:**
- Only visual attributes change (colors, opacity, stroke)
- Data structure is unchanged
- Performance matters (many elements)

**Use full re-render when:**
- Data changes (elements added/removed)
- Layout needs recomputation
- Structural changes to the visualization

## Related

- `A.joinData` - Bind data to elements during tree construction
- `selectAllWithData` - Select elements that have `__data__` bound
- `selectChildInheriting` - Select children, copying parent's data
- `setAttrs` - Update attributes on bound selections
