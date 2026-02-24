-- | HATS version of TourMotionScrolly
-- |
-- | Key difference from original:
-- | - No stored selections - data is in component state
-- | - Animations by updating state and re-rendering with transitions
module Component.Tour.TourMotionScrollyHATS where

import Prelude

import Control.Monad.Rec.Class (forever)
import Data.Array (mapWithIndex, length, foldl, range, catMaybes)
import Data.String.CodeUnits as SCU
import Data.Traversable (traverse_, sequence)
import Effect.Random (random)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Int (fromString) as Int
import Data.Options ((:=))
import Data.Time.Duration (Milliseconds(..))
import Effect (Effect)
import Effect.Aff (Aff, delay)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Web.DOM.Element as Element
import Web.DOM.ParentNode (QuerySelector(..), querySelector)
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window as Window
import Web.Intersection.Observer (IntersectionObserver, newIntersectionObserver, observe, unobserve)
import Web.Intersection.Observer.Entry (IntersectionObserverEntry)
import Web.Intersection.Observer.Options (root, threshold)

-- HATS Animation module (tick-driven)
import Component.Tour.TourMotionAnimationsHATS as Anims
import Hylograph.HATS (Tree)
import Hylograph.HATS.InterpreterTick as HATS
import Hylograph.HATS.Transitions as T

-- Tree/Dendrogram animation (TreeAPI) - unchanged
import D3.Viz.TreeAPI.AnimatedTreeCluster as TreeCluster
import Hylograph.Shared.Data (loadFlareData)
import Data.Either (Either(..))

-- Les Mis force graph - unchanged
import D3.Viz.LesMisV3.Draw as LesMis
import D3.Viz.LesMisV3.Model (LesMisRawModel, processRawModel)
import Hylograph.Shared.DataLoader (simpleLoadJSON)
import Unsafe.Coerce (unsafeCoerce)

-- Navigation
import Hylograph.Shared.TourNav as TourNav
import Hylograph.Website.Types (Route(..))

-- FFI
foreign import scrollToStep :: Int -> Effect Unit

-- | A step in the motion tour
type MotionStep =
  { id :: Int
  , title :: String
  , narrative :: Array String
  , code :: String
  }

-- | Component state - HATS version uses data instead of stored selections
type State =
  { currentStep :: Int
  , observer :: Maybe IntersectionObserver
  , animationFiber :: Maybe H.ForkId
  -- Step 1-2: Single circle data
  , circleX :: Number
  , circleY :: Number
  , circleOpacity :: Number
  -- Step 3-4: Multi circle data
  , multiCircles :: Array Anims.MultiCircleData
  , multiTargetY :: Number
  -- Step 5: GUP circles visible IDs
  , gupVisibleIds :: Array Int
  -- Step 6: GUP letters
  , gupLetters :: String
  -- Step 8: Tree viz
  , treeVizState :: Maybe TreeCluster.VizState
  , currentLayout :: TreeCluster.LayoutType
  -- Step 9: Les Mis cleanup
  , lesMisCleanup :: Maybe (Effect Unit)
  , isReady :: Boolean
  -- Tick-driven transitions
  , transitions :: Maybe T.HATSTransitions
  , transitionFiber :: Maybe H.ForkId
  }

-- | Component actions
data Action
  = Initialize
  | Finalize
  | StepBecameVisible Int
  | MarkReady
  -- Animation tick actions
  | Step1Tick Boolean  -- True = fade out, False = fade in
  | Step2Tick Boolean  -- True = move right, False = move left
  | Step3Tick Boolean  -- True = move up, False = move down
  | Step4Tick Boolean  -- True = move up, False = move down
  | Step5Tick
  | Step6Tick
  | Step8Tick  -- Toggle tree/cluster layout
  -- Transition tick (delta time in ms)
  | TransitionTick Number

