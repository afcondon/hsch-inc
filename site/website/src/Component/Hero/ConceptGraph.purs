module Component.Hero.ConceptGraph where

import Prelude

import Affjax.Web as AX
import Affjax.ResponseFormat as ResponseFormat
import Data.Array as Array
import Data.Either (Either(..))
import Data.Int (toNumber)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (fromString) as Number
import Data.Nullable (Nullable, null, notNull)
import Data.String (split, trim)
import Data.String.Pattern (Pattern(..))
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.HTML.Core (AttrName(..))
import Halogen.Subscription as HS
import Halogen.Svg.Attributes as SA
import Halogen.Svg.Elements as SE
import Hylograph.ForceEngine as FE
import Hylograph.ForceEngine.Simulation (SimulationNode)
import Web.UIEvent.MouseEvent (MouseEvent, clientX, clientY)

-- | Node categories for coloring
data Category
  = CatCore        -- PureScript itself (pinned center)
  | CatBackend     -- Compile targets: JS, Python, Erlang, Lua, Rust
  | CatRuntime     -- Runtimes: WASM, BEAM, nginx, node, browser
  | CatConcept     -- FP concepts: finally tagless, type safety, etc
  | CatLibrary     -- PSD3 libraries: psd3-tree, psd3-selection, etc
  | CatExtLibrary  -- External libraries: D3, pandas, numpy, etc
  | CatShowcase    -- Showcases: Algorave, Sankey, Code Explorer
  | CatDomain      -- Domains: dataviz, live coding, scientific, etc

derive instance eqCategory :: Eq Category

-- | Extra fields for concept nodes (beyond D3 simulation fields)
type ConceptNodeExtra =
  ( label :: String
  , category :: Category
  , r :: Number
  )

-- | Full concept node type (includes D3 simulation fields: id, x, y, vx, vy, fx, fy)
type ConceptNode = SimulationNode ConceptNodeExtra

-- | Link types for categorization
data LinkType
  = BuildsTo      -- PureScript compiles to backend
  | RunsOn        -- Showcase runs on backend
  | Enables       -- Concept enables capability
  | UsesLibrary   -- Uses a library

derive instance eqLinkType :: Eq LinkType

-- | Extra fields for links
type ConceptLinkExtra :: Row Type
type ConceptLinkExtra = ()

-- | Full link type with category
type ConceptLink = { source :: Int, target :: Int, linkType :: LinkType }

-- | Parse category from string
parseCategory :: String -> Category
parseCategory = case _ of
  "core" -> CatCore
  "backend" -> CatBackend
  "runtime" -> CatRuntime
  "concept" -> CatConcept
  "library" -> CatLibrary
  "ext-library" -> CatExtLibrary
  "showcase" -> CatShowcase
  "domain" -> CatDomain
  _ -> CatConcept  -- fallback

-- | Parse link type from string
parseLinkType :: String -> LinkType
parseLinkType = case _ of
  "builds-to" -> BuildsTo
  "runs-on" -> RunsOn
  "enables" -> Enables
  "uses-library" -> UsesLibrary
  _ -> Enables  -- fallback

-- | Get Y layer for category (stratified layout)
categoryLayer :: Category -> Int
categoryLayer = case _ of
  CatCore -> 0       -- PureScript at top
  CatBackend -> 1    -- Compile targets
  CatRuntime -> 2    -- Runtimes
  CatConcept -> 3    -- Concepts
  CatLibrary -> 3    -- Libraries (same layer as concepts)
  CatExtLibrary -> 4 -- External libraries
  CatShowcase -> 5   -- Showcases
  CatDomain -> 6     -- Domains at bottom

