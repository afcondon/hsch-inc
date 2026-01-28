---
title: "Touch and Multi-Touch Support for iPad"
category: research
status: active
tags: [touch, ipad, gestures, interaction, accessibility]
created: 2026-01-27
summary: Research into making Hylograph demos touch-friendly on iPad, including hover alternatives and multi-touch interaction possibilities.
---

# Touch and Multi-Touch Support for iPad

## Overview

The current Hylograph demos rely heavily on hover interactions (tooltips, highlighting, previews) that don't translate to touch devices. Rather than building native mobile apps, the better investment is making the web demos work well on iPad with touch - and potentially discovering new interaction patterns enabled by multi-touch.

## The Problem

### Hover Doesn't Exist on Touch

Desktop visualizations commonly use hover for:
- **Tooltips**: Show details on hover
- **Highlighting**: Emphasize related elements on hover
- **Previews**: Show expanded view on hover
- **Cursor feedback**: Change cursor to indicate interactivity
- **Transient state**: Hover is inherently temporary, no commitment

On touch devices, there's no hover. The first touch is a tap (click equivalent). This breaks many interaction patterns.

### Current Hover Usage in Demos

| Demo | Hover Behavior | Impact on Touch |
|------|----------------|-----------------|
| Force graphs | Highlight connected nodes, show tooltip | Broken - no feedback before tap |
| Code Explorer | Show file details, highlight dependencies | Broken |
| Treemaps | Show cell details | Broken |
| Sankey | Highlight flow paths | Broken |
| Any chart | Tooltips on data points | Broken |

## Hover → Touch Mapping

### Pattern 1: Tap to Toggle

Hover state becomes a toggled selection state.

| Hover | Touch |
|-------|-------|
| Hover to show tooltip | Tap to show tooltip |
| Move away to dismiss | Tap elsewhere to dismiss |
| Hover to highlight | Tap to select (highlight persists) |
| Move away to unhighlight | Tap elsewhere or tap same element to deselect |

**Pros**: Simple, predictable
**Cons**: Requires explicit dismissal, can't preview multiple items quickly

### Pattern 2: Long-Press for Preview

Reserve tap for primary action, use long-press for hover-equivalent.

| Hover | Touch |
|-------|-------|
| Hover for tooltip | Long-press to show tooltip (dismiss on release) |
| Hover for preview | Long-press for preview |
| Click for action | Tap for action |

**Pros**: Preserves tap for primary action, hover-like transience
**Cons**: Discoverability - users may not know to long-press

### Pattern 3: Tap-and-Hold Drag

For items where hover reveals options:

| Hover | Touch |
|-------|-------|
| Hover to reveal drag handle | Long-press initiates drag mode |
| Hover to reveal context menu | Long-press shows context menu |

**Pros**: Familiar iOS pattern
**Cons**: Conflicts with standard long-press behaviors

### Pattern 4: Visual Affordances Replace Cursor

Since we can't change the cursor, make interactivity visible:

| Desktop | Touch |
|---------|-------|
| Cursor: pointer | Subtle shadow, border, or scale on interactive elements |
| Cursor: grab | Visual handle indicators |
| Cursor: crosshair | Target/crosshair overlay |

### Pattern 5: Mode Switching

Explicit modes for different interaction types:

- **Explore mode**: Tap for tooltip, pan to move
- **Select mode**: Tap to select, shift-tap for multi-select
- **Edit mode**: Tap to modify, drag to move

**Pros**: Clear mental model
**Cons**: Mode confusion, extra UI chrome

## Multi-Touch Possibilities

### Standard Gestures (Expected)

These should "just work" or be straightforward to implement:

| Gesture | Action |
|---------|--------|
| Single-finger drag | Pan the view |
| Two-finger pinch | Zoom in/out |
| Two-finger drag | Pan (alternative) |
| Double-tap | Zoom to fit / reset view |

### Novel Gestures for Network Graphs

These could differentiate Hylograph's touch experience:

#### Spread Gesture on Cluster
- **Gesture**: Place two fingers on a dense area, spread apart
- **Action**: Apply repulsive force to nodes under fingers, push them apart
- **Use case**: Untangle a messy cluster to see individual nodes

#### Pinch Nodes Together
- **Gesture**: Place fingers on distant nodes, pinch together
- **Action**: Apply attractive force, bring nodes closer
- **Use case**: Manually cluster related nodes

#### Multi-Finger Selection
- **Gesture**: Tap multiple nodes simultaneously with different fingers
- **Action**: Add all touched nodes to selection
- **Use case**: Quickly select a set of related nodes

#### Long-Press Drag
- **Gesture**: Long-press a node, then drag
- **Action**: Move the node while force simulation reacts in real-time
- **Use case**: Manual layout adjustment, see how graph responds

#### Two-Finger Rotate
- **Gesture**: Two fingers, rotate around center point
- **Action**: Rotate entire graph (or selected subgraph)
- **Use case**: Reorient for better viewing angle

#### Three-Finger Layout Switch
- **Gesture**: Three-finger swipe left/right
- **Action**: Transition to different layout algorithm (force → radial → tree)
- **Use case**: Quick comparison of different views

#### Pinch on Single Node
- **Gesture**: Pinch on a single node
- **Action**: Collapse/expand its neighborhood (hide/show connected nodes)
- **Use case**: Focus on local structure, reduce clutter

### Gesture Vocabulary Summary

