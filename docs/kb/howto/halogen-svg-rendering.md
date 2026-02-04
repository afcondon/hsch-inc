---
title: SVG Rendering in Halogen
category: howto
status: active
tags: [halogen, svg, namespace, visualization]
created: 2026-02-04
summary: How to correctly render SVG elements in Halogen - avoiding the HTML namespace pitfall.
---

# SVG Rendering in Halogen

## The Problem

SVG elements must be created in the **SVG namespace**, not the HTML namespace. Using Halogen's generic HTML element constructor creates elements in the wrong namespace, resulting in invisible or broken SVG graphics.

### Symptoms

- SVG elements appear in the DOM but have `width: auto`, `height: auto` (computed)
- Circles, rectangles, paths don't render visually
- The DOM inspector shows the elements exist with correct attributes
- No console errors

### Root Cause

```purescript
-- WRONG: Creates an HTML element named "circle", not an SVG circle
HH.element (HH.ElemName "circle")
  [ HP.attr (HH.AttrName "r") "30"
  , HP.attr (HH.AttrName "fill") "#0066cc"
  ]
  []
```

The browser doesn't recognize `<circle>` as an HTML element, so it treats it as an unknown element with no rendering behavior.

## The Solution

Use `halogen-svg-elems` library which creates elements in the correct SVG namespace:

```purescript
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA

-- CORRECT: Creates a proper SVG circle element
SE.circle
  [ SA.r 30.0
  , SA.fill (SA.Named "#0066cc")
  ]
```

### Full Example

```purescript
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA
import Halogen.HTML as HH

renderSVG :: forall m. State -> H.ComponentHTML Action () m
renderSVG state =
  SE.svg
    [ SA.viewBox 0.0 0.0 600.0 400.0
    , SA.width 600.0
    , SA.height 400.0
    ]
    [ SE.g
        [ SA.transform [ SA.Translate 300.0 200.0 ] ]
        [ SE.circle
            [ SA.cx 0.0
            , SA.cy 0.0
            , SA.r 30.0
            , SA.fill (SA.Named "#0066cc")
            , SA.fillOpacity 0.8
            ]
        , SE.text
            [ SA.textAnchor SA.AnchorMiddle
            , SA.dominantBaseline SA.BaselineMiddle
            , SA.fill (SA.Named "white")
            ]
            [ HH.text "Label" ]
        ]
    ]
```

## Alternatives

### Option 1: halogen-svg-elems (Recommended for pure Halogen)

Best for static or simple SVG that updates via Halogen state.

```purescript
dependencies:
  - halogen-svg-elems
```

### Option 2: HATS (Recommended for complex visualizations)

For force-directed layouts, animations, or D3-style data binding, use HATS which handles SVG namespace correctly and provides the Chrome/Content pattern for efficient updates.

See: `kb/howto/hats-componentization.md`

### Option 3: Raw SVG string injection

Last resort - inject SVG as HTML string. Loses type safety.

## Quick Reference

| Task | Wrong | Right |
|------|-------|-------|
| Create SVG container | `HH.element (HH.ElemName "svg")` | `SE.svg` |
| Create circle | `HH.element (HH.ElemName "circle")` | `SE.circle` |
| Create group | `HH.element (HH.ElemName "g")` | `SE.g` |
| Set radius | `HP.attr (HH.AttrName "r") "30"` | `SA.r 30.0` |
| Set fill | `HP.attr (HH.AttrName "fill") "blue"` | `SA.fill (SA.Named "blue")` |
| Set transform | `HP.attr (HH.AttrName "transform") "..."` | `SA.transform [ SA.Translate x y ]` |

## Related Issues

### Base tag + hash routing conflict

Unrelated to SVG namespaces, but discovered in the same debugging session: the `<base href="/path/">` tag conflicts with `purescript-routing`'s `matches` function, causing scripts to re-execute repeatedly. Solution: use absolute paths for assets instead of relying on `<base>`.

## Status

Active - this is a common pitfall when starting SVG work in Halogen.
