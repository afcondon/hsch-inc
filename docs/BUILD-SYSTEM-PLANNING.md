# PSD3 Ecosystem Build System

## Overview

This document describes the unified build system for the PSD3 visualization ecosystem. A single entry point (`make all`) builds all showcase apps and libraries with proper dependency ordering across multiple languages and targets.

## Quick Start

```bash
# Check required tools
make check-tools

# Build everything
make all

# Or build specific targets
make libs          # Core PureScript libraries only
make apps          # Showcase applications only
make lib-tree      # Single library
make app-wasm      # Single application
```

## Prerequisites

### Required (for most builds)
- `spago` - PureScript package manager/build tool
- `purs` - PureScript compiler
- `npm` / `node` - Node.js and package manager

### Optional (for specific targets)

| Tool | Required For |
|------|--------------|
| `purepy` | Embedding Explorer Python backends |
| `python3` | Running Python backends |
| `purerl` | Purerl Tidal (Erlang backend) |
| `rebar3` | Purerl Tidal (Erlang build) |
| `erl` | Purerl Tidal (Erlang runtime) |
| `wasm-pack` | WASM Force Demo |
| `cargo` | WASM Force Demo (Rust) |
| `tsc` | VSCode Extension (fallback to npx) |

## Repository Structure

```
PSD3-Repos/
├── Makefile                          <- Unified build system
├── visualisation libraries/          <- Core PureScript libraries
│   ├── purescript-psd3-tree/         <- Foundation (no deps)
│   ├── purescript-psd3-graph/        <- Depends on tree
│   ├── purescript-psd3-layout/       <- Depends on tree
│   ├── purescript-psd3-selection/    <- Depends on tree, graph
│   ├── purescript-psd3-music/        <- Depends on selection
│   ├── purescript-psd3-simulation/   <- Depends on selection
│   ├── purescript-psd3-showcase-shell/  <- Depends on selection
│   ├── purescript-psd3-simulation-halogen/ <- Depends on simulation
│   └── psd3-astar-demo/              <- Demo app (depends on simulation)
│
└── showcase apps/
    ├── wasm-force-demo/              <- WASM + PureScript
    │   └── force-kernel/             <- Rust crate
    │
    ├── psd3-embedding-explorer/      <- "Hypo-Punter" (PurePy demos)
    │   ├── ee-server/                <- Embedding Explorer backend (Python)
    │   ├── ge-server/                <- Grid Explorer backend (Python)
    │   ├── ee-website/               <- Embedding Explorer frontend (JS)
    │   ├── ge-website/               <- Grid Explorer frontend (JS)
    │   └── landing/                  <- Landing page (JS)
    │
    ├── psd3-arid-keystone/           <- "Sankey Editor" (arid keystone anagram)
    │                                    Single PS app with Halogen
    │
    ├── purescript-code-explorer/     <- "Corrode Expel" (code explorer anagram)
    │   ├── ce-database/              <- DuckDB data + loader
    │   ├── ce-server/                <- Node.js API server
    │   ├── ce2-website/              <- Frontend (depends on PSD3 libs)
    │   └── code-explorer-vscode-ext/ <- TypeScript VSCode extension
    │
    └── psd3-tilted-radio/            <- "Tidal Editor" (tilted radio anagram)
        ├── purerl-tidal/             <- Erlang backend
        └── purescript-psd3-tidal/    <- PureScript frontend
```

## Library Dependency Graph

```
Layer 0 (foundation):
  psd3-tree

Layer 1 (depends on tree):
  psd3-graph ──→ psd3-tree
  psd3-layout ─→ psd3-tree

Layer 2 (depends on tree + graph):
  psd3-selection ─→ psd3-tree, psd3-graph

Layer 3 (depends on selection):
  psd3-music ─────────→ psd3-selection
  psd3-simulation ────→ psd3-selection
  psd3-showcase-shell → psd3-selection

Layer 4 (depends on simulation):
  psd3-simulation-halogen → psd3-simulation
```

## Build Targets

### Main Targets

| Target | Description |
|--------|-------------|
| `make all` | Build everything (libs + apps) |
| `make libs` | Build core PureScript libraries |
| `make apps` | Build all showcase applications |
| `make clean` | Remove build artifacts |
| `make clean-deps` | Remove artifacts + node_modules |
| `make help` | Show all available targets |

### Library Targets

| Target | Description |
|--------|-------------|
| `make lib-tree` | Foundation: Rose tree data structure |
| `make lib-graph` | Graph algorithms |
| `make lib-layout` | Layout algorithms (tree, pack, sankey) |
| `make lib-selection` | D3 selection/attribute library |
| `make lib-music` | Audio/sonification interpreter |
| `make lib-simulation` | Force-directed simulation |
| `make lib-showcase-shell` | Halogen shell for demos |
| `make lib-simulation-halogen` | Halogen integration for simulation |
| `make lib-astar-demo` | A* pathfinding demo |

