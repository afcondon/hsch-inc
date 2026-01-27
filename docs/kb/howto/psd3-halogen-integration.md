# PSD3 + Halogen Integration Patterns

**Status**: active
**Tags**: PSD3, Halogen, integration, SVG, DOM ownership

## The Ownership Problem

When using PSD3 with Halogen, there's a potential conflict over DOM ownership. Both libraries want to manage the DOM, and mixing them incorrectly causes rendering failures.

**Symptom**: SVG elements exist in the DOM with correct attributes, but nothing is visible. The container group shows `0 x N` dimensions in the inspector.

## The Solution: Let PSD3 Own the SVG

**Pattern**: Halogen renders an empty container div; PSD3 creates and owns the entire SVG structure.

### Wrong Approach (Don't Do This)

```purescript
-- Halogen render function creates SVG structure
render state =
  HH.div_
    [ HH.element (HH.ElemName "svg")
        [ HP.id "my-svg" ]
        [ HH.element (HH.ElemName "g")
            [ HP.class_ (HH.ClassName "nodes") ]
            []
        ]
    ]

-- Then PSD3 tries to render into it
liftEffect do
  void $ runD3 do
    container <- select "#my-svg .nodes"  -- This causes problems!
    renderTree container myVizTree
```

### Correct Approach

```purescript
-- Halogen render function creates ONLY an empty container div
render state =
  HH.div_
    [ HH.element (HH.ElemName "div")
        [ HP.id "viz-container" ]
        []  -- Empty! PSD3 will create everything inside
    ]

-- PSD3 creates the entire SVG structure
renderSVGContainer :: String -> Effect Unit
renderSVGContainer containerSelector = do
  void $ runD3 do
    container <- select containerSelector
    let svgTree =
          A.named SVG "my-svg"
            [ Attr.attrStatic "id" "my-svg"  -- DOM id for selectors
            , Attr.attrStatic "viewBox" "0 0 800 600"
            , Attr.attrStatic "width" "100%"
            ]
          `A.withChildren`
            [ A.named Group "nodes"
                [ Attr.attrStatic "id" "viz-nodes"  -- DOM id for selectors
                , Attr.attrStatic "class" "nodes"
                ]
            ]
    renderTree container svgTree

-- Later, render into the PSD3-created structure
liftEffect do
  void $ runD3 do
    nodesGroup <- select "#viz-nodes"  -- Select by DOM id
    renderTree nodesGroup myDataJoinTree
```

## Key Insight: `A.named` vs DOM `id`

`A.named` sets PSD3's **internal** name for the selection tracking system. It does NOT set the DOM `id` attribute.

For CSS selectors like `#viz-nodes` to work, you must **also** set the DOM `id` attribute:

```purescript
-- WRONG: Only sets PSD3 internal name, no DOM id
A.named Group "viz-nodes" [ Attr.attrStatic "class" "nodes" ]

-- CORRECT: Sets both PSD3 name AND DOM id
A.named Group "viz-nodes"
  [ Attr.attrStatic "id" "viz-nodes"  -- This is needed for "#viz-nodes" selector
  , Attr.attrStatic "class" "nodes"
  ]
```

## Initialization Sequence

In your Halogen component:

```purescript
handleAction = case _ of
  Initialize -> do
    -- Fetch data, etc.
    ...

  DataLoaded data -> do
    H.modify_ _ { loading = false }
    -- Start visualization - no delay needed
    liftEffect $ startVisualization data

startVisualization :: Data -> Effect Unit
startVisualization data = do
  -- 1. First create the SVG container (PSD3 owns it)
  renderSVGContainer "#viz-container"

  -- 2. Then run simulation/render into it
  { handle, events } <- runSimulation
    { container: "#viz-nodes"  -- Select the group we created
    , ...
    }
```

## Reference Implementation

See `site/website/src/Component/ForcePlayground.purs` for a complete working example that follows this pattern.

## Summary

1. **Halogen**: Render only an empty container `div`
2. **PSD3**: Create the entire SVG structure with `renderTree`
3. **IDs**: Always set both `A.named` AND `Attr.attrStatic "id"` for elements you'll select later
4. **Selectors**: Use `#element-id` to select PSD3-created elements
