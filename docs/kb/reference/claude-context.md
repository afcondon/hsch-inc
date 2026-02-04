# What Claude Needs to Know: Hylograph Ecosystem Reference

This document provides essential context about the Hylograph suite of libraries, tools, and showcase applications. It covers all repositories under `/Users/afc/work/afc-work/PSD3-Repos/` plus the alternative compiler backends (Erlang and Python).

> **Name Change**: The project was renamed from "PSD3" to "Hylograph" to reflect its core abstraction: HATS (Hylomorphic Abstract Tree Syntax). The visualization approach is fundamentally a hylomorphism—an unfold (data → tree) composed with a fold (tree → DOM).

## Table of Contents
1. [Design Philosophy](#design-philosophy)
2. [Ecosystem Overview](#ecosystem-overview)
3. [Core Hylograph Libraries](#core-hylograph-libraries)
4. [Site Infrastructure](#site-infrastructure)
5. [Showcase Applications](#showcase-applications)
6. [Full Applications](#full-applications)
7. [Alternative Backends](#alternative-backends)
8. [Build Systems](#build-systems)
9. [FFI Patterns](#ffi-patterns)
10. [Knowledge Base & Claude Skills](#knowledge-base--claude-skills)
11. [Common Tasks Quick Reference](#common-tasks-quick-reference)

---

## Design Philosophy

### Declarative Over Imperative

There is a strong emphasis on **declarative programming styles** throughout this ecosystem, using ASTs interpreted by Finally Tagless interpreters:

- **Hylograph takes control from D3** - We don't write imperative D3 code that mutates the DOM directly
- **D3 as calculation engine only** - We use D3's mathematical algorithms (force simulation engine) but manage state and rendering declaratively through PureScript
- **Data flows down, events flow up** - Visualizations are functions of data, not sequences of mutations

### HATS: Hylomorphic Abstract Tree Syntax

The core abstraction is **HATS** - a declarative AST for describing visualization trees. The name captures the insight that visualization IS fundamentally a hylomorphism:

- **Ana** (unfold): data → visualization tree
- **Cata** (fold): tree → DOM operations
- **Hylo** (fused): data → DOM with virtual intermediate tree

HATS enables multiple interpreters from a single specification: D3 rendering, English descriptions, Mermaid diagrams, accessibility trees.

### Prefer Public Libraries

We strive to **use public PureScript libraries from the current Spago package set** rather than reinventing. Before implementing functionality:

1. Check if it exists in the registry
2. Use well-maintained community packages
3. Only build custom solutions when the domain is truly novel

### Code Quality Standards

Everything in this ecosystem is either:

- **Library code** - Must be principled, idiomatic PureScript because it's a library that others will depend on
- **Demo code** - Must be principled, idiomatic PureScript because it's meant to be *read* as well as run

**There are no "quick hacks" here.** Code should serve as documentation of best practices.

---

## Ecosystem Overview

### What is Hylograph?

Hylograph (formerly PSD3) is a **type-safe data visualization ecosystem** that provides D3-style visualizations with PureScript's strong type system. Unlike typical D3.js wrappers, Hylograph implements layout algorithms in pure PureScript and provides a layered architecture from data structures to DOM rendering. Several showcase applications make deep use of other ecosystems (Tidal, Erlang, Excel, Python, Node).

### Architecture Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    SHOWCASE APPLICATIONS                        │
│  Code Explorer | Hypo-Punter | Sankey Editor | Tidal | Zoo     │
├─────────────────────────────────────────────────────────────────┤
│                    FRAMEWORK INTEGRATIONS                       │
│         hylograph-simulation-halogen | site/website (Halogen)   │
├─────────────────────────────────────────────────────────────────┤
│                    DOMAIN LAYER                                 │
│                  hylograph-music | hylograph-simulation         │
├─────────────────────────────────────────────────────────────────┤
│                    CORE LAYER                                   │
│             hylograph-selection (DOM + HATS AST)                │
├─────────────────────────────────────────────────────────────────┤
│                    COMPUTATION LAYER                            │
│                 hylograph-layout | hylograph-graph              │
└─────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
/Users/afc/work/afc-work/PSD3-Repos/
├── visualisation libraries/        # Core publishable Hylograph libraries
│   ├── purescript-hylograph-canvas/       # Canvas rendering
│   ├── purescript-hylograph-d3-kernel/    # D3 core bindings
│   ├── purescript-hylograph-graph/        # Graph data structures
│   ├── purescript-hylograph-layout/       # Layout algorithms
│   ├── purescript-hylograph-music/        # Audio/sonification
│   ├── purescript-hylograph-optics/       # Lens utilities
│   ├── purescript-hylograph-selection/    # D3-style DOM selection + HATS
│   ├── purescript-hylograph-simulation/   # Force-directed simulation
│   ├── purescript-hylograph-simulation-core/  # Simulation core
│   ├── purescript-hylograph-simulation-halogen/  # Halogen bindings
│   ├── purescript-hylograph-transitions/  # Animation transitions
│   └── purescript-hylograph-wasm-kernel/  # WASM acceleration
│
├── site/                           # Demo infrastructure
│   ├── website/                    # Halogen demo site
│   ├── dashboard/                  # Dev dashboard (Node.js)
│   ├── react-proof/                # React integration proof
│   ├── showcase-shell/             # Reusable Halogen demo shell
│   ├── styling/                    # psd3.css house style
│   ├── docs/                       # Antora documentation server
│   └── tests/                      # Build prerequisite tests
│       ├── purerl-test/            # Test Erlang backend
│       ├── purepy-test/            # Test Python backend
│       └── wasm-test/              # Test Rust WASM toolchain
│
├── showcases/                      # Showcase applications
│   ├── allergy-outlay/             # Gallery Outlays (image grid viz)
│   ├── corrode-expel/              # Code Explorer (Node.js backend)
│   ├── emptier-coinage/            # Emptier Coinage (metrics viz)
│   ├── graph-algos/                # Graph algorithms demo
│   ├── halogen-spider/             # Site Explorer (route analysis)
│   ├── hylograph-app/              # Hylograph main app
│   ├── hylograph-guide/            # Interactive guide
│   ├── hypo-punter/                # PurePy demos (EE + GE)
│   ├── psd3-arid-keystone/         # Sankey diagram editor
│   ├── psd3-lorenz-attractor/      # Lorenz attractor viz
│   ├── psd3-prim-zoo-mosh/         # Recursion schemes zoo
│   ├── psd3-tilted-radio/          # Tidal/Algorave
│   ├── psd3-timber-lieder/         # Timber Lieder (music viz)
│   ├── psd3-topics/                # Topic modeling viz
│   ├── purescript-makefile-parser/ # Makefile parsing library
│   ├── scuppered-ligature/         # Edge layer (PureScript → Lua)
│   ├── simpsons-paradox/           # Simpson's paradox demo
│   └── wasm-force-demo/            # Rust WASM + PureScript
│
├── apps/                           # Full applications (not showcases)
│   └── shaped-steer/               # Spreadsheet/build/WASM app
│
├── _external/                      # Music ecosystem (separate project)
│   ├── tarot-music/
│   └── ES-config/
│
├── tools/                          # Build tools
├── scripts/                        # Utility scripts
├── docs/                           # Shared documentation
│   ├── kb/                         # Knowledge base
│   └── worklog/                    # Session logs
└── purescript-python-new/          # PurePy compiler (convenience)
```

### Anagram Codenames

| Codename | Meaning | Type |
|----------|---------|------|
| **Scuppered Ligature** | PureScript Edge Lua | Lua/Nginx edge layer |
| **Hypo-Punter** | Pure Python | PurePy showcase |
| **Corrode Expel** | Code Explorer | Node.js showcase |
| **Arid Keystone** | Sankey Editor | PureScript showcase |
| **Tilted Radio** | Tidal Editor | Purerl showcase |
| **Shaped Steer** | Spreadsheet | Full app (not showcase) |
| **Allergy Outlay** | Gallery Outlays | Image grid showcase |
| **Emptier Coinage** | Metrics Coinage | Metrics showcase |
| **Halogen Spider** | Spider Halogen | Site Explorer |
| **Prim Zoo Mosh** | Morphisms Zoo | Recursion schemes |
| **Timber Lieder** | Timbrel Dialer | Music visualization |

### spago.yaml Path Conventions

Projects reference Hylograph libraries via workspace `extraPackages` with relative paths:
- Site projects: `path: "../visualisation libraries/purescript-hylograph-*"`
- Showcases: `path: "../../visualisation libraries/purescript-hylograph-*"`
- Nested showcases: `path: "../../../visualisation libraries/purescript-hylograph-*"`

---

## Core Hylograph Libraries

### 1. hylograph-selection (`purescript-hylograph-selection`)
**Purpose**: Type-safe D3 selection and HATS AST
**Path**: `visualisation libraries/purescript-hylograph-selection`
**Key modules**: `Hylograph.Selection`, `Hylograph.HATS`, `Hylograph.Attr`, `Hylograph.Scale`, `Hylograph.Axis`
**Note**: This is the core library containing the HATS declarative AST

### 2. hylograph-graph (`purescript-hylograph-graph`)
**Purpose**: Graph data structures and algorithms
**Path**: `visualisation libraries/purescript-hylograph-graph`
**Key modules**: `Data.Graph.Inductive`, `Data.Graph.Layout` (Sugiyama)

### 3. hylograph-layout (`purescript-hylograph-layout`)
**Purpose**: Pure PureScript layout algorithms (tree, pack, sankey, edge-bundle)
**Path**: `visualisation libraries/purescript-hylograph-layout`
**Key modules**: `Layout.Tree`, `Layout.Sankey`, `Layout.Pack`, `Layout.EdgeBundle`

### 4. hylograph-simulation (`purescript-hylograph-simulation`)
**Purpose**: Force-directed graph simulation
**Path**: `visualisation libraries/purescript-hylograph-simulation`
**Key modules**: `Hylograph.Simulation`, `Hylograph.Force`

### 5. hylograph-simulation-halogen (`purescript-hylograph-simulation-halogen`)
**Purpose**: Halogen integration for force simulation
**Path**: `visualisation libraries/purescript-hylograph-simulation-halogen`

### 6. hylograph-music (`purescript-hylograph-music`)
**Purpose**: Data sonification for accessibility
**Path**: `visualisation libraries/purescript-hylograph-music`

### 7. hylograph-canvas (`purescript-hylograph-canvas`)
**Purpose**: Canvas rendering backend
**Path**: `visualisation libraries/purescript-hylograph-canvas`

### 8. hylograph-d3-kernel (`purescript-hylograph-d3-kernel`)
**Purpose**: Core D3.js bindings
**Path**: `visualisation libraries/purescript-hylograph-d3-kernel`

### 9. hylograph-transitions (`purescript-hylograph-transitions`)
**Purpose**: Animation and transition support
**Path**: `visualisation libraries/purescript-hylograph-transitions`

### 10. hylograph-wasm-kernel (`purescript-hylograph-wasm-kernel`)
**Purpose**: WASM acceleration for compute-intensive operations
**Path**: `visualisation libraries/purescript-hylograph-wasm-kernel`

---

## Site Infrastructure

The `site/` directory contains demo and documentation infrastructure:

### dashboard
**Purpose**: Dev dashboard for managing all services
**Path**: `site/dashboard`
**Technologies**: Node.js, WebSocket
**Port**: 9000
**Features**: Start/stop services, view logs, port configuration

### website
**Purpose**: Main Halogen demo website
**Path**: `site/website`
**Technologies**: Halogen, Hylograph

### react-proof
**Purpose**: Prove Hylograph works with React
**Path**: `site/react-proof`
**Technologies**: React, Hylograph

### showcase-shell
**Purpose**: Reusable Halogen shell component for demos
**Path**: `site/showcase-shell`
**Features**: Header slot, zoomable SVG layer, toggleable panels

### styling
**Purpose**: Hylograph house style CSS
**Path**: `site/styling`
**File**: `psd3.css` - design tokens, components, utilities

---

## Showcase Applications

### 1. Corrode Expel (`showcases/corrode-expel`)
**Purpose**: Code structure visualization
**Type**: Full-stack development tool
**Codename**: Anagram of "Code Explorer"

- **ce-server**: Node.js HTTP API server with DuckDB
- **ce-database**: DuckDB code indexing
- **ce2-website**: Halogen + Hylograph frontend with dependency graph
- **code-explorer-vscode-ext**: VSCode extension

### 2. Hypo-Punter (`showcases/hypo-punter`)
**Purpose**: PurePy demonstration (word embeddings + power grid)
**Type**: Monorepo with 5 sub-projects
**Codename**: Anagram of "Pure Python"

#### ee-server (Embedding Explorer Backend)
- **Language**: PureScript → Python (via purepy)
- **Technologies**: Flask, UMAP, GloVe word embeddings
- **Port**: 5081

#### ee-website (Embedding Explorer Frontend)
- **Framework**: Halogen + D3
- **Features**: SPLOM (scatterplot matrix), linked brushing
- **Port**: 8087

#### ge-server (Grid Explorer Backend)
- **Language**: PureScript → Python (via purepy)
- **Technologies**: Flask, pandapower, NetworkX
- **Port**: 5082

#### ge-website (Grid Explorer Frontend)
- **Framework**: Halogen + Hylograph
- **Features**: Force-directed network graph, voltage coloring
- **Port**: 8088

### 3. Arid Keystone (`showcases/psd3-arid-keystone`)
**Purpose**: Sankey diagram editor + build visualization
**Codename**: Anagram of "Sankey Editor"
**Features**: Interactive Sankey diagram creation, Makefile dependency visualization
**Port**: 8089

### 4. Tilted Radio (`showcases/psd3-tilted-radio`)
**Purpose**: TidalCycles live coding
**Codename**: Anagram of "Tidal Editor"

#### purerl-tidal (Erlang Backend)
- **Language**: PureScript → Erlang (via purerl)
- **Technologies**: Cowboy WebSocket, OTP, sendmidi
- **Port**: 8083

#### purescript-psd3-tidal (Browser Frontend)
- **Framework**: Halogen + Hylograph
- **Features**: Pattern visualization, MIDI output
- **Port**: 8084

### 5. WASM Force Demo (`showcases/wasm-force-demo`)
**Purpose**: Rust WASM + PureScript force simulation
**Technologies**: wasm-pack, Rust, PureScript
**Port**: 8079

### 6. Halogen Spider (`showcases/halogen-spider`)
**Purpose**: Site Explorer - route analysis and annotation
**Codename**: Anagram of "Spider Halogen"
**Features**: D3 force graph, route reachability analysis, Rose Adler Art Deco styling
**Backend**: Uses ce-server API

### 7. Prim Zoo Mosh (`showcases/psd3-prim-zoo-mosh`)
**Purpose**: Recursion schemes educational zoo
**Codename**: Anagram of "Morphisms Zoo"
**Features**: Catamorphism, anamorphism, hylomorphism, apomorphism visualizations
**Includes**: L-System implementation demonstrating schemes

### 8. Scuppered Ligature (`showcases/scuppered-ligature`)
**Purpose**: Edge layer for Polyglot PureScript
**Codename**: Anagram of "PureScript Edge Lua"
**Technologies**: PureScript, Lua, Nginx/OpenResty
**Features**: Request routing, rate limiting, metrics, upstream proxying
**Note**: Entry point for entire polyglot website - all requests flow through PureScript→Lua

### 9. Graph Algos (`showcases/graph-algos`)
**Purpose**: Graph algorithm visualizations
**Features**: A* pathfinding, Dijkstra, BFS/DFS demos

### 10. Simpsons Paradox (`showcases/simpsons-paradox`)
**Purpose**: Simpson's paradox statistical visualization
**Features**: Interactive demonstration of aggregation fallacy

### 11. Lorenz Attractor (`showcases/psd3-lorenz-attractor`)
**Purpose**: Chaos theory visualization
**Features**: 3D Lorenz attractor rendering

### 12. Timber Lieder (`showcases/psd3-timber-lieder`)
**Purpose**: Music/timbre visualization
**Codename**: Related to "Timbrel Dialer"

---

## Full Applications

### Shaped Steer (`apps/shaped-steer`)
**Purpose**: Full-featured spreadsheet/build system/database application
**Codename**: Anagram of "Spreadsheet"
**Status**: In development
**Vision**: Unifies spreadsheets, charting, build systems, databases with WASM calculations
**Note**: Not a showcase - this is a standalone product exploring "typed feedback loops"

---

## Alternative Backends

### Purerl (PureScript → Erlang)

**Binary**: `/Users/afc/bin/purerl`
**Compatible PureScript**: 0.15.14
**Erlang**: `/opt/homebrew/bin/erl` (Erlang/OTP 24+)

#### Compilation Pipeline
```bash
spago build            # Generate CoreFn with purerl backend
purerl                 # CoreFn → Erlang source
rebar3 compile         # Compile to BEAM
```

#### Module Naming
- `Foo.Bar` → `foo_bar@ps` (compiled module)
- `Foo.Bar` → `foo_bar@foreign` (FFI module)

#### Key Frameworks
- **Pinto**: OTP wrapper (GenServer, Supervisor)
- **Stetson**: Cowboy web framework wrapper
- **Documentation**: https://purerl-cookbook.readthedocs.io/

### PurePy (PureScript → Python)

**Location**: `purescript-python-new/`
**Command**: `purepy`

#### Compilation Pipeline
```bash
spago build                    # Generate CoreFn
purepy output output-py        # CoreFn → Python source
cp src/*_foreign.py output-py/ # Copy FFI files
```

#### Module Naming
- `Data.Array` → `data_array.py`
- `Data.Array` FFI → `data_array_foreign.py`

---

## Build Systems

### Unified Makefile

The repository has a comprehensive Makefile:

```bash
make all              # Build everything
make libs             # Build core libraries only
make apps             # Build showcase apps only
make clean            # Remove build artifacts
make check-tools      # Verify prerequisites
make help             # Show all targets

# Serve targets
make dashboard        # Dev dashboard on :9000
make serve-sankey     # Sankey Editor on :8089
make serve-ee         # Embedding Explorer on :8087
make serve-tidal      # Tidal Editor on :8084

# Prerequisite tests
make test-prereqs     # Test all backend toolchains
make test-purerl      # Test Erlang backend
make test-purepy      # Test Python backend
make test-wasm        # Test WASM toolchain

# Utility
make deps-csv         # Export build deps as CSV
make deps-json        # Export build deps as JSON
make verify-bundles   # Verify browser bundle co-location
```

### Build Conventions

**Rule Zero**: ALL builds go through `make`. Never run raw `spago bundle` directly.

**Browser bundle convention**: All browser targets use `bundle.js` in the same directory as `index.html`. No exceptions.

| Pattern | index.html | bundle |
|---------|-----------|--------|
| Standard | `public/index.html` | `public/bundle.js` |
| Demo | `demo/index.html` | `demo/bundle.js` |

Run `make verify-bundles` to check all browser targets follow this convention.

### Prerequisites

The build system auto-discovers tools:
- **Core**: spago, purs, npm, node
- **PurePy**: purepy (from purescript-python-new/.stack-work)
- **Purerl**: purerl (~/bin/purerl), rebar3, erlang
- **WASM**: wasm-pack, cargo, rustup with wasm32 target

Run `make check-tools` to verify your setup, then `make test-prereqs` to run the toolchain tests.

### Deployment Policy

**Always use full Docker deployment.** Never spin up ad-hoc HTTP servers for testing.

| Target | Machine | Port | Usage |
|--------|---------|------|-------|
| **Local** (default) | MacBook Pro | 80 | `docker compose up -d` |
| **Remote** | MacMini | 80 | rsync + SSH docker commands |

**Local Docker Workflow:**
```bash
make <target>                                    # Build artifact
docker compose build --no-cache <service>        # Rebuild container
docker compose up -d <service>                   # Start container
# Test at http://localhost/<path>
```

**Remote Workflow:**
```bash
make <target>                                    # Build locally
rsync -avz --delete <local>/ andrew@100.101.177.83:~/psd3/<remote>/
ssh andrew@100.101.177.83 "cd ~/psd3 && /usr/local/bin/docker compose build --no-cache <service> && /usr/local/bin/docker compose up -d <service>"
```

**Key rule:** Containers bake in files at build time. Always rebuild containers after code changes.

---

## FFI Patterns

### Effect Pattern (All Backends)

Effects are **thunks** (zero-argument functions) that defer execution:

```purescript
-- PureScript declaration
foreign import readFile :: String -> Effect String
```

```javascript
// JavaScript FFI
export const readFile = path => () => fs.readFileSync(path, 'utf8');
```

```python
# Python FFI
def readFile(path):
    def effect():
        with open(path) as f:
            return f.read()
    return effect
```

```erlang
% Erlang FFI
readFile(Path) ->
  fun() ->
    {ok, Content} = file:read_file(Path),
    Content
  end.
```

### Currying Pattern

All multi-argument functions must be curried:

```python
# Python: f(x, y, z) becomes f(x)(y)(z)
def addThree(x):
    return lambda y: lambda z: x + y + z
```

---

## Knowledge Base & Claude Skills

### Knowledge Base (`docs/kb/`)

The knowledge base contains classified technical reports:

```
docs/kb/
├── INDEX.md           # Master index of all reports
├── _TEMPLATE.md       # Template for new reports
├── architecture/      # System design documents
├── plans/             # Implementation roadmaps
├── research/          # Analysis and investigations
├── reference/         # Specifications and status docs
├── howto/             # Practical guides
└── archive/           # Superseded/completed docs
```

**When to consult**: Before working on unfamiliar territory, check INDEX.md for relevant reports. The `howto/` guides often have solutions to common problems.

### Claude Skills (`.claude/commands/`)

Custom skills extend Claude Code's capabilities:

| Skill | Purpose |
|-------|---------|
| `/build` | Build any/all project artifacts via Makefile |
| `/deploy` | Deploy to MacMini via rsync + Docker |
| `/css-review` | Review CSS for cleanliness and modern practices |
| `/feature` | Create feature branches with proper workflow |
| `/plan-stack` | Plan implementation with stack considerations |
| `/fp-police` | Code quality audit for FP principles |

### Session Logging

Session logs go in `docs/worklog/YYYY-MM-DD.md`. Required sections:
1. **Accomplished**: What was completed
2. **Explored But Not Pursued**: Paths investigated but set aside
3. **Parking Lot**: Ideas surfaced but not addressed
4. **Decisions Made**: Choices with rationale
5. **Next Session Setup**: Context for resuming

---

## Common Tasks Quick Reference

### Starting Dev Dashboard
```bash
make dashboard
# Open http://localhost:9000
```

### Building Everything
```bash
make all
```

### Running Showcase Apps (Docker)

All apps run via Docker on port 80. Default is local Docker on MacBook Pro.

```bash
# Build and deploy locally
make <target>
docker compose build --no-cache <service>
docker compose up -d <service>

# Example: Minard
make app-minard
docker compose build --no-cache minard-frontend minard-backend
docker compose up -d minard-frontend minard-backend
# Access at http://localhost/code/

# Example: Full stack
docker compose up -d
# Access website at http://localhost/
# Access showcases at http://localhost/code/, /ee/, /ge/, /tidal/, /sankey/, /wasm/
```

### Adding Python FFI

1. Create PureScript foreign import in `src/Data/MyLib.purs`
2. Create Python implementation in `src/Data/MyLib.py`
3. Build: `spago build && purepy output output-py && cp src/Data/*.py output-py/`

### Debugging Build Issues

```bash
make check-tools      # Verify all prerequisites
make show-config      # Show resolved tool paths
make deps-graph       # Show library dependency order
```

---

## Package Registry Versions

| Project Type | Registry Version | Notes |
|--------------|------------------|-------|
| Most projects | 67.0.1 | Standard PureScript registry |
| Purerl projects | erl-0.15.3-20220629 | Purerl-specific package set |
| PurePy projects | 67.0.1 | Uses standard registry + custom FFI |

---

*Last updated: January 2026*
*Backends: JavaScript (default), Erlang (purerl), Python (purepy), Rust/WASM*
