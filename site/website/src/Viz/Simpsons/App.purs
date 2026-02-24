-- | Simpson's Paradox Visualization - Halogen Application
-- |
-- | A PureScript port of the classic Simpson's Paradox visualization
-- | by Lewis Lehe & Victor Powell (2014): https://setosa.io/simpsons/
module D3.Viz.Simpsons.App
  ( component
  , Query
  ) where

import Prelude

import Content.Simpsons.Illustration as Illustration
import Content.Simpsons.MoreInfo as MoreInfo
import Content.Simpsons.ProperPooling as ProperPooling
import D3.Viz.Simpsons.Dataset (Dataset)
import D3.Viz.Simpsons.Datasets as Datasets
import D3.Viz.Simpsons.InteractiveParadoxCard as Card
import D3.Viz.Simpsons.DataTable as DataTable
import D3.Viz.Simpsons.DonutChart as Donut
import D3.Viz.Simpsons.ForceViz as ForceViz
import D3.Viz.Simpsons.LineChart as Line
import D3.Viz.Simpsons.ScatterChart as Scatter
import D3.Viz.Simpsons.Types (DerivedData, Proportions, defaultProportions, deriveData, green, overallAcceptanceRates, purple)
import Data.Array (mapWithIndex)
import Data.Int (round) as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (fromString) as Number
import Effect (Effect)
import Effect.Aff (Milliseconds(..))
import Effect.Aff as Aff
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect, liftEffect)
import Effect.Ref as Ref
import Effect.Unsafe (unsafePerformEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Hylograph.HATS.InterpreterTick (rerender)
import Type.Proxy (Proxy(..))

-- =============================================================================
-- Module-level state for force visualization handle
-- =============================================================================

-- | Mutable ref holding the ForceViz handle (set during initialization)
forceVizHandleRef :: Ref.Ref (Maybe ForceViz.ForceVizHandle)
forceVizHandleRef = unsafePerformEffect $ Ref.new Nothing

-- =============================================================================
-- Component Types
-- =============================================================================

-- | Component state
type State =
  { proportions :: Proportions
  , isCombined :: Boolean
  , initialized :: Boolean
  }

-- | Initial state
initialState :: forall i. i -> State
initialState _ =
  { proportions: defaultProportions
  , isCombined: false
  , initialized: false
  }

-- | Component actions
data Action
  = Initialize
  | SetMaleProportion Number
  | SetFemaleProportion Number
  | ToggleCombined
  | Render

-- | Query type (empty for now)
data Query a = NoOp a

-- | Slots for child components (interactive paradox cards keyed by dataset ID)
type Slots = ( paradoxCard :: Card.Slot String )

-- =============================================================================
-- Component
-- =============================================================================

component :: forall i o m. MonadAff m => MonadEffect m => H.Component Query i o m
component = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

-- =============================================================================
-- Render
-- =============================================================================

render :: forall m. MonadAff m => State -> H.ComponentHTML Action Slots m
render state =
  let
    derived = deriveData state.proportions
  in
    HH.div
      [ HP.classes [ HH.ClassName "simpsons-paradox" ] ]
      [ -- Header (hidden in standalone mode via CSS)
        renderHeader

      -- HERO SECTION: Admissions intro (left) + Force animation (right)
      , HH.section
          [ HP.classes [ HH.ClassName "simpsons-hero-row" ] ]
          [ HH.div
              [ HP.classes [ HH.ClassName "simpsons-hero-left" ] ]
              [ renderDonutSection ]
          , HH.div
              [ HP.classes [ HH.ClassName "simpsons-hero-right" ] ]
              [ renderForceSection state ]
          ]

      -- TWO-COLUMN: Interactive demo + Illustration table
      , HH.section
          [ HP.classes [ HH.ClassName "simpsons-explore-row" ] ]
          [ HH.div
              [ HP.classes [ HH.ClassName "simpsons-explore-left" ] ]
              [ renderInteractiveSection state derived ]
          , HH.div
              [ HP.classes [ HH.ClassName "simpsons-explore-right" ] ]
              [ renderDataTable state derived ]
          ]

      -- TWO-COLUMN: "What is Simpson's Paradox?" (left) + "What it is NOT" (right)
      , HH.section
          [ HP.classes [ HH.ClassName "simpsons-explain-row" ] ]
          [ HH.div
              [ HP.classes [ HH.ClassName "simpsons-explain-left" ] ]
              [ renderScatterSection ]
          , HH.div
              [ HP.classes [ HH.ClassName "simpsons-explain-right" ] ]
              [ renderIllustrationSection ]
          ]

      -- Proper Pooling section - the sociology behind it
      , HH.section
          [ HP.classes [ HH.ClassName "simpsons-proper-pooling" ] ]
          [ renderProperPoolingSection ]

      -- More Information / References
      , renderMoreInfoSection

      -- Credits (shown only in non-standalone mode)
      , renderCredits

      -- Postscript: All Simpson's Paradox examples
      , renderPostscriptSection
      ]

-- | Header section
renderHeader :: forall w i. HH.HTML w i
renderHeader =
  HH.header
    [ HP.classes [ HH.ClassName "simpsons-header" ] ]
    [ HH.h1_ [ HH.text "Simpson's Paradox" ]
    , HH.p
        [ HP.classes [ HH.ClassName "simpsons-tagline" ] ]
        [ HH.text "Girls gone average. Averages gone wild." ]
    ]

-- | The Berkeley Story - full original text
renderDonutSection :: forall w i. HH.HTML w i
renderDonutSection =
  HH.section
    [ HP.classes [ HH.ClassName "simpsons-donuts" ] ]
    [ HH.h2_ [ HH.text "UC Berkeley Graduate Admissions (1973)" ]
    , HH.p_
        [ HH.text "In 1973, the University of California-Berkeley was sued for sex discrimination. "
        , HH.text "The numbers looked pretty damning: the overall acceptance rate for men was "
        , HH.strong_ [ HH.text "44%" ]
        , HH.text ", while for women it was only "
        , HH.strong_ [ HH.text "35%" ]
        , HH.text "."
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "simpsons-donuts-container" ] ]
        [ HH.div
            [ HP.id "donut-men"
            , HP.classes [ HH.ClassName "donut-chart" ]
            ]
            []
        , HH.div
            [ HP.id "donut-women"
            , HP.classes [ HH.ClassName "donut-chart" ]
            ]
            []
        ]
    , HH.p_
        [ HH.text "When researchers looked at the data on a "
        , HH.em_ [ HH.text "department by department" ]
        , HH.text " basis, however, they found that "
        , HH.strong_ [ HH.text "women were admitted at higher rates than men in most departments" ]
        , HH.text "!"
        ]
    , HH.blockquote_
        [ HH.p_
            [ HH.text "\"If the data are properly pooled...there is a small but statistically significant bias in favor of women.\"" ]
        , HH.cite_
            [ HH.text "— Bickel et al. (1975), p. 403" ]
        ]
    , HH.p_
        [ HH.text "This is an example of "
        , HH.strong_ [ HH.text "Simpson's Paradox" ]
        , HH.text ": a phenomenon in which a trend appears in different groups of data but disappears or reverses when these groups are combined."
        ]
    ]