-- | The tour steps
tourSteps :: Array MotionStep
tourSteps =
  [ step1_oneCircle
  , step2_circleMove
  , step3_manyCircles
  , step4_staggered
  , step5_gupCircles
  , step6_gupLetters
  , step7_transition
  , step8_treeDendrogram
  , step9_lesMis
  ]

step1_oneCircle :: MotionStep
step1_oneCircle =
  { id: 1
  , title: "A Circle"
  , narrative:
      [ "Here is a circle. The simplest possible element."
      , "Watch it breathe - fading in and out. Even this minimal animation creates a sense of life."
      ]
  , code: """elem Circle
  [ cx $ num 100.0
  , cy $ num 150.0
  , r $ num 30.0
  , fill $ text "steelblue"
  , opacity $ num 1.0
  ]"""
  }

step2_circleMove :: MotionStep
step2_circleMove =
  { id: 2
  , title: "Motion"
  , narrative:
      [ "Now the circle moves. From here to there, and back again."
      , "This is the fundamental unit of animation: an attribute changing over time."
      ]
  , code: """withTransition config selection
  [ cx $ num targetX ]

-- config:
transitionWith
  { duration: 1200ms
  , easing: CubicInOut
  }"""
  }

step3_manyCircles :: MotionStep
step3_manyCircles =
  { id: 3
  , title: "Many Circles"
  , narrative:
      [ "More data means more circles. They all move together, in lockstep."
      , "When every element animates identically, the motion feels mechanical."
      ]
  , code: """joinData "circles" "circle" data
  (\\d -> elem Circle
    [ cx $ num d.x
    , cy $ num 150.0
    , r $ num 25.0
    ])"""
  }

step4_staggered :: MotionStep
step4_staggered =
  { id: 4
  , title: "Staggered Motion"
  , narrative:
      [ "Now each circle waits its turn. A small delay creates a wave effect."
      , "Staggering transforms mechanical motion into something organic."
      ]
  , code: """withTransitionStaggered config
  (staggerByIndex 80.0)
  selection
  [ cy $ num targetY ]"""
  }

step5_gupCircles :: MotionStep
step5_gupCircles =
  { id: 5
  , title: "The General Update Pattern"
  , narrative:
      [ "Data changes. Some circles appear, some disappear, some remain."
      , "Green circles enter. Brown circles exit. Gray circles stay."
      ]
  , code: """forEachWithGUP "circles" data keyFn
  template
  { enter: Just enterSpec
  , update: Just updateSpec
  , exit: Just exitSpec
  }"""
  }

step6_gupLetters :: MotionStep
step6_gupLetters =
  { id: 6
  , title: "Letters Dance"
  , narrative:
      [ "The same pattern, different data. Letters shuffle and rearrange."
      , "Green letters drop in. Red letters fall away. Dark letters slide."
      ]
  , code: """forEachWithGUP "letters" letters _.letter
  (\\d -> elem Text
    [ x $ letterXExpr
    , y $ num 150.0
    , textContent $ text d.letter
    ])
  gupSpec"""
  }

step7_transition :: MotionStep
step7_transition =
  { id: 7
  , title: "Beyond Simple Shapes"
  , narrative:
      [ "But it's not just simple shapes that can dance."
      , "The same principles apply to complex structures too."
      ]
  , code: """-- The same patterns scale up:
-- • Data binding
-- • Enter/Update/Exit
-- • Smooth transitions
-- • Staggered timing"""
  }

step8_treeDendrogram :: MotionStep
step8_treeDendrogram =
  { id: 8
  , title: "Tree ↔ Dendrogram"
  , narrative:
      [ "A hierarchical tree morphs into a dendrogram layout."
      , "Every node maintains its identity while flowing to new positions."
      ]
  , code: """-- Layout algorithms:
treeWithSorting config dataTree
cluster config dataTree

-- Same nodes, different positions"""
  }

step9_lesMis :: MotionStep
step9_lesMis =
  { id: 9
  , title: "Networks"
  , narrative:
      [ "And when data forms a network of relationships..."
      , "This is Les Misérables - 77 characters, 254 connections."
      ]
  , code: """simulation
  [ forceLink links
  , forceManyBody
  , forceCenter (w/2) (h/2)
  ]"""
  }

