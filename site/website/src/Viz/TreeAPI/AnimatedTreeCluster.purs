module D3.Viz.TreeAPI.AnimatedTreeCluster where

-- | Animated transition between Tree (Reingold-Tilford) and Cluster (dendrogram) layouts
-- | Uses HATS for initial rendering, then pure transitions for nodes with links recalculated
-- | each tick to follow node positions

import Prelude hiding (add, sub, mul)

import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Tuple.Nested ((/\))
import Data.Traversable (for_, traverse)
import Control.Comonad.Cofree (head, tail)
import Data.Tree (Tree)
import Effect (Effect)
import Effect.Console as Console
import Effect.Ref as Ref
import Type.Proxy (Proxy(..))
import Hylograph.Internal.Selection.Types (ElementType(..))
import DataViz.Layout.Hierarchy.Cluster (cluster, defaultClusterConfig)
import DataViz.Layout.Hierarchy.Tree (treeWithSorting, defaultTreeConfig)
import Web.DOM.Element (Element)
import Web.DOM.Element as Element
import Web.DOM.ParentNode (QuerySelector(..), querySelectorAll)
import Web.DOM.NodeList as NodeList
import Web.HTML (window)
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.Window as Window

-- HATS imports
import Hylograph.HATS (elem, forEach) as HATS
import Hylograph.HATS (Tree) as HTree
import Hylograph.HATS.Friendly as F
import Hylograph.HATS.InterpreterTick (rerender, clearContainer) as HATS

-- v3 DSL imports (still needed for link path calculation)
import Hylograph.Expr.Expr (class NumExpr)
import Hylograph.Expr.Datum (class DatumExpr, field)
import Hylograph.Expr.Path (linkVertical)
import Hylograph.Expr.Interpreter.Eval (EvalD, runEvalD)

-- | Layout type
data LayoutType = TreeLayout | ClusterLayout

derive instance Eq LayoutType

instance Show LayoutType where
  show TreeLayout = "Tree (Reingold-Tilford)"
  show ClusterLayout = "Cluster (Dendrogram)"

-- | Toggle between layouts
toggleLayout :: LayoutType -> LayoutType
toggleLayout TreeLayout = ClusterLayout
toggleLayout ClusterLayout = TreeLayout

-- | Tree model with position data
type TreeModel = { name :: String, value :: Number, x :: Number, y :: Number, depth :: Int, height :: Int }
type TreeModelRow = (name :: String, value :: Number, x :: Number, y :: Number, depth :: Int, height :: Int)

-- | Link data with source/target positions
type LinkData =
  { name :: String  -- Unique key: "source->target"
  , sourceX :: Number
  , sourceY :: Number
  , targetX :: Number
  , targetY :: Number
  }
type LinkRow = (name :: String, sourceX :: Number, sourceY :: Number, targetX :: Number, targetY :: Number)

-- | Node positions map for interpolation
type NodePositions = Map.Map String { x :: Number, y :: Number }

-- =============================================================================
-- v3 Expressions
-- =============================================================================

-- | Node X position
nodeX :: forall repr. NumExpr repr => DatumExpr repr TreeModelRow => repr Number
nodeX = field (Proxy :: Proxy "x")

-- | Node Y position
nodeY :: forall repr. NumExpr repr => DatumExpr repr TreeModelRow => repr Number
nodeY = field (Proxy :: Proxy "y")

-- | Link path using v3 PathExpr
-- | linkVertical creates a smooth bezier curve between source and target
linkSourceX :: forall repr. NumExpr repr => DatumExpr repr LinkRow => repr Number
linkSourceX = field (Proxy :: Proxy "sourceX")

linkSourceY :: forall repr. NumExpr repr => DatumExpr repr LinkRow => repr Number
linkSourceY = field (Proxy :: Proxy "sourceY")

linkTargetX :: forall repr. NumExpr repr => DatumExpr repr LinkRow => repr Number
linkTargetX = field (Proxy :: Proxy "targetX")

linkTargetY :: forall repr. NumExpr repr => DatumExpr repr LinkRow => repr Number
linkTargetY = field (Proxy :: Proxy "targetY")

