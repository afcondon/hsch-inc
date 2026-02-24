module Component.Tour.TourScrolly where

import Prelude

import Data.Array (mapWithIndex, length, (!!), range, foldl)
import Data.Traversable (traverse_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Int (fromString) as Int
import Data.Options ((:=))
import Effect (Effect)
import Effect.Aff (Milliseconds(..), delay)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (liftEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Hylograph.Shared.TourNav as TourNav
import Hylograph.Website.Types (Route(..))
import Web.DOM.Element as Element
import Web.DOM.ParentNode (QuerySelector(..), querySelector)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window as Window
import Web.Intersection.Observer (IntersectionObserver, newIntersectionObserver, observe, unobserve)
import Web.Intersection.Observer.Entry (IntersectionObserverEntry)
import Web.Intersection.Observer.Options (root, threshold)

-- HATS Visualization imports
import Component.Tour.TourScrollyViz as Viz

-- Minimal FFI for scrollIntoView (not available in web-dom)
foreign import scrollToStep :: Int -> Effect Unit

-- | A single step in the tour
type TourStep =
  { id :: Int
  , title :: String
  , narrative :: Array String  -- Paragraphs
  , codeLines :: Array CodeLine
  , insight :: Maybe String
  }

-- | A line of code with optional highlight
type CodeLine =
  { code :: String
  , highlight :: Boolean  -- New in this step?
  , indent :: Int
  }

-- | Component state
type State =
  { currentStep :: Int
  , observer :: Maybe IntersectionObserver
  , isReady :: Boolean  -- Flag to ignore initial intersection events
  }

-- | Component actions
data Action
  = Initialize
  | Finalize
  | StepBecameVisible Int
  | GoToStep Int
  | MarkReady  -- Called after initialization delay

-- | The tour steps - Progressive Enhancement sequence
tourSteps :: Array TourStep
tourSteps =
  [ step1_emptyCanvas
  , step2_threeCirclesGreen
  , step3_threeCirclesData
  , step4_parabolaBasic
  , step5_parabolaAxes
  , step6_axisLabels
  , step7_anscombeScatter
  , step8_anscombeSmallMultiple
  , step9_anscombeOverlay
  , step10_multiLine
  , step11_hoverTooltip
  ]

-- Step 1: Empty Canvas
step1_emptyCanvas :: TourStep
step1_emptyCanvas =
  { id: 1
  , title: "The Empty Canvas"
  , narrative:
      [ "Every visualization begins here: an SVG element. It's just a container - a blank canvas waiting for content."
      , "In PSD3, we describe what we want declaratively. This single line creates a 400x300 pixel drawing area."
      ]
  , codeLines:
      [ { code: "svg [ width 400, height 300 ]", highlight: true, indent: 0 }
      ]
  , insight: Nothing
  }

-- Step 2: Three Green Circles
step2_threeCirclesGreen :: TourStep
step2_threeCirclesGreen =
  { id: 2
  , title: "Three Green Circles"
  , narrative:
      [ "The most minimal visualization: three circles. We don't even need data yet - just hardcoded positions."
      , "Each circle has attributes: position (cx, cy), size (r), and color (fill). These are static values."
      ]
  , codeLines:
      [ { code: "svg [ width 400, height 300 ]", highlight: false, indent: 0 }
      , { code: "  [ circle [ cx 80,  cy 150, r 30, fill \"green\" ]", highlight: true, indent: 0 }
      , { code: "  , circle [ cx 200, cy 150, r 30, fill \"green\" ]", highlight: true, indent: 0 }
      , { code: "  , circle [ cx 320, cy 150, r 30, fill \"green\" ]", highlight: true, indent: 0 }
      , { code: "  ]", highlight: false, indent: 0 }
      ]
  , insight: Just "Static attributes = hardcoded values"
  }

-- Step 3: Data-Driven Circles
step3_threeCirclesData :: TourStep
step3_threeCirclesData =
  { id: 3
  , title: "Data-Driven Circles"
  , narrative:
      [ "Now the magic: a data join. Instead of hardcoding three circles, we say 'for each item in this array, create a circle.'"
      , "Both position AND color come from data. Change the array, and the circles change automatically."
      ]
  , codeLines:
      [ { code: "svg [ width 400, height 300 ]", highlight: false, indent: 0 }
      , { code: "  [ join \"circle\" [\"red\", \"green\", \"blue\"] \\color i ->", highlight: true, indent: 0 }
      , { code: "      circle", highlight: false, indent: 2 }
      , { code: "        [ cx (80 + i * 120)  -- position from index", highlight: true, indent: 2 }
      , { code: "        , cy 150", highlight: false, indent: 2 }
      , { code: "        , r 30", highlight: false, indent: 2 }
      , { code: "        , fill color         -- color from data!", highlight: true, indent: 2 }
      , { code: "        ]", highlight: false, indent: 2 }
      , { code: "  ]", highlight: false, indent: 0 }
      ]
  , insight: Just "Data join: one datum = one element"
  }

-- Step 4: Parabola
step4_parabolaBasic :: TourStep
step4_parabolaBasic =
  { id: 4
  , title: "A Parabola of Circles"
  , narrative:
      [ "Now the Y position comes from a mathematical relationship: y = x². The data is numbers, and we compute the visual position."
      , "This is the essence of data visualization: mapping data values to visual properties."
      ]
  , codeLines:
      [ { code: "let data = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]", highlight: true, indent: 0 }
      , { code: "", highlight: false, indent: 0 }
      , { code: "svg [ width 400, height 300 ]", highlight: false, indent: 0 }
      , { code: "  [ join \"circle\" data \\x _ ->", highlight: false, indent: 0 }
      , { code: "      let y = x * x  -- parabola!", highlight: true, indent: 2 }
      , { code: "      in circle", highlight: false, indent: 2 }
      , { code: "        [ cx (scaleX x)  -- map data to pixels", highlight: true, indent: 2 }
      , { code: "        , cy (scaleY y)", highlight: true, indent: 2 }
      , { code: "        , r 8", highlight: false, indent: 2 }
      , { code: "        , fill \"green\"", highlight: false, indent: 2 }
      , { code: "        ]", highlight: false, indent: 2 }
      , { code: "  ]", highlight: false, indent: 0 }
      ]
  , insight: Just "Scales: map data domain -> pixel range"
  }

-- Step 5: Add Axes
step5_parabolaAxes :: TourStep
step5_parabolaAxes =
  { id: 5
  , title: "Adding Context: Axes"
  , narrative:
      [ "Circles alone don't tell the story. Axes provide context - they show what the positions mean."
      , "An axis is just another visualization element. It's built from the same scale we use for the circles."
      ]
  , codeLines:
      [ { code: "svg [ width 400, height 300 ]", highlight: false, indent: 0 }
      , { code: "  [ g [ transform \"translate(50, 250)\" ]  -- X axis", highlight: true, indent: 0 }
      , { code: "      [ axisBottom scaleX ]", highlight: true, indent: 2 }
      , { code: "  , g [ transform \"translate(50, 0)\" ]    -- Y axis", highlight: true, indent: 0 }
      , { code: "      [ axisLeft scaleY ]", highlight: true, indent: 2 }
      , { code: "  , g [ transform \"translate(50, 0)\" ]    -- circles", highlight: false, indent: 0 }
      , { code: "      [ join \"circle\" data \\x _ -> ... ]", highlight: false, indent: 2 }
      , { code: "  ]", highlight: false, indent: 0 }
      ]
  , insight: Just "Axes are just visualizations of scales"
  }

-- Step 6: Axis Labels
step6_axisLabels :: TourStep
step6_axisLabels =
  { id: 6
  , title: "Labels Complete the Picture"
  , narrative:
      [ "Labels tell the viewer what they're looking at. The X axis shows the input values, Y shows the squared output."
      , "Notice: labels are just text elements. Everything in SVG is elements with attributes."
      ]
  , codeLines:
      [ { code: "-- After the axes...", highlight: false, indent: 0 }
      , { code: "  , text", highlight: true, indent: 0 }
      , { code: "      [ x 200, y 290", highlight: true, indent: 2 }
      , { code: "      , textAnchor \"middle\"", highlight: true, indent: 2 }
      , { code: "      , textContent \"x\"", highlight: true, indent: 2 }
      , { code: "      ]", highlight: true, indent: 2 }
      , { code: "  , text", highlight: true, indent: 0 }
      , { code: "      [ x 15, y 150", highlight: true, indent: 2 }
      , { code: "      , textAnchor \"middle\"", highlight: true, indent: 2 }
      , { code: "      , transform \"rotate(-90, 15, 150)\"", highlight: true, indent: 2 }
      , { code: "      , textContent \"x²\"", highlight: true, indent: 2 }
      , { code: "      ]", highlight: true, indent: 2 }
      ]
  , insight: Just "Everything is elements + attributes"
  }

-- Step 7: Anscombe Scatter
step7_anscombeScatter :: TourStep
step7_anscombeScatter =
  { id: 7
  , title: "Real Data: Anscombe's Dataset A"
  , narrative:
      [ "Now we're visualizing real data. Anscombe's Quartet is famous: four datasets with identical statistics but very different patterns."
      , "Dataset A shows a clear linear relationship. Each point is an {x, y} record."
      ]
  , codeLines:
      [ { code: "let datasetA =", highlight: true, indent: 0 }
      , { code: "  [ {x: 10, y: 8.04}, {x: 8, y: 6.95}", highlight: true, indent: 2 }
      , { code: "  , {x: 13, y: 7.58}, {x: 9, y: 8.81}", highlight: true, indent: 2 }
      , { code: "  , ... ]", highlight: true, indent: 2 }
      , { code: "", highlight: false, indent: 0 }
      , { code: "join \"circle\" datasetA \\d _ ->", highlight: false, indent: 0 }
      , { code: "  circle", highlight: false, indent: 2 }
      , { code: "    [ cx (scaleX d.x)  -- x from record", highlight: true, indent: 2 }
      , { code: "    , cy (scaleY d.y)  -- y from record", highlight: true, indent: 2 }
      , { code: "    , r 5", highlight: false, indent: 2 }
      , { code: "    , fill \"steelblue\"", highlight: false, indent: 2 }
      , { code: "    ]", highlight: false, indent: 2 }
      ]
  , insight: Just "Records as data: d.x, d.y"
  }

-- Step 8: Small Multiple
step8_anscombeSmallMultiple :: TourStep
step8_anscombeSmallMultiple =
  { id: 8
  , title: "Small Multiples: Nested Data"
  , narrative:
      [ "To show all four datasets, we feed in nested data: an array of arrays. The outer array creates panels, each inner array creates the circles."
      , "This 'small multiples' pattern repeats the same visualization for easy comparison."
      ]
  , codeLines:
      [ { code: "let allDatasets = [datasetA, datasetB, datasetC, datasetD]", highlight: true, indent: 0 }
      , { code: "", highlight: false, indent: 0 }
      , { code: "join \"g\" allDatasets \\dataset i ->", highlight: true, indent: 0 }
      , { code: "  g [ transform (panelPosition i) ]", highlight: false, indent: 2 }
      , { code: "    [ axisBottom, axisLeft", highlight: false, indent: 2 }
      , { code: "    , join \"circle\" dataset.points \\d _ ->", highlight: true, indent: 2 }
      , { code: "        circle [ cx d.x, cy d.y, r 4 ]", highlight: false, indent: 4 }
      , { code: "    ]", highlight: false, indent: 2 }
      ]
  , insight: Just "Nested data = nested visualization"
  }

-- Step 9: Overlay
step9_anscombeOverlay :: TourStep
step9_anscombeOverlay =
  { id: 9
  , title: "Overlay: A Stepping Stone"
  , narrative:
      [ "Overlaying datasets on one chart isn't always a good choice - it gets crowded fast. But it's a stepping stone to something better."
      , "With 44 points it's already hard to read. Imagine hundreds of data points. We need a different approach..."
      ]
  , codeLines:
      [ { code: "let colors = [\"red\", \"blue\", \"green\", \"purple\"]", highlight: true, indent: 0 }
      , { code: "", highlight: false, indent: 0 }
      , { code: "join \"g\" (zip allDatasets colors) \\(dataset, color) _ ->", highlight: true, indent: 0 }
      , { code: "  join \"circle\" dataset.points \\d _ ->", highlight: false, indent: 2 }
      , { code: "    circle", highlight: false, indent: 4 }
      , { code: "      [ cx d.x, cy d.y, r 5", highlight: false, indent: 4 }
      , { code: "      , fill color", highlight: true, indent: 4 }
      , { code: "      , opacity 0.7", highlight: false, indent: 4 }
      , { code: "      ]", highlight: false, indent: 4 }
      ]
  , insight: Just "Crowded charts need interaction to be readable"
  }

-- Step 10: Multi-Line Chart
step10_multiLine :: TourStep
step10_multiLine =
  { id: 10
  , title: "From Points to Lines"
  , narrative:
      [ "Line charts connect points to show trends. This is real BLS data: 45 metro areas × 166 months = 7,470 data points."
      , "All lines are gray. The 2008 recession spike is visible, but which city is which? Impossible to tell."
      ]
  , codeLines:
      [ { code: "let linePath points =", highlight: true, indent: 0 }
      , { code: "  \"M\" <> first <> foldl (\\acc p -> acc <> \"L\" <> p) \"\" rest", highlight: true, indent: 2 }
      , { code: "", highlight: false, indent: 0 }
      , { code: "join \"path\" allSeries \\series _ ->", highlight: false, indent: 0 }
      , { code: "  path", highlight: true, indent: 2 }
      , { code: "    [ d (linePath series.points)", highlight: true, indent: 2 }
      , { code: "    , stroke \"#999\"  -- all same color", highlight: true, indent: 2 }
      , { code: "    , strokeWidth 1.5", highlight: false, indent: 2 }
      , { code: "    , fill \"none\"", highlight: false, indent: 2 }
      , { code: "    ]", highlight: false, indent: 2 }
      ]
  , insight: Just "7,470 points - but which line is which?"
  }

-- Step 11: Hover and Tooltip
step11_hoverTooltip :: TourStep
step11_hoverTooltip =
  { id: 11
  , title: "Interaction Makes It Readable"
  , narrative:
      [ "Add hover: the line highlights, others fade. A tooltip shows the metro area and exact values."
      , "7,470 data points across 45 cities, now instantly explorable. Interaction makes dense data readable."
      ]
  , codeLines:
      [ { code: "-- CSS handles the visual feedback", highlight: false, indent: 0 }
      , { code: ".line { stroke: #bbb }", highlight: true, indent: 0 }
      , { code: ".line:hover { stroke: #333; stroke-width: 2.5 }", highlight: true, indent: 0 }
      , { code: "", highlight: false, indent: 0 }
      , { code: "-- PureScript handles the tooltip", highlight: false, indent: 0 }
      , { code: "path", highlight: false, indent: 0 }
      , { code: "  [ onMouseMove \\info ->", highlight: true, indent: 2 }
      , { code: "      showTooltip info.datum.division info.pageX info.pageY", highlight: true, indent: 4 }
      , { code: "  , onMouseLeave \\_ -> hideTooltip", highlight: true, indent: 2 }
      , { code: "  ]", highlight: false, indent: 2 }
      ]
  , insight: Just "7,470 points made explorable with hover"
  }

-- | The visualization container selector
vizContainerSelector :: String
vizContainerSelector = "#scrolly-viz-container"

-- | Render the visualization for a given step
renderVizForStep :: Int -> Effect Unit
renderVizForStep stepId = do
  Viz.clearViz vizContainerSelector
  case stepId of
    1 -> Viz.renderViz vizContainerSelector Viz.step1EmptyCanvas
    2 -> Viz.renderViz vizContainerSelector Viz.step2ThreeGreenCircles
    3 -> Viz.renderViz vizContainerSelector Viz.step3ColoredCircles
    4 -> Viz.renderViz vizContainerSelector Viz.step4ParabolaBasic
    5 -> Viz.renderViz vizContainerSelector Viz.step5ParabolaAxes
    6 -> Viz.renderViz vizContainerSelector Viz.step6ParabolaLabels
    7 -> Viz.renderViz vizContainerSelector Viz.step7AnscombeSingle
    8 -> Viz.renderViz vizContainerSelector Viz.step8AnscombeQuartet
    9 -> Viz.renderViz vizContainerSelector Viz.step9AnscombeOverlay
    10 -> Viz.renderViz vizContainerSelector Viz.step10MultiLineBasic
    11 -> Viz.renderViz vizContainerSelector Viz.step11MultiLineHover
    _ -> pure unit

-- | Component definition
component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: \_ -> { currentStep: 1, observer: Nothing, isReady: false }
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      , finalize = Just Finalize
      }
  }

