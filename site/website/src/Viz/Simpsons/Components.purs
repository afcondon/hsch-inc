-- | Simple Halogen component wrappers for all Simpson's Paradox visualizations.
-- | Each viz becomes a self-contained component with standard interface.
module D3.Viz.Simpsons.Components
  ( donutChartsComponent
  , lineChartComponent
  , scatterChartComponent
  , dataTableComponent
  , forceVizComponent
  , postscriptCardsComponent
  , illustrationComponent
  , SimpleQuery(..)
  ) where

import Prelude

import Data.Array (mapWithIndex)
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.Number as Number
import Data.Foldable (for_)
import Effect (Effect)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Effect.Aff (Milliseconds(..), delay)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA
import Halogen.Svg.Attributes (Color(..))
import Halogen.HTML.Core (AttrName(..))
import Halogen.HTML.Properties (attr)
import Type.Proxy (Proxy(..))

-- HATS imports
import Hylograph.HATS.InterpreterTick (rerender, clearContainer)

-- Viz implementations
import D3.Viz.Simpsons.ForceViz as ForceViz
import D3.Viz.Simpsons.DonutChart as Donut
import D3.Viz.Simpsons.LineChart as Line
import D3.Viz.Simpsons.ScatterChart as Scatter
import D3.Viz.Simpsons.DataTable as DataTable
import D3.Viz.Simpsons.Types (defaultProportions, deriveData, Proportions, Gender(..), rates, purple, green)
import Data.Number.Format (fixed, toStringWith)

-- InteractiveParadoxCard for postscript
import D3.Viz.Simpsons.InteractiveParadoxCard as Card
import D3.Viz.Simpsons.Datasets as Datasets
import D3.Viz.Simpsons.Dataset (Dataset)

-- =============================================================================
-- Shared Types
-- =============================================================================

data SimpleQuery a = NoQuery a

type SimpleSlots = ()

-- =============================================================================
-- ForceViz Component
-- =============================================================================

type ForceVizState =
  { handle :: Maybe ForceViz.ForceVizHandle
  , isCombined :: Boolean
  }

data ForceVizAction
  = ForceVizInit
  | ForceVizToggle

forceVizComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
forceVizComponent = H.mkComponent
  { initialState: \_ -> { handle: Nothing, isCombined: false }
  , render: renderForceViz
  , eval: H.mkEval H.defaultEval
      { initialize = Just ForceVizInit
      , handleAction = handleForceVizAction
      }
  }

renderForceViz :: forall m. ForceVizState -> H.ComponentHTML ForceVizAction () m
renderForceViz state =
  HH.div
    [ HP.classes [ HH.ClassName "force-viz-section" ] ]
    [ -- Legend / Key
      HH.div
        [ HP.classes [ HH.ClassName "force-viz-legend" ] ]
        [ HH.span [ HP.classes [ HH.ClassName "legend-item", HH.ClassName "legend-accepted" ] ]
            [ HH.span [ HP.classes [ HH.ClassName "legend-dot", HH.ClassName "accepted" ] ] []
            , HH.text "Accepted"
            ]
        , HH.span [ HP.classes [ HH.ClassName "legend-item", HH.ClassName "legend-rejected" ] ]
            [ HH.span [ HP.classes [ HH.ClassName "legend-dot", HH.ClassName "rejected" ] ] []
            , HH.text "Rejected"
            ]
        ]
    -- Toggle button
    , HH.button
        [ HP.classes [ HH.ClassName "simpsons-toggle" ]
        , HE.onClick \_ -> ForceVizToggle
        ]
        [ HH.text if state.isCombined then "Separate by Department" else "Combine All" ]
    -- Container for the D3 visualization
    , HH.div
        [ HP.id "force-viz"
        , HP.classes [ HH.ClassName "force-viz-container" ]
        ]
        []
    -- Combined mode indicator
    , if state.isCombined
        then HH.div
          [ HP.classes [ HH.ClassName "force-viz-combined-label" ] ]
          [ HH.text "Combined: All departments merged" ]
        else HH.text ""
    ]

