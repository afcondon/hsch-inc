-- | Scale Transition Rendering - Animated Powers of Ten zoom
-- |
-- | Renders animated transitions between scale levels (beeswarm <-> treemap).
-- | All state lives in Halogen; this module provides pure rendering functions.
-- |
-- | Transitions:
-- | - PackageSetScale → ProjectDepsScale: ZoomOut → FadeOut → PopIn → Done
-- | - ProjectDepsScale → ProjectOnlyScale: MoveToTreemap → CrossfadeToModules → Done
-- | - Zoom out (coarser): No animation, instant jump
module CE2.Viz.ScaleTransition
  ( -- Rendering functions
    renderZoomOut
  , renderFadeOut
  , renderPopIn
  , renderPopInPacked      -- Pre-computed packed positions
  , renderResize
  , renderMoveToTreemap
  , renderMoveToTreemapNew -- New version using library transform functions
  , renderCrossfade
  , renderCrossfadeNew     -- New version using library transform functions
  , clearTransitionElements
  , prepareModuleCircles
  , renderPackedModules    -- Render modules from packed data
  , reheatWithPackedRadii  -- Reheat force after PopIn
    -- Treemap transition FFI
  , stopBeeswarmSimulation
  , getCurrentPositions
  , getCurrentPositionsByName
  , renderTreemapBackdrop
  , removeFadedPackages
  , removeBeeswarmElements
  , removeTreemapBackdrop
    -- Types
  , SourcePosition
  , TargetPosition
    -- Phase duration helpers
  , zoomOutDuration
  , fadeOutDuration
  , popInDuration
  , resizeDuration
  , moveToTreemapDuration
  , crossfadeDuration
    -- Legacy FFI (deprecated, use library functions instead)
  , moveGroupsToPositions
  , setPackageGroupsOpacity
  , transitionViewBox
  ) where

import Prelude

import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Traversable (traverse_)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Class.Console (log)
import Hylograph.Transition.Tick as Tick
import Hylograph.Transform as Transform
import CE2.Types (PackedPackageData, TreemapRect, ViewBoxSpec)

-- =============================================================================
-- Configuration
-- =============================================================================

-- | Phase durations (in animation progress units)
-- | At animationDelta = 0.02, these translate to:
-- | - 25 ticks = 0.5 seconds
-- | - 20 ticks = 0.4 seconds
-- | - 40 ticks = 0.8 seconds
zoomOutDuration :: Number
zoomOutDuration = 1.0  -- ViewBox expands (establish new scale)

fadeOutDuration :: Number
fadeOutDuration = 1.0  -- Non-relevant packages fade out

popInDuration :: Number
popInDuration = 1.0  -- Remaining packages grow into bubble packs

resizeDuration :: Number
resizeDuration = 1.0

moveToTreemapDuration :: Number
moveToTreemapDuration = 1.0

crossfadeDuration :: Number
crossfadeDuration = 1.0

-- =============================================================================
-- Render Functions
-- =============================================================================

-- | Render fade-out of non-relevant packages
-- | Progress 0.0 → 1.0: opacity 1.0 → 0.0
renderFadeOut
  :: String              -- Container selector
  -> Set Int             -- IDs of nodes to fade out
  -> Tick.Progress       -- Progress in this phase
  -> Effect Unit
renderFadeOut selector fadingIds progress = do
  let easedProgress = Tick.easeOutQuad progress
      opacity = 1.0 - easedProgress
  log $ "[ScaleTransition] FadeOut progress: " <> show progress
      <> " -> opacity: " <> show opacity
      <> " (fading " <> show (Set.size fadingIds) <> " nodes)"

  -- Apply opacity to fading nodes via CSS class or direct style
  setOpacityByIds selector fadingIds opacity

-- | Render zoom out phase (viewBox only, no circle changes)
-- | Progress 0.0 → 1.0: viewBox expands to establish new spatial scale
renderZoomOut
  :: String
  -> { width :: Number, height :: Number }  -- Source viewBox
  -> { width :: Number, height :: Number }  -- Target viewBox
  -> Tick.Progress
  -> Effect Unit
renderZoomOut selector sourceVB targetVB progress = do
  let easedProgress = Tick.easeInOutCubic progress
      -- Interpolate viewBox dimensions
      newWidth = Tick.lerp sourceVB.width targetVB.width easedProgress
      newHeight = Tick.lerp sourceVB.height targetVB.height easedProgress

  log $ "[ScaleTransition] ZoomOut progress: " <> show progress
      <> " -> viewBox: " <> show newWidth <> "x" <> show newHeight

  -- Update viewBox only (circles stay same size in data coords, shrink visually)
  setViewBox selector newWidth newHeight

