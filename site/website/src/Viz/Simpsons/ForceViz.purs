-- | Force-Directed Visualization for Simpson's Paradox (HATS Version)
-- |
-- | The star feature: animated cohorts showing the paradox.
-- | Each dot represents an applicant. Dots cluster by department
-- | when separated, or merge when combined.
-- |
-- | Animation: toggle between separated (6 department columns) and
-- | combined (single column) to reveal the paradox.
module D3.Viz.Simpsons.ForceViz
  ( initForceViz
  , ForceVizHandle
  ) where

import Prelude

import D3.Viz.Simpsons.ForceDirected (ForceConfig, createApplicants, departmentX, combinedX, genderY, defaultConfig)
import D3.Viz.Simpsons.Types (Gender(..), blue, red, green, purple, black)
import Data.Array (mapWithIndex)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Nullable (null)
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Random (random)
import Effect.Ref as Ref
import Hylograph.ForceEngine.Core as Core
import Hylograph.ForceEngine.Simulation as Sim
import Hylograph.ForceEngine.Simulation (SimulationNode)
import Hylograph.ForceEngine.Types (ForceSpec(..), defaultCollide)
import Hylograph.HATS (Tree, elem, forEach, staticStr, staticNum, thunkedNum, thunkedStr)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))

-- =============================================================================
-- Types
-- =============================================================================

-- | Simulation node for an applicant
-- | Uses gridX/gridY for the optimized Grid forces
type ApplicantNode = SimulationNode
  ( gender :: Gender
  , department :: Int
  , accepted :: Boolean
  , gridX :: Number  -- Target X for ForceXGrid
  , gridY :: Number  -- Target Y for ForceYGrid
  )

-- | Handle returned from initialization
type ForceVizHandle =
  { toggle :: Effect Unit
  , stop :: Effect Unit
  , isCombined :: Effect Boolean
  }

-- =============================================================================
-- HATS Trees
-- =============================================================================

-- | Container SVG structure
containerTree :: ForceConfig -> Tree
containerTree config =
  elem SVG
    [ staticNum "width" config.width
    , staticNum "height" config.height
    , staticStr "viewBox" ("0 0 " <> show config.width <> " " <> show config.height)
    , staticStr "class" "force-viz-svg"
    ]
    [ elem Group []
        [ elem Group [ staticStr "class" "dept-labels", staticStr "id" "force-viz-dept-labels" ] []
        , elem Group [ staticStr "class" "gender-labels", staticStr "id" "force-viz-gender-labels" ] []
        , elem Group [ staticStr "class" "applicants", staticStr "id" "force-viz-applicants" ] []
        ]
    ]

-- | Department labels tree
type DeptLabel = { idx :: Int, name :: String }

deptLabelsTree :: ForceConfig -> Tree
deptLabelsTree config =
  let
    deptNames = ["A", "B", "C", "D", "E", "F"]
    labelData = mapWithIndex (\i name -> { idx: i, name }) deptNames
  in
    forEach "dept-labels" Text labelData (\d -> show d.idx) \d ->
      elem Text
        [ thunkedNum "x" (departmentX config d.idx)
        , staticNum "y" (config.marginTop - 10.0)
        , staticStr "text-anchor" "middle"
        , staticNum "font-size" 12.0
        , staticStr "fill" black
        , thunkedStr "textContent" d.name
        ] []

-- | Gender labels tree
type GenderLabel = { gender :: Gender, label :: String }

genderLabelsTree :: ForceConfig -> Tree
genderLabelsTree config =
  let
    genders = [{ gender: Female, label: "Women" }, { gender: Male, label: "Men" }]
  in
    forEach "gender-labels" Text genders (\d -> d.label) \d ->
      elem Text
        [ staticNum "x" 15.0
        , thunkedNum "y" (genderY config d.gender)
        , staticStr "text-anchor" "start"
        , staticNum "font-size" 14.0
        , thunkedStr "fill" (if d.gender == Female then green else purple)
        , thunkedStr "textContent" d.label
        ] []

-- | Applicant circles tree (updated on each tick)
applicantsTree :: ForceConfig -> Array ApplicantNode -> Tree
applicantsTree config nodes =
  forEach "applicants" Circle nodes (\n -> show n.id) \node ->
    elem Circle
      [ thunkedNum "cx" node.x
      , thunkedNum "cy" node.y
      , staticNum "r" config.nodeRadius
      , thunkedStr "fill" (if node.accepted then blue else red)
      , staticStr "stroke" "white"
      , staticNum "stroke-width" 0.5
      ] []

