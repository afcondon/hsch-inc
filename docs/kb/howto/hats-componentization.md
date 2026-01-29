# HATS Componentization Patterns

## The Chrome/Content Split

A visualization naturally divides into two parts:

1. **Static Chrome** - The frame that doesn't change with data
   - Backgrounds, borders, boxes
   - Labels, titles, legends (when static)
   - Marker definitions (`<defs>`)
   - Axes lines (but not ticks - see below)

2. **Data-Driven Content** - Elements that repeat or vary with data
   - The actual data points, bars, nodes
   - Axis ticks (they enumerate over tick values)
   - Legend items (when generated from data)

## Why This Matters

In the MetaHATS structural view:

```
SVG
├── Rect (background)      ← Static: appears once
├── Rect (domain-box)      ← Static: appears once
├── Text (domain-label)    ← Static: appears once
├── ...more chrome...
├── Fold "arrows" ×5       ← Data-driven: deck-of-cards
├── Fold "keys" ×5         ← Data-driven: deck-of-cards
└── Fold "values" ×3       ← Data-driven: deck-of-cards
```

Static elements appear as individual `Elem` nodes.
Data-driven elements appear as `Fold` nodes with repetition counts.

This **structural distinction is meaningful** - it shows what varies with data vs what's fixed.

## The Pattern

```purescript
-- Extract static chrome as a reusable function
functionDiagramChrome :: Config -> Array Tree
functionDiagramChrome cfg =
  [ elem Rect [ staticStr "data-label" "background", ... ] []
  , elem Rect [ staticStr "data-label" "domain-box", ... ] []
  , elem Text [ staticStr "data-label" "domain-label", ... ] []
  , ...
  ]

-- Main visualization composes chrome + data-driven content
mapDiagramTree :: Config -> Map k v -> Tree
mapDiagramTree cfg m =
  elem SVG [...]
    ( functionDiagramChrome cfg <>
      [ forEachP "arrows" ...
      , forEachP "keys" ...
      , forEachP "values" ...
      ]
    )
```

## Benefits

1. **Clarity**: The structure of your visualization is explicit
2. **Reuse**: Chrome can be shared across similar visualizations
3. **MetaHATS**: The structural view correctly shows chrome as static, content as repeated
4. **Testing**: Chrome can be tested/styled independently

## Labeling for MetaHATS

Add `data-label` attributes to static elements for comprehension:

```purescript
elem Rect
  [ staticStr "data-label" "background"  -- Shows as "Rect: background"
  , staticNum "width" cfg.width
  , ...
  ] []
```

The MetaHATS interpreter extracts `data-label` (preferred) or `class` attributes and displays them beneath the element type.

## Map vs forEach

**Key insight**: `map` expands at definition time, `forEach` creates a Fold.

```purescript
-- Using map: expands to 10 individual Elem nodes
tickElements = map renderTick ticks  -- MetaHATS shows 10 Rects

-- Using forEach: creates one Fold node
ticksFold = forEach "ticks" ticks renderTick  -- MetaHATS shows "Fold ×10"
```

Use `forEach` for anything that conceptually represents "this pattern repeated N times."

## When to Componentize

Componentize chrome when:
- The same frame pattern appears in multiple visualizations
- You want MetaHATS to show a clean structural view
- The chrome is complex enough to benefit from separation

Don't over-componentize:
- Simple visualizations may not need this split
- If the "chrome" is just one or two elements, inline is fine
