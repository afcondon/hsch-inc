module Hylograph.Home where -- stays at top level

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Halogen.HTML.Core (AttrName(..))
import Hylograph.RoutingDSL (routeToPath)
import Hylograph.Website.Types (Route(..))
import Hylograph.Shared.Footer as Footer
import Component.Hero.ConceptGraph as ConceptGraph
import Type.Proxy (Proxy(..))

-- | Home page state
type State = Unit

-- | Home page actions
data Action = Initialize

-- | Child component slots
type Slots = ( conceptGraph :: forall q. H.Slot q Void Unit )

_conceptGraph :: Proxy "conceptGraph"
_conceptGraph = Proxy

-- | Home page component
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
    [ HP.classes [ HH.ClassName "home-page", HH.ClassName "home-page--no-nav" ] ]
    [ -- Hero section - revolutionary poster layout
      HH.section
        [ HP.id "hero"
        , HP.classes [ HH.ClassName "home-hero", HH.ClassName "home-hero--poster" ]
        ]
        [ -- Left column: POLYGLOT acrostic (1/3)
          HH.div
            [ HP.classes [ HH.ClassName "home-hero__acrostic-col" ] ]
            [ HH.div
                [ HP.classes [ HH.ClassName "home-acrostic" ] ]
                [ renderAcrosticLine "" "p" "urescript" "purescript" true
                , renderAcrosticLine "n" "o" "de" "nodejs" false
                , renderAcrosticLine "er" "l" "ang" "erlang" false
                , renderAcrosticLine "p" "y" "thon" "python" false
                , renderAcrosticLine "" "g" "raphical" "js" true
                , renderAcrosticLine "" "l" "ua" "lua" false
                , renderAcrosticLine "expl" "o" "ration" "wasm" true
                , renderAcrosticLine "rus" "t" "" "wasm" false
                ]
            ]
        -- Right column: Concept graph (2/3)
        , HH.div
            [ HP.classes [ HH.ClassName "home-hero__image-col" ] ]
            [ HH.slot _conceptGraph unit ConceptGraph.component unit absurd
            ]
        ]

    -- Showcases section - alternating spine layout
    , HH.section
        [ HP.id "showcases"
        , HP.classes [ HH.ClassName "home-showcases" ]
        ]
        [ HH.div
            [ HP.classes [ HH.ClassName "home-showcases__spine-container" ] ]
            [ -- ===========================================
              -- LIBRARIES (linked directly to demos)
              -- ===========================================
              renderLibrarySpineItem
                "hylograph-selection"
                "Type-safe D3 selections with a declarative AST"
                "assets/screenshots/hylograph-explorer.jpg"
                "/psd3/selection/demo/"
            , renderLibrarySpineItem
                "hylograph-simulation"
                "Force simulation with D3 or WASM backend"
                "assets/screenshots/force-playground.jpeg"
                ("#" <> routeToPath ForcePlayground)
            , renderLibrarySpineItem
                "hylograph-layout"
                "Pure PureScript hierarchical layouts"
                "assets/screenshots/lib-layout.jpeg"
                "/psd3/layout/demo/"
            , renderLibrarySpineItem
                "hylograph-graph"
                "Graph algorithms for visualization"
                "assets/screenshots/lib-graph.jpeg"
                "/psd3/graph/demo/"
            , renderLibrarySpineItem
                "hylograph-music"
                "Data sonification and live coding"
                "assets/screenshots/lib-music.jpeg"
                "/psd3/music/demo/"

            -- ===========================================
            -- SHOWCASES
            -- ===========================================
            -- Algorave - Erlang/Purerl
            , renderSpineItem
                "Algorave / Tidal"
                "Live coding music with Purerl"
                "erlang"
                "assets/screenshots/algorave.png"
                (Just "/tidal")
            -- Scientific Python - PurePy
            , renderSpineItem
                "Scientific Python"
                "UMAP, NumPy, NetworkX via PurePy"
                "python"
                "assets/screenshots/embedding-explorer.png"
                (Just "/ge")
            -- Code Explorer - Node.js
            , renderSpineItem
                "Code Explorer"
                "Interactive AST visualization"
                "nodejs"
                "assets/screenshots/code-explorer.jpg"
                (Just "/code")
            -- Sankey Editor - JavaScript
            , renderSpineItem
                "Sankey Editor"
                "Functional reactive data flows"
                "js"
                "assets/screenshots/sankey-editor.png"
                (Just "/sankey")
            -- Emptier Coinage - Optics visualization
            , renderSpineItem
                "Optic Menagerie"
                "Interactive optics on heterogeneous trees"
                "purescript"
                "assets/screenshots/emptier-coinage.jpeg"
                (Just "/optics")
            -- Morphism Zoo - PureScript Halogen
            , renderSpineItem
                "Morphism Zoo"
                "A children's book of recursion schemes"
                "purescript"
                "assets/screenshots/morphism-zoo.jpeg"
                (Just "/zoo")
            -- Simpson's Paradox - Statistical Visualization
            , renderSpineItem
                "Simpson's Paradox"
                "Interactive statistical paradox visualization"
                "js"
                "assets/screenshots/simpsons-paradox.jpeg"
                (Just $ "#" <> routeToPath SimpsonsV2)
            -- Site Explorer - Halogen route analysis
            , renderSpineItem
                "Site Explorer"
                "AST-driven Halogen route discovery and dead code detection"
                "nodejs"
                "assets/screenshots/site-explorer.jpg"
                (Just "/spider/")
            -- Lua Edge Router - architecture page (last)
            , renderSpineItem
                "Lua Edge Router"
                "The invisible showcase routing this site"
                "lua"
                "assets/screenshots/scuppered-ligature.jpeg"
                (Just $ "#" <> routeToPath ShowcaseLuaEdge)
            ]
        ]

    -- Link to Hylograph documentation with Ana/Cata twins
    , HH.section
        [ HP.id "hylograph"
        , HP.classes [ HH.ClassName "home-hylograph-link" ]
        ]
        [ HH.div
            [ HP.classes [ HH.ClassName "hylograph-attribution" ] ]
            [ HH.img
                [ HP.src "assets/hylo-twins.png"
                , HP.alt "Ana and Cata, the Hylograph twins"
                , HP.classes [ HH.ClassName "hylograph-twins" ]
                ]
            , HH.p
                [ HP.classes [ HH.ClassName "hylograph-message" ] ]
                [ HH.text "Almost all of these demos are made possible through the "
                , HH.a
                    [ HP.href "https://hylograph.net"
                    , HP.classes [ HH.ClassName "hylograph-link" ]
                    ]
                    [ HH.text "purescript-hylograph" ]
                , HH.text " library suite."
                ]
            ]
        ]

    -- Footer
    , Footer.render
    ]

