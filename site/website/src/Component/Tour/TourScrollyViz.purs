-- | HATS visualizations for TourScrolly
-- |
-- | Simple, static visualizations for the "From the Basics" tour.
-- | No animations - just declarative HATS trees rendered via tick.
module Component.Tour.TourScrollyViz where

import Prelude

import Data.Array (range, uncons)
import Data.Foldable (foldl)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Number (exp, sin)
import Effect (Effect)
import Hylograph.HATS (Tree, elem, forEach)
import Hylograph.HATS.Friendly as F
import Hylograph.HATS.InterpreterTick (rerender, clearContainer) as HATS
import Hylograph.Internal.Selection.Types (ElementType(..))

-- =============================================================================
-- Constants
-- =============================================================================

svgWidth :: Number
svgWidth = 400.0

svgHeight :: Number
svgHeight = 300.0

-- =============================================================================
-- Render Helpers
-- =============================================================================

renderViz :: String -> Tree -> Effect Unit
renderViz selector tree = do
  _ <- HATS.rerender selector tree
  pure unit

clearViz :: String -> Effect Unit
clearViz = HATS.clearContainer

-- | Build SVG container
buildSvg :: Array Tree -> Tree
buildSvg children =
  elem SVG
    [ F.width svgWidth
    , F.height svgHeight
    , F.viewBox 0.0 0.0 svgWidth svgHeight
    , F.class_ "scrolly-viz-svg"
    ]
    children

-- =============================================================================
-- Step 1: Empty Canvas
-- =============================================================================

step1EmptyCanvas :: Tree
step1EmptyCanvas = buildSvg []

-- =============================================================================
-- Step 2: Three Green Circles (hardcoded)
-- =============================================================================

step2ThreeGreenCircles :: Tree
step2ThreeGreenCircles = buildSvg
  [ elem Circle [ F.cx 80.0, F.cy 150.0, F.r 30.0, F.fill "green" ] []
  , elem Circle [ F.cx 200.0, F.cy 150.0, F.r 30.0, F.fill "green" ] []
  , elem Circle [ F.cx 320.0, F.cy 150.0, F.r 30.0, F.fill "green" ] []
  ]

-- =============================================================================
-- Step 3: Three Colored Circles (data-driven)
-- =============================================================================

type ColorCircle = { color :: String, x :: Number }

colorCircles :: Array ColorCircle
colorCircles =
  [ { color: "red", x: 80.0 }
  , { color: "green", x: 200.0 }
  , { color: "blue", x: 320.0 }
  ]

step3ColoredCircles :: Tree
step3ColoredCircles = buildSvg
  [ elem Group []
      [ forEach "color-circle" Circle colorCircles _.color \d ->
          elem Circle
            [ F.cx d.x
            , F.cy 150.0
            , F.r 30.0
            , F.fill d.color
            ]
            []
      ]
  ]

-- =============================================================================
-- Step 4: Parabola (no axes)
-- =============================================================================

type ParabolaPoint = { x :: Number, y :: Number }

parabolaData :: Array ParabolaPoint
parabolaData = range 0 9 <#> \i ->
  let x = toNumber i
  in { x, y: x * x }

-- Scale helpers for parabola
scaleParabolaX :: Number -> Number
scaleParabolaX x = 50.0 + x * 35.0  -- 0-9 maps to 50-365

scaleParabolaY :: Number -> Number
scaleParabolaY y = 280.0 - y * 3.0  -- 0-81 maps to 280-37

step4ParabolaBasic :: Tree
step4ParabolaBasic = buildSvg
  [ elem Group []
      [ forEach "parabola-point" Circle parabolaData (show <<< _.x) \d ->
          elem Circle
            [ F.cx (scaleParabolaX d.x)
            , F.cy (scaleParabolaY d.y)
            , F.r 8.0
            , F.fill "green"
            ]
            []
      ]
  ]

-- =============================================================================
-- Step 5: Parabola with Axes
-- =============================================================================

