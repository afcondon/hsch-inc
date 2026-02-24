module Hylograph.LibShell where

import Prelude

import Halogen.HTML as HH
import Halogen.HTML.Properties as HP

-- | Configuration for a library documentation site
type LibConfig =
  { name :: String           -- e.g. "psd3-selection"
  , title :: String          -- e.g. "Selection"
  , tagline :: String        -- e.g. "D3-style data binding for PureScript"
  , version :: String        -- e.g. "0.1.0"
  , github :: String         -- e.g. "afcondon/purescript-psd3-selection"
  , docsPath :: String       -- e.g. "/docs/selection" or "#" for no docs yet
  , polyglotUrl :: String    -- Base URL for polyglot site, e.g. "https://polyglot.purescri.pt"
  }

-- | Render the full shell with header, content, and footer
shell :: forall w i. LibConfig -> Array (HH.HTML w i) -> HH.HTML w i
shell config content =
  HH.div
    [ HP.classes [ HH.ClassName "lib-shell" ] ]
    [ header config
    , HH.main
        [ HP.classes [ HH.ClassName "lib-shell__main" ] ]
        content
    , footer config
    ]

-- | Render just the header
header :: forall w i. LibConfig -> HH.HTML w i
header config =
  HH.header
    [ HP.classes [ HH.ClassName "lib-shell__header" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "lib-shell__header-inner" ] ]
        [ -- Logo linking back to Polyglot PureScript
          HH.a
            [ HP.href config.polyglotUrl
            , HP.classes [ HH.ClassName "lib-shell__logo" ]
            ]
            [ HH.span
                [ HP.classes [ HH.ClassName "lib-shell__logo-text" ] ]
                [ HH.text "PSD3" ]
            ]
        -- Library name
        , HH.div
            [ HP.classes [ HH.ClassName "lib-shell__title-group" ] ]
            [ HH.h1
                [ HP.classes [ HH.ClassName "lib-shell__title" ] ]
                [ HH.text config.title ]
            , HH.span
                [ HP.classes [ HH.ClassName "lib-shell__version" ] ]
                [ HH.text $ "v" <> config.version ]
            ]
        -- Navigation
        , HH.nav
            [ HP.classes [ HH.ClassName "lib-shell__nav" ] ]
            [ navLink "Overview" "#"
            , navLink "API Docs" config.docsPath
            , navLink "GitHub" $ "https://github.com/" <> config.github
            ]
        ]
    ]

-- | Render just the footer
footer :: forall w i. LibConfig -> HH.HTML w i
footer config =
  HH.footer
    [ HP.classes [ HH.ClassName "lib-shell__footer" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "lib-shell__footer-inner" ] ]
        [ HH.span_
            [ HH.text $ config.name <> " is part of "
            , HH.a
                [ HP.href config.polyglotUrl ]
                [ HH.text "Polyglot PureScript" ]
            ]
        , HH.span_
            [ HH.text " · "
            , HH.a
                [ HP.href $ "https://github.com/" <> config.github ]
                [ HH.text "Source on GitHub" ]
            ]
        ]
    ]

-- | Helper for navigation links
navLink :: forall w i. String -> String -> HH.HTML w i
navLink label href =
  HH.a
    [ HP.href href
    , HP.classes [ HH.ClassName "lib-shell__nav-link" ]
    ]
    [ HH.text label ]

-- | Render a hero section with tagline and install command (simple version)
hero :: forall w i. LibConfig -> HH.HTML w i
hero config =
  HH.section
    [ HP.classes [ HH.ClassName "lib-hero" ] ]
    [ HH.h2
        [ HP.classes [ HH.ClassName "lib-hero__tagline" ] ]
        [ HH.text config.tagline ]
    , HH.div
        [ HP.classes [ HH.ClassName "lib-hero__install" ] ]
        [ HH.code_
            [ HH.text $ "spago install " <> config.name ]
        ]
    ]

