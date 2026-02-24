-- | Donut Chart - Acceptance Rate Visualization (HATS Version)
-- |
-- | Shows the famous 44% male vs 35% female acceptance rates
-- | that triggered the Berkeley discrimination investigation.
module D3.Viz.Simpsons.DonutChart
  ( donutChartTree
  , DonutConfig
  , defaultConfig
  ) where

import Prelude

import D3.Viz.Simpsons.Pie (PieSlice, pie)
import D3.Viz.Simpsons.Types (black, blue, red)
import Data.Array (mapWithIndex)
import Data.Int (round) as Int
import Data.Number (cos, sin)
import Hylograph.Internal.FFI (ArcGenerator_, arcGenerator_, arcPath_, setArcInnerRadius_, setArcOuterRadius_)
import Hylograph.Internal.Types (Datum_)
import Hylograph.HATS (Tree, elem, forEach, staticStr, staticNum, thunkedStr)
import Hylograph.Internal.Selection.Types (ElementType(..))
import Unsafe.Coerce (unsafeCoerce)

-- =============================================================================
-- Configuration
-- =============================================================================

type DonutConfig =
  { outerRadius :: Number
  , innerRadius :: Number
  , centerX :: Number
  , centerY :: Number
  }

defaultConfig :: DonutConfig
defaultConfig =
  { outerRadius: 60.0
  , innerRadius: 40.0
  , centerX: 70.0
  , centerY: 70.0
  }

-- =============================================================================
-- Data Types
-- =============================================================================

type SliceData =
  { label :: String    -- "accepted" or "rejected"
  , percent :: Number  -- 0-100
  }

type IndexedSlice = { index :: Int, slice :: PieSlice SliceData }

-- =============================================================================
-- Arc Generator Helpers
-- =============================================================================

configureArc :: Number -> Number -> ArcGenerator_
configureArc innerR outerR =
  setArcOuterRadius_
    (setArcInnerRadius_ (arcGenerator_ unit) innerR)
    outerR

sliceToDatum :: PieSlice SliceData -> Datum_
sliceToDatum slice = unsafeCoerce
  { startAngle: slice.startAngle
  , endAngle: slice.endAngle
  }

arcCentroid :: Number -> Number -> PieSlice SliceData -> { x :: Number, y :: Number }
arcCentroid innerR outerR slice =
  let
    midAngle = (slice.startAngle + slice.endAngle) / 2.0 - 1.5707963267948966
    midRadius = (innerR + outerR) / 2.0
  in
    { x: midRadius * cos midAngle
    , y: midRadius * sin midAngle
    }

sliceColor :: String -> String
sliceColor "accepted" = blue
sliceColor "rejected" = red
sliceColor _ = "#999"

-- =============================================================================
-- HATS Donut Chart Tree
-- =============================================================================

-- | Create a donut chart HATS tree
donutChartTree :: DonutConfig -> Number -> String -> Tree
donutChartTree config acceptedPercent label =
  let
    sliceData :: Array SliceData
    sliceData =
      [ { label: "rejected", percent: 100.0 - acceptedPercent }
      , { label: "accepted", percent: acceptedPercent }
      ]
    slices = pie _.percent sliceData
    indexedSlices = mapWithIndex (\i s -> { index: i, slice: s }) slices
    arcGen = configureArc config.innerRadius config.outerRadius
    svgWidth = config.centerX * 2.0
    svgHeight = config.centerY + config.outerRadius + 30.0
  in
    elem SVG
      [ staticNum "width" svgWidth
      , staticNum "height" svgHeight
      , staticStr "viewBox" ("0 0 " <> show svgWidth <> " " <> show svgHeight)
      , staticStr "class" "donut-chart"
      ]
      [ elem Group
          [ staticStr "transform" ("translate(" <> show config.centerX <> "," <> show config.centerY <> ")") ]
          [ -- Arcs
            forEach "arcs" Group indexedSlices (\is -> show is.index) \{ slice } ->
              let
                centroid = arcCentroid config.innerRadius config.outerRadius slice
              in
                elem Group [ staticStr "class" "arc" ]
                  [ elem Path
                      [ thunkedStr "d" (arcPath_ arcGen (sliceToDatum slice))
                      , thunkedStr "fill" (sliceColor slice.datum.label)
                      , staticStr "stroke" black
                      , staticNum "stroke-width" 1.0
                      ] []
                  , elem Text
                      [ staticStr "transform" ("translate(" <> show centroid.x <> "," <> show centroid.y <> ")")
                      , staticStr "dy" "0.35em"
                      , staticStr "text-anchor" "middle"
                      , staticStr "fill" black
                      , staticNum "font-size" 12.0
                      , thunkedStr "textContent" (show (Int.round slice.datum.percent) <> "%")
                      ] []
                  ]

          -- Center label
          , elem Text
              [ staticStr "dy" "0.35em"
              , staticStr "text-anchor" "middle"
              , staticStr "fill" black
              , staticNum "font-size" 14.0
              , staticStr "transform" ("translate(0," <> show (config.outerRadius + 20.0) <> ")")
              , staticStr "textContent" label
              ] []
          ]
      ]
