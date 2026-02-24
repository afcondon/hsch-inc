-- | Data Table with Bar Charts and Mini Donuts (HATS Version)
-- |
-- | Displays department-level statistics with:
-- | - Small bar charts showing applied/admitted counts
-- | - Mini donut charts showing acceptance rates
-- | - Highlight ring on donut when that gender has higher rate
module D3.Viz.Simpsons.DataTable
  ( initDataTable
  , updateDataTable
  , barChartTree
  , miniDonutTree
  , defaultBarConfig
  , defaultMiniDonutConfig
  , TableRowData
  , buildRowData
  , BarConfig
  , MiniDonutConfig
  ) where

import Prelude

import D3.Viz.Simpsons.Pie (PieSlice, pie)
import D3.Viz.Simpsons.Types (DerivedData, Gender(..), blue, gray, green, population, purple, rates, red)
import Data.Array (mapWithIndex)
import Data.Int (round, toNumber) as Int
import Data.Number (cos, sin)
import Data.Traversable (for_)
import Effect (Effect)
import Hylograph.Internal.FFI (ArcGenerator_, arcGenerator_, arcPath_, setArcInnerRadius_, setArcOuterRadius_)
import Hylograph.Internal.Types (Datum_)
import Hylograph.HATS (Tree, elem, staticStr, staticNum, thunkedStr, thunkedNum)
import Hylograph.HATS.InterpreterTick (rerender, clearContainer)
import Hylograph.Internal.Selection.Types (ElementType(..))
import Unsafe.Coerce (unsafeCoerce)

-- =============================================================================
-- Configuration
-- =============================================================================

type BarConfig =
  { width :: Number
  , height :: Number
  , maxValue :: Number
  }

defaultBarConfig :: BarConfig
defaultBarConfig =
  { width: 50.0
  , height: 20.0
  , maxValue: Int.toNumber population.male
  }

type MiniDonutConfig =
  { size :: Number
  , outerRadius :: Number
  , innerRadius :: Number
  , highlightRadius :: Number
  , labelSize :: Number
  }

defaultMiniDonutConfig :: MiniDonutConfig
defaultMiniDonutConfig =
  { size: 85.0
  , outerRadius: 85.0 / 2.3
  , innerRadius: 85.0 / 2.3 - 10.0
  , highlightRadius: 85.0 / 2.1
  , labelSize: 12.0
  }

-- =============================================================================
-- Arc Generator Helpers
-- =============================================================================

configureArc :: Number -> Number -> ArcGenerator_
configureArc innerR outerR =
  setArcOuterRadius_
    (setArcInnerRadius_ (arcGenerator_ unit) innerR)
    outerR

type SliceData =
  { label :: String
  , percent :: Number
  }

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
-- HATS Bar Chart Tree
-- =============================================================================

barChartTree :: BarConfig -> Number -> Gender -> Tree
barChartTree config value gender =
  let
    barWidth = (value / config.maxValue) * config.width
    fillColor = case gender of
      Male -> purple
      Female -> green
  in
    elem SVG
      [ staticNum "width" config.width
      , staticNum "height" config.height
      , staticStr "viewBox" ("0 0 " <> show config.width <> " " <> show config.height)
      , staticStr "class" "bar-chart-svg"
      ]
      [ elem Rect
          [ staticNum "width" config.width
          , staticNum "height" config.height
          , staticStr "fill" "none"
          , staticStr "stroke" gray
          , staticNum "stroke-width" 2.0
          ] []
      , elem Rect
          [ thunkedNum "width" barWidth
          , staticNum "height" config.height
          , thunkedStr "fill" fillColor
          ] []
      ]

-- =============================================================================
-- HATS Mini Donut Chart Tree
-- =============================================================================

miniDonutTree :: MiniDonutConfig -> Number -> Boolean -> Tree
miniDonutTree config acceptedPercent isWinner =
  let
    sliceData :: Array SliceData
    sliceData =
      [ { label: "rejected", percent: 100.0 - acceptedPercent }
      , { label: "accepted", percent: acceptedPercent }
      ]
    slices = pie _.percent sliceData
    indexedSlices = mapWithIndex (\i s -> { index: i, slice: s }) slices
    arcGen = configureArc config.innerRadius config.outerRadius
    centerX = config.size / 2.0
    centerY = config.size / 2.0
    highlightOpacity = if isWinner then 0.6 else 0.0
  in
    elem SVG
      [ staticNum "width" config.size
      , staticNum "height" config.size
      , staticStr "viewBox" ("0 0 " <> show config.size <> " " <> show config.size)
      , staticStr "class" "mini-donut-svg"
      ]
      [ elem Group
          [ staticStr "transform" ("translate(" <> show centerX <> "," <> show centerY <> ")") ]
          ([ -- Highlight ring
             elem Circle
              [ staticNum "cx" 0.0
              , staticNum "cy" 0.0
              , staticNum "r" config.highlightRadius
              , staticStr "fill" "none"
              , staticStr "stroke" "#333"
              , staticNum "stroke-width" 4.0
              , thunkedNum "stroke-opacity" highlightOpacity
              ] []
           ] <>
           -- Arc slices
           map (\{ slice } ->
             let centroid = arcCentroid config.innerRadius config.outerRadius slice
             in elem Group [ staticStr "class" "arc" ]
                  [ elem Path
                      [ thunkedStr "d" (arcPath_ arcGen (sliceToDatum slice))
                      , thunkedStr "fill" (sliceColor slice.datum.label)
                      , staticStr "stroke" "#2C3E50"
                      , staticNum "stroke-width" 1.0
                      ] []
                  , elem Text
                      [ thunkedNum "x" centroid.x
                      , thunkedNum "y" centroid.y
                      , staticStr "text-anchor" "middle"
                      , staticNum "font-size" config.labelSize
                      , staticStr "fill" "#34495e"
                      , thunkedStr "textContent" (show (Int.round slice.datum.percent) <> "%")
                      ] []
                  ]
           ) indexedSlices)
      ]

