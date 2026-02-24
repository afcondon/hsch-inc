-- | Interactive Paradox Card Component
-- |
-- | A self-contained Halogen component that displays a Simpson's Paradox
-- | dataset with interactive sliders, visualization, and data table.
-- | Each card has its own state for slider values.
-- | Uses pure Halogen SVG for chart rendering.
module D3.Viz.Simpsons.InteractiveParadoxCard
  ( component
  , Input
  , Output
  , Query
  , Slot
  ) where

import Prelude

import D3.Viz.Simpsons.Dataset (Dataset)
import Data.Int (round)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (fromString) as Number
import Data.Number.Format (fixed, toStringWith)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA
import Halogen.Svg.Attributes (Color(..))
import Halogen.HTML.Core (AttrName(..))
import Halogen.HTML.Properties (attr)

-- =============================================================================
-- Types
-- =============================================================================

-- | Input is just the dataset
type Input = Dataset

-- | No output (the component is self-contained)
type Output = Void

-- | Query (unused for now)
data Query a = GetSliderValues (SliderState -> a)

-- | Slot type alias for parent components
type Slot = H.Slot Query Void

-- | Internal state
type State =
  { dataset :: Dataset
  , sliderA :: Number  -- % in row2 for group A (0-100)
  , sliderB :: Number  -- % in row2 for group B (0-100)
  }

-- | Actions
data Action
  = Initialize
  | SetSliderA Number
  | SetSliderB Number
  | ResetSliders

-- | Slider state (for queries)
type SliderState = { a :: Number, b :: Number }

-- =============================================================================
-- Component
-- =============================================================================

component :: forall m. MonadAff m => H.Component Query Input Output m
component = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

initialState :: Input -> State
initialState dataset =
  { dataset
  , sliderA: dataset.initialLv.a
  , sliderB: dataset.initialLv.b
  }

-- =============================================================================
-- Render
-- =============================================================================

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  let
    d = state.dataset

    -- Calculate rates from dataset (outcome/count as percentage)
    row1RateA = if d.row1.countA > 0.0 then d.row1.outcomeA / d.row1.countA * 100.0 else 0.0
    row1RateB = if d.row1.countB > 0.0 then d.row1.outcomeB / d.row1.countB * 100.0 else 0.0
    row2RateA = if d.row2.countA > 0.0 then d.row2.outcomeA / d.row2.countA * 100.0 else 0.0
    row2RateB = if d.row2.countB > 0.0 then d.row2.outcomeB / d.row2.countB * 100.0 else 0.0

    -- Current combined rates based on slider positions
    fracInRow2_A = state.sliderA / 100.0
    fracInRow2_B = state.sliderB / 100.0
    combinedRateA = row1RateA * (1.0 - fracInRow2_A) + row2RateA * fracInRow2_A
    combinedRateB = row1RateB * (1.0 - fracInRow2_B) + row2RateB * fracInRow2_B

    -- Is paradox present with current slider values?
    aBetterInRow1 = row1RateA > row1RateB
    aBetterInRow2 = row2RateA > row2RateB
    aBetterCombined = combinedRateA > combinedRateB
    isParadox = (aBetterInRow1 && aBetterInRow2 && not aBetterCombined)
             || (not aBetterInRow1 && not aBetterInRow2 && aBetterCombined)
  in
    HH.article
      [ HP.classes [ HH.ClassName "interactive-card" ] ]
      [ -- Header
        HH.header
          [ HP.classes [ HH.ClassName "interactive-card-header" ] ]
          [ HH.h3_ [ HH.text d.title ]
          , HH.p
              [ HP.classes [ HH.ClassName "interactive-card-description" ] ]
              [ HH.text d.description ]
          ]

      -- Body: Sliders (left) + Chart (right)
      , HH.div
          [ HP.classes [ HH.ClassName "interactive-card-body" ] ]
          [ -- Left: Sliders and controls
            HH.div
              [ HP.classes [ HH.ClassName "interactive-card-sliders" ] ]
              [ renderSlider d.colALabel state.sliderA colorA SetSliderA
              , renderSlider d.colBLabel state.sliderB colorB SetSliderB
              -- Reset button
              , HH.div
                  [ HP.classes [ HH.ClassName "interactive-card-controls" ] ]
                  [ HH.button
                      [ HP.classes [ HH.ClassName "reset-button" ]
                      , HE.onClick \_ -> ResetSliders
                      ]
                      [ HH.text "Reset" ]
                  ]
              -- Paradox indicator
              , HH.div
                  [ HP.classes
                      [ HH.ClassName "paradox-indicator"
                      , HH.ClassName (if isParadox then "is-paradox" else "no-paradox")
                      ]
                  ]
                  [ HH.strong_ [ HH.text "Paradox: " ]
                  , HH.text (if isParadox then "Yes" else "No")
                  ]
              ]

          -- Right: Chart (rendered directly in Halogen SVG)
          , HH.div
              [ HP.classes [ HH.ClassName "interactive-card-chart" ] ]
              [ renderChart state ]
          ]

      -- Footer with source
      , HH.footer
          [ HP.classes [ HH.ClassName "interactive-card-footer" ] ]
          [ HH.cite_ [ HH.text d.source ] ]
      ]

