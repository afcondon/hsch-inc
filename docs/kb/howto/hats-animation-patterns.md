# HATS Animation Patterns

**Status**: Active
**Created**: 2026-01-31
**Category**: howto
**Tags**: hats, animation, transitions, interpolation

## Overview

This guide covers when to use HATS tick-driven transitions vs manual animation, and how to handle cases where HATS interpolation isn't sufficient.

## HATS Tick System: What It Can and Can't Do

The HATS tick system (`rerenderWithTick`, `GUPSpec` transitions) interpolates attribute values over time. However, it has a critical limitation:

| Attribute Type | HATS Tick Can Interpolate? | Example |
|----------------|---------------------------|---------|
| Numbers | ✓ Yes | `cx`, `cy`, `r`, `opacity`, `strokeWidth` |
| Colors | ✓ Yes | `fill`, `stroke` (via color interpolation) |
| Strings | ✗ No | `d` (path), `transform`, `textContent` |

**Key insight**: HATS tick interpolates between numeric values. It cannot interpolate SVG path strings like `"M0,0 C50,100 100,100 150,0"`.

## Pattern 1: Pure HATS Tick (Simple Cases)

When all animated attributes are numeric, use HATS tick directly:

```purescript
-- Build tree with target positions
let tree = buildCircleTree { x: targetX, y: targetY, opacity: 1.0 }

-- Rerender triggers interpolation from current to target
rerenderWithTick selector tree
```

The `GUPSpec` defines enter/update/exit transitions:

```purescript
gupSpec :: GUPSpec CircleData
gupSpec =
  { enter: Just
      { attrs: [ staticNum "opacity" 0.0 ]  -- Start invisible
      , transition: Just $ transitionWith { duration: 500ms, easing: CubicOut }
      }
  , update: Just
      { attrs: []  -- Template has target positions
      , transition: Just $ transitionWith { duration: 750ms, easing: CubicInOut }
      }
  , exit: Just
      { attrs: [ staticNum "opacity" 0.0 ]  -- Fade out
      , transition: Just $ transitionWith { duration: 300ms, easing: CubicIn }
      }
  }
```

**Use this for**: Circles moving, opacity changes, radius changes, color transitions.

## Pattern 2: Hybrid (HATS Structure + Manual Animation)

When you need to animate path strings (links, curves, complex shapes), HATS tick won't work. Use this hybrid approach:

1. **HATS for initial render** - Creates the DOM structure
2. **Manual `requestAnimationFrame_` loop** - Handles animation
3. **Recalculate paths each frame** - From interpolated positions

### Example: Tree/Cluster Layout Animation

The tree-to-cluster animation interpolates node positions, but link paths must be recalculated:

```purescript
-- Initial render with HATS
draw :: Tree TreeModel -> String -> LayoutType -> Effect VizState
draw dataTree selector layout = do
  -- Use HATS to create SVG structure with groups for links and nodes
  let containerTree = HATS.elem SVG [...]
        [ HATS.elem Group [ F.class_ "links" ] []
        , HATS.elem Group [ F.class_ "nodes" ] []
        ]
  _ <- HATS.rerender selector containerTree

  -- Render links and nodes with data attributes for lookup
  _ <- HATS.rerender (selector <> " .links") linksTree
  _ <- HATS.rerender (selector <> " .nodes") nodesTree

  pure vizState
```

```purescript
-- Animation update with manual requestAnimationFrame
update :: Tree TreeModel -> String -> Number -> Number -> LayoutType -> Effect Unit
update dataTree selector width height newLayout = do
  -- Read current positions from DOM
  oldPositions <- readNodePositionsFromDOM selector

  -- Compute new positions from layout algorithm
  let newPositions = computeLayout newLayout dataTree

  -- Animation loop
  startTimeRef <- Ref.new Nothing
  let duration = 1500.0

  let animate = do
        now <- getTimestamp
        startTime <- readOrInit startTimeRef now
        let progress = min 1.0 ((now - startTime) / duration)

        -- Interpolate positions with easing
        let currentPos = interpolatePositions oldPositions newPositions (easeInOutCubic progress)

        -- Update node positions in DOM
        updateNodesInDOM selector currentPos

        -- CRITICAL: Recalculate link paths from interpolated positions
        let currentLinks = makeLinksFromPositions linkSpecs currentPos
        updateLinksInDOM selector currentLinks

        when (progress < 1.0) $
          void $ requestAnimationFrame_ animate

  void $ requestAnimationFrame_ animate
```

### Why This Works

1. **Nodes**: Positions are numeric (`cx`, `cy`) - could use HATS tick, but we need coordinated animation
2. **Links**: Path `d` attribute is a string (`"M... C..."`) - must recalculate each frame
3. **Coordination**: Links must follow node positions exactly, so we animate both together

### FFI Required

```javascript
// AnimatedTreeCluster.js
export const requestAnimationFrame_ = (callback) => () => {
  return window.requestAnimationFrame(() => callback());
};

export const setAttributeNS_ = (attrName) => (value) => (element) => () => {
  element.setAttribute(attrName, value);
};

export const getTimestamp = () => performance.now();
```

## Pattern 3: When to Use Which

| Scenario | Pattern | Reason |
|----------|---------|--------|
| Circles/rects changing position | HATS tick | All numeric attributes |
| Opacity/color transitions | HATS tick | Interpolatable values |
| GUP enter/exit animations | HATS tick | Standard lifecycle |
| Path morphing (lines, curves) | Hybrid | Path strings can't interpolate |
| Tree/graph layout transitions | Hybrid | Links follow node positions |
| Force simulation | Neither | D3/WASM controls positions |

## Common Mistakes

### Mistake 1: Using HATS GUPSpec for Paths

```purescript
-- WON'T ANIMATE SMOOTHLY - path strings don't interpolate!
linkGupSpec =
  { update: Just
      { attrs: []  -- Template has new path
      , transition: Just $ transitionWith { duration: 750ms }
      }
  ...
  }
```

This will snap between paths, not smoothly morph.

### Mistake 2: Forgetting Data Attributes

When using manual animation, you need to find elements in the DOM:

```purescript
-- Add data attributes during HATS render
HATS.elem Circle
  [ F.attr "data-node" node.name  -- For lookup during animation
  , F.cx node.x
  , F.cy node.y
  ]
```

Then query them during animation:

```purescript
nodeList <- querySelectorAll (QuerySelector $ selector <> " .nodes circle") parentNode
-- Use data-node attribute to match with position data
```

### Mistake 3: Not Storing State for Animation

The `draw` function should return state needed for `update`:

```purescript
type VizState =
  { dataTree :: Tree TreeModel
  , chartWidth :: Number
  , chartHeight :: Number
  , linkSpecs :: Array LinkSpec  -- Link structure for path recalculation
  , selector :: String           -- Where to find elements
  }
```

## Reference Implementation

See `site/website/src/Viz/TreeAPI/AnimatedTreeCluster.purs` for a complete example of the hybrid pattern with tree/cluster layout animation.

## Related Documents

- `docs/kb/architecture/unified-transition-model.md` - Broader transition architecture
- `docs/kb/howto/hats-halogen-integration.md` - HATS + Halogen patterns
- `Hylograph.HATS.Transitions` - HATS tick system internals
