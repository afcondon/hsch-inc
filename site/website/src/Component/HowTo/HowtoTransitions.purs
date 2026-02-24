module Component.HowTo.HowtoTransitions where

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
                [ HH.text "Creating Animated Transitions" ]
            , HH.p_
                [ HH.text "Hylograph uses a rerender-based approach to animation. Instead of imperative transition commands, you rebuild your HATS tree with new values and let the diff engine update the DOM." ]
            ]

        -- Rerender-Based Animation
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Rerender-Based Updates" ]

            , HH.p_ [ HH.text "The simplest animation pattern: rebuild the tree with new data and call rerender:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """import Effect.Ref as Ref
import Hylograph.HATS (Tree, elem, staticNum, thunkedNum)
import Hylograph.HATS.InterpreterTick (rerender)
import Hylograph.Internal.Selection.Types (ElementType(..))

-- Build tree from current state
circleTree :: Number -> Number -> Tree
circleTree x radius =
  elem SVG [ staticNum "width" 400.0, staticNum "height" 200.0 ]
    [ elem Circle
        [ thunkedNum "cx" x
        , thunkedNum "cy" 100.0
        , thunkedNum "r" radius
        , staticStr "fill" "steelblue"
        ] []
    ]

-- Update: just rebuild and rerender
updateCircle :: Ref.Ref { x :: Number, r :: Number } -> Effect Unit
updateCircle stateRef = do
  { x, r } <- Ref.read stateRef
  void $ rerender "#viz" (circleTree x r)""" ]
                ]
            ]

        -- CSS Transitions
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "CSS Transitions" ]

            , HH.p_ [ HH.text "For smooth visual transitions, combine rerender with CSS:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """/* In your stylesheet */
.animated-circle {
  transition: cx 0.5s ease-out, cy 0.5s ease-out, r 0.3s ease;
}""" ]
                ]

            , HH.p_ [ HH.text "Add the CSS class in your HATS tree:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """elem Circle
  [ thunkedNum "cx" newX
  , thunkedNum "cy" newY
  , thunkedNum "r" newRadius
  , staticStr "class" "animated-circle"
  ] []""" ]
                ]
            , HH.p_ [ HH.text "When rerender updates the attributes, the browser animates the change smoothly via CSS." ]
            ]

        -- Tick-Based Animation
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Tick-Based Animation" ]

            , HH.p_ [ HH.text "For physics-based animation, use a force simulation with tick callbacks:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """import Hylograph.ForceEngine.Simulation as Sim

-- Create simulation and set nodes
sim <- Sim.create Sim.defaultConfig
Sim.setNodes myNodes sim

-- On each tick, rebuild tree from node positions and rerender
Sim.onTick (do
  state <- Ref.read stateRef
  void $ rerender "#viz" (nodesTree state.nodes)
) sim

Sim.start sim""" ]
                ]

            , HH.p_ [ HH.text "The simulation updates node positions on each tick, and you rebuild the HATS tree from the new positions." ]
            ]

        -- requestAnimationFrame
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "requestAnimationFrame" ]

            , HH.p_ [ HH.text "For custom animations outside of force simulations:" ]
            , HH.pre
                [ HP.classes [ HH.ClassName "code-block" ] ]
                [ HH.code_
                    [ HH.text """import Web.HTML.Window (requestAnimationFrame)

animate :: Ref.Ref Number -> Effect Unit
animate tRef = do
  t <- Ref.read tRef
  Ref.write (t + 1.0) tRef
  void $ rerender "#viz" (animatedTree t)
  void $ requestAnimationFrame (animate tRef) =<< window""" ]
                ]
            ]

        -- Key Points
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Key Points" ]
            , HH.ul_
                [ HH.li_ [ HH.strong_ [ HH.text "Rerender" ], HH.text " - Rebuild tree with new data, call rerender. The diff engine handles DOM updates." ]
                , HH.li_ [ HH.strong_ [ HH.text "CSS transitions" ], HH.text " - Add transition CSS to elements for smooth attribute interpolation." ]
                , HH.li_ [ HH.strong_ [ HH.text "Force simulations" ], HH.text " - Use onTick for physics-based animation." ]
                , HH.li_ [ HH.strong_ [ HH.text "requestAnimationFrame" ], HH.text " - For custom frame-by-frame animation loops." ]
                ]
            ]

        -- Real Example
        , HH.section
            [ HP.classes [ HH.ClassName "tutorial-section" ] ]
            [ HH.h2
                [ HP.classes [ HH.ClassName "tutorial-section-title" ] ]
                [ HH.text "Real Example" ]
            , HH.p_ [ HH.text "See animated rendering in action:" ]
            , HH.ul_
                [ HH.li_
                    [ HH.a [ HP.href "#/tour/simpsons" ] [ HH.text "Simpson's Paradox" ]
                    , HH.text " - Force-directed animation with multi-phase transitions"
                    ]
                , HH.li_
                    [ HH.a [ HP.href "#/showcase" ] [ HH.text "Code Explorer" ]
                    , HH.text " - Beeswarm and treemap animations"
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
