module Hylographic.Viz.MetaHATS where

import Prelude

import Data.Const (Const)
import Data.Void (Void)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA

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
  SE.svg
    [ SA.viewBox 0.0 0.0 200.0 150.0
    , SA.width 200.0
    , SA.height 150.0
    ]
    [ SE.circle
        [ SA.cx 100.0
        , SA.cy 75.0
        , SA.r 50.0
        , SA.fill (SA.Named "#0066cc")
        , SA.stroke (SA.Named "#003366")
        , SA.strokeWidth 2.0
        ]
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
  SE.svg
    [ SA.viewBox 0.0 0.0 240.0 120.0
    , SA.width 240.0
    , SA.height 120.0
    ]
    [ SE.rect [ SA.x 10.0, SA.y 90.0, SA.width 40.0, SA.height 10.0, SA.fill (SA.Named "#0066cc") ]
    , SE.rect [ SA.x 55.0, SA.y 75.0, SA.width 40.0, SA.height 25.0, SA.fill (SA.Named "#0066cc") ]
    , SE.rect [ SA.x 100.0, SA.y 60.0, SA.width 40.0, SA.height 40.0, SA.fill (SA.Named "#0066cc") ]
    , SE.rect [ SA.x 145.0, SA.y 70.0, SA.width 40.0, SA.height 30.0, SA.fill (SA.Named "#0066cc") ]
    , SE.rect [ SA.x 190.0, SA.y 50.0, SA.width 40.0, SA.height 50.0, SA.fill (SA.Named "#0066cc") ]
    ]