-- | Evaluate v3 expressions
evalNode :: forall a. EvalD TreeModel a -> TreeModel -> a
evalNode expr datum = runEvalD expr datum 0

evalLink :: forall a. EvalD LinkData a -> LinkData -> a
evalLink expr datum = runEvalD expr datum 0

-- =============================================================================
-- Data Helpers
-- =============================================================================

-- | Flatten tree to array
flattenTree :: forall r. Tree { name :: String | r } -> Array { name :: String | r }
flattenTree = Array.fromFoldable

-- | Create links from tree structure (with node names for lookup)
type LinkSpec =
  { name :: String  -- Unique key
  , sourceName :: String
  , targetName :: String
  }

makeLinkSpecs :: forall r. Tree { name :: String | r } -> Array LinkSpec
makeLinkSpecs t =
  let
    val = head t
    children = tail t
    childLinks = Array.fromFoldable children >>= \child ->
      let childVal = head child
      in [ { name: val.name <> "->" <> childVal.name
           , sourceName: val.name
           , targetName: childVal.name
           } ]
    grandchildLinks = Array.fromFoldable children >>= makeLinkSpecs
  in
    childLinks <> grandchildLinks

-- | Create LinkData from LinkSpec using position map
linkSpecToData :: NodePositions -> LinkSpec -> Maybe LinkData
linkSpecToData positions spec = do
  sourcePos <- Map.lookup spec.sourceName positions
  targetPos <- Map.lookup spec.targetName positions
  pure
    { name: spec.name
    , sourceX: sourcePos.x
    , sourceY: sourcePos.y
    , targetX: targetPos.x
    , targetY: targetPos.y
    }

-- | Create links from positions
makeLinksFromPositions :: Array LinkSpec -> NodePositions -> Array LinkData
makeLinksFromPositions specs positions =
  Array.catMaybes $ map (linkSpecToData positions) specs

-- | Vertical link path using v3 PathExpr
verticalLinkPathV3 :: LinkData -> String
verticalLinkPathV3 link = runEvalD (linkVertical linkSourceX linkSourceY linkTargetX linkTargetY) link 0

-- | Key functions for updateJoin
nodeKey :: TreeModel -> String
nodeKey node = node.name

linkKey :: LinkData -> String
linkKey link = link.name

-- =============================================================================
-- Animation Helpers
-- =============================================================================

-- | Easing function (cubic ease-in-out)
easeInOutCubic :: Number -> Number
easeInOutCubic t =
  if t < 0.5
    then 4.0 * t * t * t
    else 1.0 - (pow (-2.0 * t + 2.0) 3) / 2.0

pow :: Number -> Int -> Number
pow base exp
  | exp <= 0 = 1.0
  | otherwise = base * pow base (exp - 1)

-- | Lerp (linear interpolation)
lerp :: Number -> Number -> Number -> Number
lerp start end t = start + (end - start) * t

-- | Interpolate positions
interpolatePositions :: NodePositions -> NodePositions -> Number -> NodePositions
interpolatePositions oldPos newPos t =
  let easedT = easeInOutCubic t
  in Map.mapMaybeWithKey (\name newP ->
       case Map.lookup name oldPos of
         Just oldP -> Just
           { x: lerp oldP.x newP.x easedT
           , y: lerp oldP.y newP.y easedT
           }
         Nothing -> Just newP  -- New node, no interpolation
     ) newPos

-- | Extract positions from nodes array
nodesToPositions :: Array TreeModel -> NodePositions
nodesToPositions nodes =
  Map.fromFoldable $ nodes <#> \n -> n.name /\ { x: n.x, y: n.y }

-- =============================================================================
-- FFI for DOM manipulation
-- =============================================================================

foreign import requestAnimationFrame_ :: Effect Unit -> Effect Int
foreign import setAttributeNS_ :: String -> String -> Element -> Effect Unit

-- =============================================================================
-- TreeAPI Implementation
-- =============================================================================