-- | Render a documentation category box with bookmark (internal route)
renderDocBox :: forall w i. String -> String -> String -> HH.HTML w i
renderDocBox title description path =
  HH.a
    [ HP.href $ "#" <> path
    , HP.classes [ HH.ClassName "home-doc-box" ]
    ]
    [ HH.div
        [ HP.classes [ HH.ClassName "home-doc-box__image-container" ] ]
        [ HH.img
            [ HP.src $ getBookmarkImage title
            , HP.alt ""
            , HP.classes [ HH.ClassName "home-doc-box__image" ]
            ]
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "home-doc-box__content" ] ]
        [ HH.h3
            [ HP.classes [ HH.ClassName "home-doc-box-title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "home-doc-box-description" ] ]
            [ HH.text description ]
        ]
    ]

-- | Render a documentation category box with bookmark (external URL)
renderDocBoxExternal :: forall w i. String -> String -> String -> HH.HTML w i
renderDocBoxExternal title description url =
  HH.a
    [ HP.href url
    , HP.classes [ HH.ClassName "home-doc-box" ]
    ]
    [ HH.div
        [ HP.classes [ HH.ClassName "home-doc-box__image-container" ] ]
        [ HH.img
            [ HP.src $ getBookmarkImage title
            , HP.alt ""
            , HP.classes [ HH.ClassName "home-doc-box__image" ]
            ]
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "home-doc-box__content" ] ]
        [ HH.h3
            [ HP.classes [ HH.ClassName "home-doc-box-title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "home-doc-box-description" ] ]
            [ HH.text description ]
        ]
    ]

-- | Render a showcase box with typography, backend badge, and hover screenshot (internal link)
renderShowcaseBox :: forall w i. String -> String -> String -> String -> String -> HH.HTML w i
renderShowcaseBox title subtitle backend screenshotPath path =
  HH.a
    [ HP.href $ "#" <> path
    , HP.classes [ HH.ClassName "home-showcase-box" ]
    ]
    [ -- Badge indicating backend technology
      HH.span
        [ HP.classes [ HH.ClassName "home-showcase-box__badge", HH.ClassName $ "home-showcase-box__badge--" <> backend ] ]
        [ HH.text backend ]
    -- Text layer (visible by default, fades on hover)
    , HH.div
        [ HP.classes [ HH.ClassName "home-showcase-box__text" ] ]
        [ HH.h3
            [ HP.classes [ HH.ClassName "home-showcase-box__title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "home-showcase-box__subtitle" ] ]
            [ HH.text subtitle ]
        ]
    -- Screenshot layer (revealed on hover)
    , HH.div
        [ HP.classes [ HH.ClassName "home-showcase-box__screenshot" ] ]
        [ HH.img
            [ HP.src screenshotPath
            , HP.alt $ title <> " screenshot"
            ]
        ]
    ]

-- | Render a showcase box for external links (opens in new tab)
renderShowcaseBoxExternal :: forall w i. String -> String -> String -> String -> String -> HH.HTML w i
renderShowcaseBoxExternal title subtitle backend screenshotPath url =
  HH.a
    [ HP.href url
    , HP.attr (AttrName "target") "_blank"
    , HP.classes [ HH.ClassName "home-showcase-box" ]
    ]
    [ -- Badge indicating backend technology
      HH.span
        [ HP.classes [ HH.ClassName "home-showcase-box__badge", HH.ClassName $ "home-showcase-box__badge--" <> backend ] ]
        [ HH.text backend ]
    -- Text layer (visible by default, fades on hover)
    , HH.div
        [ HP.classes [ HH.ClassName "home-showcase-box__text" ] ]
        [ HH.h3
            [ HP.classes [ HH.ClassName "home-showcase-box__title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "home-showcase-box__subtitle" ] ]
            [ HH.text subtitle ]
        ]
    -- Screenshot layer (revealed on hover)
    , HH.div
        [ HP.classes [ HH.ClassName "home-showcase-box__screenshot" ] ]
        [ HH.img
            [ HP.src screenshotPath
            , HP.alt $ title <> " screenshot"
            ]
        ]
    ]

-- | Render a library spine item (with "library" badge)
renderLibrarySpineItem :: forall w i. String -> String -> String -> String -> HH.HTML w i
renderLibrarySpineItem title subtitle screenshotPath href =
  HH.a
    [ HP.href href
    , HP.classes [ HH.ClassName "spine-item" ]
    ]
    [ -- Card side
      HH.div
        [ HP.classes [ HH.ClassName "spine-item__card" ] ]
        [ HH.span
            [ HP.classes [ HH.ClassName "spine-item__badge", HH.ClassName "spine-item__badge--library" ] ]
            [ HH.text "library" ]
        , HH.h3
            [ HP.classes [ HH.ClassName "spine-item__title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "spine-item__subtitle" ] ]
            [ HH.text subtitle ]
        ]
    -- Screenshot side
    , HH.div
        [ HP.classes [ HH.ClassName "spine-item__screenshot" ] ]
        [ HH.img
            [ HP.src screenshotPath
            , HP.alt $ title <> " screenshot"
            ]
        ]
    ]

-- | Render a showcase spine item (with language badge + "showcase" badge)
renderShowcaseSpineItem :: forall w i. String -> String -> String -> String -> Maybe String -> HH.HTML w i
renderShowcaseSpineItem title subtitle backend screenshotPath mHref =
  wrapper
    [ -- Card side
      HH.div
        [ HP.classes [ HH.ClassName "spine-item__card" ] ]
        [ HH.div
            [ HP.classes [ HH.ClassName "spine-item__badges" ] ]
            [ HH.span
                [ HP.classes [ HH.ClassName "spine-item__badge", HH.ClassName $ "spine-item__badge--" <> backend ] ]
                [ HH.text backend ]
            , HH.span
                [ HP.classes [ HH.ClassName "spine-item__badge", HH.ClassName "spine-item__badge--showcase" ] ]
                [ HH.text "showcase" ]
            ]
        , HH.h3
            [ HP.classes [ HH.ClassName "spine-item__title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "spine-item__subtitle" ] ]
            [ HH.text subtitle ]
        ]
    -- Screenshot side
    , HH.div
        [ HP.classes [ HH.ClassName "spine-item__screenshot" ] ]
        [ HH.img
            [ HP.src screenshotPath
            , HP.alt $ title <> " screenshot"
            ]
        ]
    ]
  where
  wrapper = case mHref of
    Just href -> HH.a
      [ HP.href href
      , HP.classes [ HH.ClassName "spine-item" ]
      ]
    Nothing -> HH.div
      [ HP.classes [ HH.ClassName "spine-item" ]
      ]

-- | Render a spine item (alternating card | screenshot layout via CSS)
-- | Kept for backwards compatibility
renderSpineItem :: forall w i. String -> String -> String -> String -> Maybe String -> HH.HTML w i
renderSpineItem = renderShowcaseSpineItem

-- | Render the "Take the tour" CTA box
renderTourBox :: forall w i. HH.HTML w i
renderTourBox =
  HH.a
    [ HP.href $ "#" <> routeToPath TourIndex
    , HP.classes [ HH.ClassName "home-tour-box" ]
    ]
    [ HH.div
        [ HP.classes [ HH.ClassName "home-tour-box__content" ] ]
        [ HH.h3
            [ HP.classes [ HH.ClassName "home-tour-box__title" ] ]
            [ HH.text "Take the Tour" ]
        , HH.p
            [ HP.classes [ HH.ClassName "home-tour-box__subtitle" ] ]
            [ HH.text "Progressive introduction to PSD3 capabilities" ]
        ]
    ]

-- | Get bookmark image path based on title
getBookmarkImage :: String -> String
getBookmarkImage = case _ of
  "Getting Started" -> "assets/bookmark-images/getting-started.jpeg"
  "How-to Guides" -> "assets/bookmark-images/howto.jpeg"
  "API Reference" -> "assets/bookmark-images/reference.jpeg"
  "Understanding" -> "assets/bookmark-images/understanding.jpeg"
  _ -> "assets/bookmark-images/howto.jpeg"

-- | Render a tutorial link card
renderTutorialLink :: forall w i. String -> String -> String -> HH.HTML w i
renderTutorialLink title description path =
  HH.a
    [ HP.href $ "#" <> path
    , HP.classes [ HH.ClassName "home-tutorial-card" ]
    ]
    [ HH.h3
        [ HP.classes [ HH.ClassName "home-tutorial-card-title" ] ]
        [ HH.text title ]
    , HH.p
        [ HP.classes [ HH.ClassName "home-tutorial-card-description" ] ]
        [ HH.text description ]
    ]

-- | Render a category section with examples
renderExampleCategory :: forall w i. String -> Array (HH.HTML w i) -> HH.HTML w i
renderExampleCategory categoryName examples =
  HH.div
    [ HP.classes [ HH.ClassName "home-gallery-category" ] ]
    [ HH.h3
        [ HP.classes [ HH.ClassName "home-gallery-category-title" ] ]
        [ HH.text categoryName ]
    , HH.div
        [ HP.classes [ HH.ClassName "home-examples-grid" ] ]
        examples
    ]

-- | Render an example card with thumbnail
renderExampleCard :: forall w i. String -> String -> String -> Route -> HH.HTML w i
renderExampleCard title description thumbnail route =
  HH.a
    [ HP.href $ "#" <> routeToPath route
    , HP.classes [ HH.ClassName "home-example-card" ]
    ]
    [ HH.div
        [ HP.classes [ HH.ClassName "home-example-thumbnail" ] ]
        [ HH.img
            [ HP.src thumbnail
            , HP.alt title
            , HP.classes [ HH.ClassName "home-example-thumbnail-img" ]
            ]
        ]
    , HH.div
        [ HP.classes [ HH.ClassName "home-example-content" ] ]
        [ HH.h3
            [ HP.classes [ HH.ClassName "home-example-title" ] ]
            [ HH.text title ]
        , HH.p
            [ HP.classes [ HH.ClassName "home-example-description" ] ]
            [ HH.text description ]
        ]
    ]

-- | Render a line of the POLYGLOT acrostic
-- | prefix: letters before the highlighted letter
-- | letter: the POLYGLOT letter (highlighted)
-- | suffix: letters after the highlighted letter
-- | backend: data attribute for hover linking
-- | isPrimary: true for PureScript words (red), false for backend words (gray)
renderAcrosticLine :: forall w i. String -> String -> String -> String -> Boolean -> HH.HTML w i
renderAcrosticLine prefix letter suffix backend isPrimary =
  HH.div
    [ HP.classes [ HH.ClassName "acrostic-word" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "acrostic-lhs", HH.ClassName wordClass ] ]
        [ HH.text $ if prefix == "" then "\x00A0" else prefix ]  -- nbsp if empty
    , HH.div
        [ HP.classes [ HH.ClassName "acrostic-letter" ]
        , HP.attr (AttrName "data-backend") backend
        ]
        [ HH.text letter ]
    , HH.div
        [ HP.classes [ HH.ClassName "acrostic-rhs", HH.ClassName wordClass ] ]
        [ HH.text $ if suffix == "" then "\x00A0" else suffix ]  -- nbsp if empty
    ]
  where
  wordClass = if isPrimary then "acrostic-word--primary" else "acrostic-word--backend"

handleAction :: forall o. Action -> H.HalogenM State Action Slots o Aff Unit
handleAction = case _ of
  Initialize -> pure unit
