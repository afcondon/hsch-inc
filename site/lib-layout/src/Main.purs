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
  { name: "psd3-layout"
  , title: "Layout"
  , tagline: "Pure PureScript implementations of layout algorithms for hierarchies and flow diagrams."
  , version: "0.1.0"
  , github: "afcondon/purescript-psd3-layout"
  , docsPath: "/docs/layout"
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
        [ { heading: "Hierarchical Layouts"
          , content:
              [ Shell.para "Tree - Tidy tree layout (Reingold-Tilford algorithm)"
              , Shell.para "Pack - Circle packing for hierarchical data"
              , Shell.para "Partition - Sunburst/icicle partition layout"
              , Shell.para "Treemap - Multiple tiling algorithms: squarify (default), slice, dice, sliceDice, binary"
              ]
          }
        , { heading: "Graph Layouts"
          , content:
              [ Shell.para "Sankey - Flow diagram layout for directed acyclic graphs"
              , Shell.para "EdgeBundle - Hierarchical edge bundling"
              ]
          }
        ]
    , Shell.codeExample "Example" codeSnippet
    ]

heroText :: forall w i. Array (HH.HTML w i)
heroText =
  [ HH.p_
      [ HH.text "Layout algorithms for hierarchical and graph data, implemented in pure PureScript. Many of these layouts are familiar to users of D3 but here they are implemented without FFI dependencies using FP implementations in 100% PureScript. These work with the rose-tree data structure from purescript-tree-rose." ]
  ]

heroViz :: forall w i. HH.HTML w i
heroViz = Shell.screenshotLink "demo.jpeg" "/layouts/" "Layout Gallery Demo"

codeSnippet :: String
codeSnippet = """import DataViz.Layout.Hierarchy.Tree (tree, defaultTreeConfig)
import Data.Tree (mkTree)

myTree = mkTree "root" [mkTree "a" [], mkTree "b" []]
config = defaultTreeConfig { size = { width: 400.0, height: 300.0 } }
positioned = tree config myTree
-- Each node now has x, y coordinates"""
