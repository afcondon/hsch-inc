-- | Type Class Grid Visualization
-- |
-- | Displays all type classes as a grid of cards.
-- | Each card shows:
-- | - Class name
-- | - Module name
-- | - Method count (as donut arcs)
-- | - Instance count (center number)
-- |
-- | Ported from Minard's CE2.Viz.TypeClassGrid
module TypeExplorer.Views.TypeClassGrid
  ( initTypeClassGrid
  , TypeClassGridHandle
  ) where

import Prelude

import Data.Array as Array
import Data.Int (toNumber)
import Data.Int (floor) as Int
import Data.Number (pi, cos, sin)
import Data.String.Pattern (Pattern(..))
import Data.String.Common (split) as StringCommon
import Effect (Effect)
import Effect.Ref as Ref
import Hylograph.HATS (Tree, elem, staticStr, thunkedStr)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))
import TypeExplorer.Types (TypeClassGridData, TypeClassGridInfo, colors)

-- =============================================================================
-- Types
-- =============================================================================

type GridConfig =
  { width :: Number
  , height :: Number
  , cardWidth :: Number
  , cardHeight :: Number
  , padding :: Number
  }

defaultConfig :: GridConfig
defaultConfig =
  { width: 1000.0
  , height: 800.0
  , cardWidth: 120.0
  , cardHeight: 100.0
  , padding: 10.0
  }

type TypeClassGridHandle =
  { onClassClick :: ((Int -> Effect Unit) -> Effect Unit)
  }

-- =============================================================================
-- Public API
-- =============================================================================

-- | Initialize the type class grid
initTypeClassGrid :: String -> TypeClassGridData -> Effect TypeClassGridHandle
initTypeClassGrid selector gridData = do
  let config = defaultConfig

  -- Click callback ref
  clickCallbackRef <- Ref.new (\_ -> pure unit :: Effect Unit)

  -- Render the grid
  _ <- rerender selector (renderGrid config gridData)

  pure
    { onClassClick: \callback -> Ref.write callback clickCallbackRef
    }

-- =============================================================================
-- Grid Rendering
-- =============================================================================

-- | Render the full grid
renderGrid :: GridConfig -> TypeClassGridData -> Tree
renderGrid config stats =
  elem SVG
    [ staticStr "viewBox" $ "0 0 " <> show config.width <> " " <> show config.height
    , staticStr "width" "100%"
    , staticStr "height" "100%"
    , staticStr "class" "type-class-grid"
    ]
    [ -- Background
      elem Rect
        [ staticStr "x" "0", staticStr "y" "0"
        , thunkedStr "width" (show config.width)
        , thunkedStr "height" (show config.height)
        , staticStr "fill" colors.bg
        ] []
    , renderHeader config stats
    , renderCards config stats.typeClasses
    ]

-- | Header with summary stats
renderHeader :: GridConfig -> TypeClassGridData -> Tree
renderHeader _config stats =
  elem Group
    [ staticStr "class" "header"
    , staticStr "transform" "translate(20, 30)"
    ]
    [ elem Text
        [ staticStr "font-size" "18"
        , staticStr "font-weight" "bold"
        , staticStr "fill" colors.text
        , thunkedStr "textContent" $ show stats.count <> " Type Classes"
        ] []
    , elem Text
        [ staticStr "y" "22"
        , staticStr "font-size" "12"
        , staticStr "fill" "#666"
        , thunkedStr "textContent" $ show stats.summary.totalMethods <> " methods, "
              <> show stats.summary.totalInstances <> " instances"
        ] []
    ]

-- | Render all type class cards in a grid
renderCards :: GridConfig -> Array TypeClassGridInfo -> Tree
renderCards config classes =
  let
    startY = 70.0
    startX = 20.0

    -- Calculate columns based on width
    cols = max 1.0 $ (config.width - startX * 2.0) / (config.cardWidth + config.padding)

    -- Position each card
    positionedCards = Array.mapWithIndex (positionCard cols config startX startY) classes
  in
    elem Group
      [ staticStr "class" "cards" ]
      positionedCards

-- | Position a single card in the grid
positionCard :: Number -> GridConfig -> Number -> Number -> Int -> TypeClassGridInfo -> Tree
positionCard cols config startX startY idx tc =
  let
    colsInt = max 1 $ Int.floor cols
    col = toNumber (idx `mod` colsInt)
    row = toNumber (idx / colsInt)
    x = startX + col * (config.cardWidth + config.padding)
    y = startY + row * (config.cardHeight + config.padding)
  in
    renderCard config.cardWidth config.cardHeight x y tc

