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
import Data.Foldable (foldl)
import Data.Int as Int
import Data.Number as Number
import Data.Set as Set
import TypeExplorer.Types (TypeInfo, TypeLink, TypeKind(..), LinkType(..), NodeRole(..), colors)

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
  , padding :: Number  -- Virtual padding around edges
  }

defaultConfig :: ForceConfig
defaultConfig =
  { width: 1200.0
  , height: 800.0
  , nodeRadius: 12.0
  , linkDistance: 80.0
  , centerX: 600.0
  , centerY: 400.0
  , padding: 80.0  -- Virtual padding for force layout breathing room
  }

-- | Simulation node for a type
type TypeNode = SimulationNode
  ( name :: String
  , moduleName :: String
  , packageName :: String
  , kind :: TypeKind
  , maturityLevel :: Int
  , role :: NodeRole          -- Role in type graph (for coloring)
  , componentId :: Int        -- Connected component ID (for grid layout)
  , gridX :: Number           -- Target X for ForceXGrid (clustering)
  , gridY :: Number           -- Target Y for ForceYGrid
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
        , staticStr "fill" (roleColor node.role)
        , staticStr "stroke" (roleStroke node.role)
        , staticNum "stroke-width" (roleStrokeWidth node.role)
        , staticStr "class" "node"
        , staticStr "data-type-id" (show node.id)
        , staticStr "cursor" "pointer"
        ] []

-- | Get color based on node role (primary visual distinction)
roleColor :: NodeRole -> String
roleColor = case _ of
  RoleTypeClass -> colors.typeClass           -- Purple
  RoleInstanceProvider -> colors.instanceProvider  -- Green
  RoleSuperclass -> colors.superclass         -- Pink
  RoleReferenced -> colors.referenced         -- Blue
  RoleIsolated -> colors.isolated             -- Gray

-- | Stroke color for node role
roleStroke :: NodeRole -> String
roleStroke = case _ of
  RoleTypeClass -> "#5a3a7a"     -- Darker purple
  RoleSuperclass -> "#a01848"    -- Darker pink
  RoleInstanceProvider -> "#2e7d32" -- Darker green
  RoleReferenced -> "#1565c0"    -- Darker blue
  RoleIsolated -> "#555"

-- | Stroke width for node role
roleStrokeWidth :: NodeRole -> Number
roleStrokeWidth = case _ of
  RoleTypeClass -> 3.0
  RoleSuperclass -> 2.5
  RoleInstanceProvider -> 2.0
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
-- Connected Components (for grid layout of disjoint graphs)
-- =============================================================================

-- | Find connected components using union-find style approach
-- | Returns a Map from node id to normalized component id (0, 1, 2, ...)
findConnectedComponents :: Array TypeInfo -> Array TypeLink -> Map.Map Int Int
findConnectedComponents types links =
  let
    -- Initialize each node in its own component
    typeIds = map _.id types
    initialComponents = Map.fromFoldable $ map (\id -> id /\ id) typeIds

    -- Find representative (with path compression simulation)
    findRoot :: Map.Map Int Int -> Int -> Int
    findRoot components nodeId =
      case Map.lookup nodeId components of
        Just parent | parent == nodeId -> nodeId
        Just parent -> findRoot components parent
        Nothing -> nodeId

    -- Union two components
    unionComponents :: Map.Map Int Int -> TypeLink -> Map.Map Int Int
    unionComponents components link =
      let
        root1 = findRoot components link.source
        root2 = findRoot components link.target
      in
      if root1 == root2
        then components
        else Map.insert root2 root1 components

    -- Apply all links to union components
    mergedComponents = foldl unionComponents initialComponents links

    -- Get raw root for each node
    rawRoots = map (\nodeId -> nodeId /\ findRoot mergedComponents nodeId) typeIds

    -- Get unique roots and assign normalized IDs (0, 1, 2, ...)
    uniqueRoots = Array.nub $ map (\(_ /\ root) -> root) rawRoots
    rootToNormalizedId = Map.fromFoldable $
      Array.mapWithIndex (\idx root -> root /\ idx) uniqueRoots

    -- Map each node to its normalized component ID
    normalizeNode (nodeId /\ root) =
      case Map.lookup root rootToNormalizedId of
        Just normalizedId -> nodeId /\ normalizedId
        Nothing -> nodeId /\ 0
  in
  Map.fromFoldable $ map normalizeNode rawRoots