handleForceVizAction :: forall o m. MonadAff m => ForceVizAction -> H.HalogenM ForceVizState ForceVizAction () o m Unit
handleForceVizAction = case _ of
  ForceVizInit -> do
    liftAff $ delay (Milliseconds 50.0)
    handle <- liftEffect $ ForceViz.initForceViz "#force-viz"
    H.modify_ _ { handle = Just handle }

  ForceVizToggle -> do
    state <- H.get
    case state.handle of
      Just handle -> do
        liftEffect handle.toggle
        H.modify_ _ { isCombined = not state.isCombined }
      Nothing -> pure unit

-- =============================================================================
-- DonutCharts Component
-- =============================================================================

donutChartsComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
donutChartsComponent = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ ->
      HH.div
        [ HP.classes [ HH.ClassName "donut-charts-row" ] ]
        [ HH.div [ HP.id "donut-men", HP.classes [ HH.ClassName "donut-chart" ] ] []
        , HH.div [ HP.id "donut-women", HP.classes [ HH.ClassName "donut-chart" ] ] []
        ]
  , eval: H.mkEval H.defaultEval
      { initialize = Just unit
      , handleAction = \_ -> do
          liftAff $ delay (Milliseconds 50.0)
          liftEffect initDonutCharts
      }
  }
  where
  initDonutCharts :: Effect Unit
  initDonutCharts = do
    _ <- rerender "#donut-men" (Donut.donutChartTree Donut.defaultConfig 44.0 "Men")
    _ <- rerender "#donut-women" (Donut.donutChartTree Donut.defaultConfig 35.0 "Women")
    pure unit

-- =============================================================================
-- LineChart Component
-- =============================================================================

lineChartComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
lineChartComponent = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ ->
      HH.div
        [ HP.id "line-chart"
        , HP.classes [ HH.ClassName "line-chart-container" ]
        ]
        []
  , eval: H.mkEval H.defaultEval
      { initialize = Just unit
      , handleAction = \_ -> do
          liftAff $ delay (Milliseconds 50.0)
          liftEffect initLineChart
      }
  }
  where
  initLineChart :: Effect Unit
  initLineChart = do
    _ <- rerender "#line-chart" (Line.lineChartTree Line.defaultConfig defaultProportions)
    pure unit

-- =============================================================================
-- ScatterChart Component
-- =============================================================================

scatterChartComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
scatterChartComponent = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ ->
      HH.div
        [ HP.id "scatter-chart"
        , HP.classes [ HH.ClassName "scatter-chart-container" ]
        ]
        []
  , eval: H.mkEval H.defaultEval
      { initialize = Just unit
      , handleAction = \_ -> do
          liftAff $ delay (Milliseconds 50.0)
          liftEffect initScatterChart
      }
  }
  where
  initScatterChart :: Effect Unit
  initScatterChart = do
    _ <- rerender "#scatter-chart" (Scatter.scatterChartTree Scatter.defaultConfig)
    pure unit

-- =============================================================================
-- DataTable Component
-- =============================================================================

dataTableComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
dataTableComponent = H.mkComponent
  { initialState: \_ -> deriveData defaultProportions
  , render: renderDataTable
  , eval: H.mkEval H.defaultEval
      { initialize = Just unit
      , handleAction = \_ -> do
          derived <- H.get
          liftAff $ delay (Milliseconds 50.0)
          liftEffect $ DataTable.initDataTable derived
      }
  }
  where
  renderDataTable derived =
    let
      rows = DataTable.buildRowData derived
      renderRow idx row =
        HH.tr_
          [ HH.td [ HP.classes [ HH.ClassName "dept-cell" ] ] [ HH.text row.department ]
          -- Applied bars
          , HH.td_ [ HH.div [ HP.id ("row-" <> show idx <> "-male-applied"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
          , HH.td_ [ HH.div [ HP.id ("row-" <> show idx <> "-female-applied"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
          -- Admitted bars
          , HH.td_ [ HH.div [ HP.id ("row-" <> show idx <> "-male-admitted"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
          , HH.td_ [ HH.div [ HP.id ("row-" <> show idx <> "-female-admitted"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
          -- Rate donuts
          , HH.td_ [ HH.div [ HP.id ("row-" <> show idx <> "-male-rate"), HP.classes [ HH.ClassName "donut-cell" ] ] [] ]
          , HH.td_ [ HH.div [ HP.id ("row-" <> show idx <> "-female-rate"), HP.classes [ HH.ClassName "donut-cell" ] ] [] ]
          ]
    in
      HH.div
        [ HP.id "data-table"
        , HP.classes [ HH.ClassName "data-table-container" ]
        ]
        [ HH.table
            [ HP.classes [ HH.ClassName "simpsons-data-table" ] ]
            [ HH.thead_
                [ HH.tr_
                    [ HH.th_ [ HH.text "Dept." ]
                    , HH.th [ HP.classes [ HH.ClassName "header-group" ] ]
                        [ HH.text "Applied"
                        , HH.div [ HP.classes [ HH.ClassName "subheaders" ] ]
                            [ HH.span [ HP.classes [ HH.ClassName "male" ] ] [ HH.text "M" ]
                            , HH.span [ HP.classes [ HH.ClassName "female" ] ] [ HH.text "F" ]
                            ]
                        ]
                    , HH.th [ HP.classes [ HH.ClassName "header-group" ] ]
                        [ HH.text "Admitted"
                        , HH.div [ HP.classes [ HH.ClassName "subheaders" ] ]
                            [ HH.span [ HP.classes [ HH.ClassName "male" ] ] [ HH.text "M" ]
                            , HH.span [ HP.classes [ HH.ClassName "female" ] ] [ HH.text "F" ]
                            ]
                        ]
                    , HH.th [ HP.classes [ HH.ClassName "header-group" ] ]
                        [ HH.text "Rate"
                        , HH.div [ HP.classes [ HH.ClassName "subheaders" ] ]
                            [ HH.span [ HP.classes [ HH.ClassName "male" ] ] [ HH.text "M" ]
                            , HH.span [ HP.classes [ HH.ClassName "female" ] ] [ HH.text "F" ]
                            ]
                        ]
                    ]
                ]
            , HH.tbody_ (mapWithIndex renderRow rows)
            ]
        ]

-- =============================================================================
-- Illustration Component (Sliders + Line Chart + Data Table)
-- Following InteractiveParadoxCard pattern: sliders left, chart right, table below
-- =============================================================================

type IllustrationState =
  { proportions :: Proportions
  }

data IllustrationAction
  = IllustrationInit
  | UpdateMaleProportion String
  | UpdateFemaleProportion String
  | ResetProportions

illustrationComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
illustrationComponent = H.mkComponent
  { initialState: \_ -> { proportions: defaultProportions }
  , render: renderIllustration
  , eval: H.mkEval H.defaultEval
      { initialize = Just IllustrationInit
      , handleAction = handleIllustrationAction
      }
  }

renderIllustration :: forall m. IllustrationState -> H.ComponentHTML IllustrationAction () m
renderIllustration state =
  let
    derived = deriveData state.proportions
    malePercent = Int.round (state.proportions.easyMale * 100.0)
    femalePercent = Int.round (state.proportions.easyFemale * 100.0)
  in
    HH.div
      [ HP.classes [ HH.ClassName "illustration-section" ] ]
      [ -- Top row: Sliders (left) + Line Chart (right)
        HH.div
          [ HP.classes [ HH.ClassName "illustration-body" ] ]
          [ -- Left: Sliders
            HH.div
              [ HP.classes [ HH.ClassName "illustration-sliders" ] ]
              [ renderIllustrationSlider "Men" malePercent purple UpdateMaleProportion
              , renderIllustrationSlider "Women" femalePercent green UpdateFemaleProportion
              -- Reset button
              , HH.div
                  [ HP.classes [ HH.ClassName "illustration-controls" ] ]
                  [ HH.button
                      [ HP.classes [ HH.ClassName "reset-button" ]
                      , HE.onClick \_ -> ResetProportions
                      ]
                      [ HH.text "Reset" ]
                  ]
              -- Paradox indicator (small, below sliders)
              , HH.div
                  [ HP.classes
                      [ HH.ClassName "paradox-indicator-small"
                      , HH.ClassName if derived.isParadox then "is-paradox" else "no-paradox"
                      ]
                  ]
                  [ HH.strong_ [ HH.text "Paradox: " ]
                  , HH.text if derived.isParadox then "Yes" else "No"
                  ]
              ]
          -- Right: Line Chart (pure Halogen SVG)
          , HH.div
              [ HP.classes [ HH.ClassName "illustration-chart" ] ]
              [ renderIllustrationLineChart state ]
          ]
      -- Bottom: Data table
      , HH.div
          [ HP.id "illustration-table"
          , HP.classes [ HH.ClassName "illustration-table-container" ]
          ]
          [ renderIllustrationTable derived ]
      ]

-- | Render a compact slider (like InteractiveParadoxCard)
renderIllustrationSlider :: forall m. String -> Int -> String -> (String -> IllustrationAction) -> H.ComponentHTML IllustrationAction () m
renderIllustrationSlider label value color action =
  HH.div
    [ HP.classes [ HH.ClassName "paradox-slider" ] ]
    [ HH.label
        [ HP.style ("color: " <> color) ]
        [ HH.text (label <> " to \"Easy\"") ]
    , HH.input
        [ HP.type_ HP.InputRange
        , HP.min 0.0
        , HP.max 100.0
        , HP.value (show value)
        , HP.step (HP.Step 1.0)
        , HP.style ("accent-color: " <> color)
        , HE.onValueInput action
        ]
    , HH.span_ [ HH.text (show value <> "%") ]
    ]

-- | Render line chart using pure Halogen SVG (like InteractiveParadoxCard)
renderIllustrationLineChart :: forall m. IllustrationState -> H.ComponentHTML IllustrationAction () m
renderIllustrationLineChart state =
  let
    config = { width: 280.0, height: 220.0, marginTop: 20.0, marginRight: 15.0, marginBottom: 45.0, marginLeft: 50.0 }
    iw = config.width - config.marginLeft - config.marginRight
    ih = config.height - config.marginTop - config.marginBottom

    -- Scale functions
    scaleX v = config.marginLeft + (v / 100.0) * iw
    scaleY v = config.marginTop + ih - (v / 100.0 * ih)

    -- Rate lines (fixed based on department admission rates)
    menHardRate = rates.male.hard * 100.0
    menEasyRate = rates.male.easy * 100.0
    womenHardRate = rates.female.hard * 100.0
    womenEasyRate = rates.female.easy * 100.0

    -- Line paths
    lineMen = "M " <> showN (scaleX 0.0) <> " " <> showN (scaleY menHardRate) <> " L " <> showN (scaleX 100.0) <> " " <> showN (scaleY menEasyRate)
    lineWomen = "M " <> showN (scaleX 0.0) <> " " <> showN (scaleY womenHardRate) <> " L " <> showN (scaleX 100.0) <> " " <> showN (scaleY womenEasyRate)

    -- Current positions from slider values
    derived = deriveData state.proportions
    menX = state.proportions.easyMale * 100.0
    menY = derived.combined.male * 100.0
    womenX = state.proportions.easyFemale * 100.0
    womenY = derived.combined.female * 100.0

    ptMen_x = scaleX menX
    ptMen_y = scaleY menY
    ptWomen_x = scaleX womenX
    ptWomen_y = scaleY womenY
  in
    SE.svg
      [ SA.viewBox 0.0 0.0 config.width config.height
      , SA.width config.width
      , SA.height config.height
      , SA.classes [ HH.ClassName "illustration-line-chart-svg" ]
      ]
      [ -- Background
        SE.rect
          [ SA.x config.marginLeft, SA.y config.marginTop
          , SA.width iw, SA.height ih
          , SA.fill (Named "#fafafa")
          ]
      -- Grid lines
      , SE.line [ SA.x1 config.marginLeft, SA.y1 (config.marginTop + ih * 0.5), SA.x2 (config.marginLeft + iw), SA.y2 (config.marginTop + ih * 0.5), SA.stroke (Named "#e0e0e0"), SA.strokeWidth 1.0 ]
      , SE.line [ SA.x1 (config.marginLeft + iw * 0.5), SA.y1 config.marginTop, SA.x2 (config.marginLeft + iw * 0.5), SA.y2 (config.marginTop + ih), SA.stroke (Named "#e0e0e0"), SA.strokeWidth 1.0 ]
      -- X-axis
      , SE.line [ SA.x1 config.marginLeft, SA.y1 (config.marginTop + ih), SA.x2 (config.marginLeft + iw), SA.y2 (config.marginTop + ih), SA.stroke (Named "#333"), SA.strokeWidth 1.0 ]
      -- Y-axis
      , SE.line [ SA.x1 config.marginLeft, SA.y1 config.marginTop, SA.x2 config.marginLeft, SA.y2 (config.marginTop + ih), SA.stroke (Named "#333"), SA.strokeWidth 1.0 ]
      -- Men's rate line (purple)
      , SE.path [ attr (AttrName "d") lineMen, SA.stroke (Named purple), SA.strokeWidth 2.0, SA.fill (Named "none") ]
      -- Women's rate line (green)
      , SE.path [ attr (AttrName "d") lineWomen, SA.stroke (Named green), SA.strokeWidth 2.0, SA.fill (Named "none") ]
      -- Axis labels
      , SE.text [ SA.x (config.marginLeft + iw / 2.0), SA.y (config.height - 5.0), SA.textAnchor SA.AnchorMiddle, SA.fill (Named "#666") ] [ HH.text "% to Easy dept" ]
      , SE.text [ SA.x (config.marginLeft - 35.0), SA.y (config.marginTop + ih / 2.0), SA.textAnchor SA.AnchorMiddle, SA.fill (Named "#666"), SA.transform [ SA.Rotate (-90.0) (config.marginLeft - 35.0) (config.marginTop + ih / 2.0) ] ] [ HH.text "% admitted" ]
      -- Y-axis ticks
      , SE.text [ SA.x (config.marginLeft - 5.0), SA.y (config.marginTop + ih + 3.0), SA.textAnchor SA.AnchorEnd, SA.fill (Named "#888") ] [ HH.text "0" ]
      , SE.text [ SA.x (config.marginLeft - 5.0), SA.y (config.marginTop + ih * 0.5 + 3.0), SA.textAnchor SA.AnchorEnd, SA.fill (Named "#888") ] [ HH.text "50" ]
      , SE.text [ SA.x (config.marginLeft - 5.0), SA.y (config.marginTop + 3.0), SA.textAnchor SA.AnchorEnd, SA.fill (Named "#888") ] [ HH.text "100" ]
      -- X-axis ticks
      , SE.text [ SA.x config.marginLeft, SA.y (config.marginTop + ih + 12.0), SA.textAnchor SA.AnchorMiddle, SA.fill (Named "#888") ] [ HH.text "0" ]
      , SE.text [ SA.x (config.marginLeft + iw), SA.y (config.marginTop + ih + 12.0), SA.textAnchor SA.AnchorMiddle, SA.fill (Named "#888") ] [ HH.text "100" ]
      -- Legend
      , SE.g [ SA.transform [ SA.Translate (config.marginLeft + 5.0) (config.marginTop + 5.0) ] ]
          [ SE.circle [ SA.cx 4.0, SA.cy 0.0, SA.r 3.0, SA.fill (Named purple) ]
          , SE.text [ SA.x 10.0, SA.y 3.0, SA.fill (Named purple) ] [ HH.text "Men" ]
          , SE.circle [ SA.cx 4.0, SA.cy 12.0, SA.r 3.0, SA.fill (Named green) ]
          , SE.text [ SA.x 10.0, SA.y 15.0, SA.fill (Named green) ] [ HH.text "Women" ]
          ]
      -- Guide lines
      , SE.line [ SA.x1 config.marginLeft, SA.y1 ptMen_y, SA.x2 ptMen_x, SA.y2 ptMen_y, SA.stroke (Named "#333"), SA.strokeWidth 1.0, SA.strokeDashArray "3,3", SA.strokeOpacity 0.5 ]
      , SE.line [ SA.x1 config.marginLeft, SA.y1 ptWomen_y, SA.x2 ptWomen_x, SA.y2 ptWomen_y, SA.stroke (Named "#333"), SA.strokeWidth 1.0, SA.strokeDashArray "3,3", SA.strokeOpacity 0.5 ]
      -- Dynamic points
      , SE.circle [ SA.cx ptMen_x, SA.cy ptMen_y, SA.r 6.0, SA.fill (Named purple), SA.stroke (Named "white"), SA.strokeWidth 2.0 ]
      , SE.circle [ SA.cx ptWomen_x, SA.cy ptWomen_y, SA.r 6.0, SA.fill (Named green), SA.stroke (Named "white"), SA.strokeWidth 2.0 ]
      -- Rate labels
      , SE.text [ SA.x (ptMen_x + 8.0), SA.y (ptMen_y - 5.0), SA.fill (Named purple) ] [ HH.text (show (Int.round menY) <> "%") ]
      , SE.text [ SA.x (ptWomen_x + 8.0), SA.y (ptWomen_y + 12.0), SA.fill (Named green) ] [ HH.text (show (Int.round womenY) <> "%") ]
      ]

-- | Helper to format numbers for SVG paths
showN :: Number -> String
showN n = toStringWith (fixed 1) n

renderIllustrationTable :: forall w i. { departments :: _, combined :: _, isParadox :: Boolean } -> HH.HTML w i
renderIllustrationTable derived =
  let
    rows = DataTable.buildRowData derived
    renderRow idx row =
      HH.tr_
        [ HH.td [ HP.classes [ HH.ClassName "dept-cell" ] ] [ HH.text row.department ]
        , HH.td_ [ HH.div [ HP.id ("illus-row-" <> show idx <> "-male-applied"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
        , HH.td_ [ HH.div [ HP.id ("illus-row-" <> show idx <> "-female-applied"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
        , HH.td_ [ HH.div [ HP.id ("illus-row-" <> show idx <> "-male-admitted"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
        , HH.td_ [ HH.div [ HP.id ("illus-row-" <> show idx <> "-female-admitted"), HP.classes [ HH.ClassName "bar-cell" ] ] [] ]
        , HH.td_ [ HH.div [ HP.id ("illus-row-" <> show idx <> "-male-rate"), HP.classes [ HH.ClassName "donut-cell" ] ] [] ]
        , HH.td_ [ HH.div [ HP.id ("illus-row-" <> show idx <> "-female-rate"), HP.classes [ HH.ClassName "donut-cell" ] ] [] ]
        ]
  in
    HH.table
      [ HP.classes [ HH.ClassName "simpsons-data-table" ] ]
      [ HH.thead_
          [ HH.tr_
              [ HH.th_ [ HH.text "Dept." ]
              , HH.th [ HP.classes [ HH.ClassName "header-group" ] ]
                  [ HH.text "Applied"
                  , HH.div [ HP.classes [ HH.ClassName "subheaders" ] ]
                      [ HH.span [ HP.classes [ HH.ClassName "male" ] ] [ HH.text "M" ]
                      , HH.span [ HP.classes [ HH.ClassName "female" ] ] [ HH.text "F" ]
                      ]
                  ]
              , HH.th [ HP.classes [ HH.ClassName "header-group" ] ]
                  [ HH.text "Admitted"
                  , HH.div [ HP.classes [ HH.ClassName "subheaders" ] ]
                      [ HH.span [ HP.classes [ HH.ClassName "male" ] ] [ HH.text "M" ]
                      , HH.span [ HP.classes [ HH.ClassName "female" ] ] [ HH.text "F" ]
                      ]
                  ]
              , HH.th [ HP.classes [ HH.ClassName "header-group" ] ]
                  [ HH.text "Rate"
                  , HH.div [ HP.classes [ HH.ClassName "subheaders" ] ]
                      [ HH.span [ HP.classes [ HH.ClassName "male" ] ] [ HH.text "M" ]
                      , HH.span [ HP.classes [ HH.ClassName "female" ] ] [ HH.text "F" ]
                      ]
                  ]
              ]
          ]
      , HH.tbody_ (mapWithIndex renderRow rows)
      ]

handleIllustrationAction :: forall o m. MonadAff m => IllustrationAction -> H.HalogenM IllustrationState IllustrationAction () o m Unit
handleIllustrationAction = case _ of
  IllustrationInit -> do
    liftAff $ delay (Milliseconds 50.0)
    state <- H.get
    liftEffect $ initIllustrationTable state.proportions

  UpdateMaleProportion valueStr -> do
    case Number.fromString valueStr of
      Just v -> do
        H.modify_ \s -> s { proportions = s.proportions { easyMale = v / 100.0 } }
        state <- H.get
        liftEffect $ initIllustrationTable state.proportions
      Nothing -> pure unit

  UpdateFemaleProportion valueStr -> do
    case Number.fromString valueStr of
      Just v -> do
        H.modify_ \s -> s { proportions = s.proportions { easyFemale = v / 100.0 } }
        state <- H.get
        liftEffect $ initIllustrationTable state.proportions
      Nothing -> pure unit

  ResetProportions -> do
    H.modify_ _ { proportions = defaultProportions }
    state <- H.get
    liftEffect $ initIllustrationTable state.proportions

-- | Initialize/update illustration table with current proportions
initIllustrationTable :: Proportions -> Effect Unit
initIllustrationTable props = do
  let derived = deriveData props
  let rows = DataTable.buildRowData derived
  -- Clear and re-render each cell
  for_ (mapWithIndex (\i row -> { idx: i, row }) rows) \{ idx, row } -> do
    let prefix = "#illus-row-" <> show idx
    clearContainer (prefix <> "-male-applied")
    clearContainer (prefix <> "-female-applied")
    clearContainer (prefix <> "-male-admitted")
    clearContainer (prefix <> "-female-admitted")
    clearContainer (prefix <> "-male-rate")
    clearContainer (prefix <> "-female-rate")
    -- Render new content via HATS
    _ <- rerender (prefix <> "-male-applied") (DataTable.barChartTree DataTable.defaultBarConfig row.maleApplied Male)
    _ <- rerender (prefix <> "-female-applied") (DataTable.barChartTree DataTable.defaultBarConfig row.femaleApplied Female)
    _ <- rerender (prefix <> "-male-admitted") (DataTable.barChartTree DataTable.defaultBarConfig row.maleAdmitted Male)
    _ <- rerender (prefix <> "-female-admitted") (DataTable.barChartTree DataTable.defaultBarConfig row.femaleAdmitted Female)
    _ <- rerender (prefix <> "-male-rate") (DataTable.miniDonutTree DataTable.defaultMiniDonutConfig row.maleRate row.maleWins)
    _ <- rerender (prefix <> "-female-rate") (DataTable.miniDonutTree DataTable.defaultMiniDonutConfig row.femaleRate row.femaleWins)
    pure unit

-- =============================================================================
-- PostscriptCards Component (shows all 7 datasets)
-- =============================================================================

type PostscriptSlots = ( card :: H.Slot Card.Query Void String )

_card :: Proxy "card"
_card = Proxy

postscriptCardsComponent :: forall m. MonadAff m => H.Component SimpleQuery Unit Void m
postscriptCardsComponent = H.mkComponent
  { initialState: \_ -> Datasets.allDatasets
  , render
  , eval: H.mkEval H.defaultEval
  }
  where
  render :: Array Dataset -> H.ComponentHTML Unit PostscriptSlots m
  render datasets =
    HH.div
      [ HP.classes [ HH.ClassName "simpsons-datasets-grid" ] ]
      (map renderCard datasets)

  renderCard :: Dataset -> H.ComponentHTML Unit PostscriptSlots m
  renderCard dataset =
    HH.slot _card dataset.id Card.component dataset absurd