-- =============================================================================
-- Initialization
-- =============================================================================

-- | Initialize the force visualization
-- | Returns a handle with toggle function and cleanup
initForceViz :: String -> Effect ForceVizHandle
initForceViz selector = do
  let config = defaultConfig

  -- Create applicant nodes with jitter
  nodes <- createApplicantNodes config

  -- State: is combined mode?
  isCombinedRef <- Ref.new false

  -- State ref for tick updates
  stateRef <- Ref.new { nodes, config }

  -- Create simulation
  sim <- Sim.create Sim.defaultConfig
  Sim.setNodes nodes sim

  -- Add forces using the Grid-optimized versions (read gridX/gridY from nodes)
  let forceXHandle = Core.createForceXGrid 0.15
  _ <- Core.initializeForce forceXHandle nodes
  Ref.modify_ (Map.insert "forceX" forceXHandle) sim.forces

  let forceYHandle = Core.createForceYGrid 0.15
  _ <- Core.initializeForce forceYHandle nodes
  Ref.modify_ (Map.insert "forceY" forceYHandle) sim.forces

  -- Collision prevents overlap
  Sim.addForce (Collide "collide" defaultCollide { radius = config.nodeRadius + 0.5, strength = 0.7, iterations = 2 }) sim

  -- Render initial DOM structure using HATS
  _ <- rerender selector (containerTree config)

  -- Render labels
  _ <- rerender "#force-viz-dept-labels" (deptLabelsTree config)
  _ <- rerender "#force-viz-gender-labels" (genderLabelsTree config)

  -- Tick handler - update circle positions using HATS
  Sim.onTick (tick stateRef) sim
  Sim.start sim

  -- Toggle function with multi-phase animation
  let
    smallOffset = 12.0
    largeOffset = 60.0
    phaseDelay = 1200

    fourGroupsXFn :: ApplicantNode -> Number
    fourGroupsXFn node =
      let baseX = combinedX config
      in if node.accepted then baseX - largeOffset else baseX + largeOffset

    twoGroupsXFn :: ApplicantNode -> Number
    twoGroupsXFn node =
      let baseX = combinedX config
      in if node.accepted then baseX - smallOffset else baseX + smallOffset

    separatedXFn :: ApplicantNode -> Number
    separatedXFn node =
      let baseX = departmentX config node.department
      in if node.accepted then baseX - smallOffset else baseX + smallOffset

    updateX xFn = Sim.updateGridXYAndReinit (Just xFn) Nothing forceXHandle Nothing sim

    toggle = do
      isCombined <- Ref.read isCombinedRef
      let newMode = not isCombined
      Ref.write newMode isCombinedRef

      if newMode
        then do
          updateX fourGroupsXFn
          _ <- setTimeout_ (do
            stillCombined <- Ref.read isCombinedRef
            when stillCombined do
              updateX twoGroupsXFn
          ) phaseDelay
          pure unit
        else do
          updateX fourGroupsXFn
          _ <- setTimeout_ (do
            stillSeparated <- not <$> Ref.read isCombinedRef
            when stillSeparated do
              updateX separatedXFn
          ) phaseDelay
          pure unit

  pure
    { toggle
    , stop: Sim.stop sim
    , isCombined: Ref.read isCombinedRef
    }

-- | Tick handler - renders with current positions using HATS
tick :: Ref.Ref { nodes :: Array ApplicantNode, config :: ForceConfig } -> Effect Unit
tick stateRef = do
  state <- Ref.read stateRef
  -- Use HATS rerender - it handles the diff internally
  _ <- rerender "#force-viz-applicants" (applicantsTree state.config state.nodes)
  pure unit

-- | Create applicant nodes from data with jitter
createApplicantNodes :: ForceConfig -> Effect (Array ApplicantNode)
createApplicantNodes config = do
  let baseApplicants = createApplicants config
  let jitterRange = 40.0

  traverse (\app -> do
    dx <- (\r -> (r - 0.5) * jitterRange) <$> random
    dy <- (\r -> (r - 0.5) * jitterRange) <$> random
    pure
      { id: app.id
      , x: app.x + dx
      , y: app.y + dy
      , vx: 0.0
      , vy: 0.0
      , fx: null
      , fy: null
      , gender: app.gender
      , department: app.department
      , accepted: app.accepted
      , gridX: app.targetX
      , gridY: app.targetY
      }
  ) baseApplicants

-- =============================================================================
-- FFI for setTimeout
-- =============================================================================

foreign import setTimeout_ :: Effect Unit -> Int -> Effect Int