-- =============================================================================
-- Table Row Data
-- =============================================================================

type TableRowData =
  { department :: String
  , maleApplied :: Number
  , femaleApplied :: Number
  , maleAdmitted :: Number
  , femaleAdmitted :: Number
  , maleRate :: Number
  , femaleRate :: Number
  , maleWins :: Boolean
  , femaleWins :: Boolean
  }

buildRowData :: DerivedData -> Array TableRowData
buildRowData derived =
  let
    easyMaleRate = rates.male.easy * 100.0
    easyFemaleRate = rates.female.easy * 100.0
    hardMaleRate = rates.male.hard * 100.0
    hardFemaleRate = rates.female.hard * 100.0
    combinedMaleRate = derived.combined.male * 100.0
    combinedFemaleRate = derived.combined.female * 100.0

    combinedMaleApplied = derived.departments.easy.male.applied + derived.departments.hard.male.applied
    combinedFemaleApplied = derived.departments.easy.female.applied + derived.departments.hard.female.applied
    combinedMaleAdmitted = derived.departments.easy.male.admitted + derived.departments.hard.male.admitted
    combinedFemaleAdmitted = derived.departments.easy.female.admitted + derived.departments.hard.female.admitted
  in
    [ { department: "\"Easy\""
      , maleApplied: derived.departments.easy.male.applied
      , femaleApplied: derived.departments.easy.female.applied
      , maleAdmitted: derived.departments.easy.male.admitted
      , femaleAdmitted: derived.departments.easy.female.admitted
      , maleRate: easyMaleRate
      , femaleRate: easyFemaleRate
      , maleWins: easyMaleRate > easyFemaleRate
      , femaleWins: easyFemaleRate > easyMaleRate
      }
    , { department: "\"Hard\""
      , maleApplied: derived.departments.hard.male.applied
      , femaleApplied: derived.departments.hard.female.applied
      , maleAdmitted: derived.departments.hard.male.admitted
      , femaleAdmitted: derived.departments.hard.female.admitted
      , maleRate: hardMaleRate
      , femaleRate: hardFemaleRate
      , maleWins: hardMaleRate > hardFemaleRate
      , femaleWins: hardFemaleRate > hardMaleRate
      }
    , { department: "Combined"
      , maleApplied: combinedMaleApplied
      , femaleApplied: combinedFemaleApplied
      , maleAdmitted: combinedMaleAdmitted
      , femaleAdmitted: combinedFemaleAdmitted
      , maleRate: combinedMaleRate
      , femaleRate: combinedFemaleRate
      , maleWins: combinedMaleRate > combinedFemaleRate
      , femaleWins: combinedFemaleRate > combinedMaleRate
      }
    ]

-- =============================================================================
-- Rendering Functions
-- =============================================================================

-- | Initialize the data table (render all SVG elements)
initDataTable :: DerivedData -> Effect Unit
initDataTable derived = do
  let rows = buildRowData derived
  -- Render each row's SVG elements
  for_ (mapWithIndex (\i row -> { idx: i, row }) rows) \{ idx, row } -> do
    let prefix = "#row-" <> show idx
    -- Bar charts
    _ <- rerender (prefix <> "-male-applied") (barChartTree defaultBarConfig row.maleApplied Male)
    _ <- rerender (prefix <> "-female-applied") (barChartTree defaultBarConfig row.femaleApplied Female)
    _ <- rerender (prefix <> "-male-admitted") (barChartTree defaultBarConfig row.maleAdmitted Male)
    _ <- rerender (prefix <> "-female-admitted") (barChartTree defaultBarConfig row.femaleAdmitted Female)
    -- Donut charts
    _ <- rerender (prefix <> "-male-rate") (miniDonutTree defaultMiniDonutConfig row.maleRate row.maleWins)
    _ <- rerender (prefix <> "-female-rate") (miniDonutTree defaultMiniDonutConfig row.femaleRate row.femaleWins)
    pure unit

-- | Update the data table (re-render SVG elements with new data)
updateDataTable :: DerivedData -> Effect Unit
updateDataTable derived = do
  let rows = buildRowData derived
  -- Clear and re-render each row's SVG elements
  for_ (mapWithIndex (\i row -> { idx: i, row }) rows) \{ idx, row } -> do
    let prefix = "#row-" <> show idx
    -- Clear all containers first
    clearContainer (prefix <> "-male-applied")
    clearContainer (prefix <> "-female-applied")
    clearContainer (prefix <> "-male-admitted")
    clearContainer (prefix <> "-female-admitted")
    clearContainer (prefix <> "-male-rate")
    clearContainer (prefix <> "-female-rate")
    -- Then re-render
    _ <- rerender (prefix <> "-male-applied") (barChartTree defaultBarConfig row.maleApplied Male)
    _ <- rerender (prefix <> "-female-applied") (barChartTree defaultBarConfig row.femaleApplied Female)
    _ <- rerender (prefix <> "-male-admitted") (barChartTree defaultBarConfig row.maleAdmitted Male)
    _ <- rerender (prefix <> "-female-admitted") (barChartTree defaultBarConfig row.femaleAdmitted Female)
    _ <- rerender (prefix <> "-male-rate") (miniDonutTree defaultMiniDonutConfig row.maleRate row.maleWins)
    _ <- rerender (prefix <> "-female-rate") (miniDonutTree defaultMiniDonutConfig row.femaleRate row.femaleWins)
    pure unit