-- | Render a single type class card
renderCard :: Number -> Number -> Number -> Number -> TypeClassGridInfo -> Tree
renderCard w h x y tc =
  let
    donutCx = w / 2.0
    donutCy = h / 2.0 - 10.0
    donutRadius = 35.0
  in
    elem Group
      [ staticStr "class" "type-class-card"
      , thunkedStr "transform" $ "translate(" <> show x <> "," <> show y <> ")"
      ]
      [ -- Card background
        elem Rect
          [ staticStr "x" "0", staticStr "y" "0"
          , staticStr "width" (show w)
          , staticStr "height" (show h)
          , staticStr "fill" "#2a2a3e"
          , staticStr "rx" "8"
          , staticStr "stroke" "#3a3a4e"
          , staticStr "stroke-width" "1"
          ] []
      , -- Donut with instance count in center
        renderDonut donutCx donutCy donutRadius tc.methodCount tc.instanceCount 12
      , -- Class name
        elem Text
          [ thunkedStr "x" (show (w / 2.0))
          , thunkedStr "y" (show (h - 18.0))
          , staticStr "text-anchor" "middle"
          , staticStr "font-size" "10"
          , staticStr "font-weight" "600"
          , staticStr "fill" "#e2e8f0"
          , thunkedStr "textContent" tc.name
          ] []
      , -- Module name
        elem Text
          [ thunkedStr "x" (show (w / 2.0))
          , thunkedStr "y" (show (h - 6.0))
          , staticStr "text-anchor" "middle"
          , staticStr "font-size" "7"
          , staticStr "fill" "#64748b"
          , thunkedStr "textContent" $ truncateModule tc.moduleName
          ] []
      ]

-- | Color based on instance count
instanceCountColor :: Int -> String
instanceCountColor n
  | n >= 100 = "#22c55e"   -- Green - heavily used
  | n >= 20 = "#eab308"    -- Yellow - moderate
  | n >= 1 = "#94a3b8"     -- Gray - light use
  | otherwise = "#475569"  -- Dim - no instances

-- | Truncate long module names
truncateModule :: String -> String
truncateModule s =
  let parts = StringCommon.split (Pattern ".") s
      len = Array.length parts
  in if len <= 2
     then s
     else "..." <> (Array.intercalate "." $ Array.drop (len - 2) parts)

-- =============================================================================
-- Donut Chart
-- =============================================================================

-- | Render a donut showing method count as arcs, instance count in center
renderDonut :: Number -> Number -> Number -> Int -> Int -> Int -> Tree
renderDonut cx cy radius methodCount instanceCount maxMethods =
  let
    displayCount = min methodCount maxMethods
    arcs = if displayCount <= 0
           then [ renderEmptyRing cx cy radius ]
           else Array.mapWithIndex (renderMethodArc cx cy radius displayCount) (Array.range 0 (displayCount - 1))
    centerText = elem Text
      [ thunkedStr "x" (show cx)
      , thunkedStr "y" (show (cy + 6.0))
      , staticStr "text-anchor" "middle"
      , staticStr "font-size" "14"
      , staticStr "font-weight" "bold"
      , staticStr "fill" $ instanceCountColor instanceCount
      , thunkedStr "textContent" $ show instanceCount
      ] []
  in
    elem Group
      [ staticStr "class" "donut" ]
      (Array.snoc arcs centerText)

-- | Empty ring for classes with 0 methods
renderEmptyRing :: Number -> Number -> Number -> Tree
renderEmptyRing cx cy r =
  elem Circle
    [ thunkedStr "cx" (show cx)
    , thunkedStr "cy" (show cy)
    , thunkedStr "r" (show (r - 6.0))
    , staticStr "fill" "none"
    , staticStr "stroke" "#334155"
    , staticStr "stroke-width" "8"
    ] []

-- | Render a single method arc
renderMethodArc :: Number -> Number -> Number -> Int -> Int -> Int -> Tree
renderMethodArc cx cy radius total idx _ =
  let
    gap = 0.08
    arcLength = (2.0 * pi - toNumber total * gap) / toNumber total
    startAngle = toNumber idx * (arcLength + gap) - pi / 2.0
    endAngle = startAngle + arcLength

    innerR = radius - 8.0
    outerR = radius - 2.0

    x1 = cx + outerR * cos startAngle
    y1 = cy + outerR * sin startAngle
    x2 = cx + outerR * cos endAngle
    y2 = cy + outerR * sin endAngle
    x3 = cx + innerR * cos endAngle
    y3 = cy + innerR * sin endAngle
    x4 = cx + innerR * cos startAngle
    y4 = cy + innerR * sin startAngle

    largeArc = if arcLength > pi then "1" else "0"

    d = "M " <> show x1 <> " " <> show y1
      <> " A " <> show outerR <> " " <> show outerR <> " 0 " <> largeArc <> " 1 " <> show x2 <> " " <> show y2
      <> " L " <> show x3 <> " " <> show y3
      <> " A " <> show innerR <> " " <> show innerR <> " 0 " <> largeArc <> " 0 " <> show x4 <> " " <> show y4
      <> " Z"
  in
    elem Path
      [ thunkedStr "d" d
      , staticStr "fill" "#f59e0b"
      , staticStr "opacity" "0.85"
      ] []