-- | "What is Simpson's Paradox?" section with theoretical explanation
renderScatterSection :: forall w i. HH.HTML w i
renderScatterSection =
  HH.section
    [ HP.classes [ HH.ClassName "simpsons-scatter" ] ]
    [ HH.h2_ [ HH.text "What is Simpson's Paradox?" ]
    , HH.p_
        [ HH.text "Simpson's Paradox occurs when a relationship between two variables has one direction in subgroups but the opposite direction when the groups are combined." ]
    , HH.p_
        [ HH.text "Formally, there are three variables:" ]
    , HH.ol
        [ HP.classes [ HH.ClassName "simpsons-variables-list" ] ]
        [ HH.li_
            [ HH.strong_ [ HH.text "The explained variable" ]
            , HH.text " (admission result: accepted or rejected)"
            ]
        , HH.li_
            [ HH.strong_ [ HH.text "The observed explanatory variable" ]
            , HH.text " (gender: male or female)"
            ]
        , HH.li_
            [ HH.strong_ [ HH.text "The lurking explanatory variable" ]
            , HH.text " (department: which department applied to)"
            ]
        ]
    , HH.p_
        [ HH.text "The paradox occurs when the effect of the observed variable "
        , HH.em_ [ HH.text "reverses direction" ]
        , HH.text " once we account for the lurking variable."
        ]
    , HH.div
        [ HP.id "scatter-chart"
        , HP.classes [ HH.ClassName "scatter-chart" ]
        ]
        []
    , HH.p
        [ HP.classes [ HH.ClassName "simpsons-scatter-explanation" ] ]
        [ HH.text "In the chart above, each color represents a different group. Within each group, y increases with x (positive correlation). "
        , HH.text "But look at the overall trend line: y "
        , HH.em_ [ HH.text "decreases" ]
        , HH.text " with x (negative correlation)!"
        ]
    ]

