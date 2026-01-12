# What Claude Needs to Know: PSD3 Ecosystem Reference

This document provides essential context about the PSD3 suite of libraries, tools, and showcase applications. It covers all repositories under `/Users/afc/work/afc-work/PSD3-Repos/` plus the alternative compiler backends (Erlang and Python).

## Table of Contents
1. [Design Philosophy](#design-philosophy)
2. [Ecosystem Overview](#ecosystem-overview)
3. [Core PSD3 Libraries](#core-psd3-libraries)
4. [Site Infrastructure](#site-infrastructure)
5. [Showcase Applications](#showcase-applications)
6. [Full Applications](#full-applications)
7. [Alternative Backends](#alternative-backends)
8. [Build Systems](#build-systems)
9. [FFI Patterns](#ffi-patterns)
10. [Common Tasks Quick Reference](#common-tasks-quick-reference)

---

## Design Philosophy

### Declarative Over Imperative

There is a strong emphasis on **declarative programming styles** throughout this ecosystem, using ASTs interpreted by Finally Tagless interpreters:

- **PSD3 takes control from D3** - We don't write imperative D3 code that mutates the DOM directly
- **D3 as calculation engine only** - We use D3's mathematical algorithms (force simulation engine) but manage state and rendering declaratively through PureScript
- **Data flows down, events flow up** - Visualizations are functions of data, not sequences of mutations

### Prefer Public Libraries

We strive to **use public PureScript libraries from the current Spago package set** rather than reinventing. Before implementing functionality:

1. Check if it exists in the registry
2. Use well-maintained community packages
3. Only build custom solutions when the domain is truly novel (like PSD3's type-safe D3 bindings)

### Code Quality Standards

Everything in this ecosystem is either:

- **Library code** - Must be principled, idiomatic PureScript because it's a library that others will depend on
- **Demo code** - Must be principled, idiomatic PureScript because it's meant to be *read* as well as run

**There are no "quick hacks" here.** Code should serve as documentation of best practices.

---

## Ecosystem Overview

### What is PSD3?

PSD3 (PureScript D3) is a **type-safe data visualization ecosystem** that provides D3-style visualizations with PureScript's strong type system. Unlike typical D3.js wrappers, PSD3 implements layout algorithms in pure PureScript and provides a layered architecture from data structures to DOM rendering. Several showcase applications make deep use of other ecosystems (Tidal, Erlang, Excel, Python, Node).

### Architecture Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    SHOWCASE APPLICATIONS                        │
│  Corrode Expel | Hypo-Punter | Arid Keystone | Tilted Radio    │
├─────────────────────────────────────────────────────────────────┤
│                    FRAMEWORK INTEGRATIONS                       │
│              psd3-react | site/website (Halogen)                │
├─────────────────────────────────────────────────────────────────┤
│                    PRESENTATION LAYER                           │
│                  psd3-music | psd3-tidal                        │
├─────────────────────────────────────────────────────────────────┤
│                    INTERACTION LAYER                            │
│           psd3-selection (DOM) | psd3-simulation (force)        │
├─────────────────────────────────────────────────────────────────┤
│                    COMPUTATION LAYER                            │
│             psd3-layout | psd3-graph                            │
├─────────────────────────────────────────────────────────────────┤
│                    FOUNDATION LAYER                             │
│                       psd3-tree                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
/Users/afc/work/afc-work/PSD3-Repos/
├── visualisation libraries/        # Core PSD3 libraries
│   ├── purescript-psd3-tree/       # Rose trees (foundation)
│   ├── purescript-psd3-graph/      # Graph data structures
│   ├── purescript-psd3-layout/     # Layout algorithms
│   ├── purescript-psd3-selection/  # D3-style DOM selection
│   ├── purescript-psd3-simulation/ # Force-directed simulation
│   ├── purescript-psd3-simulation-halogen/  # Halogen bindings
│   ├── purescript-psd3-music/      # Audio/sonification
│   └── psd3-astar-demo/            # Pathfinding visualization
│
├── site/                           # Demo infrastructure
│   ├── scuppered-ligature/         # Edge layer (PureScript → Lua → Nginx)
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
│   ├── hypo-punter/                # PurePy demos (monorepo)
│   │   ├── ee-server/              # Embedding Explorer Python backend
│   │   ├── ee-website/             # Embedding Explorer Halogen frontend
│   │   ├── ge-server/              # Grid Explorer Python backend
│   │   ├── ge-website/             # Grid Explorer Halogen frontend
│   │   └── landing/                # Unified landing page
│   ├── corrode-expel/              # Code Explorer
│   │   ├── ce-server/              # Node.js API server
│   │   ├── ce-database/            # DuckDB code indexing
│   │   ├── ce2-website/            # Halogen + PSD3 frontend
│   │   └── code-explorer-vscode-ext/  # VSCode extension
│   ├── psd3-arid-keystone/         # Sankey diagram editor
│   ├── psd3-tilted-radio/          # Tidal/Algorave
│   │   ├── purerl-tidal/           # Erlang backend
│   │   └── purescript-psd3-tidal/  # PureScript frontend
│   └── wasm-force-demo/            # Rust WASM + PureScript
│       └── force-kernel/           # Rust WASM kernel
│
├── apps/                           # Full applications (not showcases)
│   └── shaped-steer/               # Spreadsheet/build/WASM vision
│
├── _external/                      # Music ecosystem (separate project)
│   ├── tarot-music/
│   └── ES-config/
│
├── tools/                          # Build tools
├── scripts/                        # makefile-to-sankey.js etc
├── docs/                           # Shared documentation
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

### spago.yaml Path Conventions

Projects reference PSD3 libraries via workspace `extraPackages` with relative paths:
- Site projects: `path: "../visualisation libraries/purescript-psd3-*"`
- Showcases: `path: "../../visualisation libraries/purescript-psd3-*"`
- Nested showcases: `path: "../../../visualisation libraries/purescript-psd3-*"`

---

## Core PSD3 Libraries

### 1. psd3-tree (`purescript-psd3-tree`)
**Purpose**: Rose tree data structure
**Path**: `visualisation libraries/purescript-psd3-tree`
**Dependencies**: arrays, foldable-traversable, lists, maybe, prelude, tree-rose
**Used by**: psd3-graph, psd3-layout, psd3-selection

### 2. psd3-graph (`purescript-psd3-graph`)
**Purpose**: Graph data structures and algorithms
**Path**: `visualisation libraries/purescript-psd3-graph`
**Dependencies**: psd3-tree, arrays, control, foldable-traversable, free, graphs
**Key modules**: `Data.Graph.Inductive`, graph traversal algorithms

### 3. psd3-layout (`purescript-psd3-layout`)
**Purpose**: Pure PureScript layout algorithms (tree, pack, sankey, edge-bundle)
**Path**: `visualisation libraries/purescript-psd3-layout`
**Dependencies**: psd3-tree, ordered-collections, random, transformers
**Key modules**: `Layout.Tree`, `Layout.Sankey`, `Layout.Pack`, `Layout.EdgeBundle`

### 4. psd3-selection (`purescript-psd3-selection`)
**Purpose**: Type-safe D3 selection and attribute binding
**Path**: `visualisation libraries/purescript-psd3-selection`
**Dependencies**: psd3-tree, psd3-graph, web-dom, web-events, halogen-subscriptions
**Key modules**: `PSD3.Selection`, `PSD3.Attr`, `PSD3.Scale`, `PSD3.Axis`

### 5. psd3-simulation (`purescript-psd3-simulation`)
**Purpose**: Force-directed graph simulation
**Path**: `visualisation libraries/purescript-psd3-simulation`
**Dependencies**: psd3-selection, halogen-subscriptions, refs
**Key modules**: `PSD3.Simulation`, `PSD3.Force`

### 6. psd3-simulation-halogen (`purescript-psd3-simulation-halogen`)
**Purpose**: Halogen integration for force simulation
**Path**: `visualisation libraries/purescript-psd3-simulation-halogen`
**Dependencies**: psd3-simulation, halogen

### 7. psd3-music (`purescript-psd3-music`)
**Purpose**: Data sonification for accessibility
**Path**: `visualisation libraries/purescript-psd3-music`
**Dependencies**: psd3-selection, refs, transformers

---

## Site Infrastructure

The `site/` directory contains demo and documentation infrastructure:

### scuppered-ligature
**Purpose**: Edge layer for Polyglot PureScript - routes all traffic through PureScript compiled to Lua
**Path**: `site/scuppered-ligature`
**Technologies**: PureScript, Lua, Nginx/OpenResty
**Port**: 80
**Features**: Request routing, rate limiting, metrics collection, upstream proxying
**Codename**: Anagram of "PureScript Edge Lua"

This is the entry point for the entire Polyglot PureScript website. Every request
flows through PureScript code running as Lua inside Nginx, demonstrating that
PureScript can run at the edge. See `docker-compose.yml` for the full stack.

### dashboard
**Purpose**: Dev dashboard for managing all services
**Path**: `site/dashboard`
**Technologies**: Node.js, WebSocket
**Port**: 9000
**Features**: Start/stop services, view logs, port configuration

### website
**Purpose**: Main Halogen demo website
**Path**: `site/website`
**Technologies**: Halogen, PSD3

### react-proof
**Purpose**: Prove PSD3 works with React
**Path**: `site/react-proof`
**Technologies**: React, PSD3

### showcase-shell
**Purpose**: Reusable Halogen shell component for demos
**Path**: `site/showcase-shell`
**Features**: Header slot, zoomable SVG layer, toggleable panels

### styling
**Purpose**: PSD3 house style CSS
**Path**: `site/styling`
**File**: `psd3.css` - design tokens, components, utilities

### docs
**Purpose**: Antora documentation server
**Path**: `site/docs`

---

## Showcase Applications

### 1. Hypo-Punter (`showcases/hypo-punter`)
**Purpose**: PurePy demonstration (word embeddings + power grid)
**Type**: Monorepo with 5 sub-projects

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
- **Framework**: Halogen + PSD3
- **Features**: Force-directed network graph, voltage coloring
- **Port**: 8088

#### landing
- **Purpose**: Unified landing page for both demos
- **Port**: 8091

### 2. Corrode Expel (`showcases/corrode-expel`)
**Purpose**: Code structure visualization
**Type**: Full-stack development tool

- **ce-server**: Node.js HTTP API server
- **ce-database**: DuckDB code indexing
- **ce2-website**: Halogen + PSD3 frontend with dependency graph
- **code-explorer-vscode-ext**: VSCode extension

### 3. Arid Keystone (`showcases/psd3-arid-keystone`)
**Purpose**: Sankey diagram editor + build visualization
**Features**: Interactive Sankey diagram creation, Makefile dependency visualization
**Uses**: psd3-layout (Sankey algorithm), psd3-selection, Halogen
**Port**: 8089

### 4. Tilted Radio (`showcases/psd3-tilted-radio`)
**Purpose**: TidalCycles live coding

#### purerl-tidal (Erlang Backend)
- **Language**: PureScript → Erlang (via purerl)
- **Technologies**: Cowboy WebSocket, OTP, sendmidi
- **Port**: 8083

#### purescript-psd3-tidal (Browser Frontend)
- **Framework**: Halogen + PSD3
- **Features**: Pattern visualization, MIDI output
- **Port**: 8084

### 5. WASM Force Demo (`showcases/wasm-force-demo`)
**Purpose**: Rust WASM + PureScript force simulation
**Technologies**: wasm-pack, Rust, PureScript
**Port**: 8079

---

## Full Applications

### Shaped Steer (`apps/shaped-steer`)
**Purpose**: Full-featured spreadsheet/build system/database application
**Status**: In development
**Vision**: Unifies spreadsheets, charting, build systems, databases with WASM calculations
**Note**: Not a showcase - this is a standalone product

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

### Running Showcase Apps
```bash
# Sankey Editor (with build deps visualization)
make serve-sankey
# Open http://localhost:8089/?data=build-deps.json

# Code Explorer (needs backend + frontend)
make serve-code-explorer-backend &
make serve-code-explorer

# Tidal (needs Erlang backend + frontend)
make serve-tidal-backend &  # Starts rebar3 shell
make serve-tidal
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
