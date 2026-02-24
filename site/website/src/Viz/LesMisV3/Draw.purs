-- | Les Misérables Force-Directed Graph (HATS Architecture)
-- |
-- | A clean, simple force-directed graph using the ForceEngine library.
-- | Uses HATS (Hylomorphic Abstract Tree Syntax) for declarative rendering.
-- |
-- | NO FFI in this demo - all D3 interaction goes through library modules.
module D3.Viz.LesMisV3.Draw
  ( startLesMis
  ) where

import Prelude

import D3.Viz.LesMisV3.Model (LesMisModel, LesMisNode)
import Data.Number (sqrt)
import Effect (Effect)
import Effect.Ref as Ref
import Hylograph.ForceEngine.Simulation as Sim
import Hylograph.ForceEngine.Types (ForceSpec(..), defaultManyBody, defaultCollide, defaultLink, defaultCenter)
import Hylograph.ForceEngine.Links (swizzleLinks)
import Hylograph.Scale (schemeCategory10At)
import Hylograph.Internal.Behavior.FFI as BehaviorFFI
import Hylograph.Internal.Behavior.Types (DragConfig(..), ScaleExtent(..), defaultZoom)
import Hylograph.Internal.Selection.Types (ElementType(..))
import Hylograph.HATS (elem, forEach, withBehaviors, onDrag, onZoom) as HATS
import Hylograph.HATS (Tree) as HTree
import Hylograph.HATS.Friendly as F
import Hylograph.HATS.InterpreterTick (rerender, clearContainer) as HATS

-- =============================================================================
-- Types
-- =============================================================================

-- | Swizzled link (source/target are node references, not indices)
type SwizzledLink =
  { source :: LesMisNode
  , target :: LesMisNode
  , value :: Number
  , index :: Int
  }

-- =============================================================================
-- Constants
-- =============================================================================

svgWidth :: Number
svgWidth = 900.0

svgHeight :: Number
svgHeight = 600.0

-- | Simulation ID for the registry
-- | Separate from GUPDemo to avoid interference
simulationId :: String
simulationId = "lesmis-main"

-- =============================================================================
-- Entry Point
-- =============================================================================

-- | Clone a node to create an independent copy
-- | This prevents mutations (like fx/fy from drag) from affecting other simulations
cloneNode :: LesMisNode -> LesMisNode
cloneNode n = { id: n.id, name: n.name, group: n.group, x: n.x, y: n.y, vx: n.vx, vy: n.vy, fx: n.fx, fy: n.fy }

-- | Start the Les Misérables force-directed graph
-- | Returns a cleanup function to stop the simulation
startLesMis :: LesMisModel -> String -> Effect (Effect Unit)
startLesMis model containerSelector = do
  -- Clone nodes to have independent data from other visualizations
  let clonedNodes = map cloneNode model.nodes

  -- Swizzle links using cloned nodes
  let swizzledLinks = swizzleLinks clonedNodes model.links \src tgt i link ->
        { source: src, target: tgt, index: i, value: link.value }

  -- Create simulation using library API
  sim <- Sim.create Sim.defaultConfig
  Sim.setNodes clonedNodes sim
  Sim.setLinks model.links sim

  -- Register simulation for declarative drag
  BehaviorFFI.registerSimulation_ simulationId (Sim.reheat sim)

  -- Add forces using declarative ForceSpec
  Sim.addForce (ManyBody "charge" defaultManyBody { strength = -100.0, distanceMax = 500.0 }) sim
  Sim.addForce (Collide "collision" defaultCollide { radius = 5.0, strength = 1.0, iterations = 1 }) sim
  Sim.addForce (Center "center" defaultCenter { x = 0.0, y = 0.0, strength = 0.1 }) sim
  Sim.addForce (Link "links" defaultLink { distance = 30.0, strength = 0.5, iterations = 1 }) sim

  -- Create state ref for tick updates
  stateRef <- Ref.new { nodes: clonedNodes, links: swizzledLinks }

  -- Render initial SVG structure using HATS
  HATS.clearContainer containerSelector
  let containerTree :: HTree.Tree
      containerTree =
        HATS.withBehaviors
          [ HATS.onZoom (defaultZoom (ScaleExtent 0.1 10.0) "#lesmis-zoom-group") ]
        $ HATS.elem SVG
            [ F.width svgWidth
            , F.height svgHeight
            , F.viewBox ((-svgWidth) / 2.0) ((-svgHeight) / 2.0) svgWidth svgHeight
            , F.attr "id" "lesmis-v3-svg"
            , F.class_ "lesmis-v3"
            ]
            [ HATS.elem Group
                [ F.attr "id" "lesmis-zoom-group"
                , F.class_ "zoom-group"
                ]
                [ HATS.elem Group [ F.attr "id" "lesmis-links", F.class_ "links" ] []
                , HATS.elem Group [ F.attr "id" "lesmis-nodes", F.class_ "nodes" ] []
                ]
            ]
  _ <- HATS.rerender containerSelector containerTree

  -- Set tick callback to update DOM using HATS
  Sim.onTick (updateDOM stateRef) sim

  -- Start simulation
  Sim.start sim

  -- Return cleanup function (also unregisters simulation)
  pure do
    Sim.stop sim
    BehaviorFFI.unregisterSimulation_ simulationId

-- =============================================================================
-- DOM Updates (on each tick) - using HATS
-- =============================================================================

-- | Update DOM positions based on current node positions
-- | Called on each simulation tick
updateDOM :: Ref.Ref { nodes :: Array LesMisNode, links :: Array SwizzledLink } -> Effect Unit
updateDOM stateRef = do
  state <- Ref.read stateRef

  -- Create links tree
  let linkKey :: SwizzledLink -> String
      linkKey link = show link.index

  let linksTree :: HTree.Tree
      linksTree =
        HATS.forEach "links" Line state.links linkKey \link ->
          HATS.elem Line
            [ F.x1 link.source.x
            , F.y1 link.source.y
            , F.x2 link.target.x
            , F.y2 link.target.y
            , F.strokeWidth (sqrt link.value)
            , F.stroke "#999"
            , F.opacity "0.6"
            ]
            []

  -- Create nodes tree with drag behavior
  let nodeKey :: LesMisNode -> String
      nodeKey node = show node.id

  let nodesTree :: HTree.Tree
      nodesTree =
        HATS.forEach "nodes" Circle state.nodes nodeKey \node ->
          HATS.withBehaviors
            [ HATS.onDrag (SimulationDrag simulationId) ]
          $ HATS.elem Circle
              [ F.cx node.x
              , F.cy node.y
              , F.r 5.0
              , F.fill (schemeCategory10At node.group)
              , F.stroke "#fff"
              , F.strokeWidth 1.5
              ]
              []

  -- Render using HATS
  _ <- HATS.rerender "#lesmis-links" linksTree
  _ <- HATS.rerender "#lesmis-nodes" nodesTree
  pure unit