-- | Interactive line chart with sliders
renderInteractiveSection :: forall m. State -> DerivedData -> H.ComponentHTML Action Slots m
renderInteractiveSection state derived =
  HH.section
    [ HP.classes [ HH.ClassName "simpsons-interactive" ] ]
    [ HH.h2_ [ HH.text "Interactive Demonstration" ]
    , HH.p_
        [ HH.text "Adjust the sliders to see how the distribution of applicants affects overall rates." ]

    -- Sliders
    , HH.div
        [ HP.classes [ HH.ClassName "simpsons-sliders" ] ]
        [ renderSlider "Women to Easy Dept" state.proportions.easyFemale green SetFemaleProportion
        , renderSlider "Men to Easy Dept" state.proportions.easyMale purple SetMaleProportion
        ]

    -- Line chart (rendered via HATS)
    , HH.div
        [ HP.id "line-chart"
        , HP.classes [ HH.ClassName "line-chart" ]
        ]
        []

    -- Paradox indicator
    , HH.div
        [ HP.classes
            [ HH.ClassName "simpsons-paradox-indicator"
            , HH.ClassName if derived.isParadox then "is-paradox" else "no-paradox"
            ]
        ]
        [ if derived.isParadox
            then HH.text "Simpson's Paradox is present! Men have higher overall rate despite lower per-department rates."
            else HH.text "No paradox - the group with higher per-department rates also has higher overall rate."
        ]
    ]

-- | Render a slider control
renderSlider :: forall m. String -> Number -> String -> (Number -> Action) -> H.ComponentHTML Action Slots m
renderSlider label value color action =
  HH.div
    [ HP.classes [ HH.ClassName "simpsons-slider" ] ]
    [ HH.label
        [ HP.style ("color: " <> color) ]
        [ HH.text label ]
    , HH.input
        [ HP.type_ HP.InputRange
        , HP.min 0.0
        , HP.max 100.0
        , HP.value (show (value * 100.0))
        , HP.step (HP.Step 1.0)
        , HP.style ("accent-color: " <> color)
        , HE.onValueInput \val ->
            action (fromMaybe (value * 100.0) (Number.fromString val) / 100.0)
        ]
    , HH.span_ [ HH.text (show (Int.round (value * 100.0)) <> "%") ]
    ]

