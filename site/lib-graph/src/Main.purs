module Main where

import Prelude

import Effect (Effect)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.VDom.Driver (runUI)
import Hylograph.LibShell as Shell

-- | Library configuration
config :: Shell.LibConfig
config =
  { name: "psd3-graph"
  , title: "Graph"
  , tagline: "Graph algorithms and data structures for PureScript, designed for visualization."
  , version: "0.1.0"
  , github: "afcondon/purescript-psd3-graph"
  , docsPath: "/docs/graph"
  , polyglotUrl: "/"
  }

-- | Main entry point
main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Page component (stateless)
component :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
  }

render :: forall m. Unit -> H.ComponentHTML Unit () m
render _ =
  Shell.shell config
    [ Shell.heroWithViz config heroText heroViz
    , Shell.elaboration
        [ { heading: "Graph Algorithms"
          , content:
              [ Shell.para "Pathfinding: A*, Dijkstra, BFS/DFS"
              , Shell.para "Analysis: Reachability, transitive reduction, layer computation"
              , Shell.para "DAG operations: Topological sort, cycle detection"
              ]
          }
        , { heading: "Tree Utilities"
          , content:
              [ Shell.para "Rose tree helpers (wrapping tree-rose)"
              , Shell.para "Tree manipulation functions"
              , Shell.para "DAGTree for \"mostly hierarchical\" graphs"
              ]
          }
        , { heading: "Visualization Support"
          , content:
              [ Shell.para "Optional algorithm tracing for step-by-step animation"
              , Shell.para "Position helpers for layout"
              ]
          }
        ]
    , Shell.codeExample "Example" codeSnippet
    ]

heroText :: forall w i. Array (HH.HTML w i)
heroText =
  [ HH.p_
      [ HH.text "This package provides graph algorithms with optional tracing for visualization, consolidating graph-related code from the PSD3 ecosystem." ]
  ]

heroViz :: forall w i. HH.HTML w i
heroViz = Shell.screenshotLink "demo.jpeg" "/honeycomb/" "Honeycomb Puzzle Demo"

codeSnippet :: String
codeSnippet = """import Data.Graph.Pathfinding (findPath)

result = findPath startNode endNode myGraph"""