-- | Colors (purple for A, green for B - matching the original)
colorA :: String
colorA = "#7b3294"

colorB :: String
colorB = "#008837"

-- =============================================================================
-- Chart Rendering (Pure Halogen SVG)
-- =============================================================================

-- | Chart configuration
type ChartConfig =
  { width :: Number
  , height :: Number
  , marginTop :: Number
  , marginRight :: Number
  , marginBottom :: Number
  , marginLeft :: Number
  }

defaultChartConfig :: ChartConfig
defaultChartConfig =
  { width: 280.0
  , height: 220.0
  , marginTop: 20.0
  , marginRight: 15.0
  , marginBottom: 45.0
  , marginLeft: 50.0
  }

-- | Render the chart entirely in Halogen SVG
renderChart :: forall m. State -> H.ComponentHTML Action () m
renderChart state =
  let
    d = state.dataset
    config = defaultChartConfig
    iw = config.width - config.marginLeft - config.marginRight
    ih = config.height - config.marginTop - config.marginBottom

    -- Calculate rates from dataset
    row1RateA = if d.row1.countA > 0.0 then d.row1.outcomeA / d.row1.countA * 100.0 else 0.0
    row1RateB = if d.row1.countB > 0.0 then d.row1.outcomeB / d.row1.countB * 100.0 else 0.0
    row2RateA = if d.row2.countA > 0.0 then d.row2.outcomeA / d.row2.countA * 100.0 else 0.0
    row2RateB = if d.row2.countB > 0.0 then d.row2.outcomeB / d.row2.countB * 100.0 else 0.0

    -- Scale functions
    scaleX v = config.marginLeft + (v / 100.0) * iw
    scaleY v = config.marginTop + ih - (v / 100.0) * ih

    -- Line paths for rate lines
    lineA = "M " <> showN (scaleX 0.0) <> " " <> showN (scaleY row1RateA) <> " L " <> showN (scaleX 100.0) <> " " <> showN (scaleY row2RateA)
    lineB = "M " <> showN (scaleX 0.0) <> " " <> showN (scaleY row1RateB) <> " L " <> showN (scaleX 100.0) <> " " <> showN (scaleY row2RateB)

    -- Dynamic points based on slider values
    fracA = state.sliderA / 100.0
    fracB = state.sliderB / 100.0
    combinedRateA = row1RateA * (1.0 - fracA) + row2RateA * fracA
    combinedRateB = row1RateB * (1.0 - fracB) + row2RateB * fracB
    ptA_x = scaleX state.sliderA
    ptA_y = scaleY combinedRateA
    ptB_x = scaleX state.sliderB
    ptB_y = scaleY combinedRateB
  in
    SE.svg
      [ SA.viewBox 0.0 0.0 config.width config.height
      , SA.width (config.width)
      , SA.height (config.height)
      , SA.classes [ HH.ClassName "paradox-chart-svg" ]
      ]
      [ -- Background
        SE.rect
          [ SA.x (config.marginLeft)
          , SA.y (config.marginTop)
          , SA.width (iw)
          , SA.height (ih)
          , SA.fill (Named "#fafafa")
          ]

      -- Grid lines
      , SE.line
          [ SA.x1 (config.marginLeft), SA.y1 (config.marginTop + ih * 0.5)
          , SA.x2 (config.marginLeft + iw), SA.y2 (config.marginTop + ih * 0.5)
          , SA.stroke (Named "#e0e0e0"), SA.strokeWidth 1.0
          ]
      , SE.line
          [ SA.x1 (config.marginLeft + iw * 0.5), SA.y1 (config.marginTop)
          , SA.x2 (config.marginLeft + iw * 0.5), SA.y2 (config.marginTop + ih)
          , SA.stroke (Named "#e0e0e0"), SA.strokeWidth 1.0
          ]

      -- X-axis
      , SE.line
          [ SA.x1 (config.marginLeft), SA.y1 (config.marginTop + ih)
          , SA.x2 (config.marginLeft + iw), SA.y2 (config.marginTop + ih)
          , SA.stroke (Named "#333"), SA.strokeWidth 1.0
          ]

      -- Y-axis
      , SE.line
          [ SA.x1 (config.marginLeft), SA.y1 (config.marginTop)
          , SA.x2 (config.marginLeft), SA.y2 (config.marginTop + ih)
          , SA.stroke (Named "#333"), SA.strokeWidth 1.0
          ]

      -- Rate line A
      , SE.path
          [ attr (AttrName "d") lineA
          , SA.stroke (Named colorA), SA.strokeWidth 2.0
          , SA.fill (Named "none")
          ]

      -- Rate line B
      , SE.path
          [ attr (AttrName "d") lineB
          , SA.stroke (Named colorB), SA.strokeWidth 2.0
          , SA.fill (Named "none")
          ]

      -- Axis label X
      , SE.text
          [ SA.x (config.marginLeft + iw / 2.0), SA.y (config.height - 5.0)
          , SA.textAnchor SA.AnchorMiddle
          , SA.fill (Named "#666")
          ]
          [ HH.text d.axisLabels.x ]

      -- Axis label Y (rotated)
      , SE.text
          [ SA.x (config.marginLeft - 35.0), SA.y (config.marginTop + ih / 2.0)
          , SA.textAnchor SA.AnchorMiddle
          , SA.fill (Named "#666")
          , SA.transform [ SA.Rotate (-90.0) (config.marginLeft - 35.0) (config.marginTop + ih / 2.0) ]
          ]
          [ HH.text d.colGroupLabels.percent ]

      -- Y-axis tick labels
      , SE.text [ SA.x (config.marginLeft - 5.0), SA.y (config.marginTop + ih + 3.0), SA.textAnchor SA.AnchorEnd, SA.fill (Named "#888") ] [ HH.text "0" ]
      , SE.text [ SA.x (config.marginLeft - 5.0), SA.y (config.marginTop + ih * 0.5 + 3.0), SA.textAnchor SA.AnchorEnd, SA.fill (Named "#888") ] [ HH.text "50" ]
      , SE.text [ SA.x (config.marginLeft - 5.0), SA.y (config.marginTop + 3.0), SA.textAnchor SA.AnchorEnd, SA.fill (Named "#888") ] [ HH.text "100" ]

      -- X-axis tick labels
      , SE.text [ SA.x (config.marginLeft), SA.y (config.marginTop + ih + 12.0), SA.textAnchor SA.AnchorMiddle, SA.fill (Named "#888") ] [ HH.text "0" ]
      , SE.text [ SA.x (config.marginLeft + iw), SA.y (config.marginTop + ih + 12.0), SA.textAnchor SA.AnchorMiddle, SA.fill (Named "#888") ] [ HH.text "100" ]

      -- Legend
      , SE.g [ SA.transform [ SA.Translate (config.marginLeft + 5.0) (config.marginTop + 5.0) ] ]
          [ SE.circle [ SA.cx 4.0, SA.cy 0.0, SA.r 3.0, SA.fill (Named colorA) ]
          , SE.text [ SA.x 10.0, SA.y 3.0, SA.fill (Named colorA) ] [ HH.text d.colALabel ]
          , SE.circle [ SA.cx 4.0, SA.cy 12.0, SA.r 3.0, SA.fill (Named colorB) ]
          , SE.text [ SA.x 10.0, SA.y 15.0, SA.fill (Named colorB) ] [ HH.text d.colBLabel ]
          ]

      -- Dynamic guide line A
      , SE.line
          [ SA.x1 (config.marginLeft), SA.y1 ptA_y
          , SA.x2 ptA_x, SA.y2 ptA_y
          , SA.stroke (Named "#333"), SA.strokeWidth 1.0
          , SA.strokeDashArray "3,3"
          , SA.strokeOpacity 0.5
          ]

      -- Dynamic guide line B
      , SE.line
          [ SA.x1 (config.marginLeft), SA.y1 ptB_y
          , SA.x2 ptB_x, SA.y2 ptB_y
          , SA.stroke (Named "#333"), SA.strokeWidth 1.0
          , SA.strokeDashArray "3,3"
          , SA.strokeOpacity 0.5
          ]

      -- Dynamic point A
      , SE.circle
          [ SA.cx ptA_x, SA.cy ptA_y, SA.r 6.0
          , SA.fill (Named colorA)
          , SA.stroke (Named "white"), SA.strokeWidth 2.0
          ]

      -- Dynamic point B
      , SE.circle
          [ SA.cx ptB_x, SA.cy ptB_y, SA.r 6.0
          , SA.fill (Named colorB)
          , SA.stroke (Named "white"), SA.strokeWidth 2.0
          ]

      -- Rate label A
      , SE.text
          [ SA.x (ptA_x + 8.0), SA.y (ptA_y - 5.0)
          , SA.fill (Named colorA)
          ]
          [ HH.text (show (round combinedRateA) <> "%") ]

      -- Rate label B
      , SE.text
          [ SA.x (ptB_x + 8.0), SA.y (ptB_y + 12.0)
          , SA.fill (Named colorB)
          ]
          [ HH.text (show (round combinedRateB) <> "%") ]
      ]