### Application Targets

| Target | Description |
|--------|-------------|
| `make app-wasm` | WASM force simulation demo |
| `make app-embedding-explorer` | Word embedding explorer (all 5 sub-projects) |
| `make app-sankey` | Sankey diagram editor |
| `make app-code-explorer` | Code visualization explorer |
| `make app-tilted-radio` | Tidal patterns (Purerl + PS) |

### Sub-Project Targets

**Embedding Explorer:**
- `make ee-server` - Python backend (port 8081)
- `make ge-server` - Grid Explorer Python backend (port 8082)
- `make ee-website` - Frontend bundle
- `make ge-website` - Grid Explorer frontend
- `make landing` - Hypo-Punter landing page

**Code Explorer:**
- `make ce-server` - Node.js API server
- `make ce2-website` - Frontend bundle
- `make vscode-ext` - VSCode extension

**Tilted Radio:**
- `make purerl-tidal` - Erlang backend
- `make ps-tidal` - PureScript frontend

### Utility Targets

| Target | Description |
|--------|-------------|
| `make check-tools` | Verify required tools are installed |
| `make install-python-deps` | Install Python packages for PurePy |
| `make deps-graph` | Print library dependency graph |

## Build Patterns

### Standard PureScript (JS target)
```bash
cd "$PROJECT_DIR"
spago build
# Optional: spago bundle --module Main --outfile dist/bundle.js
```

### PurePy (Python backend)
```bash
cd "$PROJECT_DIR"
spago build
purepy output output-py
cp src/*_foreign.py output-py/  # FFI files follow naming convention
# Run: python3 -c "import sys; sys.path.insert(0, 'output-py'); from main import main; main()()"
```

### Purerl (Erlang backend)
```bash
cd "$PROJECT_DIR"
spago build  # Uses --backend purerl via spago.yaml
purerl       # Transpile to Erlang
rebar3 compile
# Run: rebar3 shell
```

### WASM (Rust kernel)
```bash
cd force-kernel
wasm-pack build --target web --out-dir ../pkg
cd ..
spago build
spago bundle --module Main --outfile dist/bundle.js
```

## Naming Conventions

The showcase apps use anagram codenames to allow flexibility as projects evolve:

| Directory | Anagram Of | Project |
|-----------|------------|---------|
| psd3-tilted-radio | tidal editor | Tidal pattern visualization |
| psd3-arid-keystone | sankey editor | Sankey diagram editor |
| psd3-embedding-explorer | (hypo-punter) | Python backend demos |
| purescript-code-explorer | (corrode expel) | Code visualization |

## Parallel Builds

Make can parallelize independent builds:

```bash
make -j4 libs    # Build libraries with 4 parallel jobs
make -j apps     # Build apps (limited by dependencies)
```

Note: Library dependencies are explicitly declared, so Make will respect the build order even with `-j`.

## Output Locations

| Project Type | Output Location |
|--------------|-----------------|
| PureScript | `output/` |
| Spago bundles | Varies by project (see spago.yaml `bundle.outfile`) |
| PurePy | `output-py/` |
| Purerl | `ebin/`, `_build/` |
| WASM | `pkg/` |
| TypeScript | `out/` |

## Troubleshooting

### Missing tools
Run `make check-tools` to see which tools are available and which are missing.

### Path issues
The Makefile handles directories with spaces (`visualisation libraries/`, `showcase apps/`) correctly. If you encounter issues, ensure you're using GNU Make 4.x+.

### Incremental builds
Spago handles PureScript incremental builds. For clean rebuilds:
```bash
make clean
make all
```

### Python dependencies
```bash
make install-python-deps
# Or manually:
pip install flask flask-cors umap-learn numpy pandapower networkx
```

## Future: Native PureScript Build Tool

The long-term vision is to replace this Makefile with a native PureScript build tool that:

1. **Visualizes the build DAG** as a Sankey diagram using `psd3-layout`
2. **Shows live build progress** with animated flows through the dependency graph
3. **Demonstrates the ecosystem** eating its own dog food

This would be fronted by a version of the Sankey Editor (`psd3-arid-keystone`), making the build system itself a showcase of PSD3 capabilities.

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Build commands reference
- [KERNEL-SEPARATION-ARCHITECTURE.md](./KERNEL-SEPARATION-ARCHITECTURE.md) - WASM kernel details
- [PUREPY-BUILD-SYSTEM.md](./PUREPY-BUILD-SYSTEM.md) - Python backend details (if exists)

---

*Updated: January 2026*
*Makefile created and tested*
