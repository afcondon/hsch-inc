module Hylographic.Viz.MetaHATS where

import Prelude

import Data.Const (Const)
import Data.Void (Void)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | MetaHATS component shows both HATS code and its visualization side by side.
-- | This demonstrates the "meta" aspect - seeing the code AND the output together.
-- |
-- | Since HATS is a PureScript DSL, we can't evaluate it at runtime.
-- | Instead, this component pairs pre-written code strings with pre-compiled visualizations.

type VizComponent = H.Component (Const Void) Unit Void Aff

-- | A MetaHATS example with code and visualization
type MetaExample =
  { name :: String
  , description :: String
  , code :: String
  , render :: forall m. H.ComponentHTML Unit () m
  }

-- | The MetaHATS component - shows code + visualization
component :: VizComponent
component = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ -> renderMetaHATS circleExample
  , eval: H.mkEval H.defaultEval
  }

-- | Render a MetaHATS example
renderMetaHATS :: forall m. MetaExample -> H.ComponentHTML Unit () m
renderMetaHATS example =
  HH.div
    [ HP.classes [ HH.ClassName "meta-hats" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "meta-hats__header" ] ]
        [ HH.h3_ [ HH.text example.name ]
        , HH.p_ [ HH.text example.description ]
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "meta-hats__content" ] ]
        [ HH.div
            [ HP.classes [ HH.ClassName "meta-hats__code" ] ]
            [ HH.pre_
                [ HH.element (HH.ElemName "code")
                    [ HP.classes [ HH.ClassName "language-purescript" ] ]
                    [ HH.text example.code ]
                ]
            ]
        , HH.div
            [ HP.classes [ HH.ClassName "meta-hats__viz" ] ]
            [ example.render ]
        ]
    ]

-- =============================================================================
-- Example: Simple Circle
-- =============================================================================

circleExample :: MetaExample
circleExample =
  { name: "HATS Circle"
  , description: "A simple circle element using HATS DSL"
  , code: """elem Circle
  [ F.cx 100.0
  , F.cy 75.0
  , F.r 50.0
  , F.fill "#0066cc"
  , F.stroke "#003366"
  , F.strokeWidth 2.0
  ]
  []"""
  , render: circleViz
  }

circleViz :: forall m. H.ComponentHTML Unit () m
circleViz =
  HH.element (HH.ElemName "svg")
    [ HP.attr (HH.AttrName "viewBox") "0 0 200 150"
    , HP.attr (HH.AttrName "width") "200"
    , HP.attr (HH.AttrName "height") "150"
    ]
    [ HH.element (HH.ElemName "circle")
        [ HP.attr (HH.AttrName "cx") "100"
        , HP.attr (HH.AttrName "cy") "75"
        , HP.attr (HH.AttrName "r") "50"
        , HP.attr (HH.AttrName "fill") "#0066cc"
        , HP.attr (HH.AttrName "stroke") "#003366"
        , HP.attr (HH.AttrName "stroke-width") "2"
        ]
        []
    ]

-- =============================================================================
-- Example: Grouped Rectangles (Fold pattern)
-- =============================================================================

foldExample :: MetaExample
foldExample =
  { name: "HATS Fold"
  , description: "A fold over data to create multiple elements"
  , code: """fold "bars"
  { enumerate: FromArray [10, 25, 40, 30, 50]
  , assemble: Siblings
  , template: \\value ->
      elem Rect
        [ F.x (toNumber idx * 45.0 + 10.0)
        , F.y (100.0 - value)
        , F.width 40.0
        , F.height value
        , F.fill "#0066cc"
        ]
        []
  }"""
  , render: foldViz
  }

foldViz :: forall m. H.ComponentHTML Unit () m
foldViz =
  HH.element (HH.ElemName "svg")
    [ HP.attr (HH.AttrName "viewBox") "0 0 240 120"
    , HP.attr (HH.AttrName "width") "240"
    , HP.attr (HH.AttrName "height") "120"
    ]
    [ -- Bar 1
      HH.element (HH.ElemName "rect")
        [ HP.attr (HH.AttrName "x") "10"
        , HP.attr (HH.AttrName "y") "90"
        , HP.attr (HH.AttrName "width") "40"
        , HP.attr (HH.AttrName "height") "10"
        , HP.attr (HH.AttrName "fill") "#0066cc"
        ]
        []
    , -- Bar 2
      HH.element (HH.ElemName "rect")
        [ HP.attr (HH.AttrName "x") "55"
        , HP.attr (HH.AttrName "y") "75"
        , HP.attr (HH.AttrName "width") "40"
        , HP.attr (HH.AttrName "height") "25"
        , HP.attr (HH.AttrName "fill") "#0066cc"
        ]
        []
    , -- Bar 3
      HH.element (HH.ElemName "rect")
        [ HP.attr (HH.AttrName "x") "100"
        , HP.attr (HH.AttrName "y") "60"
        , HP.attr (HH.AttrName "width") "40"
        , HP.attr (HH.AttrName "height") "40"
        , HP.attr (HH.AttrName "fill") "#0066cc"
        ]
        []
    , -- Bar 4
      HH.element (HH.ElemName "rect")
        [ HP.attr (HH.AttrName "x") "145"
        , HP.attr (HH.AttrName "y") "70"
        , HP.attr (HH.AttrName "width") "40"
        , HP.attr (HH.AttrName "height") "30"
        , HP.attr (HH.AttrName "fill") "#0066cc"
        ]
        []
    , -- Bar 5
      HH.element (HH.ElemName "rect")
        [ HP.attr (HH.AttrName "x") "190"
        , HP.attr (HH.AttrName "y") "50"
        , HP.attr (HH.AttrName "width") "40"
        , HP.attr (HH.AttrName "height") "50"
        , HP.attr (HH.AttrName "fill") "#0066cc"
        ]
        []
    ]