| Fingers | Gesture | Action |
|---------|---------|--------|
| 1 | Tap | Select / show tooltip |
| 1 | Long-press | Initiate drag / context menu |
| 1 | Drag | Pan view |
| 2 | Pinch | Zoom |
| 2 | Spread on area | Repel nodes |
| 2 | Pinch on nodes | Attract nodes |
| 2 | Rotate | Rotate graph |
| 3 | Swipe | Switch layout |

## Technical Considerations

### iOS Safari Gesture Conflicts

Some gestures are reserved by iOS:

| Gesture | iOS Behavior | Conflict Risk |
|---------|--------------|---------------|
| Two-finger pinch | Zoom (if not handled) | Low - can override in web |
| Two-finger double-tap | Zoom out | Medium |
| Three-finger pinch | Copy/paste UI | High - avoid |
| Four-finger swipe | App switching | Reserved - cannot override |
| Swipe from edge | Back navigation / app switcher | Reserved |

**Safe to use**: 1-2 finger gestures in the content area
**Avoid**: 3+ finger gestures, edge swipes

### Touch Event APIs

```javascript
// Pointer Events (recommended - unified mouse/touch/pen)
element.addEventListener('pointerdown', handlePointerDown);
element.addEventListener('pointermove', handlePointerMove);
element.addEventListener('pointerup', handlePointerUp);

// Touch Events (for multi-touch specifics)
element.addEventListener('touchstart', handleTouchStart);
element.addEventListener('touchmove', handleTouchMove);
element.addEventListener('touchend', handleTouchEnd);

// Gesture Events (Safari-specific, limited)
element.addEventListener('gesturestart', handleGestureStart);
element.addEventListener('gesturechange', handleGestureChange);
element.addEventListener('gestureend', handleGestureEnd);
```

**Recommendation**: Use Pointer Events as primary, Touch Events for multi-touch finger tracking.

### D3 Touch Support

D3's drag and zoom behaviors have touch support, but it's historically buggy:

```javascript
// D3 zoom with touch
d3.zoom()
  .touchable(true)  // Enable touch
  .on("zoom", handleZoom);

// D3 drag with touch
d3.drag()
  .touchable(true)
  .on("drag", handleDrag);
```

**Known issues**:
- Drag and zoom can conflict on same element
- Multi-touch beyond pinch-zoom is not well supported
- Touch event coordinates sometimes off on high-DPI displays

**PSD3 opportunity**: Build better touch handling into the selection/behavior layer.

### PureScript Touch Handling

Current FFI approach for events could be extended:

```purescript
-- Existing pattern
onClick :: forall d. (d -> Effect Unit) -> Behavior d
onClick handler = ...

-- New touch-specific behaviors
onTap :: forall d. (d -> Effect Unit) -> Behavior d
onLongPress :: forall d. (d -> Effect Unit) -> Behavior d
onPinch :: forall d. ({ scale :: Number, center :: Point } -> Effect Unit) -> Behavior d
onMultiTouch :: forall d. (Array Touch -> Effect Unit) -> Behavior d
```

Could also provide gesture recognizers:

```purescript
data Gesture
  = Tap Point
  | LongPress Point Duration
  | Pinch { scale :: Number, center :: Point }
  | Spread { points :: Tuple Point Point, delta :: Number }
  | Rotate { center :: Point, angle :: Number }

onGesture :: forall d. (Gesture -> Effect Unit) -> Behavior d
```

## Implementation Approach

### Phase 1: Baseline Touch Support

1. Audit current hover usage across all demos
2. Implement tap-to-toggle for tooltips
3. Ensure pinch-zoom and pan work on all visualizations
4. Add visual affordances for interactive elements
5. Test on actual iPad

### Phase 2: Long-Press and Selection

1. Implement long-press detection
2. Add long-press for context menus / detail views
3. Implement multi-select via successive taps
4. Add clear selection affordance (X button or tap background)

### Phase 3: Multi-Touch Experiments

1. Implement spread gesture for force graphs
2. Implement pinch-to-cluster for force graphs
3. User testing - are these discoverable? useful?
4. Decide which gestures to keep

### Phase 4: Library-Level Support

1. Extract touch handling into psd3-selection
2. Create gesture recognizer module
3. Document touch behavior API
4. Ensure all demos use library-level touch support

## Open Questions

1. **Discoverability**: How do users learn about long-press and multi-touch gestures? Onboarding? Hints?

2. **Consistency**: Should all demos have identical touch behavior, or can they differ based on visualization type?

3. **Fallback**: What happens on devices that support touch but not multi-touch (older devices, accessibility settings)?

4. **Testing**: How do we test touch interactions in development? (Simulator? Actual devices?)

5. **Performance**: Multi-touch with force simulation - can we maintain 60fps while tracking multiple fingers and running physics?

## References

- [Pointer Events W3C Spec](https://www.w3.org/TR/pointerevents/)
- [Touch Events W3C Spec](https://www.w3.org/TR/touch-events/)
- [D3 Zoom Touch Support](https://github.com/d3/d3-zoom#zoom_touchable)
- [Apple Human Interface Guidelines - Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures)
- [Hammer.js](https://hammerjs.github.io/) - Popular gesture recognition library

---

## Status / Next Steps

- [ ] Audit hover usage in current demos
- [ ] Prototype tap-to-toggle tooltip on one demo
- [ ] Test on actual iPad
- [ ] Evaluate multi-touch gesture feasibility
- [ ] Decide on library-level vs demo-level implementation
