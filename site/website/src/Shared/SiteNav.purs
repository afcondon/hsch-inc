-- | Site-wide navigation component
-- |
-- | Provides consistent header navigation across all pages
module Hylograph.Shared.SiteNav
  ( render
  , LogoSize(..)
  , Quadrant(..)
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Hylograph.RoutingDSL (routeToPath)
import Hylograph.Website.Types (Route(..))

-- | Logo display size
data LogoSize = Large | Normal

-- | Current section quadrant for visual indicator
data Quadrant
  = NoQuadrant
  | QuadGettingStarted
  | QuadHowTo
  | QuadUnderstanding
  | QuadReference

-- | Navigation config
type NavConfig =
  { logoSize :: LogoSize
  , quadrant :: Quadrant
  , prevNext :: Maybe { prev :: Maybe Route, next :: Maybe Route }
  , pageTitle :: Maybe String
  }

-- | Render the site navigation header
render :: forall w i. NavConfig -> HH.HTML w i
render config =
  HH.header
    [ HP.classes [ HH.ClassName "site-header" ] ]
    [ HH.nav
        [ HP.classes [ HH.ClassName "site-nav" ] ]
        [ renderLogo config.logoSize
        , renderNavLinks config.quadrant
        , renderPrevNext config.prevNext
        ]
    ]

renderLogo :: forall w i. LogoSize -> HH.HTML w i
renderLogo size =
  HH.a
    [ HP.href $ "#" <> routeToPath Home
    , HP.classes [ HH.ClassName "site-logo", HH.ClassName sizeClass ]
    ]
    [ HH.span
        [ HP.classes [ HH.ClassName "logo-text" ] ]
        [ HH.text "Hylograph" ]
    ]
  where
    sizeClass = case size of
      Large -> "logo-large"
      Normal -> "logo-normal"

renderNavLinks :: forall w i. Quadrant -> HH.HTML w i
renderNavLinks quadrant =
  HH.ul
    [ HP.classes [ HH.ClassName "nav-links" ] ]
    [ navLink "Getting Started" GettingStarted (quadrant == QuadGettingStarted)
    , navLink "How To" HowtoIndex (quadrant == QuadHowTo)
    , navLink "Understanding" Understanding (quadrant == QuadUnderstanding)
    , navLink "Reference" Reference (quadrant == QuadReference)
    ]

navLink :: forall w i. String -> Route -> Boolean -> HH.HTML w i
navLink label route isActive =
  HH.li
    [ HP.classes $ [ HH.ClassName "nav-item" ] <> if isActive then [ HH.ClassName "active" ] else [] ]
    [ HH.a
        [ HP.href $ "#" <> routeToPath route
        , HP.classes [ HH.ClassName "nav-link" ]
        ]
        [ HH.text label ]
    ]

renderPrevNext :: forall w i. Maybe { prev :: Maybe Route, next :: Maybe Route } -> HH.HTML w i
renderPrevNext Nothing = HH.text ""
renderPrevNext (Just { prev, next }) =
  HH.div
    [ HP.classes [ HH.ClassName "prev-next-nav" ] ]
    [ case prev of
        Nothing -> HH.text ""
        Just route ->
          HH.a
            [ HP.href $ "#" <> routeToPath route
            , HP.classes [ HH.ClassName "prev-link" ]
            ]
            [ HH.text "← Prev" ]
    , case next of
        Nothing -> HH.text ""
        Just route ->
          HH.a
            [ HP.href $ "#" <> routeToPath route
            , HP.classes [ HH.ClassName "next-link" ]
            ]
            [ HH.text "Next →" ]
    ]

derive instance eqQuadrant :: Eq Quadrant