-- | Data table showing current statistics with bar charts and donuts
renderDataTable :: forall w i. State -> DerivedData -> HH.HTML w i
renderDataTable _state derived =
  let
    rows = DataTable.buildRowData derived
  in
    HH.section
      [ HP.classes [ HH.ClassName "simpsons-table" ] ]
      [ HH.h2_ [ HH.text "Illustration" ]
      , HH.p
          [ HP.classes [ HH.ClassName "simpsons-table-description" ] ]
          [ HH.text "Suppose there are two departments: one easy, one hard ('hard' as in 'hard to get into'). The sliders below set what percentage each gender applies to the easy department. Both departments prefer women, but if too many women apply to the hard one, their acceptance rate drops below the men's." ]
      , HH.table
          [ HP.classes [ HH.ClassName "simpsons-data-table" ] ]
          [ HH.thead_
              [ HH.tr_
                  [ HH.th_ [ HH.text "departments" ]
                  , HH.th
                      [ HP.colSpan 2 ]
                      [ HH.text "# applied" ]
                  , HH.th
                      [ HP.colSpan 2 ]
                      [ HH.text "# admitted" ]
                  , HH.th
                      [ HP.colSpan 2 ]
                      [ HH.text "% admitted" ]
                  ]
              , HH.tr
                  [ HP.classes [ HH.ClassName "simpsons-subheader" ] ]
                  [ HH.th_ []
                  , HH.th
                      [ HP.style ("color: " <> purple) ]
                      [ HH.text "men" ]
                  , HH.th
                      [ HP.style ("color: " <> green) ]
                      [ HH.text "women" ]
                  , HH.th
                      [ HP.style ("color: " <> purple) ]
                      [ HH.text "men" ]
                  , HH.th
                      [ HP.style ("color: " <> green) ]
                      [ HH.text "women" ]
                  , HH.th
                      [ HP.style ("color: " <> purple) ]
                      [ HH.text "men" ]
                  , HH.th
                      [ HP.style ("color: " <> green) ]
                      [ HH.text "women" ]
                  ]
              ]
          , HH.tbody_
              ( rows # mapWithIndex \idx row ->
                  let
                    prefix = "row-" <> show idx
                  in
                    HH.tr_
                      [ -- Department name
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-dept-name" ] ]
                          [ HH.text row.department ]
                      , -- Men applied
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-data-cell" ] ]
                          [ HH.span_ [ HH.text (formatNumber row.maleApplied) ]
                          , HH.div
                              [ HP.id (prefix <> "-male-applied")
                              , HP.classes [ HH.ClassName "bar-container" ]
                              ]
                              []
                          ]
                      , -- Women applied
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-data-cell" ] ]
                          [ HH.span_ [ HH.text (formatNumber row.femaleApplied) ]
                          , HH.div
                              [ HP.id (prefix <> "-female-applied")
                              , HP.classes [ HH.ClassName "bar-container" ]
                              ]
                              []
                          ]
                      , -- Men admitted
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-data-cell" ] ]
                          [ HH.span_ [ HH.text (formatNumber row.maleAdmitted) ]
                          , HH.div
                              [ HP.id (prefix <> "-male-admitted")
                              , HP.classes [ HH.ClassName "bar-container" ]
                              ]
                              []
                          ]
                      , -- Women admitted
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-data-cell" ] ]
                          [ HH.span_ [ HH.text (formatNumber row.femaleAdmitted) ]
                          , HH.div
                              [ HP.id (prefix <> "-female-admitted")
                              , HP.classes [ HH.ClassName "bar-container" ]
                              ]
                              []
                          ]
                      , -- Men rate donut
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-donut-cell" ] ]
                          [ HH.div
                              [ HP.id (prefix <> "-male-rate")
                              , HP.classes [ HH.ClassName "donut-container" ]
                              ]
                              []
                          ]
                      , -- Women rate donut
                        HH.td
                          [ HP.classes [ HH.ClassName "simpsons-donut-cell" ] ]
                          [ HH.div
                              [ HP.id (prefix <> "-female-rate")
                              , HP.classes [ HH.ClassName "donut-container" ]
                              ]
                              []
                          ]
                      ]
              )
          ]
      , HH.div
          [ HP.classes
              [ HH.ClassName "simpsons-paradox-result"
              , HH.ClassName if derived.isParadox then "is-paradox" else "no-paradox"
              ]
          ]
          [ HH.strong_ [ HH.text "Simpson's paradox? " ]
          , HH.span_ [ HH.text if derived.isParadox then "yes" else "no" ]
          ]
      ]

