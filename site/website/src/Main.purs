module Hylograph.Main where

import Prelude

import Data.Maybe (Maybe(..))
import Debug (spy)
import Effect (Effect)
import Effect.Aff (Aff)
import Web.HTML (window)
import Web.HTML.Location as Web.HTML.Location
import Web.HTML.Window as Web.HTML.Window
import Web.HTML.Window (scroll)
import Web.DOM.ParentNode (QuerySelector(..))
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Halogen.VDom.Driver (runUI)

-- Core pages
import Hylograph.Home as Home
import Hylograph.Tutorial.GettingStarted as GettingStarted
import Hylograph.HowTo.HowtoIndex as HowtoIndex
import Component.HowTo.HowtoTransitions as HowtoTransitions
import Component.HowTo.HowtoForceGraphs as HowtoForceGraphs
import Component.HowTo.HowtoHierarchical as HowtoHierarchical
import Component.HowTo.HowtoEvents as HowtoEvents
import Component.HowTo.HowtoLoadingData as HowtoLoadingData
import Component.HowTo.HowtoTooltips as HowtoTooltips
import Component.HowTo.HowtoDebugging as HowtoDebugging
import Component.HowTo.HowtoPerformance as HowtoPerformance
import Hylograph.Understanding as Understanding
import Component.Understanding.UnderstandingGrammar as UnderstandingGrammar
import Component.Understanding.UnderstandingAttributes as UnderstandingAttributes
import Component.Understanding.UnderstandingSelections as UnderstandingSelections
import Component.Understanding.UnderstandingScenes as UnderstandingScenes
import Hylograph.Reference.Reference as Reference
import Hylograph.Acknowledgements as Acknowledgements

-- Tour pages
import Component.Tour.TourIndex as TourIndex
import Component.Tour.TourScrolly as TourScrolly
import Component.Tour.TourMotionScrollyHATS as TourMotionScrollyHATS
import Component.Tour.TourSimpsons as TourSimpsons

-- Showcase
import Component.Showcase.ShowcaseIndex as ShowcaseIndex
import Component.Showcase.ShowcaseLuaEdge as ShowcaseLuaEdge
import Page.Simpsons as SimpsonsV2

-- Active demos
import Component.ForcePlayground as ForcePlayground
-- import TreeBuilder.App as TreeBuilder  -- REMOVED: module deleted

-- Routing
import Hylograph.RoutingDSL (routing, routeToPath)
import Hylograph.Website.Types (Route(..))
import Routing.Hash (matches, setHash)
import Type.Proxy (Proxy(..))

-- | Main application state
type State = {
  currentRoute :: Route
}

-- | Main application actions
data Action
  = Initialize
  | Navigate Route
  | RouteChanged (Maybe Route)

-- | Child component slots
type Slots =
  ( home :: forall q. H.Slot q Void Unit
  , gettingStarted :: forall q. H.Slot q Void Unit
  , howtoIndex :: forall q. H.Slot q Void Unit
  , howtoTransitions :: forall q. H.Slot q Void Unit
  , howtoForceGraphs :: forall q. H.Slot q Void Unit
  , howtoHierarchical :: forall q. H.Slot q Void Unit
  , howtoEvents :: forall q. H.Slot q Void Unit
  , howtoLoadingData :: forall q. H.Slot q Void Unit
  , howtoTooltips :: forall q. H.Slot q Void Unit
  , howtoDebugging :: forall q. H.Slot q Void Unit
  , howtoPerformance :: forall q. H.Slot q Void Unit
  , understanding :: forall q. H.Slot q Void Unit
  , understandingGrammar :: forall q. H.Slot q Void Unit
  , understandingAttributes :: forall q. H.Slot q Void Unit
  , understandingSelections :: forall q. H.Slot q Void Unit
  , understandingScenes :: forall q. H.Slot q Void Unit
  , reference :: forall q. H.Slot q Void Unit
  , tourIndex :: forall q. H.Slot q Void Unit
  , tourScrolly :: forall q. H.Slot q Void Unit
  , tourMotionScrollyHATS :: forall q. H.Slot q Void Unit
  , tourSimpsons :: forall q. H.Slot q Void Unit
  , showcase :: forall q. H.Slot q Void Unit
  , showcaseLuaEdge :: forall q. H.Slot q Void Unit
  , simpsonsV2 :: H.Slot SimpsonsV2.Query Void Unit
  , moduleGraph :: forall q. H.Slot q Void Unit
  , forcePlayground :: forall q. H.Slot q Void Unit
  -- , treeBuilder :: forall q. H.Slot q Void Unit  -- REMOVED
  , acknowledgements :: forall q. H.Slot q Void Unit
  )