step5ParabolaAxes :: Tree
step5ParabolaAxes = buildSvg
  [ -- X axis
    elem Line
      [ F.x1 50.0, F.y1 280.0, F.x2 380.0, F.y2 280.0
      , F.stroke "#333", F.strokeWidth 1.0
      ]
      []
  -- Y axis
  , elem Line
      [ F.x1 50.0, F.y1 280.0, F.x2 50.0, F.y2 30.0
      , F.stroke "#333", F.strokeWidth 1.0
      ]
      []
  -- Data points
  , elem Group []
      [ forEach "parabola-point" Circle parabolaData (show <<< _.x) \d ->
          elem Circle
            [ F.cx (scaleParabolaX d.x)
            , F.cy (scaleParabolaY d.y)
            , F.r 8.0
            , F.fill "green"
            ]
            []
      ]
  ]

-- =============================================================================
-- Step 6: Parabola with Labels
-- =============================================================================

step6ParabolaLabels :: Tree
step6ParabolaLabels = buildSvg
  [ -- X axis
    elem Line
      [ F.x1 50.0, F.y1 280.0, F.x2 380.0, F.y2 280.0
      , F.stroke "#333", F.strokeWidth 1.0
      ]
      []
  -- Y axis
  , elem Line
      [ F.x1 50.0, F.y1 280.0, F.x2 50.0, F.y2 30.0
      , F.stroke "#333", F.strokeWidth 1.0
      ]
      []
  -- X label
  , elem Text
      [ F.x 200.0, F.y 295.0
      , F.textAnchor "middle"
      , F.fontSize "14px"
      , F.attr "textContent" "x"
      ]
      []
  -- Y label
  , elem Text
      [ F.x 20.0, F.y 150.0
      , F.textAnchor "middle"
      , F.fontSize "14px"
      , F.attr "transform" "rotate(-90, 20, 150)"
      , F.attr "textContent" "x²"
      ]
      []
  -- Data points
  , elem Group []
      [ forEach "parabola-point" Circle parabolaData (show <<< _.x) \d ->
          elem Circle
            [ F.cx (scaleParabolaX d.x)
            , F.cy (scaleParabolaY d.y)
            , F.r 8.0
            , F.fill "green"
            ]
            []
      ]
  ]

-- =============================================================================
-- Anscombe's Quartet Data
-- =============================================================================

type AnscombePoint = { x :: Number, y :: Number }

anscombeA :: Array AnscombePoint
anscombeA =
  [ {x: 10.0, y: 8.04}, {x: 8.0, y: 6.95}, {x: 13.0, y: 7.58}
  , {x: 9.0, y: 8.81}, {x: 11.0, y: 8.33}, {x: 14.0, y: 9.96}
  , {x: 6.0, y: 7.24}, {x: 4.0, y: 4.26}, {x: 12.0, y: 10.84}
  , {x: 7.0, y: 4.82}, {x: 5.0, y: 5.68}
  ]

anscombeB :: Array AnscombePoint
anscombeB =
  [ {x: 10.0, y: 9.14}, {x: 8.0, y: 8.14}, {x: 13.0, y: 8.74}
  , {x: 9.0, y: 8.77}, {x: 11.0, y: 9.26}, {x: 14.0, y: 8.10}
  , {x: 6.0, y: 6.13}, {x: 4.0, y: 3.10}, {x: 12.0, y: 9.13}
  , {x: 7.0, y: 7.26}, {x: 5.0, y: 4.74}
  ]

anscombeC :: Array AnscombePoint
anscombeC =
  [ {x: 10.0, y: 7.46}, {x: 8.0, y: 6.77}, {x: 13.0, y: 12.74}
  , {x: 9.0, y: 7.11}, {x: 11.0, y: 7.81}, {x: 14.0, y: 8.84}
  , {x: 6.0, y: 6.08}, {x: 4.0, y: 5.39}, {x: 12.0, y: 8.15}
  , {x: 7.0, y: 6.42}, {x: 5.0, y: 5.73}
  ]

anscombeD :: Array AnscombePoint
anscombeD =
  [ {x: 8.0, y: 6.58}, {x: 8.0, y: 5.76}, {x: 8.0, y: 7.71}
  , {x: 8.0, y: 8.84}, {x: 8.0, y: 8.47}, {x: 8.0, y: 7.04}
  , {x: 8.0, y: 5.25}, {x: 19.0, y: 12.50}, {x: 8.0, y: 5.56}
  , {x: 8.0, y: 7.91}, {x: 8.0, y: 6.89}
  ]

