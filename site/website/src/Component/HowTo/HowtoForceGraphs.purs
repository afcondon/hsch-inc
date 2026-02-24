module Component.HowTo.HowtoForceGraphs where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Hylograph.RoutingDSL (routeToPath)
import Hylograph.Shared.SiteNav as SiteNav
import Hylograph.Website.Types (Route(..))

type State = Unit

data Action = Initialize

component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: \_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

handleAction :: forall o m. MonadAff m => Action -> H.HalogenM State Action () o m Unit
handleAction = case _ of
  Initialize -> pure unit

render :: forall m. State -> H.ComponentHTML Action () m
render _ =
  HH.div
    [ HP.classes [ HH.ClassName "tutorial-page" ] ]
    [ SiteNav.render
        { logoSize: SiteNav.Large
        , quadrant: SiteNav.QuadHowTo
        , prevNext: Nothing
        , pageTitle: Nothing
        }

    , HH.main_
        [ -- Intro
          HH.section
            [ HP.classes [ HH.ClassName "tutorial-section", HH.ClassName "tutorial-intro" ] ]
            [ HH.h1
                [ HP.classes [ HH.ClassName "tutorial-title" ] ]
                [ HH.text "Building Force-Directed Graphs" ]
            , HH.p_
                [ HH.text "Use the ForceEngine API for physics-based layouts. See "
                , HH.a [ HP.href "#/force-playground" ] [ HH.text "Force Playground" ]
                , HH.text " for an interactive example."
                ]
            ]

        -- Create Simulation
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Create a Simulation" ]

            , HH.p_ [ HH.text "Create a force simulation and configure it with nodes and forces:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """import Hylograph.ForceEngine.Simulation as Sim
import Hylograph.ForceEngine.Types (ForceSpec(..), defaultCollide, defaultManyBody)

-- Create simulation with default config
sim <- Sim.create Sim.defaultConfig

-- Set your nodes (must have id, x, y, vx, vy, fx, fy fields)
Sim.setNodes myNodes sim

-- Add forces
Sim.addForce (ManyBody "charge" defaultManyBody { strength = -100.0 }) sim
Sim.addForce (Center "center" { x: width / 2.0, y: height / 2.0, strength: 1.0 }) sim
Sim.addForce (Collide "collide" defaultCollide { radius = 5.0 }) sim""" ]
                ]
            ]

        -- Tick Handler with HATS
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Rendering with HATS" ]

            , HH.p_ [ HH.text "Register a tick handler that rebuilds and rerenders the HATS tree on each simulation step:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """import Hylograph.HATS (Tree, elem, forEach, staticNum, staticStr, thunkedNum, thunkedStr)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))

-- Build HATS tree from current node positions
nodesTree :: Array MyNode -> Tree
nodesTree nodes =
  forEach "nodes" Circle nodes (\\n -> show n.id) \\node ->
    elem Circle
      [ thunkedNum "cx" node.x
      , thunkedNum "cy" node.y
      , staticNum "r" 5.0
      , staticStr "fill" "steelblue"
      ] []

-- Tick handler: rerender with updated positions
Sim.onTick (do
  nodes <- Ref.read nodesRef
  void $ rerender "#nodes-group" (nodesTree nodes)
) sim

-- Start the simulation
Sim.start sim""" ]
                ]
            ]

        -- Forces
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Available Forces" ]

            , HH.ul_
                [ HH.li_ [ HH.strong_ [ HH.text "Center" ], HH.text " - Keep nodes centered at a point" ]
                , HH.li_ [ HH.strong_ [ HH.text "ManyBody" ], HH.text " - Repulsion/attraction between all nodes" ]
                , HH.li_ [ HH.strong_ [ HH.text "Link" ], HH.text " - Springs between connected nodes" ]
                , HH.li_ [ HH.strong_ [ HH.text "Collide" ], HH.text " - Prevent node overlap" ]
                , HH.li_ [ HH.strong_ [ HH.text "ForceX / ForceY" ], HH.text " - Push nodes toward a target position" ]
                , HH.li_ [ HH.strong_ [ HH.text "ForceXGrid / ForceYGrid" ], HH.text " - Per-node target positions (read from node fields)" ]
                ]

            , HH.p_ [ HH.text "Forces are specified as algebraic data types:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """-- Push all nodes toward x = 300
Sim.addForce (ForceX "xCenter" { x: 300.0, strength: 0.1 }) sim

-- Per-node targets: each node has a gridX field
let forceXHandle = Core.createForceXGrid 0.15
Core.initializeForce forceXHandle nodes
Ref.modify_ (Map.insert "gridX" forceXHandle) sim.forces""" ]
                ]
            ]

        -- Dynamic Updates
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Dynamic Updates" ]

            , HH.p_ [ HH.text "Update node data and reheat the simulation:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """-- Update nodes and restart
Sim.setNodes newNodes sim
Sim.setAlpha 0.7 sim
Sim.start sim

-- Or update force targets per-node
Sim.updateGridXYAndReinit
  (Just \\node -> departmentX node.dept)  -- new X targets
  Nothing                                 -- keep Y targets
  forceXHandle
  Nothing
  sim""" ]
                ]
            ]

        -- Key Points
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Key Points" ]
            , HH.ul_
                [ HH.li_ [ HH.strong_ [ HH.text "Sim.create" ], HH.text " - Creates a simulation with configurable alpha decay" ]
                , HH.li_ [ HH.strong_ [ HH.text "Sim.onTick" ], HH.text " - Register a callback that fires on each simulation step" ]
                , HH.li_ [ HH.strong_ [ HH.text "rerender" ], HH.text " - Rebuild HATS tree from node positions, diff updates the DOM" ]
                , HH.li_ [ HH.strong_ [ HH.text "ForceSpec" ], HH.text " - ADT for all force types with sensible defaults" ]
                ]
            ]

        -- Real Examples
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Real Examples" ]
            , HH.p_ [ HH.text "See force simulation in action:" ]
            , HH.ul_
                [ HH.li_
                    [ HH.a [ HP.href "#/force-playground" ] [ HH.text "Force Playground" ]
                    , HH.text " - Interactive force simulation with multiple datasets"
                    ]
                , HH.li_
                    [ HH.a [ HP.href "#/tour/simpsons" ] [ HH.text "Simpson's Paradox" ]
                    , HH.text " - Multi-phase force animation with toggle between layouts"
                    ]
                ]
            ]
        ]
    ]

renderHeader :: forall w i. String -> HH.HTML w i
renderHeader title =
  HH.header
    [ HP.classes [ HH.ClassName "example-header" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "example-header-left" ] ]
        [ HH.a
            [ HP.href $ "#" <> routeToPath Home
            , HP.classes [ HH.ClassName "example-logo-link" ]
            ]
            [ HH.img
                [ HP.src "assets/psd3-logo-color.svg"
                , HP.alt "PSD3 Logo"
                , HP.classes [ HH.ClassName "example-logo" ]
                ]
            ]
        , HH.a
            [ HP.href "#/howto"
            , HP.classes [ HH.ClassName "example-gallery-link" ]
            ]
            [ HH.text "How-to" ]
        , HH.div
            [ HP.classes [ HH.ClassName "example-title-container" ] ]
            [ HH.h1
                [ HP.classes [ HH.ClassName "example-title" ] ]
                [ HH.text title ]
            ]
        ]
    ]
