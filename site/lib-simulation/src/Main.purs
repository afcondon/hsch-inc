module Main where

import Prelude

import Effect (Effect)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.VDom.Driver (runUI)
import Hylograph.LibShell as Shell

-- | Library configuration
config :: Shell.LibConfig
config =
  { name: "psd3-simulation"
  , title: "Simulation"
  , tagline: "Force-directed graph simulation with unified D3 and WASM engine support."
  , version: "0.1.0"
  , github: "afcondon/purescript-psd3-simulation"
  , docsPath: "/docs/simulation"
  , polyglotUrl: "/"
  }

-- | Main entry point
main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Page state
type State = Unit

-- | Page component
component :: forall q i o m. MonadAff m => H.Component q i o m
component = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ -> renderLandingPage
  , eval: H.mkEval H.defaultEval
  }

renderLandingPage :: forall w i. HH.HTML w i
renderLandingPage =
  Shell.shell config
    [ Shell.heroWithViz config heroText heroViz
    , Shell.elaboration
        [ { heading: "Features"
          , content:
              [ Shell.para "Dual Engine Support - Same API for D3.js and Rust/WASM physics"
              , Shell.para "Framework Agnostic - Works with Halogen, React, or vanilla JS"
              , Shell.para "Declarative Forces - Compose forces with a fluent builder API"
              , Shell.para "Event Subscription - React to Tick, Started, Stopped, Completed events"
              , Shell.para "GUP Semantics - Enter/update/exit tracking when data changes"
              ]
          }
        , { heading: "Available Forces"
          , content:
              [ Shell.para "| Force | Description |"
              , Shell.para "|-------|-------------|"
              , Shell.para "| manyBody | N-body charge simulation (attract/repel) |"
              , Shell.para "| center | Pulls nodes toward a center point |"
              , Shell.para "| link | Spring forces between connected nodes |"
              , Shell.para "| collide | Prevents node overlap |"
              , Shell.para "| positionX | Pulls nodes toward an X position |"
              , Shell.para "| positionY | Pulls nodes toward a Y position |"
              , Shell.para "| radial | Pulls nodes toward a circle |"
              ]
          }
        ]
    , Shell.codeExample "Example" codeSnippet
    ]

heroText :: forall w i. Array (HH.HTML w i)
heroText =
  [ HH.p_
      [ HH.text "Force-directed graph simulation with unified D3 and WASM engine support." ]
  ]

heroViz :: forall w i. HH.HTML w i
heroViz = Shell.screenshotLink "demo.jpeg" "/#/force-playground" "Force Playground Demo"

codeSnippet :: String
codeSnippet = """module Main where

import Prelude
import Effect (Effect)
import Effect.Console (log)
import Data.Nullable (null) as Nullable

import Hylograph.Simulation
  ( runSimulation, Engine(..), SimulationEvent(..), subscribe
  , setup, manyBody, center, withStrength, withX, withY, static
  )
import Hylograph.AST as A
import Hylograph.Unified.Attribute as Attr
import Hylograph.Unified.Display (showNumD)
import Hylograph.Internal.Selection.Types (ElementType(..))

main :: Effect Unit
main = do
  -- Run simulation with D3 engine (or use WASM for same API)
  { handle, events } <- runSimulation
    { engine: D3
    , setup: setup "physics"
        [ manyBody "charge" # withStrength (static (-50.0))
        , center "center" # withX (static 200.0) # withY (static 150.0)
        ]
    , nodes:
        [ { id: 0, x: 190.0, y: 140.0, vx: 0.0, vy: 0.0, fx: Nullable.null, fy: Nullable.null }
        , { id: 1, x: 200.0, y: 150.0, vx: 0.0, vy: 0.0, fx: Nullable.null, fy: Nullable.null }
        , { id: 2, x: 210.0, y: 160.0, vx: 0.0, vy: 0.0, fx: Nullable.null, fy: Nullable.null }
        ]
    , links: []
    , container: "#visualization"
    , nodeTemplate: \_ -> A.elem Circle
        [ Attr.attr "cx" _.x showNumD
        , Attr.attr "cy" _.y showNumD
        , Attr.attrStatic "r" "8"
        , Attr.attrStatic "fill" "#4a9eff"
        ]
    , alphaMin: 0.001
    }

  -- Subscribe to simulation events
  _ <- subscribe events \event -> case event of
    Tick { alpha } -> log $ "Alpha: " <> show alpha
    Completed -> log "Simulation converged!"
    _ -> pure unit

  log "Simulation running!""""