-- | Viz state returned from draw
type VizState =
  { dataTree :: Tree TreeModel
  , chartWidth :: Number
  , chartHeight :: Number
  , currentPositions :: NodePositions  -- Current node positions for next animation
  , linkSpecs :: Array LinkSpec        -- Link structure (doesn't change between layouts)
  , selector :: String                 -- Container selector for updates
  }

-- | Draw the animated tree/cluster visualization using HATS
draw :: Tree TreeModel -> String -> LayoutType -> Effect VizState
draw dataTree selector currentLayout = do
  let chartWidth = 500.0
  let chartHeight = 300.0

  Console.log $ "=== Drawing AnimatedTreeCluster with HATS ==="
  Console.log $ "Layout: " <> show currentLayout

  -- Apply layout
  let positioned = case currentLayout of
        TreeLayout ->
          let config = defaultTreeConfig { size = { width: chartWidth, height: chartHeight } }
          in treeWithSorting config dataTree
        ClusterLayout ->
          let config = defaultClusterConfig { size = { width: chartWidth, height: chartHeight } }
          in cluster config dataTree

  -- Flatten nodes and create link specs
  let nodes = flattenTree positioned
  let linkSpecs = makeLinkSpecs positioned
  let currentPositions = nodesToPositions nodes
  let links = makeLinksFromPositions linkSpecs currentPositions

  Console.log $ "Nodes: " <> show (Array.length nodes) <> ", Links: " <> show (Array.length linkSpecs)

  -- Clear container and render structure with HATS
  HATS.clearContainer selector

  -- Build the SVG container tree with nested groups
  let containerTree :: HTree.Tree
      containerTree =
        HATS.elem SVG
          [ F.viewBox 0.0 0.0 chartWidth chartHeight
          , F.class_ "animated-tree-cluster"
          , F.width chartWidth
          , F.height chartHeight
          ]
          [ HATS.elem Group [ F.class_ "links", F.attr "id" "atc-links" ] []
          , HATS.elem Group [ F.class_ "nodes", F.attr "id" "atc-nodes" ] []
          ]

  _ <- HATS.rerender selector containerTree

  -- Render links with HATS
  let linksTree :: HTree.Tree
      linksTree =
        HATS.forEach "linkElements" Path links linkKey \link ->
          HATS.elem Path
            [ F.class_ "link"
            , F.attr "data-link" link.name  -- For lookup during animation
            , F.d (verticalLinkPathV3 link)
            , F.fill "none"
            , F.stroke "#555"
            , F.strokeWidth 1.5
            ]
            []

  _ <- HATS.rerender (selector <> " #atc-links") linksTree

  -- Render nodes with HATS
  let nodesTree :: HTree.Tree
      nodesTree =
        HATS.forEach "nodeElements" Circle nodes nodeKey \node ->
          HATS.elem Circle
            [ F.class_ "node"
            , F.attr "data-node" node.name  -- For lookup during animation
            , F.cx node.x
            , F.cy node.y
            , F.r 4.0
            , F.fill "#999"
            , F.stroke "#555"
            , F.strokeWidth 1.5
            ]
            []

  _ <- HATS.rerender (selector <> " #atc-nodes") nodesTree

  Console.log "Initial render complete"

  pure { dataTree, chartWidth, chartHeight, currentPositions, linkSpecs, selector }

-- | Update existing visualization with new layout
-- | Uses a manual animation loop: interpolate node positions, recalculate link paths
update :: Tree TreeModel -> String -> Number -> Number -> LayoutType -> Effect Unit
update dataTree selector chartWidth chartHeight currentLayout = do
  Console.log $ "=== Updating AnimatedTreeCluster to " <> show currentLayout <> " ==="

  -- Get current positions from DOM (the "from" state)
  oldPositions <- readNodePositionsFromDOM selector

  -- Apply layout to get new positions (the "to" state)
  let positioned = case currentLayout of
        TreeLayout ->
          let config = defaultTreeConfig { size = { width: chartWidth, height: chartHeight } }
          in treeWithSorting config dataTree
        ClusterLayout ->
          let config = defaultClusterConfig { size = { width: chartWidth, height: chartHeight } }
          in cluster config dataTree

  let nodes = flattenTree positioned
  let newPositions = nodesToPositions nodes
  let linkSpecs = makeLinkSpecs positioned

  -- Animation parameters
  let duration = 1500.0  -- ms
  startTimeRef <- Ref.new Nothing

  -- Animation loop
  let
    animate :: Effect Unit
    animate = do
      maybeStartTime <- Ref.read startTimeRef
      now <- getTimestamp

      startTime <- case maybeStartTime of
        Nothing -> do
          Ref.write (Just now) startTimeRef
          pure now
        Just t -> pure t

      let elapsed = now - startTime
      let progress = min 1.0 (elapsed / duration)

      -- Interpolate positions
      let currentPos = interpolatePositions oldPositions newPositions progress

      -- Update nodes
      updateNodesInDOM selector currentPos

      -- Update links by recalculating paths from interpolated positions
      let currentLinks = makeLinksFromPositions linkSpecs currentPos
      updateLinksInDOM selector currentLinks

      -- Continue if not done
      when (progress < 1.0) do
        void $ requestAnimationFrame_ animate

  -- Start animation
  void $ requestAnimationFrame_ animate

-- | Read current node positions from DOM
readNodePositionsFromDOM :: String -> Effect NodePositions
readNodePositionsFromDOM selector = do
  win <- window
  doc <- Window.document win
  let parentNode = HTMLDocument.toParentNode doc
  nodeList <- querySelectorAll (QuerySelector $ selector <> " svg .nodes circle") parentNode
  nodes <- NodeList.toArray nodeList

  positions <- traverse (\node -> do
    let elem = unsafeCoerceToElement node
    maybeName <- Element.getAttribute "data-node" elem
    maybeCx <- Element.getAttribute "cx" elem
    maybeCy <- Element.getAttribute "cy" elem
    pure $ case maybeName, maybeCx, maybeCy of
      Just name, Just cxStr, Just cyStr ->
        let x = fromMaybe 0.0 (parseNumber cxStr)
            y = fromMaybe 0.0 (parseNumber cyStr)
        in Just (name /\ { x, y })
      _, _, _ -> Nothing
  ) nodes

  pure $ Map.fromFoldable $ Array.catMaybes positions

-- | Update node positions in DOM
updateNodesInDOM :: String -> NodePositions -> Effect Unit
updateNodesInDOM selector positions = do
  win <- window
  doc <- Window.document win
  let parentNode = HTMLDocument.toParentNode doc
  nodeList <- querySelectorAll (QuerySelector $ selector <> " svg .nodes circle") parentNode
  nodes <- NodeList.toArray nodeList

  for_ nodes \node -> do
    let elem = unsafeCoerceToElement node
    maybeName <- Element.getAttribute "data-node" elem
    case maybeName of
      Just name -> case Map.lookup name positions of
        Just pos -> do
          setAttributeNS_ "cx" (show pos.x) elem
          setAttributeNS_ "cy" (show pos.y) elem
        Nothing -> pure unit
      Nothing -> pure unit

-- | Update link paths in DOM
updateLinksInDOM :: String -> Array LinkData -> Effect Unit
updateLinksInDOM selector links = do
  win <- window
  doc <- Window.document win
  let parentNode = HTMLDocument.toParentNode doc
  linkList <- querySelectorAll (QuerySelector $ selector <> " svg .links path") parentNode
  linkNodes <- NodeList.toArray linkList

  -- Create a map for quick lookup
  let linkMap = Map.fromFoldable $ links <#> \link -> link.name /\ link

  for_ linkNodes \node -> do
    let elem = unsafeCoerceToElement node
    maybeName <- Element.getAttribute "data-link" elem
    case maybeName of
      Just name -> case Map.lookup name linkMap of
        Just link -> do
          let pathStr = verticalLinkPathV3 link
          setAttributeNS_ "d" pathStr elem
        Nothing -> pure unit
      Nothing -> pure unit

-- =============================================================================
-- FFI Helpers
-- =============================================================================

foreign import getTimestamp :: Effect Number
foreign import parseNumberNullable :: String -> Nullable Number
foreign import unsafeCoerceToElement :: forall a. a -> Element

-- | Parse a number string, returning Maybe
parseNumber :: String -> Maybe Number
parseNumber = toMaybe <<< parseNumberNullable