vizContainerSelector :: String
vizContainerSelector = "#motion-viz-container"

component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: \_ ->
      { currentStep: 1
      , observer: Nothing
      , animationFiber: Nothing
      , circleX: Anims.leftX
      , circleY: Anims.centerY
      , circleOpacity: 1.0
      , multiCircles: Anims.makeMultiCircleData 6
      , multiTargetY: Anims.centerY
      , gupVisibleIds: [0, 1, 2, 3, 4, 5, 6]
      , gupLetters: "ABCDEFG"
      , treeVizState: Nothing
      , currentLayout: TreeCluster.TreeLayout
      , lesMisCleanup: Nothing
      , isReady: false
      , transitions: Nothing
      , transitionFiber: Nothing
      }
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
    H.liftAff $ delay (Milliseconds 100.0)

    -- Initial render for step 1
    state <- H.get
    let tree = Anims.buildStep1Tree { id: 0, x: state.circleX, y: state.circleY, opacity: state.circleOpacity }
    liftEffect $ Anims.renderViz vizContainerSelector tree

    liftEffect $ scrollToStep 1
    startAnimationForStep 1

    -- Set up intersection observer (same as original)
    { emitter, listener } <- liftEffect HS.create
    maybeScrollContainer <- liftEffect $ do
      win <- window
      doc <- Window.document win
      let parentNode = HTMLDocument.toParentNode doc
      querySelector (QuerySelector ".motion-scroll-panel") parentNode

    case maybeScrollContainer of
      Nothing -> pure unit
      Just scrollContainer -> do
        let callback :: Array IntersectionObserverEntry -> IntersectionObserver -> Effect Unit
            callback entries _ = do
              let bestEntry = foldl (\acc entry ->
                    if entry.isIntersecting && entry.intersectionRatio > (fromMaybe 0.0 (map _.intersectionRatio acc))
                    then Just entry
                    else acc
                  ) Nothing entries
              case bestEntry of
                Nothing -> pure unit
                Just entry -> do
                  maybeStepStr <- Element.getAttribute "data-step" entry.target
                  case maybeStepStr >>= Int.fromString of
                    Nothing -> pure unit
                    Just stepId -> HS.notify listener (StepBecameVisible stepId)

        observer <- liftEffect $ newIntersectionObserver callback
          (root := scrollContainer <> threshold := 0.6)

        liftEffect $ do
          win <- window
          doc <- Window.document win
          let parentNode = HTMLDocument.toParentNode doc
          traverse_ (\i -> do
            maybeMarker <- querySelector (QuerySelector $ "[data-step=\"" <> show i <> "\"]") parentNode
            case maybeMarker of
              Just marker -> observe observer marker
              Nothing -> pure unit
          ) (range 1 (length tourSteps))

        H.modify_ \s -> s { observer = Just observer }
        void $ H.subscribe emitter

    H.liftAff $ delay (Milliseconds 300.0)
    handleAction MarkReady

  MarkReady ->
    H.modify_ \s -> s { isReady = true }

  Finalize -> do
    state <- H.get
    case state.animationFiber of
      Just forkId -> H.kill forkId
      Nothing -> pure unit
    case state.transitionFiber of
      Just forkId -> H.kill forkId
      Nothing -> pure unit
    case state.lesMisCleanup of
      Just cleanup -> liftEffect cleanup
      Nothing -> pure unit

  StepBecameVisible stepId -> do
    state <- H.get
    when state.isReady do
      when (stepId /= state.currentStep) do
        case state.animationFiber of
          Just forkId -> H.kill forkId
          Nothing -> pure unit
        H.modify_ \s -> s { animationFiber = Nothing }

        case state.lesMisCleanup of
          Just cleanup -> do
            liftEffect cleanup
            H.modify_ \s -> s { lesMisCleanup = Nothing }
          Nothing -> pure unit

        -- Kill any running transition tick loop
        case state.transitionFiber of
          Just forkId -> H.kill forkId
          Nothing -> pure unit
        H.modify_ \s -> s { transitions = Nothing, transitionFiber = Nothing }

        -- Clear container before switching to new step (different step types have different DOM structures)
        liftEffect $ Anims.clearViz vizContainerSelector

        -- Transition to new step
        case stepId of
          1 -> do
            H.modify_ \s -> s { circleX = Anims.leftX, circleY = Anims.centerY, circleOpacity = 1.0 }
            st' <- H.get
            let tree = Anims.buildStep1Tree { id: 0, x: st'.circleX, y: st'.circleY, opacity: st'.circleOpacity }
            rerenderWithTick vizContainerSelector tree

          2 -> do
            H.modify_ \s -> s { circleX = Anims.leftX, circleY = Anims.centerY, circleOpacity = 1.0 }
            st' <- H.get
            let tree = Anims.buildStep2Tree { id: 0, x: st'.circleX, y: st'.circleY, opacity: st'.circleOpacity }
            rerenderWithTick vizContainerSelector tree

          3 -> do
            let circles = Anims.makeMultiCircleData 6
            H.modify_ \s -> s { multiCircles = circles, multiTargetY = Anims.centerY }
            st' <- H.get
            let tree = Anims.buildStep3Tree st'.multiCircles st'.multiTargetY
            rerenderWithTick vizContainerSelector tree

          4 -> do
            st' <- H.get
            let tree = Anims.buildStep4Tree st'.multiCircles st'.multiTargetY
            rerenderWithTick vizContainerSelector tree

          5 -> do
            H.modify_ \s -> s { gupVisibleIds = [0, 1, 2, 3, 4, 5, 6] }
            st' <- H.get
            let tree = Anims.buildStep5Tree st'.gupVisibleIds
            rerenderWithTick vizContainerSelector tree

          6 -> do
            H.modify_ \s -> s { gupLetters = "ABCDEFG" }
            st' <- H.get
            let tree = Anims.buildStep6Tree st'.gupLetters
            rerenderWithTick vizContainerSelector tree

          7 -> do
            liftEffect $ Anims.clearViz vizContainerSelector

          8 -> do
            liftEffect $ Anims.clearViz vizContainerSelector
            result <- H.liftAff loadFlareData
            case result of
              Left _err -> pure unit
              Right flareTree -> do
                -- Draw initial tree with HATS, animation uses requestAnimationFrame
                vizState <- liftEffect $ TreeCluster.draw flareTree vizContainerSelector TreeCluster.TreeLayout
                H.modify_ \s -> s { treeVizState = Just vizState, currentLayout = TreeCluster.TreeLayout }

          9 -> do
            liftEffect $ Anims.clearViz vizContainerSelector
            rawJson <- H.liftAff $ simpleLoadJSON "./assets/data/miserables.json"
            let rawModel :: LesMisRawModel
                rawModel = unsafeCoerce rawJson
            let model = processRawModel rawModel
            cleanup <- liftEffect $ LesMis.startLesMis model vizContainerSelector
            H.modify_ \s -> s { lesMisCleanup = Just cleanup }

          _ -> pure unit

        startAnimationForStep stepId
        H.modify_ \s -> s { currentStep = stepId }

  -- Animation ticks - update state and rerender with transitions
  Step1Tick fadeOut -> do
    let targetOpacity = if fadeOut then 0.3 else 1.0
    H.modify_ \s -> s { circleOpacity = targetOpacity }
    st <- H.get
    let tree = Anims.buildStep1Tree { id: 0, x: st.circleX, y: st.circleY, opacity: st.circleOpacity }
    rerenderWithTick vizContainerSelector tree

  Step2Tick moveRight -> do
    let targetX = if moveRight then Anims.rightX else Anims.leftX
    H.modify_ \s -> s { circleX = targetX }
    st <- H.get
    let tree = Anims.buildStep2Tree { id: 0, x: st.circleX, y: st.circleY, opacity: st.circleOpacity }
    rerenderWithTick vizContainerSelector tree

  Step3Tick moveUp -> do
    let targetY = if moveUp then 120.0 else 180.0
    H.modify_ \s -> s { multiTargetY = targetY }
    st <- H.get
    let tree = Anims.buildStep3Tree st.multiCircles st.multiTargetY
    rerenderWithTick vizContainerSelector tree

  Step4Tick moveUp -> do
    let targetY = if moveUp then 120.0 else 180.0
    H.modify_ \s -> s { multiTargetY = targetY }
    st <- H.get
    let tree = Anims.buildStep4Tree st.multiCircles st.multiTargetY
    rerenderWithTick vizContainerSelector tree

  Step5Tick -> do
    visibleIds <- liftEffect $ randomSubset 7
    H.modify_ \s -> s { gupVisibleIds = visibleIds }
    st <- H.get
    let tree = Anims.buildStep5Tree st.gupVisibleIds
    rerenderWithTick vizContainerSelector tree

  Step6Tick -> do
    letters <- liftEffect getRandomLetters
    H.modify_ \s -> s { gupLetters = letters }
    st <- H.get
    let tree = Anims.buildStep6Tree st.gupLetters
    rerenderWithTick vizContainerSelector tree

  Step8Tick -> do
    st <- H.get
    case st.treeVizState of
      Nothing -> pure unit
      Just vizState -> do
        let newLayout = TreeCluster.toggleLayout st.currentLayout
        H.modify_ \s -> s { currentLayout = newLayout }
        -- Uses manual requestAnimationFrame animation loop with interpolation
        liftEffect $ TreeCluster.update vizState.dataTree vizContainerSelector vizState.chartWidth vizState.chartHeight newLayout

  TransitionTick deltaMs -> do
    st <- H.get
    case st.transitions of
      Nothing -> pure unit
      Just ts -> do
        result <- liftEffect $ T.tickTransitions deltaMs ts
        case result of
          T.Complete -> do
            -- Kill the tick loop and clear transitions
            case st.transitionFiber of
              Just forkId -> H.kill forkId
              Nothing -> pure unit
            H.modify_ \s -> s { transitions = Nothing, transitionFiber = Nothing }
          T.Running newTs ->
            H.modify_ \s -> s { transitions = Just newTs }

-- | Rerender and start tick loop if transitions are returned
rerenderWithTick :: forall o m. MonadAff m => String -> Tree -> H.HalogenM State Action () o m Unit
rerenderWithTick selector tree = do
  -- Kill any existing transition loop
  st <- H.get
  case st.transitionFiber of
    Just forkId -> H.kill forkId
    Nothing -> pure unit

  -- Rerender and capture transitions
  result <- liftEffect $ HATS.rerender selector tree
  case result.transitions of
    Nothing ->
      H.modify_ \s -> s { transitions = Nothing, transitionFiber = Nothing }
    Just ts -> do
      -- Store transitions
      H.modify_ \s -> s { transitions = Just ts }
      -- Start tick loop (~60fps)
      forkId <- H.fork $ tickLoop
      H.modify_ \s -> s { transitionFiber = Just forkId }
  where
  tickLoop = do
    H.liftAff $ delay (Milliseconds 16.0)  -- ~60fps
    handleAction (TransitionTick 16.0)
    st <- H.get
    -- Continue if still running
    case st.transitions of
      Just _ -> tickLoop
      Nothing -> pure unit

startAnimationForStep :: forall o m. MonadAff m => Int -> H.HalogenM State Action () o m Unit
startAnimationForStep stepId = case stepId of
  1 -> do
    forkId <- H.fork $ forever do
      H.liftAff $ delay (Milliseconds 1200.0)
      handleAction (Step1Tick true)
      H.liftAff $ delay (Milliseconds 1200.0)
      handleAction (Step1Tick false)
    H.modify_ \s -> s { animationFiber = Just forkId }

  2 -> do
    forkId <- H.fork $ forever do
      handleAction (Step2Tick true)
      H.liftAff $ delay (Milliseconds 1500.0)
      handleAction (Step2Tick false)
      H.liftAff $ delay (Milliseconds 1500.0)
    H.modify_ \s -> s { animationFiber = Just forkId }

  3 -> do
    forkId <- H.fork $ forever do
      handleAction (Step3Tick true)
      H.liftAff $ delay (Milliseconds 1000.0)
      handleAction (Step3Tick false)
      H.liftAff $ delay (Milliseconds 1000.0)
    H.modify_ \s -> s { animationFiber = Just forkId }

  4 -> do
    forkId <- H.fork $ forever do
      handleAction (Step4Tick true)
      H.liftAff $ delay (Milliseconds 1200.0)
      handleAction (Step4Tick false)
      H.liftAff $ delay (Milliseconds 1200.0)
    H.modify_ \s -> s { animationFiber = Just forkId }

  5 -> do
    forkId <- H.fork do
      H.liftAff $ delay (Milliseconds 1800.0)
      forever do
        handleAction Step5Tick
        H.liftAff $ delay (Milliseconds 1500.0)
    H.modify_ \s -> s { animationFiber = Just forkId }

  6 -> do
    forkId <- H.fork do
      H.liftAff $ delay (Milliseconds 2000.0)
      forever do
        handleAction Step6Tick
        H.liftAff $ delay (Milliseconds 2000.0)
    H.modify_ \s -> s { animationFiber = Just forkId }

  7 -> pure unit

  8 -> do
    forkId <- H.fork $ forever do
      H.liftAff $ delay (Milliseconds 2500.0)
      handleAction Step8Tick
    H.modify_ \s -> s { animationFiber = Just forkId }

  9 -> pure unit

  _ -> pure unit

getRandomLetters :: Effect String
getRandomLetters = do
  let alphabet = SCU.toCharArray "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      coinToss :: Char -> Effect (Maybe Char)
      coinToss c = do
        n <- random
        pure $ if n > 0.6 then Just c else Nothing
  choices <- sequence $ coinToss <$> alphabet
  pure $ SCU.fromCharArray $ catMaybes choices

randomSubset :: Int -> Effect (Array Int)
randomSubset n = do
  results <- sequence $ range 0 (n - 1) <#> \i -> do
    r <- random
    pure $ if r > 0.4 then Just i else Nothing
  pure $ catMaybes results

render :: forall m. State -> H.ComponentHTML Action () m
render _state =
  HH.div_
    [ TourNav.renderHeader TourMotionScrollyHATS
    , HH.div
        [ HP.class_ (HH.ClassName "motion-tour-container") ]
        [ HH.div
            [ HP.class_ (HH.ClassName "motion-viz-panel") ]
            [ HH.div
                [ HP.id "motion-viz-container"
                , HP.class_ (HH.ClassName "motion-viz-content")
                ]
                []
            ]
        , HH.div
            [ HP.class_ (HH.ClassName "motion-scroll-panel") ]
            (mapWithIndex renderStep tourSteps)
        ]
    ]

renderStep :: forall w. Int -> MotionStep -> HH.HTML w Action
renderStep _idx step =
  HH.div
    [ HP.class_ (HH.ClassName "motion-step")
    , HP.attr (HH.AttrName "data-step") (show step.id)
    ]
    [ HH.div
        [ HP.class_ (HH.ClassName "motion-step-content") ]
        [ HH.h3_ [ HH.text step.title ]
        , HH.div
            [ HP.class_ (HH.ClassName "motion-step-narrative") ]
            (map (\p -> HH.p_ [ HH.text p ]) step.narrative)
        ]
    , HH.pre
        [ HP.class_ (HH.ClassName "motion-step-code") ]
        [ HH.code_ [ HH.text step.code ] ]
    ]
