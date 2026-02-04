module Hylographic.Blog.ArticleViewer where

import Prelude

import Affjax.Web as AX
import Affjax.ResponseFormat as ResponseFormat
import Affjax.StatusCode (StatusCode(..))
import Data.Array as Array
import Data.Const (Const)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Void (Void)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff, liftAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Html.Renderer.Halogen as PH
import Type.Proxy (Proxy(..))

import Hylographic.Types (Slug)
import Hylographic.Blog.Markdown (parseMarkdown, highlightElement)
import Hylographic.Blog.ContentParser (ContentSegment(..), parseContent)
import Hylographic.Viz.Registry as VizRegistry

-- | Article loading state
data ArticleState
  = Loading
  | Loaded (Array ContentSegment)  -- Parsed content segments
  | Error String

-- | Component state
type State =
  { slug :: Slug
  , content :: ArticleState
  }

-- | Component actions
data Action
  = Initialize
  | FetchComplete (Either String String)

-- | Child slots for viz components (using Int key for dynamic components)
type Slots = ( viz :: H.Slot (Const Void) Void Int )

_viz :: Proxy "viz"
_viz = Proxy

-- | Input is the article slug
type Input = Slug

-- | ArticleViewer component
-- |
-- | Fetches markdown, parses to HTML, renders with syntax highlighting.
-- | Supports {{viz:ComponentName}} tags for embedded visualizations.
component :: forall q. H.Component q Input Void Aff
component = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

initialState :: Input -> State
initialState slug =
  { slug
  , content: Loading
  }

render :: State -> H.ComponentHTML Action Slots Aff
render state =
  HH.article
    [ HP.classes [ HH.ClassName "article" ] ]
    [ renderContent state.content ]

renderContent :: ArticleState -> H.ComponentHTML Action Slots Aff
renderContent = case _ of
  Loading ->
    HH.div
      [ HP.classes [ HH.ClassName "article__loading" ] ]
      [ HH.text "Loading article..." ]

  Loaded segments ->
    HH.div
      [ HP.classes [ HH.ClassName "article__content" ]
      , HP.id "article-content"
      ]
      (Array.mapWithIndex renderSegment segments)

  Error message ->
    HH.div
      [ HP.classes [ HH.ClassName "article__error" ] ]
      [ HH.h2_ [ HH.text "Error loading article" ]
      , HH.p_ [ HH.text message ]
      ]

-- | Render a single content segment
renderSegment :: Int -> ContentSegment -> H.ComponentHTML Action Slots Aff
renderSegment idx = case _ of
  HtmlContent html ->
    HH.div
      [ HP.classes [ HH.ClassName "article__html-segment" ] ]
      [ PH.render_ html ]

  VizComponent name ->
    case VizRegistry.lookupViz name of
      Just vizComponent ->
        HH.div
          [ HP.classes [ HH.ClassName "article__viz-segment", HH.ClassName ("viz-" <> name) ] ]
          [ HH.slot_ _viz idx vizComponent unit ]
      Nothing ->
        HH.div
          [ HP.classes [ HH.ClassName "article__viz-error" ] ]
          [ HH.p_
              [ HH.text $ "Unknown visualization: " <> name
              , HH.br_
              , HH.text $ "Available: " <> show VizRegistry.availableVizNames
              ]
          ]

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action Slots Void m Unit
handleAction = case _ of
  Initialize -> do
    slug <- H.gets _.slug
    -- Fetch the markdown file
    result <- liftAff $ fetchMarkdown slug
    handleAction (FetchComplete result)

  FetchComplete result ->
    case result of
      Left err ->
        H.modify_ _ { content = Error err }
      Right markdown -> do
        -- Parse markdown to HTML, then parse content segments
        let html = parseMarkdown markdown
        let segments = parseContent html
        H.modify_ _ { content = Loaded segments }
        -- Trigger syntax highlighting after render
        H.liftEffect $ highlightElement "#article-content"

-- | Fetch markdown content for an article
fetchMarkdown :: Slug -> Aff (Either String String)
fetchMarkdown slug = do
  let url = "/blog/posts/" <> slug <> ".md"
  response <- AX.get ResponseFormat.string url
  case response of
    Left err ->
      pure $ Left $ "Failed to fetch: " <> AX.printError err
    Right res ->
      if res.status >= StatusCode 200 && res.status < StatusCode 300
        then pure $ Right res.body
        else let (StatusCode n) = res.status
             in pure $ Left $ "HTTP " <> show n <> ": Article not found"
