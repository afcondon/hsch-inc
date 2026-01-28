# HATS-Halogen Integration Pattern

**Status**: active
**Category**: howto
**Created**: 2026-01-27
**Tags**: hats, halogen, integration, behaviors

## Overview

This guide covers integrating HATS rendering with Halogen components, enabling HATS behaviors (mouse events, etc.) to communicate back to Halogen state for coordinated interactions.

## The Pattern

```
Halogen Component
    │
    ├── render: Returns empty container divs with IDs
    │           (HATS renders into these imperatively)
    │
    ├── state.hatsListener: Stores subscription listener
    │
    └── handleAction:
            ├── Initialize: Create subscription, store listener
            ├── DataLoaded: Call renderHATSLayouts
            └── HoverNode/UnhoverNode: Update state, re-render HATS
```

### 1. Create Subscription in Initialize

```purescript
import Halogen.Subscription as HS

Initialize -> do
  { emitter, listener } <- liftEffect HS.create
  H.modify_ _ { hatsListener = Just listener }
  void $ H.subscribe emitter
```

### 2. Pass Listener to HATS Rendering

```purescript
type HoverCallbacks =
  { onHover :: String -> Effect Unit
  , onLeave :: Effect Unit
  }

renderHATSLayouts :: State -> HS.Listener Action -> Effect Unit
renderHATSLayouts state listener = do
  let callbacks =
        { onHover: \path -> HS.notify listener (HoverNode path)
        , onLeave: HS.notify listener UnhoverNode
        }
  HATS.renderTreeHorizontal "#container-id" hovered callbacks treeData
```

### 3. Attach Behaviors in HATS Tree

```purescript
import PSD3.Internal.Behavior.Types (Behavior(..))
import PSD3.HATS (withBehaviors)

HATS.forEach "nodes" Group nodes _.path \node ->
  let nodeTree = HATS.elem Circle [...] []
  in HATS.withBehaviors
       [ MouseEnter (\d -> callbacks.onHover d.path)
       , MouseLeave (\_ -> callbacks.onLeave)
       ]
       nodeTree
```

## Critical Gotcha: StaticAttr vs DataAttr

**Problem**: Elements outside `forEach`/Fold use `applyAttrsStatic`, which only processes `StaticAttr`. Using `attr $ text "..."` creates `DataAttr` which is **silently ignored**.

**Symptom**: Attributes don't appear on elements (e.g., Path elements missing `d` attribute, so links invisible).

**Wrong** (for static elements):
```purescript
HATS.elem Path
  [ path $ text pathD        -- Creates DataAttr, IGNORED!
  , fill $ text "none"       -- Creates DataAttr, IGNORED!
  ]
  []
```

**Correct** (for static elements):
```purescript
HATS.elem Path
  [ staticStr "d" pathD      -- Creates StaticAttr, works
  , staticStr "fill" "none"  -- Creates StaticAttr, works
  ]
  []
```

**Rule**:
- Inside `forEach`/Fold templates: Use `attr`, `fill`, `r`, etc. (data-driven)
- Outside Fold (static structure): Use `staticStr` for all attributes

## When to Use Each

| Context | Attribute Style | Example |
|---------|----------------|---------|
| SVG container | `staticStr` | `staticStr "class" "my-chart"` |
| Group wrappers | `staticStr` | `staticStr "transform" "translate(50,50)"` |
| Static children (links) | `staticStr` | `staticStr "d" pathD` |
| Inside forEach template | `attr`/sugar | `r $ num 5.0`, `fill $ text color` |

## File Structure

```
Component.purs          -- Halogen component with subscriptions
RenderHATS.purs         -- HATS tree builders + render functions
  ├── HoverCallbacks type
  ├── renderLayoutX functions (call interpreter)
  └── buildLayoutX functions (return HATS.Tree)
```

## See Also

- `PSD3.HATS` - Core HATS module with `withBehaviors`
- `PSD3.HATS.InterpreterTick` - The interpreter that processes HATS trees
- `Gallery.ComponentHATS` - Working example of this pattern
