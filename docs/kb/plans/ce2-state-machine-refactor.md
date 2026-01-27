---
title: "CE2 State Machine Refactoring Plan"
category: plan
status: active
tags: [ce2, code-explorer, state-machine, refactoring]
created: 2026-01-25
summary: Plan to clean up distributed/inconsistent state in SceneCoordinator.
---

# CE2 State Machine Refactoring Plan

## Problem Summary

The SceneCoordinator has accumulated state management issues:
1. Dual navigation systems (navStack + parentScene) that can diverge
2. Duplicated state between parent and child components
3. Implicit scene transitions hidden in scope changes
4. Mix of derived and stored state (theme)
5. View modes that persist inappropriately across contexts
6. Panel state not coordinated with navigation state

## Design Principles for Refactor

1. **Single source of truth** - One authoritative location for each piece of state
2. **Derived over stored** - Compute what you can, store only what you must
3. **Explicit transitions** - All state changes visible in one place
4. **Orthogonal dimensions** - Scope, view mode, and panel are independent axes

## Target State Model

```purescript
type State =
  { -- Navigation (single source of truth)
    scene :: Scene
  , previousScene :: Maybe Scene      -- For back, replaces navStack

  -- Data (immutable, from parent)
  , modelData :: Maybe LoadedModel
  , v2Data :: Maybe V2Data
  , packageSetData :: Maybe PackageSetData

  -- Orthogonal state dimensions
  , scope :: BeeswarmScope            -- Only meaningful for B, C scenes
  , viewMode :: ViewMode              -- Only meaningful for C, E scenes

  -- Panel (now tracked by coordinator)
  , panel :: PanelState

  -- Transition animation
  , capturedPositions :: Maybe (Array CapturedPosition)

  -- Hover (for coordinated highlighting)
  , hoveredPackage :: Maybe String
  }

-- Unified view mode (replaces moduleViewMode + packageViewMode)
data ViewMode
  = PrimaryView      -- Swarm for C, Treemap for E
  | MatrixView
  | ChordView

-- Panel state tracked by coordinator
type PanelState =
  { isOpen :: Boolean
  , content :: PanelContent
  }

-- Theme is DERIVED, not stored
themeForScene :: Scene -> ViewTheme
```

## Refactoring Steps

### Phase 1: Simplify Navigation (navStack → previousScene)

**Current problem**: `navStack` and `parentScene` can diverge.

**Solution**: Replace navStack with single `previousScene`. Back always goes to `parentScene`, but we remember where we came from for edge cases.

```purescript
-- BEFORE
NavigateBack -> do
  let parent = parentScene state.scene
  let newStack = fromMaybe [] (Array.init state.navStack)  -- What if these disagree?
  H.modify_ _ { scene = parent, navStack = newStack }

-- AFTER
NavigateBack -> do
  let parent = parentScene state.scene
  H.modify_ _ { scene = parent, previousScene = Just state.scene }
```

**Files**: `SceneCoordinator.purs`

**Risk**: Low - simplification

### Phase 2: Remove Theme from State

**Current problem**: Theme stored in state but also derived from scene. Multiple code paths set it differently.

**Solution**: Always derive theme. Remove from state.

```purescript
-- BEFORE
type State = { ..., theme :: ViewTheme, ... }

NavigateTo targetScene -> do
  let newTheme = themeForScene targetScene
  H.modify_ _ { scene = targetScene, theme = newTheme }

-- AFTER
type State = { ..., /* no theme */ ... }

-- In render:
render state =
  let theme = themeForScene state.scene
  in ...

-- Pass to children:
{ theme: themeForScene state.scene, ... }
```

**Files**: `SceneCoordinator.purs`, remove `SetTheme` action

**Risk**: Low - simplification, but need to update all render code

### Phase 3: Make Scope Transitions Explicit

**Current problem**: `SetScope` secretly triggers `NavigateTo SolarSwarm` for narrow scopes.

**Solution**: Remove auto-escalation. Make UI buttons do explicit scene changes.

```purescript
-- BEFORE (in SetScope)
if shouldEscalate then
  handleAction (NavigateTo SolarSwarm)  -- Hidden!

-- AFTER (in render, scope buttons)
-- Button shows "Project → SolarSwarm" not just "Project"
HH.button
  [ HE.onClick \_ -> do
      handleAction (SetScope ProjectOnly)
      handleAction (NavigateTo SolarSwarm)
  ]
  [ HH.text "Project (→ Solar)" ]

-- Or: different buttons for "filter in place" vs "zoom in"
```

**Alternative**: Keep auto-escalation but make it a documented part of the state machine (add to diagram).

**Files**: `SceneCoordinator.purs`

**Risk**: Medium - changes UX behavior

### Phase 4: Unify View Modes

**Current problem**: `moduleViewMode` and `packageViewMode` are separate, persist across unrelated scenes.