_home = Proxy :: Proxy "home"
_gettingStarted = Proxy :: Proxy "gettingStarted"
_howtoIndex = Proxy :: Proxy "howtoIndex"
_howtoTransitions = Proxy :: Proxy "howtoTransitions"
_howtoForceGraphs = Proxy :: Proxy "howtoForceGraphs"
_howtoHierarchical = Proxy :: Proxy "howtoHierarchical"
_howtoEvents = Proxy :: Proxy "howtoEvents"
_howtoLoadingData = Proxy :: Proxy "howtoLoadingData"
_howtoTooltips = Proxy :: Proxy "howtoTooltips"
_howtoDebugging = Proxy :: Proxy "howtoDebugging"
_howtoPerformance = Proxy :: Proxy "howtoPerformance"
_understanding = Proxy :: Proxy "understanding"
_understandingGrammar = Proxy :: Proxy "understandingGrammar"
_understandingAttributes = Proxy :: Proxy "understandingAttributes"
_understandingSelections = Proxy :: Proxy "understandingSelections"
_understandingScenes = Proxy :: Proxy "understandingScenes"
_reference = Proxy :: Proxy "reference"
_tourIndex = Proxy :: Proxy "tourIndex"
_tourScrolly = Proxy :: Proxy "tourScrolly"
_tourMotionScrollyHATS = Proxy :: Proxy "tourMotionScrollyHATS"
_tourSimpsons = Proxy :: Proxy "tourSimpsons"
_showcase = Proxy :: Proxy "showcase"
_showcaseLuaEdge = Proxy :: Proxy "showcaseLuaEdge"
_simpsonsV2 = Proxy :: Proxy "simpsonsV2"
_moduleGraph = Proxy :: Proxy "moduleGraph"
_forcePlayground = Proxy :: Proxy "forcePlayground"
-- _treeBuilder = Proxy :: Proxy "treeBuilder"  -- REMOVED
_acknowledgements = Proxy :: Proxy "acknowledgements"

