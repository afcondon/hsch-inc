-- | Force-Directed Graph Visualization for Type Explorer
-- |
-- | Shows types as nodes with links representing relationships.
-- | Clustering by package, maturity, or type kind.
-- | Node colors indicate maturity level; link colors indicate relationship type.
module TypeExplorer.Views.ForceGraph
  ( initForceGraph
  , ForceGraphHandle
  ) where

import Prelude

import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Nullable (null)
import Data.String as String
import Data.Traversable (traverse)
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Random (random)
import Effect.Ref as Ref
import Hylograph.ForceEngine.Core as Core
import Hylograph.ForceEngine.Simulation as Sim
import Hylograph.ForceEngine.Simulation (SimulationNode)
import Hylograph.ForceEngine.Types (ForceSpec(..), defaultCollide, defaultLink, defaultManyBody)
import Hylograph.HATS (Tree, elem, forEach, staticStr, staticNum, thunkedNum, thunkedStr, onClick, withBehaviors)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))
import TypeExplorer.Types (TypeInfo, TypeLink, TypeKind(..), LinkType(..), colors)

-- =============================================================================
-- Types
-- =============================================================================

-- | Configuration for the force graph
type ForceConfig =
  { width :: Number
  , height :: Number
  , nodeRadius :: Number
  , linkDistance :: Number
  , centerX :: Number
  , centerY :: Number
  }

defaultConfig :: ForceConfig
defaultConfig =
  { width: 1000.0
  , height: 700.0
  , nodeRadius: 12.0
  , linkDistance: 80.0
  , centerX: 500.0
  , centerY: 350.0
  }

-- | Simulation node for a type
type TypeNode = SimulationNode
  ( name :: String
  , moduleName :: String
  , packageName :: String
  , kind :: TypeKind
  , maturityLevel :: Int
  , gridX :: Number  -- Target X for ForceXGrid (clustering)
  , gridY :: Number  -- Target Y for ForceYGrid
  )

-- | Link for simulation
type SimLink =
  { source :: Int
  , target :: Int
  , linkType :: LinkType
  }

-- | Handle returned from initialization
type ForceGraphHandle =
  { stop :: Effect Unit
  , onNodeClick :: (Int -> Effect Unit) -> Effect Unit
  }

-- =============================================================================
-- HATS Trees
-- =============================================================================

-- | Container SVG structure
containerTree :: ForceConfig -> Tree
containerTree config =
  elem SVG
    [ staticStr "width" "100%"
    , staticStr "height" "100%"
    , staticStr "viewBox" ("0 0 " <> show config.width <> " " <> show config.height)
    , staticStr "preserveAspectRatio" "xMidYMid meet"
    , staticStr "class" "force-graph-svg"
    ]
    [ -- Defs for markers/gradients if needed
      elem Defs [] []
    , -- Links layer
      elem Group [ staticStr "class" "links", staticStr "id" "type-links" ] []
    , -- Nodes layer
      elem Group [ staticStr "class" "nodes", staticStr "id" "type-nodes" ] []
    , -- Labels layer
      elem Group [ staticStr "class" "labels", staticStr "id" "type-labels" ] []
    ]

-- | Links tree
linksTree :: Array TypeNode -> Array SimLink -> Tree
linksTree nodes links =
  let
    nodeMap = Map.fromFoldable $ map (\n -> n.id /\ n) nodes
    getNode id = Map.lookup id nodeMap
  in
  forEach "links" Line links (\l -> show l.source <> "-" <> show l.target) \link ->
    case getNode link.source, getNode link.target of
      Just src, Just tgt ->
        elem Line
          [ thunkedNum "x1" src.x
          , thunkedNum "y1" src.y
          , thunkedNum "x2" tgt.x
          , thunkedNum "y2" tgt.y
          , staticStr "class" $ "link link-" <> show link.linkType
          , staticStr "stroke" (linkColor link.linkType)
          , staticNum "stroke-width" (linkWidth link.linkType)
          , staticNum "stroke-opacity" (linkOpacity link.linkType)
          ] []
      _, _ ->
        elem Line [] []

-- | Get color for link type
linkColor :: LinkType -> String
linkColor = case _ of
  InstanceOf -> colors.linkInstance
  UsedIn -> colors.linkUsage
  SameModule -> colors.linkModule
  Superclass -> colors.linkSuperclass
  TypeReference -> colors.linkUsage

-- | Get width for link type
linkWidth :: LinkType -> Number
linkWidth = case _ of
  InstanceOf -> 2.0
  Superclass -> 2.5
  UsedIn -> 1.5
  SameModule -> 1.0
  TypeReference -> 1.5

-- | Get opacity for link type
linkOpacity :: LinkType -> Number
linkOpacity = case _ of
  SameModule -> 0.3
  _ -> 0.6

-- | Nodes tree
nodesTree :: ForceConfig -> (Int -> Effect Unit) -> Array TypeNode -> Tree
nodesTree config onNodeClick nodes =
  forEach "nodes" Circle nodes (\n -> show n.id) \node ->
    let
      radius = case node.kind of
        TypeClassDecl -> config.nodeRadius * 1.3  -- Classes slightly larger
        _ -> config.nodeRadius
    in
    withBehaviors [ onClick (onNodeClick node.id) ] $
      elem Circle
        [ thunkedNum "cx" node.x
        , thunkedNum "cy" node.y
        , staticNum "r" radius
        , staticStr "fill" (maturityColor node.maturityLevel node.kind)
        , staticStr "stroke" (kindStroke node.kind)
        , staticNum "stroke-width" (kindStrokeWidth node.kind)
        , staticStr "class" "node"
        , staticStr "data-type-id" (show node.id)
        , staticStr "cursor" "pointer"
        ] []