**Solution**: Single `viewMode` that resets to `PrimaryView` on scene change.

```purescript
-- BEFORE
type State = { moduleViewMode :: ModuleViewMode, packageViewMode :: PackageViewMode, ... }

-- AFTER
type State = { viewMode :: ViewMode, ... }

data ViewMode = PrimaryView | MatrixView | ChordView

-- Reset on scene change
NavigateTo targetScene -> do
  H.modify_ _
    { scene = targetScene
    , viewMode = PrimaryView  -- Always reset
    , previousScene = Just state.scene
    }
```

**Files**: `SceneCoordinator.purs`, update render to use unified `viewMode`

**Risk**: Low - but changes behavior (view mode resets)

### Phase 5: Track Panel State in Coordinator

**Current problem**: Panel has its own state, coordinator can't reason about it.

**Solution**: Coordinator tracks panel state, panel becomes purely presentational.

```purescript
-- BEFORE
-- Panel has: { isOpen :: Boolean, content :: PanelContent }
-- Coordinator queries panel to check state

-- AFTER
type State = { ..., panel :: PanelState, ... }

type PanelState = { isOpen :: Boolean, content :: PanelContent }

-- Actions
data Action
  = ...
  | OpenPanel PanelContent
  | ClosePanel
  | SetPanelContent PanelContent

-- Panel input changes
type PanelInput = { isOpen :: Boolean, content :: PanelContent }

-- Panel just renders what it's told, emits close requests
```

**Files**: `SceneCoordinator.purs`, `SlideOutPanel.purs`

**Risk**: Medium - significant change to panel component

### Phase 6: Simplify Child Component State

**Current problem**: Children copy Input to State, potential for desync.

**Solution**: Children should either:
- A) Be stateless (just render Input), or
- B) Only store truly internal state (simulation handle, not scope/theme)

```purescript
-- BEFORE (GalaxyBeeswarmViz)
type State =
  { packages :: Array Package      -- Copied from Input
  , scope :: BeeswarmScope         -- Copied from Input
  , theme :: ViewTheme             -- Copied from Input
  , handle :: Maybe Handle         -- Internal
  }

-- AFTER
type State =
  { handle :: Maybe Handle         -- Only internal state
  , lastInput :: Input             -- For change detection only
  }

-- Use input directly in handlers
handleAction = case _ of
  Receive input -> do
    state <- H.get
    when (inputChanged state.lastInput input) do
      -- React to changes using input, not copied state
      ...
```

**Files**: `GalaxyBeeswarmViz.purs`, `BubblePackBeeswarmViz.purs`, `CirclePackViz.purs`

**Risk**: Medium - need to verify simulation handles work correctly

## Implementation Order

1. **Phase 2: Remove theme** (lowest risk, immediate cleanup)
2. **Phase 1: Simplify navigation** (low risk, fixes real bug)
3. **Phase 4: Unify view modes** (low risk, simplifies state)
4. **Phase 5: Track panel state** (medium risk, but enables future features)
5. **Phase 6: Simplify children** (medium risk, improves architecture)
6. **Phase 3: Explicit scope transitions** (medium risk, UX change - discuss first)

## Verification

After each phase:
1. Build succeeds: `make ce2-website`
2. Navigation works: A→B→C→D→E→F and back
3. Scope filtering works: All/Trans/Deps/Proj buttons
4. View toggles work: Swarm/Matrix/Chord
5. Panel opens/closes correctly
6. No console errors

## State Machine After Refactor

```
State = {
  scene: A | B | C | D(pkg) | E(pkg) | F(pkg)
  scope: All | Trans | Deps | Proj          -- only for B, C
  viewMode: Primary | Matrix | Chord        -- only for C, E
  panel: { open: Bool, content: ... }       -- orthogonal
  previousScene: Maybe Scene                -- for edge cases
}

Transitions:
  NavigateTo(scene) → scene=scene, viewMode=Primary, previousScene=current
  NavigateBack      → scene=parentScene(current), previousScene=current
  SetScope(s)       → scope=s (no hidden navigation)
  SetViewMode(v)    → viewMode=v
  OpenPanel(c)      → panel={ open=true, content=c }
  ClosePanel        → panel.open=false
```

## Open Questions

1. **Should view mode persist within a level?** E.g., if you're in C3M (Project + Matrix), go to D and back - should you return to C3M or C3 (Primary)?

2. **Should panel auto-close on navigation?** Currently it stays open. Maybe close on scene change but not on scope/view change?

3. **What about the treemap-in-panel bug?** Separate fix needed (z-index/overflow issue).

## Notes

- This refactor doesn't change the number of views or the navigation paths
- It only cleans up how state is managed internally
- UI should look the same, but code will be easier to reason about
- Consider adding runtime assertions to catch state inconsistencies during development