-- | Render pop-in phase (OLD version with multiplier-based growth)
-- | Progress 0.0 → 1.0:
-- |   - Circle radii: r → r * multiplier
-- |   - Module circles fade in inside
renderPopIn
  :: String
  -> Number                                  -- Radius multiplier
  -> Set Int                                 -- IDs of circles to grow
  -> Tick.Progress
  -> Effect Unit
renderPopIn selector radiusMult remainingIds progress = do
  let easedProgress = Tick.easeOutCubic progress
      -- Radius grows from 1.0 to multiplier
      currentMult = Tick.lerp 1.0 radiusMult easedProgress
      -- Module circles fade in
      moduleOpacity = easedProgress

  log $ "[ScaleTransition] PopIn progress: " <> show progress
      <> " -> radiusMult: " <> show currentMult
      <> ", moduleOpacity: " <> show moduleOpacity

  -- Grow circles and fade in modules together
  growCircles selector currentMult remainingIds
  setClassOpacity selector ".module-circle" moduleOpacity

-- | Render pop-in phase (NEW version with pre-computed packed positions)
-- | Progress 0.0 → 1.0:
-- |   - Package circles grow to their enclosing radius
-- |   - Module circles rendered at packed positions, fade in
renderPopInPacked
  :: String
  -> Array PackedPackageData                 -- Pre-computed packed packages
  -> Tick.Progress
  -> Effect Unit
renderPopInPacked selector packedPackages progress = do
  let easedProgress = Tick.easeOutCubic progress
      -- Module circles fade in
      moduleOpacity = easedProgress

  log $ "[ScaleTransition] PopInPacked progress: " <> show progress
      <> " -> moduleOpacity: " <> show moduleOpacity

  -- Grow package circles to enclosing radius
  growToPackedRadii selector packedPackages easedProgress

  -- Render module circles at packed positions (creates if needed, updates opacity)
  renderPackedModulesImpl selector packedPackages moduleOpacity

-- | Prepare module circles inside package circles (OLD version)
-- | Takes radiusMultiplier so module positions are based on FINAL grown size
prepareModuleCircles
  :: String
  -> Number  -- radiusMultiplier
  -> Effect Unit
prepareModuleCircles selector radiusMult = do
  log $ "[ScaleTransition] Preparing module circles inside packages (radiusMult=" <> show radiusMult <> ")"
  addModuleCirclesToPackagesImpl selector radiusMult

-- | Render module circles from pre-computed packed positions
-- | Call this once to set up module circles, then use setModuleOpacity to animate
renderPackedModules
  :: String
  -> Array PackedPackageData
  -> Number                   -- Initial opacity
  -> Effect Unit
renderPackedModules selector packedPackages opacity = do
  log "[ScaleTransition] Rendering packed modules"
  renderPackedModulesImpl selector packedPackages opacity

-- | Render resize of remaining packages
-- | Progress 0.0 → 1.0: interpolate radius from source to target
renderResize
  :: String
  -> Map Int Number      -- Source radii (by node ID)
  -> Map Int Number      -- Target radii (by node ID)
  -> Tick.Progress
  -> Effect Unit
renderResize selector sourceRadii targetRadii progress = do
  let easedProgress = Tick.easeOutCubic progress
  log $ "[ScaleTransition] ResizeRemaining progress: " <> show progress
      <> " -> eased: " <> show easedProgress

  -- For each remaining node, interpolate radius
  let pairs :: Array _
      pairs = Map.toUnfoldable sourceRadii
  traverse_ (\(id /\ sourceR) ->
    let targetR = Map.lookup id targetRadii # fromMaybe sourceR
        newR = Tick.lerp sourceR targetR easedProgress
    in setRadiusById selector id newR
  ) pairs

-- | Render movement from beeswarm to treemap positions
-- | Progress 0.0 → 1.0: interpolate cx/cy and radius
renderMoveToTreemap
  :: String
  -> Map Int { x :: Number, y :: Number, r :: Number }  -- Source positions
  -> Map Int { x :: Number, y :: Number, r :: Number }  -- Target positions
  -> Tick.Progress
  -> Effect Unit
renderMoveToTreemap selector sourcePositions targetPositions progress = do
  let easedProgress = Tick.easeInOutCubic progress
  log $ "[ScaleTransition] MoveToTreemap progress: " <> show progress
      <> " -> eased: " <> show easedProgress

  -- Interpolate positions for all nodes
  let pairs :: Array _
      pairs = Map.toUnfoldable sourcePositions
  traverse_ (\(id /\ source) ->
    case Map.lookup id targetPositions of
      Nothing -> pure unit
      Just target -> do
        let newX = Tick.lerp source.x target.x easedProgress
            newY = Tick.lerp source.y target.y easedProgress
            newR = Tick.lerp source.r target.r easedProgress
        setPositionById selector id newX newY newR
  ) pairs