-- | Get color based on maturity level
maturityColor :: Int -> TypeKind -> String
maturityColor level kind = case kind of
  TypeClassDecl -> colors.typeClass
  _ -> case level of
    n | n >= 6 -> colors.highMaturity
    n | n >= 3 -> colors.mediumMaturity
    _ -> colors.lowMaturity

-- | Stroke color for type kind
kindStroke :: TypeKind -> String
kindStroke = case _ of
  TypeClassDecl -> "#5a3a7a"  -- Darker purple
  NewtypeDecl -> "#666"
  DataType -> "#444"
  TypeAlias -> "#888"

-- | Stroke width for type kind
kindStrokeWidth :: TypeKind -> Number
kindStrokeWidth = case _ of
  TypeClassDecl -> 3.0
  NewtypeDecl -> 2.0
  _ -> 1.5

-- | Labels tree
labelsTree :: Array TypeNode -> Tree
labelsTree nodes =
  forEach "labels" Text nodes (\n -> show n.id) \node ->
    elem Text
      [ thunkedNum "x" node.x
      , thunkedNum "y" (node.y - 16.0)
      , staticStr "text-anchor" "middle"
      , staticStr "class" "label"
      , thunkedStr "textContent" (shortName node.name)
      ] []

-- | Shorten type name for label
shortName :: String -> String
shortName name =
  let len = String.length name
  in if len > 20
    then String.take 18 name <> "..."
    else name

-- =============================================================================
-- Clustering
-- =============================================================================

-- | Get cluster target X based on package
-- | For now, simple left/right split by package
getClusterTargetX :: ForceConfig -> TypeInfo -> Number
getClusterTargetX config typeInfo =
  case typeInfo.packageName of
    "hylograph-selection" -> config.width * 0.35
    "hylograph-layout" -> config.width * 0.65
    "hylograph-graph" -> config.width * 0.5
    "hylograph-simulation" -> config.width * 0.8
    _ -> config.centerX

-- =============================================================================
-- Initialization
-- =============================================================================

-- | Initialize the force graph visualization
initForceGraph :: String -> Array TypeInfo -> Array TypeLink -> Effect ForceGraphHandle
initForceGraph selector types links = do
  let config = defaultConfig

  -- Convert types to simulation nodes
  nodes <- createTypeNodes config types

  -- Convert links
  let simLinks = map (\l -> { source: l.source, target: l.target, linkType: l.linkType }) links

  -- Click callback ref
  clickCallbackRef <- Ref.new (\_ -> pure unit :: Effect Unit)

  -- State ref
  stateRef <- Ref.new { nodes, links: simLinks, config, clickCallback: clickCallbackRef }

  -- Create simulation
  sim <- Sim.create Sim.defaultConfig
  Sim.setNodes nodes sim

  -- Set links and add link force
  when (Array.length simLinks > 0) do
    Sim.setLinks (map (\l -> { source: l.source, target: l.target }) simLinks) sim
    Sim.addForce (Link "link" defaultLink
      { distance = config.linkDistance
      , strength = 0.5
      , iterations = 1
      }) sim

  -- Add clustering forces
  let forceXHandle = Core.createForceXGrid 0.06
  let forceYHandle = Core.createForceYGrid 0.04
  _ <- Core.initializeForce forceXHandle nodes
  _ <- Core.initializeForce forceYHandle nodes
  Sim.addForceHandle "clusterX" forceXHandle sim
  Sim.addForceHandle "clusterY" forceYHandle sim

  -- Collision
  Sim.addForce (Collide "collide" defaultCollide
    { radius = config.nodeRadius + 8.0
    , strength = 0.8
    , iterations = 2
    }) sim

  -- Many-body repulsion
  Sim.addForce (ManyBody "charge" defaultManyBody { strength = -150.0 }) sim

  -- Render initial structure
  _ <- rerender selector (containerTree config)

  -- Tick handler
  Sim.onTick (tick stateRef) sim
  Sim.start sim

  pure
    { stop: Sim.stop sim
    , onNodeClick: \callback -> Ref.write callback clickCallbackRef
    }

-- | Tick handler
tick :: Ref.Ref { nodes :: Array TypeNode, links :: Array SimLink, config :: ForceConfig, clickCallback :: Ref.Ref (Int -> Effect Unit) } -> Effect Unit
tick stateRef = do
  state <- Ref.read stateRef
  callback <- Ref.read state.clickCallback
  _ <- rerender "#type-links" (linksTree state.nodes state.links)
  _ <- rerender "#type-nodes" (nodesTree state.config callback state.nodes)
  _ <- rerender "#type-labels" (labelsTree state.nodes)
  pure unit

-- | Create type nodes from TypeInfo
createTypeNodes :: ForceConfig -> Array TypeInfo -> Effect (Array TypeNode)
createTypeNodes config types = do
  let jitterRange = 80.0

  traverse (\{ typeInfo, idx } -> do
    dx <- (\r -> (r - 0.5) * jitterRange) <$> random
    dy <- (\r -> (r - 0.5) * jitterRange) <$> random

    let targetX = getClusterTargetX config typeInfo

    pure
      { id: typeInfo.id
      , x: targetX + dx
      , y: config.centerY + dy
      , vx: 0.0
      , vy: 0.0
      , fx: null
      , fy: null
      , name: typeInfo.name
      , moduleName: typeInfo.moduleName
      , packageName: typeInfo.packageName
      , kind: typeInfo.kind
      , maturityLevel: typeInfo.maturityLevel
      , gridX: targetX
      , gridY: config.centerY
      }
  ) (Array.mapWithIndex (\idx typeInfo -> { idx, typeInfo }) types)
