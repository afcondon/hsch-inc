module Component.Showcase.ShowcaseLuaEdge where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Hylograph.Shared.SiteNav as SiteNav

-- | Lua Edge showcase page state
type State = Unit

-- | Lua Edge showcase page actions
data Action = Initialize

-- | Lua Edge showcase page component
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
    [ HP.classes [ HH.ClassName "terminal-page" ] ]
    [ -- Site Navigation (minimal)
      SiteNav.render
        { logoSize: SiteNav.Normal
        , quadrant: SiteNav.NoQuadrant
        , prevNext: Nothing
        , pageTitle: Just "Edge Router"
        }

    -- Terminal container
    , HH.div
        [ HP.classes [ HH.ClassName "terminal-container" ] ]
        [ HH.div
            [ HP.classes [ HH.ClassName "terminal-screen" ] ]
            [ HH.div
                [ HP.classes [ HH.ClassName "terminal-header" ] ]
                [ HH.span_ [ HH.text "SCUPPERED LIGATURE v1.0" ]
                , HH.span [ HP.classes [ HH.ClassName "terminal-blink" ] ] [ HH.text "_" ]
                ]

            , HH.div
                [ HP.classes [ HH.ClassName "terminal-content" ] ]
                [ -- Boot sequence
                  terminalSection "SYSTEM BOOT" bootSequence

                -- What it does
                , terminalSection "MISSION BRIEF" missionBrief

                -- Architecture diagram
                , terminalSection "RUNTIME ARCHITECTURE" runtimeDiagram

                -- Build pipeline
                , terminalSection "BUILD PIPELINE" buildPipeline

                -- Route table
                , terminalSection "ROUTE TABLE" routeTable

                -- Tech stack
                , terminalSection "POLYGLOT BACKENDS" techStack

                -- Status
                , terminalSection "SYSTEM STATUS" systemStatus
                ]
            ]
        ]
    ]

-- | Render a terminal section with header
terminalSection :: forall w i. String -> String -> HH.HTML w i
terminalSection header content =
  HH.div
    [ HP.classes [ HH.ClassName "terminal-section" ] ]
    [ HH.div
        [ HP.classes [ HH.ClassName "terminal-section-header" ] ]
        [ HH.text $ "═══[ " <> header <> " ]═══════════════════════════════════════════════════" ]
    , HH.pre
        [ HP.classes [ HH.ClassName "terminal-pre" ] ]
        [ HH.text content ]
    ]

bootSequence :: String
bootSequence = """
  OpenResty/1.21.4 initializing...
  Loading lua_shared_dict: stats [10MB] .............. OK
  Loading lua_shared_dict: rate_limit [10MB] ......... OK
  Loading PureScript module: edge.lua ................ OK

  ┌─────────────────────────────────────────────────────────┐
  │  SCUPPERED LIGATURE - Edge Router                       │
  │                                                         │
  │  Status: OPERATIONAL                                    │
  │  Upstreams: 14 backends configured                      │
  │  Rate Limit: 50 req/sec (100 burst)                     │
  └─────────────────────────────────────────────────────────┘
"""

missionBrief :: String
missionBrief = """
  Every HTTP request to this domain passes through PureScript code
  compiled to Lua, running inside nginx's OpenResty module.

  This edge layer routes requests to backends written in:

    • Erlang/OTP    (Tidal live coding editor)
    • Python/Flask  (Embedding & Grid explorers)
    • Node.js       (Code analysis tools)
    • Rust/WASM     (Force simulation demo)
    • JavaScript    (Halogen frontends)

  The router is invisible. You're using it right now.
"""

runtimeDiagram :: String
runtimeDiagram = """
                           ┌─────────────────────────────────┐
                           │         SCUPPERED LIGATURE      │
                           │      (nginx + OpenResty + Lua)  │
                           └─────────────────────────────────┘
                                          │
     HTTP Request                         │
     ─────────────>          ┌────────────┴────────────┐
                             │                         │
                             │   access_by_lua_block   │
                             │   ───────────────────   │
                             │                         │
                             │   1. Extract path       │
                             │   2. Match route        │
                             │   3. Check rate limit   │
                             │   4. Rewrite URI        │
                             │   5. Set upstream       │
                             │                         │
                             └────────────┬────────────┘
                                          │
              ┌───────────────────────────┼───────────────────────────┐
              │               │           │           │               │
              ▼               ▼           ▼           ▼               ▼
        ┌──────────┐   ┌──────────┐ ┌──────────┐ ┌──────────┐  ┌──────────┐
        │  ERLANG  │   │  PYTHON  │ │  PYTHON  │ │  NODE.JS │  │   WASM   │
        │  :8083   │   │  :5081   │ │  :5082   │ │  :3001   │  │  static  │
        │          │   │          │ │          │ │          │  │          │
        │  Tidal   │   │   EE     │ │   GE     │ │  Code    │  │  Force   │
        │  Editor  │   │  API     │ │  API     │ │  API     │  │  Demo    │
        └──────────┘   └──────────┘ └──────────┘ └──────────┘  └──────────┘
"""

