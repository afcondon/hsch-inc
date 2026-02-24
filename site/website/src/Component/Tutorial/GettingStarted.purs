module Hylograph.Tutorial.GettingStarted where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Hylograph.Shared.Footer as Footer
import Hylograph.Shared.SiteNav as SiteNav
import Type.Proxy (Proxy(..))

-- | Getting Started page state
type State = Unit

-- | Getting Started page actions
data Action = Initialize

-- | Child component slots
type Slots =
  ( sectionNav :: forall q. H.Slot q Void Unit
  )

_sectionNav = Proxy :: Proxy "sectionNav"

-- | Getting Started page component
component :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: State -> H.ComponentHTML Action Slots Aff
render _ =
  HH.div
    [ HP.classes [ HH.ClassName "docs-page" ] ]
    [ -- Site Navigation
      SiteNav.render
        { logoSize: SiteNav.Large
        , quadrant: SiteNav.QuadGettingStarted
        , prevNext: Nothing
        , pageTitle: Nothing
        }

    -- Hero section
    , HH.section
        [ HP.classes [ HH.ClassName "docs-hero" ] ]
        [ HH.div
            [ HP.classes [ HH.ClassName "docs-hero-content" ] ]
            [ HH.h1
                [ HP.classes [ HH.ClassName "docs-hero-title" ] ]
                [ HH.text "Getting Started" ]
            , HH.p
                [ HP.classes [ HH.ClassName "docs-hero-description" ] ]
                [ HH.text "Build type-safe, declarative D3 visualizations in PureScript. This guide will have you rendering your first chart in minutes." ]
            ]
        ]

    -- Quick Start section
    , HH.section
        [ HP.classes [ HH.ClassName "tutorial-section" ]
        , HP.id "quickstart"
        ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
            [ HH.text "Quick Start" ]

        , HH.h3
            [ HP.id "prerequisites" ]
            [ HH.text "Prerequisites" ]
        , HH.p_
            [ HH.text "You'll need:" ]
        , HH.ul_
            [ HH.li_ [ HH.text "Node.js 18+" ]
            , HH.li_ [ HH.text "PureScript compiler and Spago" ]
            ]
        , HH.pre_
            [ HH.code_
                [ HH.text "npm install -g purescript spago" ]
            ]

        , HH.h3
            [ HP.id "installation" ]
            [ HH.text "Installation" ]
        , HH.p_
            [ HH.text "Add the Hylograph packages to your project:" ]
        , HH.pre_
            [ HH.code_
                [ HH.text """spago install hylograph-selection""" ]
            ]
        , HH.p_
            [ HH.text "For force-directed graphs and simulations, also add:" ]
        , HH.pre_
            [ HH.code_
                [ HH.text "spago install hylograph-simulation" ]
            ]
        ]

    -- First Visualization section
    , HH.section
        [ HP.classes [ HH.ClassName "tutorial-section" ]
        , HP.id "first-viz"
        ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
            [ HH.text "Your First Visualization" ]
        , HH.p_
            [ HH.text "Hylograph uses HATS (Hylomorphic Abstract Tree Syntax) - a declarative tree API. You describe what you want, and the interpreter renders it to the DOM:" ]

        , HH.pre_
            [ HH.code_
                [ HH.text """module Main where

import Prelude
import Effect (Effect)
import Hylograph.HATS (Tree, elem, forEach, staticNum, thunkedNum, thunkedStr)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))

-- Your data
type Point = { x :: Number, y :: Number, color :: String }

myData :: Array Point
myData =
  [ { x: 100.0, y: 100.0, color: "steelblue" }
  , { x: 200.0, y: 150.0, color: "coral" }
  , { x: 300.0, y: 100.0, color: "seagreen" }
  ]

-- The visualization
chart :: Tree
chart =
  elem SVG
    [ staticNum "width" 400.0, staticNum "height" 200.0 ]
    [ forEach "circles" Circle myData show \\point ->
        elem Circle
          [ thunkedNum "cx" point.x
          , thunkedNum "cy" point.y
          , staticNum "r" 20.0
          , thunkedStr "fill" point.color
          ] []
    ]

-- Render to the DOM
main :: Effect Unit
main = void $ rerender "#chart" chart""" ]
            ]

        , HH.h3_ [ HH.text "What's happening here?" ]
        , HH.ul_
            [ HH.li_
                [ HH.code_ [ HH.text "elem SVG [...]" ]
                , HH.text " - Creates an SVG container with static attributes"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "forEach \"circles\" Circle myData show" ]
                , HH.text " - Iterates over your data, creating a Circle element for each point"
                ]
            , HH.li_
                [ HH.text "The lambda "
                , HH.code_ [ HH.text "\\point -> elem Circle [...]" ]
                , HH.text " builds each circle's subtree with full type safety"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "rerender \"#chart\" chart" ]
                , HH.text " - Renders the tree to a DOM element, diffing against the previous render"
                ]
            ]
        ]

    -- HTML Setup section
    , HH.section
        [ HP.classes [ HH.ClassName "tutorial-section" ]
        , HP.id "html-setup"
        ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
            [ HH.text "HTML Setup" ]
        , HH.p_
            [ HH.text "Your HTML needs D3.js and a container element:" ]
        , HH.pre_
            [ HH.code_
                [ HH.text """<!DOCTYPE html>
<html>
<head>
  <script src="https://d3js.org/d3.v7.min.js"></script>
</head>
<body>
  <div id="chart"></div>
  <script src="bundle.js"></script>
</body>
</html>""" ]
            ]
        , HH.p_
            [ HH.text "Bundle your PureScript:" ]
        , HH.pre_
            [ HH.code_
                [ HH.text "spago bundle --module Main --outfile bundle.js" ]
            ]
        ]

    -- Key Concepts section
    , HH.section
        [ HP.classes [ HH.ClassName "tutorial-section" ]
        , HP.id "concepts"
        ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
            [ HH.text "Key Concepts" ]

        , HH.h3_ [ HH.text "HATS Trees" ]
        , HH.p_
            [ HH.text "HATS is declarative - you describe the structure of your visualization as a tree of elements. The key building blocks:" ]
        , HH.ul_
            [ HH.li_
                [ HH.code_ [ HH.text "elem" ]
                , HH.text " - A single element with attributes and children"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "forEach" ]
                , HH.text " - Data-driven elements: iterate over an array, producing a subtree for each item"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "staticStr / staticNum" ]
                , HH.text " - Attributes that never change (optimized away on re-render)"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "thunkedStr / thunkedNum" ]
                , HH.text " - Dynamic attributes that update on each render"
                ]
            ]

        , HH.h3_ [ HH.text "Attributes" ]
        , HH.p_
            [ HH.text "Attributes are simple key-value pairs. Static attributes are set once; thunked attributes are re-evaluated on each rerender:" ]
        , HH.pre_
            [ HH.code_
                [ HH.text """-- Static: set once, never updated
staticNum "r" 5.0
staticStr "fill" "steelblue"

-- Thunked: re-evaluated on each rerender
thunkedNum "cx" point.x
thunkedStr "fill" (colorScale point.category)""" ]
            ]

        , HH.h3_ [ HH.text "Interpreters" ]
        , HH.p_
            [ HH.text "The same HATS Tree can be interpreted different ways:" ]
        , HH.ul_
            [ HH.li_
                [ HH.code_ [ HH.text "InterpreterTick.rerender" ]
                , HH.text " - Renders to the DOM, diffing against previous state"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "Mermaid.interpret" ]
                , HH.text " - Generates a Mermaid diagram of the tree structure"
                ]
            , HH.li_
                [ HH.code_ [ HH.text "English.interpret" ]
                , HH.text " - Produces English description (debugging)"
                ]
            ]

        , HH.h3_ [ HH.text "Static vs Dynamic" ]
        , HH.p_
            [ HH.text "HATS trees are plain values - you build them from your current data and pass them to "
            , HH.code_ [ HH.text "rerender" ]
            , HH.text ". The interpreter handles DOM diffing automatically:"
            ]
        , HH.ul_
            [ HH.li_
                [ HH.strong_ [ HH.text "Static charts" ]
                , HH.text " - Build the tree once, render once. Bar charts, scatter plots, Sankey diagrams."
                ]
            , HH.li_
                [ HH.strong_ [ HH.text "Interactive charts" ]
                , HH.text " - Rebuild the tree with new data, call "
                , HH.code_ [ HH.text "rerender" ]
                , HH.text " again. The diff engine updates only what changed."
                ]
            , HH.li_
                [ HH.strong_ [ HH.text "Animations" ]
                , HH.text " - Use force simulations or requestAnimationFrame to call "
                , HH.code_ [ HH.text "rerender" ]
                , HH.text " on each frame. See the "
                , HH.a [ HP.href "#/showcase" ] [ HH.text "Code Explorer" ]
                , HH.text " for an example."
                ]
            ]
        ]

    -- Next Steps section
    , HH.section
        [ HP.classes [ HH.ClassName "tutorial-section" ]
        , HP.id "next"
        ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
            [ HH.text "Next Steps" ]
        , HH.ul_
            [ HH.li_
                [ HH.a [ HP.href "#/tour" ] [ HH.text "Take the Tour" ]
                , HH.text " - See what's possible with Hylograph"
                ]
            , HH.li_
                [ HH.a [ HP.href "#/showcase" ] [ HH.text "Explore the Showcase" ]
                , HH.text " - Interactive examples like the Code Explorer and SPLOM"
                ]
            , HH.li_
                [ HH.a [ HP.href "#/examples" ] [ HH.text "Browse Examples" ]
                , HH.text " - All examples organized by category"
                ]
            , HH.li_
                [ HH.a [ HP.href "#/understanding" ] [ HH.text "Understanding Hylograph" ]
                , HH.text " - Deep dive into the architecture"
                ]
            ]
        ]

    -- Footer
    , Footer.render
    ]

handleAction :: forall o. Action -> H.HalogenM State Action Slots o Aff Unit
handleAction = case _ of
  Initialize -> pure unit
