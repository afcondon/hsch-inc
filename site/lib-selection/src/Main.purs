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
  { name: "hylograph-selection"
  , title: "Selection"
  , tagline: "Type-safe D3 selection and attribute library for PureScript."
  , version: "0.1.0"
  , github: "afcondon/purescript-hylograph-selection"
  , docsPath: "/docs/selection"
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
        [ { heading: "Tree AST"
          , content:
              [ Shell.para "Build visualizations as data structures:"
              ]
          }
        , { heading: "Data Joins"
          , content:
              [ Shell.para "D3-style enter/update/exit with type safety:"
              ]
          }
        , { heading: "Interpreters"
          , content:
              [ Shell.para "D3 Interpreter - Renders to DOM via D3.js"
              , Shell.para "English Interpreter - Describes the tree in plain English"
              , Shell.para "Mermaid Interpreter - Generates Mermaid diagrams"
              ]
          }
        ]
    , Shell.codeExample "Example" codeSnippet
    ]

heroText :: forall w i. Array (HH.HTML w i)
heroText =
  [ HH.p_
      [ HH.text "A declarative, type-safe approach to D3.js visualization in PureScript. Instead of imperative D3 method chaining, you build a tree AST that describes your visualization, then interpret it to render." ]
  ]

heroViz :: forall w i. HH.HTML w i
heroViz = Shell.screenshotLink "hylograph-explorer.jpg" "demo/" "Hylograph: Interactive HATS Explorer"

codeSnippet :: String
codeSnippet = """myViz :: T.Tree Unit
myViz =
  T.named SVG "chart"
    [ attr "width" $ num 400.0
    , attr "height" $ num 300.0
    ]
    `T.withChild`
      T.elem Circle
        [ cx $ num 200.0
        , cy $ num 150.0
        , r $ num 50.0
        , fill $ text "steelblue"
        ]"""
