module Hylographic.Main where

import Prelude

import Data.Const (Const)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Web.DOM.ParentNode (QuerySelector(..))
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.HTML.Events as HE
import Halogen.Subscription as HS
import Halogen.VDom.Driver (runUI)
import Type.Proxy (Proxy(..))

import Hylographic.Types (Route(..), ArticleMetadata)
import Hylographic.RoutingDSL (routing, routeToPath)
import Hylographic.Blog.ArticleViewer as ArticleViewer
import Hylographic.Blog.ForceIndex as ForceIndex
import Routing.Hash (matches, setHash)

-- | Application state
type State =
  { currentRoute :: Route
  }

-- | Application actions
data Action
  = Initialize
  | Navigate Route
  | RouteChanged (Maybe Route)
  | ForceIndexOutput ForceIndex.Output

-- | Child component slots
type Slots =
  ( articleViewer :: H.Slot (Const Void) Void Unit
  , forceIndex :: H.Slot (Const Void) ForceIndex.Output Unit
  )

_articleViewer :: Proxy "articleViewer"
_articleViewer = Proxy

_forceIndex :: Proxy "forceIndex"
_forceIndex = Proxy

-- | Sample articles for the force index (will be loaded from API later)
sampleArticles :: Array ArticleMetadata
sampleArticles =
  [ { slug: "hello-world", title: "Hello World", date: "2024-01-15", tags: ["introduction", "demo"] }
  ]

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
    [ HP.classes [ HH.ClassName "hylographic" ] ]
    [ renderHeader
    , HH.main
        [ HP.classes [ HH.ClassName "hylographic__main" ] ]
        [ renderPage state.currentRoute ]
    ]

renderHeader :: H.ComponentHTML Action Slots Aff
renderHeader =
  HH.header
    [ HP.classes [ HH.ClassName "hylographic__header" ] ]
    [ HH.a
        [ HP.href "#/"
        , HE.onClick \_ -> Navigate Home
        ]
        [ HH.h1_ [ HH.text "Hylographic" ] ]
    ]

-- | Render the current page based on route
renderPage :: Route -> H.ComponentHTML Action Slots Aff
renderPage = case _ of
  Home ->
    HH.slot _forceIndex unit ForceIndex.component sampleArticles ForceIndexOutput

  Post slug ->
    HH.slot_ _articleViewer unit ArticleViewer.component slug

  NotFound ->
    HH.div
      [ HP.classes [ HH.ClassName "not-found" ] ]
      [ HH.h2_ [ HH.text "404 - Page Not Found" ]
      , HH.p_ [ HH.text "The page you're looking for doesn't exist." ]
      , HH.a
          [ HP.href "#/"
          , HE.onClick \_ -> Navigate Home
          ]
          [ HH.text "Go to Home" ]
      ]

handleAction :: Action -> H.HalogenM State Action Slots Void Aff Unit
handleAction = case _ of
  Initialize -> do
    -- Subscribe to route changes
    void $ H.subscribe $ HS.makeEmitter \push ->
      matches routing \_ newRoute ->
        push (RouteChanged (Just newRoute))

  Navigate route ->
    H.liftEffect $ setHash (routeToPath route)

  RouteChanged maybeRoute -> do
    case maybeRoute of
      Just route -> H.modify_ _ { currentRoute = route }
      Nothing -> H.modify_ _ { currentRoute = NotFound }

  ForceIndexOutput output -> case output of
    ForceIndex.NavigateTo slug ->
      handleAction (Navigate (Post slug))

-- | Entry point
main :: Effect Unit
main = HA.runHalogenAff do
    maybeApp <- HA.selectElement (QuerySelector "#app")
    case maybeApp of
      Nothing -> do
        body <- HA.awaitBody
        runUI component unit body
      Just appEl ->
        runUI component unit appEl