-- | Parse nodes CSV (label,category,r) with stratified Y layout
parseNodesCSV :: Number -> Number -> String -> Array ConceptNode
parseNodesCSV centerX centerY csv =
  let
    height = centerY * 2.0  -- Total height
    layerSpacing = height / 7.0  -- 7 layers (0-6)
    topPadding = 30.0

    lines = Array.filter (\l -> trim l /= "" && trim l /= "label,category,r")
          $ split (Pattern "\n") csv
    parseNode idx line =
      case split (Pattern ",") (trim line) of
        [label, cat, rStr] ->
          let r = fromMaybe 6.0 $ Number.fromString (trim rStr)
              category = parseCategory (trim cat)
              layer = categoryLayer category
              -- Y is pinned by layer, X floats
              layerY = topPadding + (toNumber layer) * layerSpacing
              -- Spread X based on index within layer (will be adjusted by force)
              spreadX = centerX + (toNumber (idx `mod` 5) - 2.0) * 40.0
              -- Core is fully pinned, others have pinned Y only
              fx = if category == CatCore then notNull centerX else null
              fy = notNull layerY  -- All nodes pinned to their layer Y
          in Just $ mkNode idx (trim label) category spreadX layerY fx fy r
        _ -> Nothing
  in Array.catMaybes $ Array.mapWithIndex parseNode lines

-- | Parse edges CSV and convert labels to indices (source,target,type)
parseEdgesCSV :: Array ConceptNode -> String -> Array ConceptLink
parseEdgesCSV nodes csv =
  let
    -- Build label -> index map
    labelToIdx = Map.fromFoldable $ Array.mapWithIndex (\i n -> Tuple n.label i) nodes
    lines = Array.filter (\l -> trim l /= "" && trim l /= "source,target,type")
          $ split (Pattern "\n") csv
    parseEdge line =
      case split (Pattern ",") (trim line) of
        [src, tgt, typ] -> do
          srcIdx <- Map.lookup (trim src) labelToIdx
          tgtIdx <- Map.lookup (trim tgt) labelToIdx
          pure { source: srcIdx, target: tgtIdx, linkType: parseLinkType (trim typ) }
        _ -> Nothing
  in Array.catMaybes $ map parseEdge lines

-- | Component state
type State =
  { nodes :: Array ConceptNode
  , links :: Array ConceptLink
  , simulation :: Maybe (FE.Simulation ConceptNodeExtra ConceptLinkExtra)
  , width :: Number
  , height :: Number
  , dragging :: Maybe String           -- Label of node being dragged
  , lastMouse :: { x :: Number, y :: Number }  -- Last mouse position (for delta dragging)
  , loading :: Boolean
  }

-- | Component actions
data Action
  = Initialize
  | SimTick
  | StartDrag String MouseEvent
  | DragMove MouseEvent
  | EndDrag

-- | Helper to create a node
mkNode :: Int -> String -> Category -> Number -> Number -> Nullable Number -> Nullable Number -> Number -> ConceptNode
mkNode nodeId label category x y fx fy r =
  { id: nodeId, label, category, x, y, vx: 0.0, vy: 0.0, fx, fy, r }

-- | The concept graph component
component :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

initialState :: forall i. i -> State
initialState _ =
  { nodes: []
  , links: []
  , simulation: Nothing
  , width: 400.0
  , height: 360.0
  , dragging: Nothing
  , lastMouse: { x: 0.0, y: 0.0 }
  , loading: true
  }