handleAction :: forall o m. MonadAff m => Action -> H.HalogenM State Action () o m Unit
handleAction = case _ of
  Initialize -> do
    -- Small delay to ensure DOM is ready
    H.liftAff $ delay (Milliseconds 100.0)

    -- Scroll to step 1 and render its visualization
    liftEffect $ scrollToStep 1
    liftEffect $ renderVizForStep 1

    -- Set up subscription for intersection observer events
    { emitter, listener } <- liftEffect HS.create

    -- Get the scroll container element for the observer root
    maybeScrollContainer <- liftEffect $ do
      win <- window
      doc <- Window.document win
      let parentNode = HTMLDocument.toParentNode doc
      querySelector (QuerySelector ".scrolly-scroll-panel") parentNode

    case maybeScrollContainer of
      Nothing -> pure unit
      Just scrollContainer -> do
        -- Create the intersection observer callback
        let callback :: Array IntersectionObserverEntry -> IntersectionObserver -> Effect Unit
            callback entries _ = do
              -- Find the entry with highest intersection ratio
              let bestEntry = foldl (\acc entry ->
                    if entry.isIntersecting && entry.intersectionRatio > (fromMaybe 0.0 (map _.intersectionRatio acc))
                    then Just entry
                    else acc
                  ) Nothing entries

              case bestEntry of
                Nothing -> pure unit
                Just entry -> do
                  -- Get the data-step attribute from the target element
                  maybeStepStr <- Element.getAttribute "data-step" entry.target
                  case maybeStepStr >>= Int.fromString of
                    Nothing -> pure unit
                    Just stepId -> HS.notify listener (StepBecameVisible stepId)

        -- Create observer with scroll container as root
        obs <- liftEffect $ newIntersectionObserver callback
          (root := scrollContainer <> threshold := 0.5)

        H.modify_ _ { observer = Just obs }

        -- Subscribe to the emitter
        void $ H.subscribe emitter

        -- Observe all step elements
        liftEffect $ do
          win <- window
          doc <- Window.document win
          let parentNode = HTMLDocument.toParentNode doc
          let stepIds = range 1 (length tourSteps)
          traverse_ (\id -> do
            maybeEl <- querySelector (QuerySelector $ "[data-step=\"" <> show id <> "\"]") parentNode
            case maybeEl of
              Nothing -> pure unit
              Just el -> observe obs el
          ) stepIds

    -- Mark as ready after a delay (to skip initial intersection events)
    H.liftAff $ delay (Milliseconds 300.0)
    handleAction MarkReady

  MarkReady -> do
    H.modify_ _ { isReady = true }

  Finalize -> do
    st <- H.get
    case st.observer of
      Just obs -> do
        -- Unobserve all elements
        liftEffect $ do
          win <- window
          doc <- Window.document win
          let parentNode = HTMLDocument.toParentNode doc
          let stepIds = range 1 (length tourSteps)
          traverse_ (\id -> do
            maybeEl <- querySelector (QuerySelector $ "[data-step=\"" <> show id <> "\"]") parentNode
            case maybeEl of
              Nothing -> pure unit
              Just el -> unobserve obs el
          ) stepIds
      Nothing -> pure unit

  StepBecameVisible stepId -> do
    st <- H.get
    -- Only process if we're ready (past initial burst of observe events)
    when st.isReady do
      when (stepId /= st.currentStep) do
        liftEffect $ renderVizForStep stepId
      H.modify_ _ { currentStep = stepId }

  GoToStep stepId -> do
    liftEffect $ scrollToStep stepId
    liftEffect $ renderVizForStep stepId
    H.modify_ _ { currentStep = stepId }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div
    [ HP.classes [ HH.ClassName "tour-scrolly" ] ]
    [ TourNav.renderHeader TourScrolly

    , HH.div
        [ HP.classes [ HH.ClassName "scrolly-container" ] ]
        [ -- Fixed visualization panel
          HH.div
            [ HP.classes [ HH.ClassName "scrolly-fixed-panel" ] ]
            [ renderVisualization state.currentStep
            , renderStepIndicator state.currentStep
            ]

        -- Scrolling content panel
        , HH.div
            [ HP.classes [ HH.ClassName "scrolly-scroll-panel" ] ]
            (mapWithIndex renderStep tourSteps)
        ]
    ]