-- | Render crossfade from package circles to module circles
-- | Progress 0.0 → 1.0:
-- |   - Package circles: opacity 1.0 → 0.0
-- |   - Module circles: opacity 0.0 → 1.0
renderCrossfade
  :: String
  -> Tick.Progress
  -> Effect Unit
renderCrossfade selector progress = do
  let easedProgress = Tick.easeOutQuad progress
      packageOpacity = 1.0 - easedProgress
      moduleOpacity = easedProgress
  log $ "[ScaleTransition] Crossfade progress: " <> show progress
      <> " -> packages: " <> show packageOpacity
      <> ", modules: " <> show moduleOpacity

  -- Fade out package circles
  setClassOpacity selector ".package-transition-circle" packageOpacity

  -- Fade in module circles
  setClassOpacity selector ".module-node" moduleOpacity

-- | Clean up transition-specific elements
clearTransitionElements :: String -> Effect Unit
clearTransitionElements selector = do
  log "[ScaleTransition] Clearing transition elements"
  removeTransitionClass selector

-- =============================================================================
-- New Treemap Transition Renders (using library functions)
-- =============================================================================

-- | Source position record (captured at start of transition)
-- | Just x/y, no radius (radius is handled separately)
type SourcePosition = { x :: Number, y :: Number }

-- | Render move-to-treemap phase (using library transform functions)
-- | Animates package groups from source positions to treemap centers
-- | Also transitions the viewBox to match treemap dimensions
-- |
-- | Source positions should be captured at the START of this phase
-- | using getCurrentPositionsByName and stored in Halogen state.
-- |
-- | NOTE: Uses NAME matching (not ID) because the DOM groups come from
-- | packageSetData while treemap targets come from modelData - different ID spaces.
renderMoveToTreemapNew
  :: String
  -> Map String SourcePosition -- Source positions BY NAME (captured at phase start)
  -> Map String SourcePosition -- Target positions BY NAME (treemap centers)
  -> ViewBoxSpec               -- Source viewBox
  -> ViewBoxSpec               -- Target viewBox
  -> Array TreemapRect         -- Treemap backdrop rectangles
  -> Tick.Progress
  -> Effect Unit
renderMoveToTreemapNew selector sourcePositions targetPositions sourceVB targetVB treemapRects progress = do
  let easedProgress = Tick.easeInOutCubic progress

  log $ "[ScaleTransition] MoveToTreemap progress: " <> show progress
      <> " -> eased: " <> show easedProgress
      <> " sources: " <> show (Map.size sourcePositions)
      <> " targets: " <> show (Map.size targetPositions)

  -- Create lookup function that interpolates position for each NAME
  let positionLookup :: String -> Maybe Transform.Point
      positionLookup name = do
        src <- Map.lookup name sourcePositions
        tgt <- Map.lookup name targetPositions
        pure
          { x: Tick.lerp src.x tgt.x easedProgress
          , y: Tick.lerp src.y tgt.y easedProgress
          }

  -- Use library function to update group transforms (by name)
  Transform.transformGroupsByName selector "g.package-group" "data-name" positionLookup

  -- Interpolate and set viewBox (using library function)
  let newMinX = Tick.lerp sourceVB.minX targetVB.minX easedProgress
      newMinY = Tick.lerp sourceVB.minY targetVB.minY easedProgress
      newWidth = Tick.lerp sourceVB.width targetVB.width easedProgress
      newHeight = Tick.lerp sourceVB.height targetVB.height easedProgress
  Transform.setViewBox selector newMinX newMinY newWidth newHeight

  -- Start rendering treemap backdrop (initially invisible, fades in during crossfade)
  -- Only render when we're close to done with move phase
  when (progress > 0.8) do
    renderTreemapBackdrop selector treemapRects 0.0

-- | Render crossfade phase (using library transform functions)
-- | Fades in treemap backdrop, fades out package groups
renderCrossfadeNew
  :: String
  -> Set Int                  -- IDs of packages to fade out
  -> Array TreemapRect
  -> Tick.Progress
  -> Effect Unit
renderCrossfadeNew selector packageIds treemapRects progress = do
  let easedProgress = Tick.easeOutQuad progress
      -- Treemap backdrop fades in
      backdropOpacity = easedProgress
      -- Package groups fade out
      groupsOpacity = 1.0 - easedProgress

  log $ "[ScaleTransition] Crossfade progress: " <> show progress
      <> " -> backdrop: " <> show backdropOpacity
      <> ", groups: " <> show groupsOpacity

  -- Ensure treemap backdrop exists and update opacity
  renderTreemapBackdrop selector treemapRects backdropOpacity

  -- Create lookup function returning opacity for each ID
  let opacityLookup :: Int -> Maybe Number
      opacityLookup id =
        if Set.member id packageIds
          then Just groupsOpacity
          else Nothing

  -- Fade out package groups using library function
  Transform.setGroupsOpacityById selector "g.package-group" "data-id" opacityLookup

