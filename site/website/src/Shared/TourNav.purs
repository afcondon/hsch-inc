module Hylograph.Shared.TourNav
  ( renderHeader
  , renderBreadcrumb
  , allTourRoutes
  , getNextTour
  , getPrevTour
  , tourTitle
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Hylograph.RoutingDSL (routeToPath)
import Hylograph.Shared.SiteNav as SiteNav
import Hylograph.Website.Types (Route(..))

-- | All tour pages in order
allTourRoutes :: Array Route
allTourRoutes =
  [ TourScrolly
  , TourMotionScrollyHATS
  , TourSimpsons
  , ForcePlayground
  ]

-- | Get human-readable title for a tour page
tourTitle :: Route -> String
tourTitle = case _ of
  TourIndex -> "Tour"
  TourScrolly -> "From the Basics"
  TourMotionScrollyHATS -> "Motion & Animation"
  TourSimpsons -> "Simpson's Paradox"
  ForcePlayground -> "Force Explorer"
  other -> show other

-- | Get the next tour in the sequence
getNextTour :: Route -> Maybe Route
getNextTour currentRoute =
  case Array.findIndex (\r -> r == currentRoute) allTourRoutes of
    Nothing -> Nothing
    Just idx -> allTourRoutes Array.!! (idx + 1)

-- | Get the previous tour in the sequence
getPrevTour :: Route -> Maybe Route
getPrevTour currentRoute =
  case Array.findIndex (\r -> r == currentRoute) allTourRoutes of
    Nothing -> Nothing
    Just idx -> if idx > 0 then allTourRoutes Array.!! (idx - 1) else Nothing

-- | Render breadcrumb navigation: Tour > Current Page
renderBreadcrumb :: forall w i. Route -> HH.HTML w i
renderBreadcrumb currentRoute =
  HH.nav
    [ HP.classes [ HH.ClassName "breadcrumb" ]
    , HP.attr (HH.AttrName "aria-label") "Breadcrumb"
    ]
    [ HH.ol
        [ HP.classes [ HH.ClassName "breadcrumb__list" ] ]
        [ HH.li
            [ HP.classes [ HH.ClassName "breadcrumb__item" ] ]
            [ HH.a
                [ HP.href $ "#" <> routeToPath TourIndex
                , HP.classes [ HH.ClassName "breadcrumb__link" ]
                ]
                [ HH.text "Tour" ]
            ]
        , HH.li
            [ HP.classes [ HH.ClassName "breadcrumb__item", HH.ClassName "breadcrumb__item--current" ]
            , HP.attr (HH.AttrName "aria-current") "page"
            ]
            [ HH.span
                [ HP.classes [ HH.ClassName "breadcrumb__text" ] ]
                [ HH.text $ tourTitle currentRoute ]
            ]
        ]
    ]

-- | Render the header with site nav + breadcrumb
renderHeader :: forall w i. Route -> HH.HTML w i
renderHeader currentRoute =
  HH.div_
    [ SiteNav.render
        { logoSize: SiteNav.Normal
        , quadrant: SiteNav.NoQuadrant
        , prevNext: Just
            { prev: getPrevTour currentRoute
            , next: getNextTour currentRoute
            }
        , pageTitle: Nothing
        }
    , renderBreadcrumb currentRoute
    ]
