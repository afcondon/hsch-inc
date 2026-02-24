-- | Scatter Chart - Paradox Illustration (HATS Version)
-- |
-- | Shows how grouped data can have opposite trends from combined data.
-- | Each color group trends upward, but overall trend is downward.
module D3.Viz.Simpsons.ScatterChart
  ( scatterChartTree
  , ScatterConfig
  , defaultConfig
  ) where

import Prelude

import D3.Viz.Simpsons.Types (green, purple, gray)
import D3.Viz.Simpsons.AxisHATS (renderAxisHATS, Scale, axisBottom, axisLeft)
import Data.Array (mapWithIndex, uncons)
import Data.Maybe (Maybe(..))
import Hylograph.HATS (Tree, elem, forEach, staticStr, staticNum, thunkedNum, thunkedStr)
import Hylograph.Internal.Selection.Types (ElementType(..))

-- =============================================================================
-- Configuration
-- =============================================================================

type ScatterConfig =
  { width :: Number
  , height :: Number
  , marginTop :: Number
  , marginRight :: Number
  , marginBottom :: Number
  , marginLeft :: Number
  }

defaultConfig :: ScatterConfig
defaultConfig =
  { width: 380.0
  , height: 260.0
  , marginTop: 20.0
  , marginRight: 10.0
  , marginBottom: 40.0
  , marginLeft: 40.0
  }

innerWidth :: ScatterConfig -> Number
innerWidth c = c.width - c.marginLeft - c.marginRight

innerHeight :: ScatterConfig -> Number
innerHeight c = c.height - c.marginTop - c.marginBottom

-- =============================================================================
-- Data Types
-- =============================================================================

type Point = { x :: Number, y :: Number, color :: String }

type IndexedPoint = { index :: Int, point :: Point }

-- | Sample data showing the paradox
greenPoints :: Array Point
greenPoints =
  [ { x: 1.0, y: 6.0, color: green }
  , { x: 2.0, y: 7.0, color: green }
  , { x: 3.0, y: 8.0, color: green }
  , { x: 4.0, y: 9.0, color: green }
  ]

purplePoints :: Array Point
purplePoints =
  [ { x: 8.0, y: 1.0, color: purple }
  , { x: 9.0, y: 2.0, color: purple }
  , { x: 10.0, y: 3.0, color: purple }
  , { x: 11.0, y: 4.0, color: purple }
  ]

allPoints :: Array Point
allPoints = greenPoints <> purplePoints

-- =============================================================================
-- HATS Scatter Chart Tree
-- =============================================================================

-- | Complete scatter chart as a HATS tree
scatterChartTree :: ScatterConfig -> Tree
scatterChartTree config =
  let
    iw = innerWidth config
    ih = innerHeight config

    xScale :: Number -> Number
    xScale v = v / 12.0 * iw

    yScale :: Number -> Number
    yScale v = ih - (v / 10.0 * ih)

    xAxisScale :: Scale
    xAxisScale = { domain: { min: 0.0, max: 12.0 }, range: { min: 0.0, max: iw } }

    yAxisScale :: Scale
    yAxisScale = { domain: { min: 0.0, max: 10.0 }, range: { min: ih, max: 0.0 } }

    greenTrendLine = [ { x: 0.0, y: 5.0 }, { x: 6.0, y: 11.0 } ]
    purpleTrendLine = [ { x: 7.0, y: 0.0 }, { x: 13.0, y: 6.0 } ]
    overallTrendLine = [ { x: 0.0, y: 8.2 }, { x: 13.0, y: 1.0 } ]

    indexedPoints = mapWithIndex (\i p -> { index: i, point: p }) allPoints
  in
    elem SVG
      [ staticNum "width" config.width
      , staticNum "height" config.height
      , staticStr "viewBox" ("0 0 " <> show config.width <> " " <> show config.height)
      , staticStr "class" "scatter-chart"
      ]
      [ elem Group
          [ staticStr "transform" ("translate(" <> show config.marginLeft <> "," <> show config.marginTop <> ")")
          , staticStr "class" "scatter-content"
          ]
          [ -- Y axis
            elem Group [ staticStr "class" "y-axis" ]
              [ renderAxisHATS (axisLeft yAxisScale)
              , elem Text
                  [ staticStr "transform" ("translate(-28," <> show (ih / 2.0) <> ") rotate(-90)")
                  , staticStr "text-anchor" "middle"
                  , staticNum "font-size" 12.0
                  , staticStr "textContent" "y"
                  ] []
              ]

          -- X axis
          , elem Group
              [ staticStr "transform" ("translate(0," <> show ih <> ")")
              , staticStr "class" "x-axis"
              ]
              [ renderAxisHATS (axisBottom xAxisScale)
              , elem Text
                  [ staticStr "transform" ("translate(" <> show (iw / 2.0) <> ",35)")
                  , staticStr "text-anchor" "middle"
                  , staticNum "font-size" 12.0
                  , staticStr "textContent" "x"
                  ] []
              ]

          -- Green trend line
          , elem Path
              [ staticStr "class" "trend-line green"
              , staticStr "d" (pathFromPoints xScale yScale greenTrendLine)
              , staticStr "stroke" green
              , staticNum "stroke-width" 1.5
              , staticStr "fill" "none"
              ] []

          -- Purple trend line
          , elem Path
              [ staticStr "class" "trend-line purple"
              , staticStr "d" (pathFromPoints xScale yScale purpleTrendLine)
              , staticStr "stroke" purple
              , staticNum "stroke-width" 1.5
              , staticStr "fill" "none"
              ] []

          -- Overall trend line (dashed)
          , elem Path
              [ staticStr "class" "trend-line overall"
              , staticStr "d" (pathFromPoints xScale yScale overallTrendLine)
              , staticStr "stroke" gray
              , staticNum "stroke-width" 1.5
              , staticStr "stroke-dasharray" "4,3"
              , staticStr "fill" "none"
              ] []

          -- Data points
          , forEach "points" Circle indexedPoints (\p -> show p.index) \{ point } ->
              elem Circle
                [ thunkedNum "cx" (xScale point.x)
                , thunkedNum "cy" (yScale point.y)
                , staticNum "r" 6.0
                , thunkedStr "fill" point.color
                , staticStr "stroke" "white"
                , staticNum "stroke-width" 1.0
                ] []
          ]
      ]

-- | Helper to build SVG path from points
pathFromPoints :: (Number -> Number) -> (Number -> Number) -> Array { x :: Number, y :: Number } -> String
pathFromPoints xScaleFn yScaleFn pts = go true pts
  where
    go :: Boolean -> Array { x :: Number, y :: Number } -> String
    go isFirst arr = case uncons arr of
      Nothing -> ""
      Just { head: p, tail: rest } ->
        let
          cmd = if isFirst then "M " else " L "
          px = xScaleFn p.x
          py = yScaleFn p.y
        in
          cmd <> show px <> " " <> show py <> go false rest