-- =============================================================================
-- FFI Imports
-- =============================================================================

-- | Set opacity on nodes by their IDs (pass as Array for reliable JS interop)
foreign import setOpacityByIdsImpl :: String -> Array Int -> Number -> Effect Unit

-- | Wrapper that converts Set to Array
setOpacityByIds :: String -> Set Int -> Number -> Effect Unit
setOpacityByIds selector ids opacity =
  setOpacityByIdsImpl selector (Set.toUnfoldable ids) opacity

-- | Set radius on a single node by ID
foreign import setRadiusById :: String -> Int -> Number -> Effect Unit

-- | Set position and radius on a single node by ID
foreign import setPositionById :: String -> Int -> Number -> Number -> Number -> Effect Unit

-- | Set opacity on all elements matching a class
foreign import setClassOpacity :: String -> String -> Number -> Effect Unit

-- | Remove transition-specific CSS classes
foreign import removeTransitionClass :: String -> Effect Unit

-- | Set viewBox only (for ZoomOut phase)
foreign import setViewBox :: String -> Number -> Number -> Effect Unit

-- | Grow circles by multiplier (pass IDs as Array for reliable JS interop)
foreign import growCirclesImpl :: String -> Number -> Array Int -> Effect Unit

-- | Wrapper that converts Set to Array
growCircles :: String -> Number -> Set Int -> Effect Unit
growCircles selector mult ids =
  growCirclesImpl selector mult (Set.toUnfoldable ids)

-- | Add module circles inside package circles (OLD - uses JS packing)
foreign import addModuleCirclesToPackagesImpl :: String -> Number -> Effect Unit

-- =============================================================================
-- NEW FFI: Render from pre-computed packed positions
-- =============================================================================

-- | Render module circles from pre-computed packed positions
foreign import renderPackedModulesImpl :: String -> Array PackedPackageData -> Number -> Effect Unit

-- | Grow package circles to their target enclosing radius
foreign import growToPackedRadiiImpl :: String -> Array PackedPackageData -> Number -> Effect Unit

-- | Wrapper for grow to packed radii
growToPackedRadii :: String -> Array PackedPackageData -> Number -> Effect Unit
growToPackedRadii = growToPackedRadiiImpl

-- | Reheat force simulation with collision based on packed radii
-- | Call this after PopIn completes to resolve overlaps
foreign import reheatWithPackedRadii :: String -> Array PackedPackageData -> Effect Unit

-- =============================================================================
-- NEW FFI: Treemap Transition (legacy, prefer library functions)
-- =============================================================================

-- | Position record for treemap targets (legacy FFI)
type TargetPosition = { id :: Int, x :: Number, y :: Number }

-- TreemapRect is now imported from CE2.Types

-- | Stop the beeswarm simulation (prevents competing with transitions)
foreign import stopBeeswarmSimulation :: String -> Effect Unit

-- | Read current positions of package groups from DOM
foreign import getCurrentPositions :: String -> Effect (Array { id :: Int, x :: Number, y :: Number, r :: Number })

-- | Read current positions of package groups from DOM, keyed by NAME
-- | Use this when matching between different data sources (packageSetData vs modelData)
foreign import getCurrentPositionsByName :: String -> Effect (Array { name :: String, x :: Number, y :: Number, r :: Number })

-- | Animate package groups from current positions to targets
foreign import moveGroupsToPositions :: String -> Array TargetPosition -> Number -> Effect Unit

-- | Render treemap backdrop rectangles with given opacity
foreign import renderTreemapBackdrop :: String -> Array TreemapRect -> Number -> Effect Unit

-- | Set opacity on all package groups
foreign import setPackageGroupsOpacity :: String -> Number -> Effect Unit

-- | Transition viewBox smoothly
foreign import transitionViewBox :: String -> Number -> Number -> Number -> Number -> Number -> Effect Unit

-- | Remove faded packages from DOM (GUP exit pattern)
-- | Called at end of FadeOut phase to remove packages that have faded to opacity 0
foreign import removeFadedPackagesImpl :: String -> Array Int -> Effect Unit

-- | Wrapper that converts Set to Array
removeFadedPackages :: String -> Set Int -> Effect Unit
removeFadedPackages selector ids =
  removeFadedPackagesImpl selector (Set.toUnfoldable ids)

-- | Remove beeswarm elements after treemap transition completes
foreign import removeBeeswarmElements :: String -> Effect Unit

-- | Remove treemap backdrop (used when zooming out from treemap to beeswarm)
foreign import removeTreemapBackdrop :: String -> Effect Unit
