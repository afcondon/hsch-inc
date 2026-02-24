-- | Line Chart - Interactive Admission Rates (HATS Version)
-- |
-- | Shows how admission rates change with the proportion
-- | of applicants to the easy department.
-- | This chart updates reactively with slider changes.
module D3.Viz.Simpsons.LineChart
  ( lineChartTree
  , LineConfig
  , defaultConfig
  ) where

import Prelude

import D3.Viz.Simpsons.AxisHATS (renderAxisHATS, Scale, axisBottom, axisLeft)
import D3.Viz.Simpsons.Types (Proportions, deriveData, rates, black, green, purple)
import Data.Array (uncons)
import Data.Maybe (Maybe(..))
import Hylograph.HATS (Tree, elem, forEach, staticStr, staticNum, thunkedNum, thunkedStr)
import Hylograph.Internal.Selection.Types (ElementType(..))

-- =============================================================================
-- Configuration
-- =============================================================================

type LineConfig =
  { width :: Number
  , height :: Number
  , marginTop :: Number
  , marginRight :: Number
  , marginBottom :: Number
  , marginLeft :: Number
  }

defaultConfig :: LineConfig
defaultConfig =
  { width: 320.0
  , height: 300.0
  , marginTop: 40.0
  , marginRight: 20.0
  , marginBottom: 55.0
  , marginLeft: 45.0
  }

innerWidth :: LineConfig -> Number
innerWidth c = c.width - c.marginLeft - c.marginRight

innerHeight :: LineConfig -> Number
innerHeight c = c.height - c.marginTop - c.marginBottom

-- =============================================================================
-- Data Types
-- =============================================================================

-- | A point on the chart (position on rate line)
type RatePoint =
  { x :: Number  -- % applied to easy (0-100)
  , y :: Number  -- % admitted (0-100)
  , color :: String
  , label :: String
  }

type IndexedRatePoint = { index :: Int, point :: RatePoint }

-- =============================================================================
-- HATS Line Chart Tree
-- =============================================================================

-- | Complete line chart as a HATS tree (both static and dynamic elements)
lineChartTree :: LineConfig -> Proportions -> Tree
lineChartTree config props =
  let
    iw = innerWidth config
    ih = innerHeight config

    xScale :: Number -> Number
    xScale v = v / 100.0 * iw

    yScale :: Number -> Number
    yScale v = ih - (v / 100.0 * ih)

    xAxisScale :: Scale
    xAxisScale = { domain: { min: 0.0, max: 100.0 }, range: { min: 0.0, max: iw } }

    yAxisScale :: Scale
    yAxisScale = { domain: { min: 0.0, max: 100.0 }, range: { min: ih, max: 0.0 } }

    -- Women's rate line: from (0, hard rate) to (100, easy rate)
    womenLine =
      [ { x: 0.0, y: rates.female.hard * 100.0 }
      , { x: 100.0, y: rates.female.easy * 100.0 }
      ]

    -- Men's rate line
    menLine =
      [ { x: 0.0, y: rates.male.hard * 100.0 }
      , { x: 100.0, y: rates.male.easy * 100.0 }
      ]

    -- Calculate current admission rates from proportions
    derived = deriveData props

    -- Women's current position
    womenX = props.easyFemale * 100.0
    womenY = derived.combined.female * 100.0

    -- Men's current position
    menX = props.easyMale * 100.0
    menY = derived.combined.male * 100.0

    ratePoints :: Array IndexedRatePoint
    ratePoints =
      [ { index: 0, point: { x: womenX, y: womenY, color: green, label: "women" } }
      , { index: 1, point: { x: menX, y: menY, color: purple, label: "men" } }
      ]
  in
    elem SVG
      [ staticNum "width" config.width
      , staticNum "height" config.height
      , staticStr "viewBox" ("0 0 " <> show config.width <> " " <> show config.height)
      , staticStr "class" "line-chart"
      ]
      [ elem Group
          [ staticStr "transform" ("translate(" <> show config.marginLeft <> "," <> show config.marginTop <> ")")
          , staticStr "class" "line-content"
          ]
          [ -- Y axis
            elem Group [ staticStr "class" "y-axis" ]
              [ renderAxisHATS (axisLeft yAxisScale)
              , elem Text
                  [ staticStr "transform" ("translate(-35," <> show (ih / 2.0) <> ") rotate(-90)")
                  , staticStr "text-anchor" "middle"
                  , staticNum "font-size" 12.0
                  , staticStr "textContent" "% admitted"
                  ] []
              ]

          -- X axis
          , elem Group
              [ staticStr "transform" ("translate(0," <> show ih <> ")")
              , staticStr "class" "x-axis"
              ]
              [ renderAxisHATS (axisBottom xAxisScale)
              , elem Text
                  [ staticStr "transform" ("translate(" <> show (iw / 2.0) <> ",40)")
                  , staticStr "text-anchor" "middle"
                  , staticNum "font-size" 12.0
                  , staticStr "textContent" "% applied to easy department"
                  ] []
              ]

          -- Women's rate line (green)
          , elem Path
              [ staticStr "class" "rate-line women"
              , staticStr "d" (pathFromPoints xScale yScale womenLine)
              , staticStr "stroke" green
              , staticNum "stroke-width" 1.5
              , staticStr "fill" "none"
              ] []

          -- Men's rate line (purple)
          , elem Path
              [ staticStr "class" "rate-line men"
              , staticStr "d" (pathFromPoints xScale yScale menLine)
              , staticStr "stroke" purple
              , staticNum "stroke-width" 1.5
              , staticStr "fill" "none"
              ] []

          -- Dynamic rate markers (data-bound, update with proportions)
          , forEach "rate-points" Group ratePoints (\p -> show p.index) \{ point } ->
              elem Group [ staticStr "class" ("rate-marker " <> point.label) ]
                [ -- Horizontal dashed line to y-axis
                  elem Path
                    [ staticStr "class" "guide-line"
                    , thunkedStr "d" ("M 0 " <> show (yScale point.y) <> " L " <> show (xScale point.x) <> " " <> show (yScale point.y))
                    , staticStr "stroke" black
                    , staticNum "stroke-width" 1.0
                    , staticStr "stroke-dasharray" "5,5"
                    , staticStr "fill" "none"
                    ] []
                -- The point itself
                , elem Circle
                    [ thunkedNum "cx" (xScale point.x)
                    , thunkedNum "cy" (yScale point.y)
                    , staticNum "r" 6.0
                    , thunkedStr "fill" point.color
                    , staticStr "stroke" "white"
                    , staticNum "stroke-width" 1.0
                    ] []
                ]
          ]
      ]

-- =============================================================================
-- Helpers
-- =============================================================================

-- | Build SVG path from points
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