render :: State -> H.ComponentHTML Action () Aff
render state =
  SE.svg
    [ SA.viewBox 0.0 0.0 state.width state.height
    , SA.classes [ HH.ClassName "concept-graph" ]
    , HE.onMouseMove DragMove
    , HE.onMouseUp \_ -> EndDrag
    , HE.onMouseLeave \_ -> EndDrag
    ]
    [ -- Links first (behind nodes)
      SE.g [ SA.classes [ HH.ClassName "concept-graph__links" ] ]
        (map renderLink state.links)
    -- Nodes on top
    , SE.g [ SA.classes [ HH.ClassName "concept-graph__nodes" ] ]
        (map renderNode state.nodes)
    ]
  where
  renderLink :: ConceptLink -> H.ComponentHTML Action () Aff
  renderLink link =
    case Array.index state.nodes link.source, Array.index state.nodes link.target of
      Just s, Just t ->
        SE.line
          [ SA.x1 s.x
          , SA.y1 s.y
          , SA.x2 t.x
          , SA.y2 t.y
          , SA.classes [ HH.ClassName "concept-graph__link", HH.ClassName $ "concept-graph__link--" <> linkTypeClass link.linkType ]
          ]
      _, _ -> SE.g [] []

  linkTypeClass :: LinkType -> String
  linkTypeClass = case _ of
    BuildsTo -> "builds-to"
    RunsOn -> "runs-on"
    Enables -> "enables"
    UsesLibrary -> "uses-library"

  renderNode :: ConceptNode -> H.ComponentHTML Action () Aff
  renderNode node =
    SE.g
      [ SA.classes [ HH.ClassName "concept-graph__node", HH.ClassName $ "concept-graph__node--" <> categoryClass node.category ]
      , SA.transform [ SA.Translate node.x node.y ]
      , HE.onMouseDown (StartDrag node.label)
      ]
      [ SE.circle
          [ SA.r node.r
          , SA.classes [ HH.ClassName "concept-graph__circle" ]
          ]
      , SE.text
          [ SA.classes [ HH.ClassName "concept-graph__label" ]
          , HP.attr (AttrName "dominant-baseline") "hanging"
          , HP.attr (AttrName "text-anchor") "end"
          , HP.attr (AttrName "x") "2"  -- Kiss the node edge (relative to g transform)
          , HP.attr (AttrName "y") (show (node.r + 2.0))  -- Below the node
          , HP.attr (AttrName "transform") "rotate(-12)"  -- Match acrostic angle
          ]
          [ HH.text node.label ]
      ]

  categoryClass :: Category -> String
  categoryClass = case _ of
    CatCore -> "core"
    CatBackend -> "backend"
    CatRuntime -> "runtime"
    CatConcept -> "concept"
    CatLibrary -> "library"
    CatExtLibrary -> "ext-library"
    CatShowcase -> "showcase"
    CatDomain -> "domain"

