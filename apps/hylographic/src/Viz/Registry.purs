module Hylographic.Viz.Registry where

import Prelude

import Data.Const (Const)
import Data.Maybe (Maybe(..))
import Data.Void (Void)
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

import Hylographic.Viz.MetaHATS as MetaHATS

-- | Registry of available visualization components
-- | Each component takes no input and produces no output
type VizComponent = H.Component (Const Void) Unit Void Aff

-- | Look up a visualization component by name
lookupViz :: String -> Maybe VizComponent
lookupViz name = case name of
  "ForceDemo" -> Just forceDemo
  "HelloViz" -> Just helloViz
  "MetaHATS" -> Just MetaHATS.component
  _ -> Nothing

-- | List of available visualization names (for documentation)
availableVizNames :: Array String
availableVizNames =
  [ "HelloViz"
  , "ForceDemo"
  , "MetaHATS"
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
        [ HH.element (HH.ElemName "svg")
            [ HP.attr (HH.AttrName "viewBox") "0 0 200 100"
            , HP.attr (HH.AttrName "width") "200"
            , HP.attr (HH.AttrName "height") "100"
            ]
            [ HH.element (HH.ElemName "circle")
                [ HP.attr (HH.AttrName "cx") "50"
                , HP.attr (HH.AttrName "cy") "50"
                , HP.attr (HH.AttrName "r") "40"
                , HP.attr (HH.AttrName "fill") "#0066cc"
                ]
                []
            , HH.element (HH.ElemName "text")
                [ HP.attr (HH.AttrName "x") "120"
                , HP.attr (HH.AttrName "y") "55"
                , HP.attr (HH.AttrName "text-anchor") "middle"
                , HP.attr (HH.AttrName "fill") "#333"
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
        [ HH.element (HH.ElemName "svg")
            [ HP.attr (HH.AttrName "viewBox") "0 0 300 200"
            , HP.attr (HH.AttrName "width") "300"
            , HP.attr (HH.AttrName "height") "200"
            ]
            [ -- Three connected circles
              HH.element (HH.ElemName "line")
                [ HP.attr (HH.AttrName "x1") "75"
                , HP.attr (HH.AttrName "y1") "100"
                , HP.attr (HH.AttrName "x2") "150"
                , HP.attr (HH.AttrName "y2") "60"
                , HP.attr (HH.AttrName "stroke") "#ccc"
                , HP.attr (HH.AttrName "stroke-width") "2"
                ]
                []
            , HH.element (HH.ElemName "line")
                [ HP.attr (HH.AttrName "x1") "150"
                , HP.attr (HH.AttrName "y1") "60"
                , HP.attr (HH.AttrName "x2") "225"
                , HP.attr (HH.AttrName "y2") "100"
                , HP.attr (HH.AttrName "stroke") "#ccc"
                , HP.attr (HH.AttrName "stroke-width") "2"
                ]
                []
            , HH.element (HH.ElemName "line")
                [ HP.attr (HH.AttrName "x1") "75"
                , HP.attr (HH.AttrName "y1") "100"
                , HP.attr (HH.AttrName "x2") "225"
                , HP.attr (HH.AttrName "y2") "100"
                , HP.attr (HH.AttrName "stroke") "#ccc"
                , HP.attr (HH.AttrName "stroke-width") "2"
                ]
                []
            , HH.element (HH.ElemName "circle")
                [ HP.attr (HH.AttrName "cx") "75"
                , HP.attr (HH.AttrName "cy") "100"
                , HP.attr (HH.AttrName "r") "25"
                , HP.attr (HH.AttrName "fill") "#0066cc"
                ]
                []
            , HH.element (HH.ElemName "circle")
                [ HP.attr (HH.AttrName "cx") "150"
                , HP.attr (HH.AttrName "cy") "60"
                , HP.attr (HH.AttrName "r") "25"
                , HP.attr (HH.AttrName "fill") "#cc6600"
                ]
                []
            , HH.element (HH.ElemName "circle")
                [ HP.attr (HH.AttrName "cx") "225"
                , HP.attr (HH.AttrName "cy") "100"
                , HP.attr (HH.AttrName "r") "25"
                , HP.attr (HH.AttrName "fill") "#00cc66"
                ]
                []
            , HH.element (HH.ElemName "text")
                [ HP.attr (HH.AttrName "x") "150"
                , HP.attr (HH.AttrName "y") "170"
                , HP.attr (HH.AttrName "text-anchor") "middle"
                , HP.attr (HH.AttrName "fill") "#666"
                , HP.attr (HH.AttrName "font-size") "12"
                ]
                [ HH.text "Force Demo (static preview)" ]
            ]
        ]
  , eval: H.mkEval H.defaultEval
  }
