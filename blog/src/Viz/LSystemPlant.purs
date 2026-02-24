-- | L-System Plant Visualization
-- |
-- | Renders a randomized L-system plant on the home page.
-- | Uses the Zoo.LSystem modules for grammar expansion and interpretation.
module Hylographic.Viz.LSystemPlant where

import Prelude

import Data.Array as Array
import Data.Const (Const)
import Data.Foldable (foldl)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Void (Void)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (liftEffect)
import Effect.Random (randomInt)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.Svg.Attributes as SA
import Halogen.Svg.Elements as SE

import Zoo.LSystem.Grammar (fractalPlant, simplePlant, binaryTree)
import Zoo.LSystem.Schemes (render) as LSystem
import Zoo.LSystem.Types (LSystem, RenderConfig, Segment, defaultRenderConfig)
import Zoo.LSystem.Render (calculateBounds)

-- | Plant L-systems to choose from
plantSystems :: Array LSystem
plantSystems = [ fractalPlant, simplePlant, binaryTree ]

-- | Component state
type State =
  { system :: Maybe LSystem
  , segments :: Array Segment
  , iterations :: Int
  , scale :: Number  -- Random scale factor for size variation
  }

-- | Component actions
data Action = Initialize

-- | The L-System Plant component
component :: H.Component (Const Void) Unit Void Aff
component = H.mkComponent
  { initialState: \_ -> { system: Nothing, segments: [], iterations: 5, scale: 1.0 }
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div
    [ HP.classes [ HH.ClassName "lsystem-background" ] ]
    [ renderSVG state ]

renderSVG :: forall m. State -> H.ComponentHTML Action () m
renderSVG state
  | Array.null state.segments =
      -- Empty placeholder while loading
      SE.svg
        [ SA.classes [ HH.ClassName "lsystem-svg" ] ]
        []
  | otherwise =
      let
        bounds = calculateBounds state.segments
        -- Add padding, more on top/right to let plant grow into view
        padLeft = 10.0
        padBottom = 10.0
        padTop = 50.0
        padRight = 50.0
        minX = bounds.minX - padLeft
        minY = bounds.minY - padTop
        w = (bounds.maxX - bounds.minX) + padLeft + padRight
        h = (bounds.maxY - bounds.minY) + padTop + padBottom
      in
        SE.svg
          [ SA.viewBox minX minY w h
          , SA.classes [ HH.ClassName "lsystem-svg" ]
          -- preserveAspectRatio to anchor to bottom-left
          ]
          (renderSegments state.segments)

-- | Render all segments grouped by depth for coloring
renderSegments :: forall m. Array Segment -> Array (H.ComponentHTML Action () m)
renderSegments segments =
  let
    maxDepth = foldl (\m s -> max m s.depth) 0 segments
    depthGroups = Array.range 0 maxDepth # map \d ->
      Array.filter (\s -> s.depth == d) segments
  in
    Array.mapWithIndex renderDepthGroup depthGroups

-- | Render a group of segments at the same depth
renderDepthGroup :: forall m. Int -> Array Segment -> H.ComponentHTML Action () m
renderDepthGroup depth segments =
  SE.g
    [ SA.classes [ HH.ClassName ("depth-" <> show depth) ] ]
    (map (renderSegment depth) segments)

-- | Render a single segment as a line
renderSegment :: forall m. Int -> Segment -> H.ComponentHTML Action () m
renderSegment depth seg =
  SE.line
    [ SA.x1 seg.x1
    , SA.y1 seg.y1
    , SA.x2 seg.x2
    , SA.y2 seg.y2
    , SA.stroke (SA.Named (colorForDepth depth))
    , SA.strokeWidth (widthForDepth depth)
    ]

-- | Color palette for depth (botanical green gradient)
depthColors :: Array String
depthColors =
  [ "#2d5a27"  -- Dark green (trunk)
  , "#3d7a37"
  , "#4d9a47"
  , "#5dba57"
  , "#6dda67"
  , "#7dfa77"  -- Light green (tips)
  , "#8dff87"
  , "#9dff97"
  ]

colorForDepth :: Int -> String
colorForDepth d =
  let idx = min d (Array.length depthColors - 1)
  in fromMaybe "#2d5a27" (Array.index depthColors idx)

widthForDepth :: Int -> Number
widthForDepth d = 2.0 * pow 0.75 (toNumber d)
  where
  pow base exp = if exp <= 0.0 then 1.0 else base * pow base (exp - 1.0)

-- | Custom render config for background plant
-- | Larger step length for bigger plants
backgroundRenderConfig :: Number -> RenderConfig
backgroundRenderConfig scale = defaultRenderConfig
  { stepLength = 12.0 * scale
  , lengthScale = 0.5
  , strokeWidth = 2.5
  }

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Void m Unit
handleAction = case _ of
  Initialize -> do
    -- Pick a random plant system
    idx <- liftEffect $ randomInt 0 (Array.length plantSystems - 1)
    let system = fromMaybe fractalPlant (Array.index plantSystems idx)

    -- Randomize iterations (4-6) for size variation
    iterations <- liftEffect $ randomInt 4 6

    -- Randomize scale factor (0.8 to 1.5) for additional size variation
    scaleInt <- liftEffect $ randomInt 80 150
    let scale = toNumber scaleInt / 100.0

    -- Render the L-system
    let segments = LSystem.render iterations system (backgroundRenderConfig scale)

    H.modify_ _ { system = Just system, segments = segments, iterations = iterations, scale = scale }
