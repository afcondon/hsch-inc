module Hylographic.Blog.ForceIndex where

import Prelude

import Data.Array as Array
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Nullable as Nullable
import Data.String (take, length) as String
import Effect.Aff.Class (class MonadAff)
import Effect.Class (liftEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA

import Hylograph.Simulation (runSimulation, SimulationEvent(..), SimulationHandle, Engine(..), setup, manyBody, center, collide, withStrength, withRadius, withX, withY, static)
import Hylograph.ForceEngine.Halogen (toHalogenEmitter)
import Hylograph.ForceEngine.Simulation (SimulationNode)

import Hylographic.Types (Slug, ArticleMetadata)

-- | Article node with simulation fields
type ArticleNode = SimulationNode (title :: String, slug :: Slug, tags :: Array String)

-- | Component state
type State =
  { nodes :: Array ArticleNode
  , alpha :: Number
  , dimensions :: { width :: Number, height :: Number }
  , simHandle :: Maybe (SimulationHandle (title :: String, slug :: Slug, tags :: Array String))
  }

-- | Component actions
data Action
  = Initialize
  | SimEvent SimulationEvent
  | ClickNode Slug

-- | Output: navigate to article
data Output = NavigateTo Slug

-- | Input: list of articles to display
type Input = Array ArticleMetadata

-- | ForceIndex component - displays articles as force-directed graph
component :: forall q m. MonadAff m => H.Component q Input Output m
component = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

initialState :: Input -> State
initialState articles =
  { nodes: articlesToNodes articles
  , alpha: 1.0
  , dimensions: { width: 600.0, height: 400.0 }
  , simHandle: Nothing
  }

-- | Convert article metadata to simulation nodes
articlesToNodes :: Array ArticleMetadata -> Array ArticleNode
articlesToNodes = Array.mapWithIndex \i meta ->
  { id: i
  , x: 300.0 + toNumber (i `mod` 3) * 100.0
  , y: 200.0 + toNumber (i `div` 3) * 100.0
  , vx: 0.0
  , vy: 0.0
  , fx: Nullable.null
  , fy: Nullable.null
  , title: meta.title
  , slug: meta.slug
  , tags: meta.tags
  }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div
    [ HP.classes [ HH.ClassName "force-index" ] ]
    [ HH.h2_ [ HH.text "Articles" ]
    , renderSVG state
    ]

renderSVG :: forall m. State -> H.ComponentHTML Action () m
renderSVG state =
  SE.svg
    [ SA.viewBox 0.0 0.0 state.dimensions.width state.dimensions.height
    , SA.width 600.0
    , SA.height 400.0
    , SA.classes [ HH.ClassName "force-index__svg" ]
    ]
    (map renderNode state.nodes)

renderNode :: forall m. ArticleNode -> H.ComponentHTML Action () m
renderNode node =
  SE.g
    [ SA.transform [ SA.Translate node.x node.y ]
    , SA.classes [ HH.ClassName "force-index__node" ]
    , HE.onClick \_ -> ClickNode node.slug
    ]
    [ SE.circle
        [ SA.cx 0.0
        , SA.cy 0.0
        , SA.r 30.0
        , SA.fill (SA.Named "#0066cc")
        , SA.fillOpacity 0.8
        , SA.classes [ HH.ClassName "force-index__circle" ]
        ]
    , SE.text
        [ SA.textAnchor SA.AnchorMiddle
        , SA.dominantBaseline SA.BaselineMiddle
        , SA.fill (SA.Named "white")
        , SA.classes [ HH.ClassName "force-index__label" ]
        ]
        [ HH.text (truncateTitle node.title) ]
    ]

-- | Truncate title to fit in node
truncateTitle :: String -> String
truncateTitle title =
  if String.length title > 12
    then String.take 10 title <> "..."
    else title

handleAction :: forall m. MonadAff m => Action -> H.HalogenM State Action () Output m Unit
handleAction = case _ of
  Initialize -> do
    state <- H.get
    -- Only run simulation if we have nodes
    when (Array.length state.nodes > 0) do
      -- Create force simulation
      let simSetup = setup "articles"
            [ manyBody "charge" # withStrength (static (-100.0))
            , center "center" # withX (static 300.0) # withY (static 200.0)
            , collide "collide" # withRadius (static 35.0)
            ]

      { handle, events } <- liftEffect $ runSimulation
        { engine: D3
        , setup: simSetup
        , nodes: state.nodes
        , links: []
        , container: ".force-index__svg"
        , alphaMin: 0.001
        }

      -- Store handle for getting updated node positions
      H.modify_ _ { simHandle = Just handle }

      -- Subscribe to simulation events
      halogenEmitter <- liftEffect $ toHalogenEmitter events
      void $ H.subscribe $ halogenEmitter <#> SimEvent

  SimEvent event -> case event of
    Tick { alpha } -> do
      state <- H.get
      case state.simHandle of
        Nothing -> pure unit
        Just handle -> do
          -- Get updated node positions from the simulation
          updatedNodes <- liftEffect $ handle.getNodes
          H.modify_ _ { nodes = updatedNodes, alpha = alpha }
    Completed -> pure unit
    Started -> pure unit
    Stopped -> pure unit

  ClickNode slug ->
    H.raise (NavigateTo slug)
