# How to Implement Brushing in HATS

**Status**: Active
**Created**: 2026-01-28
**Tags**: hats, brushing, coordinated-interaction, splom

## Overview

This guide explains how to implement brushable visualizations using HATS (Hylomorphic Abstract Tree Syntax). It covers the coordinated interaction system that enables cross-view linked brushing, as demonstrated in the Palmer Penguins SPLOM example.

## Key Concepts

### Coordinated Interaction System

HATS provides a unified interaction framework with three components:

1. **Points** register with `onCoordinatedInteraction` - they declare their identity, how to respond to triggers, and optionally their position
2. **Brush** registers with `onBrush` - it captures pointer events and emits brush regions
3. **The FFI** coordinates between them - collecting selected IDs and applying CSS classes

### Identity vs Position

For cross-view brushing (like SPLOM), you need two different identifiers:

- **GUP Key**: Cell-specific, for DOM diffing (e.g., `"cell-0-1-pt-42"`)
- **Semantic ID**: Shared across views, for selection linking (e.g., `"penguin-42"`)

```purescript
type PointData =
  { x :: Number
  , y :: Number
  , key :: String      -- Cell-specific for GUP: "cell-0-1-pt-42"
  , penguinId :: String -- Shared for linking: "penguin-42"
  , ...
  }
```

## Implementation

### Step 1: Register Points with Coordinated Interaction

Each point needs to declare:
- `identify`: The semantic ID for cross-view linking
- `respond`: How to respond to interaction triggers
- `position`: Screen coordinates for brush hit-testing
- `group`: Scope for coordination (points in same group interact)

```purescript
import PSD3.HATS (forEach, elem, withBehaviors, onCoordinatedInteraction)
import PSD3.Interaction.Coordinated (InteractionTrigger(..), InteractionState(..), BoundingBox, pointInBox)

forEach "points" Circle points _.key \pt ->
  withBehaviors
    [ onCoordinatedInteraction
        { identify: pt.semanticId  -- Shared across views
        , respond: respondToInteraction pt
        , position: Just { x: pt.x, y: pt.y }
        , group: Just "my-viz"
        }
    ] $
  elem Circle
    [ thunkedNum "cx" pt.x
    , thunkedNum "cy" pt.y
    , staticStr "pointer-events" "none"  -- Let brush receive events
    , ...
    ] []
```

### Step 2: Define the Respond Function

The respond function determines how a point reacts to different triggers:

```purescript
respondToInteraction :: PointData -> InteractionTrigger -> InteractionState
respondToInteraction pt = case _ of
  BrushTrigger box ->
    -- Note: Position checking is handled by the FFI for semantic selection
    -- This fallback is for single-view brushing
    if pointInBox { x: pt.x, y: pt.y } box
      then Selected
      else Dimmed
  HoverTrigger hoveredId ->
    if pt.semanticId == hoveredId then Primary else Neutral
  ClearTrigger ->
    Neutral
  SelectionTrigger ids ->
    if Set.member pt.semanticId ids then Selected else Dimmed
  FocusTrigger _ ->
    Neutral
```

### Step 3: Add the Brush Overlay

The brush must be a sibling of the points, positioned BEFORE the `forEach` to avoid index collision:

```purescript
buildCellContent :: ... -> Array Tree
buildCellContent ... =
  [ -- Grid lines first
    elem Group [ staticStr "class" "grid" ] [...]

  , -- Brush BEFORE forEach (critical for index stability)
    withBehaviors
      [ onBrush
          { extent: { x0: padding, y0: padding
                    , x1: cellSize - padding, y1: cellSize - padding }
          , group: Just "my-viz"
          }
      ] $
    elem Group
      [ staticStr "class" "brush" ]
      [ elem Rect
          [ staticStr "class" "brush-background"
          , staticNum "x" padding
          , staticNum "y" padding
          , staticNum "width" (cellSize - 2.0 * padding)
          , staticNum "height" (cellSize - 2.0 * padding)
          , staticStr "fill" "transparent"
          , staticStr "cursor" "crosshair"
          ] []
      ]

  , -- Points AFTER brush (forEach last to avoid index issues)
    forEach "points" Circle points _.key \pt -> ...
  ]
```

### Step 4: CSS Classes

The interaction system applies these CSS classes:

```css
/* Selected: inside brush or in selection set */
.coord-selected {
  fill-opacity: 1 !important;
  stroke: #333;
  stroke-width: 1;
}

/* Dimmed: outside brush or unrelated */
.coord-dimmed {
  fill-opacity: 0.15 !important;
}

/* Primary: directly hovered */
.coord-primary {
  fill-opacity: 1 !important;
  stroke: #333;
  stroke-width: 1.5;
}

/* Brush selection overlay */
.brush-selection-overlay {
  pointer-events: none;
}
```

## Architecture Notes

### Why Brush Before forEach?

HATS uses index-based child matching for GUP. When a `forEach` (Fold) expands to N elements, subsequent siblings have mismatched indices. Placing the brush before the Fold ensures its index remains stable.

### Semantic Selection Algorithm

The brush FFI implements a two-pass algorithm:

1. **Pass 1**: Find points in the source cell whose positions are inside the brush box. Collect their semantic IDs.

2. **Pass 2**: For ALL points in the group, check if their semantic ID is in the collected set. Apply `coord-selected` or `coord-dimmed` accordingly.

This enables cross-view linking where brushing in cell A highlights the same data points in cells B, C, D, etc.

### FFI Design: No ADT Construction

The FFI does NOT construct PureScript ADTs. Instead, it calls separate PureScript functions for each trigger type:

```purescript
-- In InterpreterTick.purs
respondToHover :: String -> Int
respondToHover hoveredId = interactionStateToInt (config.respond (HoverTrigger hoveredId))

respondToBrush :: BoundingBox -> Int
respondToBrush box = interactionStateToInt (config.respond (BrushTrigger box))

respondToClear :: Unit -> Int
respondToClear _ = interactionStateToInt (config.respond ClearTrigger)
```

This avoids depending on PureScript's internal ADT representation, which can change between compiler versions.

## Common Issues

### Brush Not Responding to Clicks

**Cause**: Circles are on top of the brush background, intercepting pointer events.

**Fix**: Add `pointer-events: none` to the circles:
```purescript
staticStr "pointer-events" "none"
```

### Brush Attached to Wrong Element

**Cause**: Index collision when Fold expands to multiple elements.

**Fix**: Place brush Group BEFORE the `forEach` in the children array.

### Selection Not Linking Across Views

**Cause**: Using cell-specific keys for identity.

**Fix**: Use a shared semantic ID (e.g., data row index) for `identify`, separate from the GUP key.

### Browser Lockup During Brushing

**Cause**: Too many elements being processed, or respond function making async calls.

**Fix**:
- Keep respond functions pure and fast
- Consider debouncing brush updates for large datasets
- Never make network calls from respond functions

## Example: Palmer Penguins SPLOM

See `/site/website/src/Viz/SPLOM/SPLOMHATS.purs` for a complete implementation showing:
- 4x4 scatterplot matrix
- ~340 penguins × 12 cells = ~4000 interactive points
- Cross-cell brushing with semantic selection
- Species coloring with coordinated highlighting

## Related

- `PSD3.HATS` - Core HATS module
- `PSD3.Interaction.Coordinated` - Interaction types and utilities
- `PSD3.HATS.InterpreterTick` - Tick-driven interpreter with behavior support