-- | Hero section with visualization: 1/3 text | 2/3 viz
heroWithViz :: forall w i. LibConfig -> Array (HH.HTML w i) -> HH.HTML w i -> HH.HTML w i
heroWithViz config textContent vizContent =
  HH.section
    [ HP.classes [ HH.ClassName "lib-hero-viz" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "lib-hero-viz__text" ] ]
        ( [ HH.h2
              [ HP.classes [ HH.ClassName "lib-hero-viz__tagline" ] ]
              [ HH.text config.tagline ]
          , HH.div
              [ HP.classes [ HH.ClassName "lib-hero-viz__install" ] ]
              [ HH.code_ [ HH.text $ "spago install " <> config.name ] ]
          ] <> textContent
        )
    , HH.div
        [ HP.classes [ HH.ClassName "lib-hero-viz__viz" ] ]
        [ vizContent ]
    ]

-- | Embed an iframe (for showcasing demos from main site)
embed :: forall w i. String -> String -> HH.HTML w i
embed src title =
  HH.iframe
    [ HP.src src
    , HP.title title
    , HP.classes [ HH.ClassName "lib-embed" ]
    ]

-- | Screenshot that links to a demo app
screenshotLink :: forall w i. String -> String -> String -> HH.HTML w i
screenshotLink imgSrc demoUrl altText =
  HH.a
    [ HP.href demoUrl
    , HP.classes [ HH.ClassName "lib-screenshot-link" ]
    , HP.target "_blank"
    ]
    [ HH.img
        [ HP.src imgSrc
        , HP.alt altText
        , HP.classes [ HH.ClassName "lib-screenshot-link__img" ]
        ]
    ]

-- | Elaboration section with key points
elaboration :: forall w i. Array { heading :: String, content :: Array (HH.HTML w i) } -> HH.HTML w i
elaboration sections =
  HH.section
    [ HP.classes [ HH.ClassName "lib-elaboration" ] ]
    (map renderSection sections)
  where
  renderSection sect =
    HH.div
      [ HP.classes [ HH.ClassName "lib-elaboration__section" ] ]
      ( [ HH.h3
            [ HP.classes [ HH.ClassName "lib-elaboration__heading" ] ]
            [ HH.text sect.heading ]
        ] <> sect.content
      )

-- | Simple paragraph for elaboration content
para :: forall w i. String -> HH.HTML w i
para text = HH.p [ HP.classes [ HH.ClassName "lib-elaboration__para" ] ] [ HH.text text ]

-- | Emphasized text
em :: forall w i. String -> HH.HTML w i
em text = HH.em_ [ HH.text text ]

-- | Strong text
strong :: forall w i. String -> HH.HTML w i
strong text = HH.strong_ [ HH.text text ]

-- | Render a features section
features :: forall w i. Array { title :: String, description :: String } -> HH.HTML w i
features items =
  HH.section
    [ HP.classes [ HH.ClassName "lib-features" ] ]
    [ HH.h3
        [ HP.classes [ HH.ClassName "lib-features__heading" ] ]
        [ HH.text "Features" ]
    , HH.ul
        [ HP.classes [ HH.ClassName "lib-features__list" ] ]
        (map renderFeature items)
    ]
  where
  renderFeature item =
    HH.li
      [ HP.classes [ HH.ClassName "lib-features__item" ] ]
      [ HH.strong_ [ HH.text item.title ]
      , HH.text $ " — " <> item.description
      ]

-- | Render a code example section
codeExample :: forall w i. String -> String -> HH.HTML w i
codeExample title code =
  HH.section
    [ HP.classes [ HH.ClassName "lib-example" ] ]
    [ HH.h3
        [ HP.classes [ HH.ClassName "lib-example__heading" ] ]
        [ HH.text title ]
    , HH.pre
        [ HP.classes [ HH.ClassName "lib-example__code" ] ]
        [ HH.code_ [ HH.text code ] ]
    ]