-- | Main application component
component :: forall q i. H.Component q i Void Aff
component = H.mkComponent
  { initialState: \_ -> { currentRoute: Home }
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: State -> H.ComponentHTML Action Slots Aff
render state =
  HH.div
    [ HP.classes [ HH.ClassName "app" ] ]
    [ HH.main
        [ HP.classes [ HH.ClassName "app__main" ] ]
        [ renderPage state.currentRoute ]
    ]

-- | Render the current page based on route
renderPage :: Route -> H.ComponentHTML Action Slots Aff
renderPage route = case spy "Route is" route of
  Home ->
    HH.slot_ _home unit Home.component unit

  GettingStarted ->
    HH.slot_ _gettingStarted unit GettingStarted.component unit

  HowtoIndex ->
    HH.slot_ _howtoIndex unit HowtoIndex.component unit

  HowtoTransitions ->
    HH.slot_ _howtoTransitions unit HowtoTransitions.component unit

  HowtoForceGraphs ->
    HH.slot_ _howtoForceGraphs unit HowtoForceGraphs.component unit

  HowtoHierarchical ->
    HH.slot_ _howtoHierarchical unit HowtoHierarchical.component unit

  HowtoEvents ->
    HH.slot_ _howtoEvents unit HowtoEvents.component unit

  HowtoLoadingData ->
    HH.slot_ _howtoLoadingData unit HowtoLoadingData.component unit

  HowtoTooltips ->
    HH.slot_ _howtoTooltips unit HowtoTooltips.component unit

  HowtoDebugging ->
    HH.slot_ _howtoDebugging unit HowtoDebugging.component unit

  HowtoPerformance ->
    HH.slot_ _howtoPerformance unit HowtoPerformance.component unit

  Understanding ->
    HH.slot_ _understanding unit Understanding.component unit

  UnderstandingGrammar ->
    HH.slot_ _understandingGrammar unit UnderstandingGrammar.component unit

  UnderstandingAttributes ->
    HH.slot_ _understandingAttributes unit UnderstandingAttributes.component unit

  UnderstandingSelections ->
    HH.slot_ _understandingSelections unit UnderstandingSelections.component unit

  UnderstandingScenes ->
    HH.slot_ _understandingScenes unit UnderstandingScenes.component unit

  Reference ->
    HH.slot_ _reference unit Reference.component unit

  ReferenceModule _ ->
    -- ReferenceModule routes redirect to the main Reference page
    HH.slot_ _reference unit Reference.component unit

  TourIndex ->
    HH.slot_ _tourIndex unit TourIndex.component unit

  TourScrolly ->
    HH.slot_ _tourScrolly unit TourScrolly.component unit

  TourMotionScrollyHATS ->
    HH.slot_ _tourMotionScrollyHATS unit TourMotionScrollyHATS.component unit

  TourSimpsons ->
    HH.slot_ _tourSimpsons unit TourSimpsons.component unit

  Showcase ->
    HH.slot_ _showcase unit ShowcaseIndex.component unit

  ShowcaseLuaEdge ->
    HH.slot_ _showcaseLuaEdge unit ShowcaseLuaEdge.component unit

  SimpsonsV2 ->
    HH.slot_ _simpsonsV2 unit SimpsonsV2.component unit

  ModuleGraph ->
    -- ModuleGraph needs its own component - for now show placeholder
    HH.div_ [ HH.text "Module Graph - coming soon" ]

  ForcePlayground ->
    HH.slot_ _forcePlayground unit ForcePlayground.component unit

  TreeBuilder ->
    -- TreeBuilder removed - Hylograph Explorer replaces it
    HH.div_ [ HH.text "Tree Builder has been replaced by Hylograph Explorer" ]

  Acknowledgements ->
    HH.slot_ _acknowledgements unit Acknowledgements.component unit

  NotFound ->
    HH.div
      [ HP.classes [ HH.ClassName "not-found" ] ]
      [ HH.h1_ [ HH.text "404 - Page Not Found" ]
      , HH.p_ [ HH.text "The page you're looking for doesn't exist." ]
      , HH.a
          [ HP.href $ "#" <> routeToPath Home ]
          [ HH.text "Go to Home" ]
      ]

handleAction :: Action -> H.HalogenM State Action Slots Void Aff Unit
handleAction = case _ of
  Initialize -> do
    -- Check if we're at root and redirect to /home for proper history
    currentHash <- H.liftEffect $ do
      w <- window
      loc <- Web.HTML.Window.location w
      Web.HTML.Location.hash loc
    when (currentHash == "" || currentHash == "#" || currentHash == "#/") $ do
      H.liftEffect $ setHash (routeToPath Home)

    -- Subscribe to route changes using purescript-routing
    _ <- H.subscribe $ HS.makeEmitter \push -> do
      matches routing \_ newRoute -> do
        push (RouteChanged (Just newRoute))
    pure unit

  Navigate route -> do
    H.liftEffect $ setHash (routeToPath route)

  RouteChanged maybeRoute -> do
    let _ = spy "RouteChanged" maybeRoute
    case maybeRoute of
      Just route -> do
        let _ = spy "Updating currentRoute to" route
        H.modify_ _ { currentRoute = route }
      Nothing -> H.modify_ _ { currentRoute = NotFound }
    -- Scroll to top of page on route change
    H.liftEffect do
      w <- window
      scroll 0 0 w

-- | Entry point
main :: Effect Unit
main = HA.runHalogenAff do
  -- Mount to #app element instead of body
  maybeApp <- HA.selectElement (QuerySelector "#app")
  case maybeApp of
    Nothing -> do
      -- Fallback to body if #app not found
      body <- HA.awaitBody
      runUI component unit body
    Just appEl ->
      runUI component unit appEl