-- Scale helpers for Anscombe
scaleAnscombeX :: Number -> Number
scaleAnscombeX x = 30.0 + (x - 4.0) * 20.0  -- 4-19 maps to 30-330

scaleAnscombeY :: Number -> Number
scaleAnscombeY y = 280.0 - (y - 3.0) * 20.0  -- 3-13 maps to 280-80

-- =============================================================================
-- Step 7: Anscombe Single (Dataset A)
-- =============================================================================

step7AnscombeSingle :: Tree
step7AnscombeSingle = buildSvg
  [ -- Axes
    elem Line [ F.x1 30.0, F.y1 280.0, F.x2 350.0, F.y2 280.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  , elem Line [ F.x1 30.0, F.y1 280.0, F.x2 30.0, F.y2 60.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  -- Data points
  , elem Group []
      [ forEach "anscombe-a" Circle anscombeA (\d -> show d.x <> "-" <> show d.y) \d ->
          elem Circle
            [ F.cx (scaleAnscombeX d.x)
            , F.cy (scaleAnscombeY d.y)
            , F.r 5.0
            , F.fill "steelblue"
            ]
            []
      ]
  ]

-- =============================================================================
-- Step 8: Anscombe Small Multiples (2x2 grid)
-- =============================================================================

type DatasetWithPos = { dataset :: Array AnscombePoint, offsetX :: Number, offsetY :: Number, label :: String }

allDatasets :: Array DatasetWithPos
allDatasets =
  [ { dataset: anscombeA, offsetX: 0.0, offsetY: 0.0, label: "A" }
  , { dataset: anscombeB, offsetX: 200.0, offsetY: 0.0, label: "B" }
  , { dataset: anscombeC, offsetX: 0.0, offsetY: 150.0, label: "C" }
  , { dataset: anscombeD, offsetX: 200.0, offsetY: 150.0, label: "D" }
  ]

step8AnscombeQuartet :: Tree
step8AnscombeQuartet =
  elem SVG
    [ F.width 420.0
    , F.height 320.0
    , F.viewBox 0.0 0.0 420.0 320.0
    , F.class_ "scrolly-viz-svg"
    ]
    [ forEach "quartet-panel" Group allDatasets _.label \panel ->
        elem Group
          [ F.attr "transform" ("translate(" <> show panel.offsetX <> "," <> show panel.offsetY <> ")") ]
          [ -- Mini axes
            elem Line [ F.x1 20.0, F.y1 130.0, F.x2 180.0, F.y2 130.0, F.stroke "#ccc", F.strokeWidth 0.5 ] []
          , elem Line [ F.x1 20.0, F.y1 130.0, F.x2 20.0, F.y2 20.0, F.stroke "#ccc", F.strokeWidth 0.5 ] []
          -- Label
          , elem Text [ F.x 100.0, F.y 145.0, F.textAnchor "middle", F.fontSize "12px", F.attr "textContent" panel.label ] []
          -- Points (scaled to mini panel)
          , forEach ("panel-" <> panel.label) Circle panel.dataset (\d -> show d.x <> "-" <> show d.y) \d ->
              elem Circle
                [ F.cx (20.0 + (d.x - 4.0) * 10.0)
                , F.cy (130.0 - (d.y - 3.0) * 10.0)
                , F.r 3.0
                , F.fill "steelblue"
                ]
                []
          ]
    ]

-- =============================================================================
-- Step 9: Anscombe Overlay (all 4 with colors)
-- =============================================================================

type ColoredDataset = { points :: Array AnscombePoint, color :: String }

coloredDatasets :: Array ColoredDataset
coloredDatasets =
  [ { points: anscombeA, color: "red" }
  , { points: anscombeB, color: "blue" }
  , { points: anscombeC, color: "green" }
  , { points: anscombeD, color: "purple" }
  ]

step9AnscombeOverlay :: Tree
step9AnscombeOverlay = buildSvg
  [ -- Axes
    elem Line [ F.x1 30.0, F.y1 280.0, F.x2 350.0, F.y2 280.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  , elem Line [ F.x1 30.0, F.y1 280.0, F.x2 30.0, F.y2 60.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  -- All datasets overlaid
  , forEach "overlay-dataset" Group coloredDatasets _.color \ds ->
      elem Group []
        [ forEach ("overlay-" <> ds.color) Circle ds.points (\d -> show d.x <> "-" <> show d.y) \d ->
            elem Circle
              [ F.cx (scaleAnscombeX d.x)
              , F.cy (scaleAnscombeY d.y)
              , F.r 5.0
              , F.fill ds.color
              , F.opacity "0.7"
              ]
              []
        ]
  ]

-- =============================================================================
-- Multi-line chart data (synthetic unemployment-like data for 45 metro areas)
-- =============================================================================

type LinePoint = { month :: Number, rate :: Number }
type Series = { name :: String, points :: Array LinePoint }

-- Generate 45 synthetic series to match the visual density of the real BLS data
-- Each series has a base rate, a recession spike around month 80-100, and some variation
sampleSeries :: Array Series
sampleSeries = range 0 44 <#> \i ->
  let
    baseRate = 3.5 + toNumber (i `mod` 8) * 0.8  -- Base rates from 3.5 to 9.1
    volatility = 0.3 + toNumber (i `mod` 5) * 0.15  -- Different volatilities
    recessionPeak = 2.0 + toNumber (i `mod` 6) * 0.5  -- How much they spike in recession
    phaseShift = toNumber (i `mod` 12)  -- Offset the patterns
  in { name: "Metro " <> show (i + 1)
     , points: range 0 165 <#> \m ->  -- 166 months like original
         let
           month = toNumber m
           -- Recession spike centered around month 90 (2008-ish)
           recessionFactor = recessionPeak * exp (-(((month - 90.0) * (month - 90.0)) / 400.0))
           -- Gradual improvement after recession
           recoveryFactor = if month > 100.0 then (month - 100.0) * 0.015 else 0.0
           -- Seasonal variation
           seasonal = volatility * sin ((month + phaseShift) * 0.5)
           -- Calculate rate (clamped to realistic bounds)
           rate = max 2.5 $ min 15.0 $ baseRate + recessionFactor - recoveryFactor + seasonal
         in { month, rate }
     }

-- Generate SVG path d attribute for a line
linePath :: Array LinePoint -> String
linePath points =
  case uncons points of
    Nothing -> ""
    Just { head: p, tail: rest } ->
      "M" <> show (scaleLineX p.month) <> " " <> show (scaleLineY p.rate) <>
      foldl (\acc pt -> acc <> " L" <> show (scaleLineX pt.month) <> " " <> show (scaleLineY pt.rate)) "" rest

scaleLineX :: Number -> Number
scaleLineX m = 50.0 + m * 2.0  -- 0-165 maps to 50-380

scaleLineY :: Number -> Number
scaleLineY r = 280.0 - (r - 2.0) * 17.0  -- 2-15 maps to 280-59

-- =============================================================================
-- Step 10: Multi-line Basic (all gray)
-- =============================================================================

step10MultiLineBasic :: Tree
step10MultiLineBasic = buildSvg
  [ -- Axes
    elem Line [ F.x1 50.0, F.y1 280.0, F.x2 380.0, F.y2 280.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  , elem Line [ F.x1 50.0, F.y1 280.0, F.x2 50.0, F.y2 60.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  -- Lines (all gray)
  , forEach "line-series" Path sampleSeries _.name \s ->
      elem Path
        [ F.d (linePath s.points)
        , F.stroke "#999"
        , F.strokeWidth 1.5
        , F.fill "none"
        , F.class_ "data-line"
        ]
        []
  ]

-- =============================================================================
-- Step 11: Multi-line with Hover (same visual, hover via CSS)
-- =============================================================================

step11MultiLineHover :: Tree
step11MultiLineHover = buildSvg
  [ -- Axes
    elem Line [ F.x1 50.0, F.y1 280.0, F.x2 380.0, F.y2 280.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  , elem Line [ F.x1 50.0, F.y1 280.0, F.x2 50.0, F.y2 60.0, F.stroke "#333", F.strokeWidth 1.0 ] []
  -- Lines (with hover class for CSS interaction)
  , forEach "line-series" Path sampleSeries _.name \s ->
      elem Path
        [ F.d (linePath s.points)
        , F.stroke "#bbb"
        , F.strokeWidth 1.5
        , F.fill "none"
        , F.class_ "data-line hoverable"
        , F.attr "data-series" s.name
        ]
        []
  ]