-- | Format a number with commas for display
formatNumber :: Number -> String
formatNumber n = formatWithCommas (show (Int.round n))

foreign import formatWithCommas :: String -> String

-- | Force-directed visualization section
renderForceSection :: forall m. State -> H.ComponentHTML Action Slots m
renderForceSection state =
  HH.section
    [ HP.classes [ HH.ClassName "simpsons-force" ] ]
    [ HH.h2_ [ HH.text "Applicant Cohorts" ]
    , HH.p_
        [ HH.text "Each dot represents an applicant. Blue = accepted, Red = rejected." ]
    , HH.button
        [ HP.classes [ HH.ClassName "simpsons-toggle" ]
        , HE.onClick \_ -> ToggleCombined
        ]
        [ HH.text if state.isCombined then "Separate by Department" else "Combine All" ]
    , HH.div
        [ HP.id "force-viz"
        , HP.classes [ HH.ClassName "force-viz" ]
        ]
        []
    ]

-- | Credits section
renderCredits :: forall w i. HH.HTML w i
renderCredits =
  HH.footer
    [ HP.classes [ HH.ClassName "simpsons-credits" ] ]
    [ HH.p_
        [ HH.text "Based on the visualization by "
        , HH.a
            [ HP.href "https://setosa.io/simpsons/"
            , HP.target "_blank"
            ]
            [ HH.text "Lewis Lehe & Victor Powell" ]
        , HH.text " (2014). Reimplemented in PureScript using "
        , HH.a
            [ HP.href "https://github.com/psd3/psd3"
            , HP.target "_blank"
            ]
            [ HH.text "PS<$>D3" ]
        , HH.text "."
        ]
    ]

-- | "What Simpson's paradox is NOT" + historical examples
-- | Content sourced from: content/simpsons/illustration.md
renderIllustrationSection :: forall w i. HH.HTML w i
renderIllustrationSection =
  HH.div
    [ HP.classes [ HH.ClassName "simpsons-illustration-content" ] ]
    [ Illustration.content ]

-- | "Proper Pooling" section - explaining the sociological context
-- | Content sourced from: content/simpsons/proper-pooling.md
renderProperPoolingSection :: forall w i. HH.HTML w i
renderProperPoolingSection =
  HH.div
    [ HP.classes [ HH.ClassName "simpsons-proper-pooling-content" ] ]
    [ ProperPooling.content ]

-- | "More Information" section with references
-- | Content sourced from: content/simpsons/more-info.md
renderMoreInfoSection :: forall w i. HH.HTML w i
renderMoreInfoSection =
  HH.section
    [ HP.classes [ HH.ClassName "simpsons-more-info" ] ]
    [ MoreInfo.content ]

-- | Slot proxy for interactive cards
_paradoxCard :: Proxy "paradoxCard"
_paradoxCard = Proxy

-- | Postscript section: All Simpson's Paradox examples (with interactive cards)
renderPostscriptSection :: forall m. MonadAff m => H.ComponentHTML Action Slots m
renderPostscriptSection =
  HH.section
    [ HP.classes [ HH.ClassName "simpsons-postscript" ] ]
    [ HH.hr_
    , HH.h2_ [ HH.text "Postscript: The Paradox Generalized" ]
    , HH.p
        [ HP.classes [ HH.ClassName "simpsons-postscript-intro" ] ]
        [ HH.text "The visualization above is a tribute to "
        , HH.a [ HP.href "https://setosa.io/simpsons/", HP.target "_blank" ]
            [ HH.text "Lehe & Powell's original" ]
        , HH.text ", which itself drew from an "
        , HH.a [ HP.href "https://www.usu.edu/math/schneit/CTIS/SP/", HP.target "_blank" ]
            [ HH.text "earlier applet by Schneiter at USU" ]
        , HH.text " featuring seven classic Simpson's Paradox examples. Use the sliders to explore how changing the distribution affects combined rates:"
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "simpsons-datasets-grid" ] ]
        (map renderInteractiveCard Datasets.allDatasets)
    ]