-- | Helper to format numbers for SVG paths
showN :: Number -> String
showN n = toStringWith (fixed 1) n

-- | Render a slider
renderSlider :: forall m. String -> Number -> String -> (Number -> Action) -> H.ComponentHTML Action () m
renderSlider label value color action =
  HH.div
    [ HP.classes [ HH.ClassName "paradox-slider" ] ]
    [ HH.label
        [ HP.style ("color: " <> color) ]
        [ HH.text (label <> " to row 2") ]
    , HH.input
        [ HP.type_ HP.InputRange
        , HP.min 0.0
        , HP.max 100.0
        , HP.value (show (round value))
        , HP.step (HP.Step 1.0)
        , HP.style ("accent-color: " <> color)
        , HE.onValueInput \val ->
            action (fromMaybe value (Number.fromString val))
        ]
    , HH.span_ [ HH.text (show (round value) <> "%") ]
    ]

-- =============================================================================
-- Action Handlers
-- =============================================================================

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Void m Unit
handleAction = case _ of
  Initialize -> pure unit  -- Chart is rendered declaratively, no initialization needed

  SetSliderA value -> H.modify_ _ { sliderA = value }

  SetSliderB value -> H.modify_ _ { sliderB = value }

  ResetSliders -> do
    state <- H.get
    H.modify_ _ { sliderA = state.dataset.initialLv.a
                , sliderB = state.dataset.initialLv.b
                }