buildPipeline :: String
buildPipeline = """
  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
  │   PureScript    │     │    CoreFn IR    │     │    Lua Code     │
  │                 │────>│                 │────>│                 │
  │  src/*.purs     │     │   output/       │     │  dist/edge.lua  │
  └─────────────────┘     └─────────────────┘     └─────────────────┘
          │                       │                       │
          │   spago build         │   pslua              │
          │                       │                       │
          ▼                       ▼                       ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │                         Lua FFI Layer                           │
  │  ─────────────────────────────────────────────────────────────  │
  │                                                                 │
  │  lua-ffi/Main.lua:                                              │
  │    • getRequestPath()    -- ngx.var.uri                         │
  │    • getClientIP()       -- ngx.var.remote_addr                 │
  │    • setUpstream()       -- ngx.var.edge_upstream = ...         │
  │    • checkRateLimit()    -- ngx.shared.rate_limit               │
  │    • recordMetrics()     -- ngx.shared.stats                    │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
          │
          │   docker build
          ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │                    OpenResty Docker Image                       │
  │  ─────────────────────────────────────────────────────────────  │
  │  FROM openresty/openresty:alpine                                │
  │  COPY dist/edge.lua /usr/local/openresty/lualib/               │
  │  COPY nginx.conf /etc/nginx/conf.d/                            │
  └─────────────────────────────────────────────────────────────────┘
"""

routeTable :: String
routeTable = """
  ┌────────────────────┬─────────────────────┬───────────────────────┐
  │  PATH PATTERN      │  UPSTREAM           │  DESTINATION          │
  ├────────────────────┼─────────────────────┼───────────────────────┤
  │  /                 │  Website            │  Halogen SPA          │
  │  /tidal/*          │  TidalFrontend      │  Static JS            │
  │  /tidal/api/*      │  TidalBackend       │  Erlang :8083         │
  │  /ee/*             │  EmbeddingFrontend  │  Halogen SPA          │
  │  /ee/api/*         │  EmbeddingBackend   │  Python :5081         │
  │  /ge/*             │  GridFrontend       │  Halogen SPA          │
  │  /ge/api/*         │  GridBackend        │  Python :5082         │
  │  /sankey/*         │  SankeyFrontend     │  Static JS            │
  │  /code/*           │  CodeFrontend       │  Halogen SPA          │
  │  /code/api/*       │  CodeBackend        │  Node.js :3001        │
  │  /wasm/*           │  WasmDemo           │  Static WASM          │
  │  /psd3/*           │  LibrarySites       │  Static docs          │
  │  /edge/metrics     │  (internal)         │  JSON metrics         │
  │  /edge/health      │  (internal)         │  Health check         │
  └────────────────────┴─────────────────────┴───────────────────────┘

  Route matching: PureScript pattern matching, compiled to Lua
  URI rewriting:  /ee/api/embed → /api/embed (strips prefix)
"""

techStack :: String
techStack = """
  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │   PureScript ──┬──> JavaScript ──> Browser (Halogen SPAs)       │
  │                │                                                │
  │                ├──> Lua ────────> nginx (THIS EDGE ROUTER)      │
  │                │                                                │
  │                ├──> Erlang ─────> BEAM VM (Tidal backend)       │
  │                │                                                │
  │                ├──> Python ─────> Flask (EE/GE backends)        │
  │                │                                                │
  │                └──> (Rust FFI) ──> WASM (Force demo)            │
  │                                                                 │
  │   One language. Five compilation targets. Zero runtime errors.  │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
"""

systemStatus :: String
systemStatus = """
  Module              Status      Notes
  ─────────────────────────────────────────────────────────────────
  Edge.Router         [ACTIVE]    Route matching operational
  Edge.RateLimit      [ACTIVE]    50 req/sec, 100 burst
  Edge.Metrics        [ACTIVE]    Request counting enabled
  Edge.Health         [ACTIVE]    /edge/health responding

  Compilation Target  Status      Compiler
  ─────────────────────────────────────────────────────────────────
  Lua (OpenResty)     [OK]        pslua v0.17.0
  JavaScript          [OK]        purs v0.15.x (also compiles)

  ═══════════════════════════════════════════════════════════════════

            Source: showcases/scuppered-ligature/

  ═══════════════════════════════════════════════════════════════════
"""

handleAction :: forall o. Action -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
  Initialize -> pure unit
