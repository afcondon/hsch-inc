module Component.Tour.TourIndex where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Hylograph.Shared.SiteNav as SiteNav
import Hylograph.Website.Types (Route(..))
import Hylograph.RoutingDSL (routeToPath)

-- | Tour Index page state
type State = Unit

-- | Tour Index page actions
data Action = Initialize

-- | Tour Index page component
component :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ -> unit
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: State -> H.ComponentHTML Action () Aff
render _ =
  HH.div
    [ HP.classes [ HH.ClassName "docs-page", HH.ClassName "tour-index" ] ]
    [ -- Site Navigation
      SiteNav.render
        { logoSize: SiteNav.Large
        , quadrant: SiteNav.NoQuadrant
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
                [ HH.text "Take the Tour" ]
            , HH.p
                [ HP.classes [ HH.ClassName "docs-hero-description" ] ]
                [ HH.text "Experience Hylograph through guided, interactive explorations." ]
            ]
        ]

    -- The Journey - Learning path
    , HH.section
        [ HP.classes [ HH.ClassName "docs-section" ] ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "docs-section-title" ] ]
            [ HH.text "The Journey" ]
        , HH.p
            [ HP.classes [ HH.ClassName "docs-section-intro" ] ]
            [ HH.text "Follow this path from simple shapes to complex visualizations." ]

        , HH.div
            [ HP.classes [ HH.ClassName "howto-card-grid" ] ]
            [ renderFeaturedCard TourMotionScrollyHATS "Motion & Animation"
                "From a single breathing circle to force-directed networks. Master the art of animated transitions."
                "9 animated steps"
            ]
        ]

    -- Featured Showcases
    , HH.section
        [ HP.classes [ HH.ClassName "docs-section" ] ]
        [ HH.h2
            [ HP.classes [ HH.ClassName "docs-section-title" ] ]
            [ HH.text "Featured" ]
        , HH.p
            [ HP.classes [ HH.ClassName "docs-section-intro" ] ]
            [ HH.text "Complex, app-like visualizations that demonstrate full capabilities." ]

        , HH.div
            [ HP.classes [ HH.ClassName "howto-card-grid" ] ]
            [ renderFeaturedCard TourSimpsons "Simpson's Paradox"
                "Interactive exploration of a famous statistical paradox. See how aggregated data can reverse trends."
                "Interactive"

            , renderFeaturedCard ForcePlayground "Force Explorer"
                "Interactive playground for network visualizations. Configure forces, filter data, explore relationships."
                "Full interaction"
            ]
        ]
    ]

-- | Render a featured card with emphasis
renderFeaturedCard :: forall w i. Route -> String -> String -> String -> HH.HTML w i
renderFeaturedCard route title description badge =
  HH.a
    [ HP.classes [ HH.ClassName "howto-card", HH.ClassName "howto-card--featured" ]
    , HP.href $ "#" <> routeToPath route
    ]
    [ HH.span
        [ HP.classes [ HH.ClassName "howto-card__badge" ] ]
        [ HH.text badge ]
    , HH.h3
        [ HP.classes [ HH.ClassName "howto-card__title" ] ]
        [ HH.text title ]
    , HH.p
        [ HP.classes [ HH.ClassName "howto-card__description" ] ]
        [ HH.text description ]
    ]

handleAction :: forall o. Action -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
  Initialize -> pure unit