-- | Render the visualization container
renderVisualization :: forall w i. Int -> HH.HTML w i
renderVisualization _ =
  HH.div
    [ HP.classes [ HH.ClassName "scrolly-viz" ]
    , HP.id "scrolly-viz-container"
    ]
    []

-- | Step indicator dots
renderStepIndicator :: forall m. Int -> H.ComponentHTML Action () m
renderStepIndicator currentStep =
  HH.div
    [ HP.classes [ HH.ClassName "scrolly-step-indicator" ] ]
    (mapWithIndex (\i _ ->
      HH.button
        [ HP.classes
            [ HH.ClassName "scrolly-step-dot"
            , HH.ClassName (if i + 1 == currentStep then "active" else "")
            ]
        , HE.onClick \_ -> GoToStep (i + 1)
        , HP.title (fromMaybe "" $ (_ .title) <$> (tourSteps !! i))
        ]
        []
    ) tourSteps)

-- | Render a single step
renderStep :: forall w i. Int -> TourStep -> HH.HTML w i
renderStep _ step =
  HH.div
    [ HP.classes [ HH.ClassName "scrolly-step" ]
    , HP.attr (HH.AttrName "data-step") (show step.id)
    ]
    [ HH.div
        [ HP.classes [ HH.ClassName "scrolly-step-number" ] ]
        [ HH.text $ show step.id ]

    , HH.h2
        [ HP.classes [ HH.ClassName "scrolly-step-title" ] ]
        [ HH.text step.title ]

    , HH.div
        [ HP.classes [ HH.ClassName "scrolly-step-narrative" ] ]
        (map (\p -> HH.p_ [ HH.text p ]) step.narrative)

    , HH.pre
        [ HP.classes [ HH.ClassName "scrolly-step-code" ] ]
        [ HH.code_
            (map renderCodeLine step.codeLines)
        ]

    , case step.insight of
        Just insight ->
          HH.div
            [ HP.classes [ HH.ClassName "scrolly-step-insight" ] ]
            [ HH.text insight ]
        Nothing -> HH.text ""
    ]

-- | Render a code line with optional highlighting
renderCodeLine :: forall w i. CodeLine -> HH.HTML w i
renderCodeLine { code, highlight } =
  HH.div
    [ HP.classes
        [ HH.ClassName "code-line"
        , HH.ClassName (if highlight then "highlight" else "")
        ]
    ]
    [ HH.text code ]
