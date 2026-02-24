module Hylographic.Viz.Registry where

import Prelude

import Data.Const (Const)
import Data.Maybe (Maybe(..))
import Data.Void (Void)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.Svg.Elements as SE
import Halogen.Svg.Attributes as SA

import Hylographic.Viz.MetaHATS as MetaHATS
import Hylographic.Viz.LSystemPlant as LSystemPlant

-- | Registry of available visualization components
-- | Each component takes no input and produces no output
type VizComponent = H.Component (Const Void) Unit Void Aff

-- | Look up a visualization component by name
lookupViz :: String -> Maybe VizComponent
lookupViz name = case name of
  "ForceDemo" -> Just forceDemo
  "HelloViz" -> Just helloViz
  "MetaHATS" -> Just MetaHATS.component
  "LSystemPlant" -> Just LSystemPlant.component
  _ -> Nothing

-- | List of available visualization names (for documentation)
availableVizNames :: Array String
availableVizNames =
  [ "HelloViz"
  , "ForceDemo"
  , "MetaHATS"
  , "LSystemPlant"
  ]

-- =============================================================================
-- Built-in Visualization Components
-- =============================================================================

-- | Simple hello world visualization (SVG circle)
helloViz :: VizComponent
helloViz = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ ->
      HH.div
        [ HP.classes [ HH.ClassName "viz-container", HH.ClassName "viz-hello" ] ]
        [ SE.svg
            [ SA.viewBox 0.0 0.0 200.0 100.0
            , SA.width 200.0
            , SA.height 100.0
            ]
            [ SE.circle
                [ SA.cx 50.0
                , SA.cy 50.0
                , SA.r 40.0
                , SA.fill (SA.Named "#0066cc")
                ]
            , SE.text
                [ SA.x 120.0
                , SA.y 55.0
                , SA.textAnchor SA.AnchorMiddle
                , SA.fill (SA.Named "#333")
                ]
                [ HH.text "Hello!" ]
            ]
        ]
  , eval: H.mkEval H.defaultEval
  }

-- | Force demo visualization (placeholder - will integrate with hylograph-simulation)
forceDemo :: VizComponent
forceDemo = H.mkComponent
  { initialState: \_ -> unit
  , render: \_ ->
      HH.div
        [ HP.classes [ HH.ClassName "viz-container", HH.ClassName "viz-force-demo" ] ]
        [ SE.svg
            [ SA.viewBox 0.0 0.0 300.0 200.0
            , SA.width 300.0
            , SA.height 200.0
            ]
            [ -- Three connected circles (lines first, then circles on top)
              SE.line
                [ SA.x1 75.0, SA.y1 100.0, SA.x2 150.0, SA.y2 60.0
                , SA.stroke (SA.Named "#ccc"), SA.strokeWidth 2.0
                ]
            , SE.line
                [ SA.x1 150.0, SA.y1 60.0, SA.x2 225.0, SA.y2 100.0
                , SA.stroke (SA.Named "#ccc"), SA.strokeWidth 2.0
                ]
            , SE.line
                [ SA.x1 75.0, SA.y1 100.0, SA.x2 225.0, SA.y2 100.0
                , SA.stroke (SA.Named "#ccc"), SA.strokeWidth 2.0
                ]
            , SE.circle [ SA.cx 75.0, SA.cy 100.0, SA.r 25.0, SA.fill (SA.Named "#0066cc") ]
            , SE.circle [ SA.cx 150.0, SA.cy 60.0, SA.r 25.0, SA.fill (SA.Named "#cc6600") ]
            , SE.circle [ SA.cx 225.0, SA.cy 100.0, SA.r 25.0, SA.fill (SA.Named "#00cc66") ]
            , SE.text
                [ SA.x 150.0, SA.y 170.0
                , SA.textAnchor SA.AnchorMiddle
                , SA.fill (SA.Named "#666")
                ]
                [ HH.text "Force Demo (static preview)" ]
            ]
        ]
  , eval: H.mkEval H.defaultEval
  }