handleAction :: forall o. Action -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
  Initialize -> do
    state <- H.get
    let centerX = state.width / 2.0
        centerY = state.height / 2.0

    -- Load CSV files
    nodesResult <- liftAff $ AX.get ResponseFormat.string "assets/data/concept-graph-nodes.csv"
    edgesResult <- liftAff $ AX.get ResponseFormat.string "assets/data/concept-graph-edges.csv"

    case nodesResult, edgesResult of
      Right nodesResp, Right edgesResp -> do
        let nodes = parseNodesCSV centerX centerY nodesResp.body
            links = parseEdgesCSV nodes edgesResp.body
        liftEffect $ Console.log $ "Loaded " <> show (Array.length nodes) <> " nodes, " <> show (Array.length links) <> " links"
        H.modify_ _ { nodes = nodes, links = links, loading = false }
        setupSimulation nodes links
      _, _ -> do
        liftEffect $ Console.log "Failed to load concept graph CSV files"
        H.modify_ _ { loading = false }

  SimTick -> do
    state <- H.get
    case state.simulation of
      Nothing -> pure unit
      Just sim -> do
        nodes <- liftEffect $ FE.getNodes sim
        H.modify_ _ { nodes = nodes }

  StartDrag nodeLabel evt -> do
    let mouseX = toNumber $ clientX evt
        mouseY = toNumber $ clientY evt
    -- Store mouse position and start dragging
    state <- H.get
    case Array.find (\n -> n.label == nodeLabel) state.nodes of
      Nothing -> pure unit
      Just node -> do
        H.modify_ _
          { dragging = Just nodeLabel
          , lastMouse = { x: mouseX, y: mouseY }
          }
        -- Pin the node at its current position
        H.modify_ \s -> s { nodes = map (pinIfMatch nodeLabel node.x node.y) s.nodes }
        case state.simulation of
          Nothing -> pure unit
          Just sim -> do
            nodes <- H.gets _.nodes
            liftEffect $ FE.setNodes nodes sim
            liftEffect $ FE.reheat sim

  DragMove evt -> do
    state <- H.get
    case state.dragging of
      Nothing -> pure unit
      Just nodeLabel -> do
        let mouseX = toNumber $ clientX evt
            mouseY = toNumber $ clientY evt
            -- Calculate delta in screen coords
            deltaX = mouseX - state.lastMouse.x
            deltaY = mouseY - state.lastMouse.y
            -- Scale factor: estimate SVG is roughly 400px wide on screen
            -- The viewBox is 400x360, so if rendered at ~400px, scale is 1
            -- For hero column (2/3 of ~600px = 400px), this should be close
            scale = 1.0
        -- Update last mouse position
        H.modify_ _ { lastMouse = { x: mouseX, y: mouseY } }
        -- Move the node by the scaled delta
        H.modify_ \s -> s { nodes = map (moveByDelta nodeLabel (deltaX * scale) (deltaY * scale)) s.nodes }
        case state.simulation of
          Nothing -> pure unit
          Just sim -> do
            nodes <- H.gets _.nodes
            liftEffect $ FE.setNodes nodes sim

  EndDrag -> do
    state <- H.get
    case state.dragging of
      Nothing -> pure unit
      Just nodeLabel -> do
        -- Unpin (unless it's the core PureScript node)
        H.modify_ \s -> s
          { dragging = Nothing
          , nodes = map (unpinIfMatch nodeLabel) s.nodes
          }
        case state.simulation of
          Nothing -> pure unit
          Just sim -> do
            nodes <- H.gets _.nodes
            liftEffect $ FE.setNodes nodes sim

  where
  setupSimulation :: Array ConceptNode -> Array ConceptLink -> H.HalogenM State Action () o Aff Unit
  setupSimulation nodes links = do
    state <- H.get
    let centerX = state.width / 2.0
        centerY = state.height / 2.0

    -- Create simulation with callbacks
    callbacks <- liftEffect FE.defaultCallbacks
    sim <- liftEffect $ FE.createWithCallbacks FE.defaultConfig callbacks

    -- Set up nodes and links
    liftEffect $ FE.setNodes nodes sim

    -- Charge force (moderate repulsion)
    liftEffect $ FE.addForce (FE.ManyBody "charge"
      { strength: -40.0
      , theta: 0.9
      , distanceMin: 1.0
      , distanceMax: 150.0
      }) sim

    -- Collision force
    liftEffect $ FE.addForce (FE.Collide "collide"
      { radius: 8.0
      , strength: 0.7
      , iterations: 1
      }) sim

    -- Link force (moderate)
    liftEffect $ FE.addForce (FE.Link "links"
      { distance: 30.0
      , strength: 0.5
      , iterations: 2
      }) sim

    -- Set links for link force
    liftEffect $ FE.setLinks (map (\l -> { source: l.source, target: l.target }) links) sim

    -- Center force (shifts whole graph)
    liftEffect $ FE.addForce (FE.Center "center"
      { x: centerX
      , y: centerY
      , strength: 0.1
      }) sim

    -- ForceX - gentle pull toward center X (prevents spreading on reheat)
    liftEffect $ FE.addForce (FE.PositionX "forceX"
      { x: centerX
      , strength: 0.06
      }) sim

    -- ForceY - gentle pull toward center Y
    liftEffect $ FE.addForce (FE.PositionY "forceY"
      { y: centerY
      , strength: 0.06
      }) sim

    -- Set up tick subscription
    { emitter, listener } <- liftEffect HS.create
    liftEffect $ FE.onTick (HS.notify listener unit) sim
    void $ H.subscribe $ emitter <#> \_ -> SimTick

    -- Start simulation
    liftEffect $ FE.start sim

    H.modify_ _ { simulation = Just sim }

  pinIfMatch :: String -> Number -> Number -> ConceptNode -> ConceptNode
  pinIfMatch lbl x y node
    | node.label == lbl = node { fx = notNull x, fy = notNull y }
    | otherwise = node

  moveByDelta :: String -> Number -> Number -> ConceptNode -> ConceptNode
  moveByDelta lbl dx dy node
    | node.label == lbl = node { x = node.x + dx, y = node.y + dy, fx = notNull (node.x + dx), fy = notNull (node.y + dy) }
    | otherwise = node

  unpinIfMatch :: String -> ConceptNode -> ConceptNode
  unpinIfMatch lbl node
    | node.label == lbl && node.label /= "PureScript" = node { fx = null, fy = null }
    | otherwise = node