-- | Render an interactive card for a dataset (as a child component)
renderInteractiveCard :: forall m. MonadAff m => Dataset -> H.ComponentHTML Action Slots m
renderInteractiveCard dataset =
  HH.slot _paradoxCard dataset.id Card.component dataset absurd

-- =============================================================================
-- Action Handlers
-- =============================================================================

handleAction :: forall o m. MonadAff m => MonadEffect m => Action -> H.HalogenM State Action Slots o m Unit
handleAction = case _ of
  Initialize -> do
    -- Give Halogen time to render the DOM
    H.liftAff $ Aff.delay (Milliseconds 100.0)

    -- Initialize all charts
    state <- H.get
    let derived = deriveData state.proportions
    liftEffect $ initializeCharts state.proportions derived
    H.modify_ _ { initialized = true }

    -- Initial render
    handleAction Render

  SetMaleProportion value -> do
    H.modify_ \s -> s { proportions = s.proportions { easyMale = value } }
    handleAction Render

  SetFemaleProportion value -> do
    H.modify_ \s -> s { proportions = s.proportions { easyFemale = value } }
    handleAction Render

  ToggleCombined -> do
    H.modify_ \s -> s { isCombined = not s.isCombined }
    -- Toggle the force visualization
    liftEffect do
      maybeHandle <- Ref.read forceVizHandleRef
      case maybeHandle of
        Just handle -> handle.toggle
        Nothing -> pure unit

  Render -> do
    state <- H.get
    when state.initialized do
      let derived = deriveData state.proportions
      liftEffect do
        updateLineChart state.proportions
        DataTable.updateDataTable derived

-- =============================================================================
-- Chart Initialization
-- =============================================================================

-- | Initialize all charts
initializeCharts :: Proportions -> DerivedData -> Effect Unit
initializeCharts props derived = do
  -- Initialize charts via HATS rerender
  initDonutCharts
  initScatterChart
  initLineChart props
  -- Initialize force visualization
  initForceViz
  -- Initialize the data table
  DataTable.initDataTable derived

-- | Initialize donut charts
initDonutCharts :: Effect Unit
initDonutCharts = do
  _ <- rerender "#donut-men" (Donut.donutChartTree Donut.defaultConfig (overallAcceptanceRates.male * 100.0) "Men")
  _ <- rerender "#donut-women" (Donut.donutChartTree Donut.defaultConfig (overallAcceptanceRates.female * 100.0) "Women")
  pure unit

-- | Initialize scatter chart
initScatterChart :: Effect Unit
initScatterChart = do
  _ <- rerender "#scatter-chart" (Scatter.scatterChartTree Scatter.defaultConfig)
  pure unit

-- | Initialize line chart
initLineChart :: Proportions -> Effect Unit
initLineChart props = do
  _ <- rerender "#line-chart" (Line.lineChartTree Line.defaultConfig props)
  pure unit

-- | Initialize force visualization
initForceViz :: Effect Unit
initForceViz = do
  -- Create the force visualization and store the handle
  handle <- ForceViz.initForceViz "#force-viz"
  Ref.write (Just handle) forceVizHandleRef

-- | Update line chart with new proportions
updateLineChart :: Proportions -> Effect Unit
updateLineChart props = do
  _ <- rerender "#line-chart" (Line.lineChartTree Line.defaultConfig props)
  pure unit