-- | Get grid position for a component
-- | Arranges components in a grid pattern with padding
getGridPosition :: ForceConfig -> Int -> Int -> { x :: Number, y :: Number }
getGridPosition config componentId totalComponents =
  let
    -- Calculate grid dimensions (roughly square)
    cols = max 1 (ceil (sqrt (toNumber totalComponents)))
    rows = max 1 (ceil (toNumber totalComponents / toNumber cols))

    -- Which cell is this component in?
    col = componentId `mod` cols
    row = componentId / cols

    -- Usable area after padding
    usableWidth = config.width - 2.0 * config.padding
    usableHeight = config.height - 2.0 * config.padding

    -- Center of this cell within usable area
    x = config.padding + (toNumber col + 0.5) * usableWidth / toNumber cols
    y = config.padding + (toNumber row + 0.5) * usableHeight / toNumber rows
  in
  { x, y }
  where
    ceil n = if n == toNumber (floor n) then floor n else floor n + 1
    floor n = Int.floor n
    sqrt = Number.sqrt
    toNumber = Int.toNumber

-- =============================================================================
-- Role Computation
-- =============================================================================

-- | Compute the role of each type based on its relationships
computeNodeRoles :: Array TypeInfo -> Array TypeLink -> Map.Map Int NodeRole
computeNodeRoles types links =
  let
    -- Types that are targets of InstanceOf links (have instances)
    instanceProviders = Set.fromFoldable $
      map _.source $ Array.filter (\l -> l.linkType == InstanceOf) links

    -- Types that are targets of Superclass links (are superclasses)
    superclasses = Set.fromFoldable $
      map _.target $ Array.filter (\l -> l.linkType == Superclass) links

    -- Types that are referenced by other types
    referenced = Set.fromFoldable $
      map _.target $ Array.filter (\l -> l.linkType == TypeReference || l.linkType == UsedIn) links

    -- All nodes that have any link
    linkedNodes = Set.fromFoldable $
      (map _.source links) <> (map _.target links)

    computeRole :: TypeInfo -> NodeRole
    computeRole typeInfo
      | typeInfo.kind == TypeClassDecl && Set.member typeInfo.id superclasses = RoleSuperclass
      | typeInfo.kind == TypeClassDecl = RoleTypeClass
      | Set.member typeInfo.id instanceProviders = RoleInstanceProvider
      | Set.member typeInfo.id referenced = RoleReferenced
      | not (Set.member typeInfo.id linkedNodes) = RoleIsolated
      | otherwise = RoleReferenced
  in
  Map.fromFoldable $ map (\t -> t.id /\ computeRole t) types

-- =============================================================================
-- Clustering
-- =============================================================================

-- | Get cluster target position based on connected component
getClusterTarget :: ForceConfig -> Map.Map Int Int -> Int -> Int -> { x :: Number, y :: Number }
getClusterTarget config componentMap totalComponents nodeId =
  case Map.lookup nodeId componentMap of
    Just compId -> getGridPosition config compId totalComponents
    Nothing -> { x: config.centerX, y: config.centerY }

-- =============================================================================
-- Initialization
-- =============================================================================

-- | Initialize the force graph visualization
initForceGraph :: String -> Array TypeInfo -> Array TypeLink -> Effect ForceGraphHandle
initForceGraph selector types links = do
  let config = defaultConfig

  -- Convert types to simulation nodes (includes role and component computation)
  nodes <- createTypeNodes config types links

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

-- | Create type nodes from TypeInfo with computed roles and component positions
createTypeNodes :: ForceConfig -> Array TypeInfo -> Array TypeLink -> Effect (Array TypeNode)
createTypeNodes config types links = do
  let
    jitterRange = 50.0

    -- Compute roles for coloring
    roleMap = computeNodeRoles types links

    -- Compute connected components for grid layout
    componentMap = findConnectedComponents types links

    -- Count unique components
    uniqueComponents = Set.size $ Set.fromFoldable $ Map.values componentMap
    totalComponents = max 1 uniqueComponents

  traverse (\{ typeInfo, idx } -> do
    dx <- (\r -> (r - 0.5) * jitterRange) <$> random
    dy <- (\r -> (r - 0.5) * jitterRange) <$> random

    let
      role = case Map.lookup typeInfo.id roleMap of
        Just r -> r
        Nothing -> RoleIsolated

      componentId = case Map.lookup typeInfo.id componentMap of
        Just c -> c
        Nothing -> 0

      target = getClusterTarget config componentMap totalComponents typeInfo.id

    pure
      { id: typeInfo.id
      , x: target.x + dx
      , y: target.y + dy
      , vx: 0.0
      , vy: 0.0
      , fx: null
      , fy: null
      , name: typeInfo.name
      , moduleName: typeInfo.moduleName
      , packageName: typeInfo.packageName
      , kind: typeInfo.kind
      , maturityLevel: typeInfo.maturityLevel
      , role: role
      , componentId: componentId
      , gridX: target.x
      , gridY: target.y
      }
  ) (Array.mapWithIndex (\idx typeInfo -> { idx, typeInfo }) types)
