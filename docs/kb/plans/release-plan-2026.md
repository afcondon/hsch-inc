---
title: "Hylograph & Polyglot PureScript Release Plan"
category: plan
status: active
tags: [release, hylograph, polyglot, deployment, infrastructure]
created: 2026-01-29
summary: Comprehensive plan for releasing the Hylograph library suite at hylograph.net and Polyglot PureScript ecosystem at polyglot.purescri.pt
---

# Release Plan: Hylograph & Polyglot PureScript

## Executive Summary

Two related but distinct projects need public release:

| Domain | Purpose | Hosting |
|--------|---------|---------|
| **hylograph.net** | Visualization library suite | Cloudflare Pages + Tunnel |
| **polyglot.purescri.pt** | Backend ecosystem showcase | GitHub Pages + link to live demos |

**Relationship**: Hylograph is the *what* (visualization libraries), Polyglot is the *how* (proves PureScript works everywhere). Many Polyglot demos use Hylograph for visualization.

---

## Part 1: hylograph.net (Library Suite)

### 1.1 Libraries to Publish

Rename from `purescript-psd3-*` to `purescript-hylograph-*`:

| Library | Current | New Name | Demo | Status |
|---------|---------|----------|------|--------|
| **selection** | psd3-selection | hylograph-selection | Hylograph Explorer | Ready |
| **simulation** | psd3-simulation | hylograph-simulation | Force Playground | Ready |
| **layout** | psd3-layout | hylograph-layout | Layout Gallery | Ready |
| **graph** | psd3-graph | hylograph-graph | Honeycomb Puzzle | Ready |
| **music** | psd3-music | hylograph-music | Anscombe's String Quartet | Ready |
| **transitions** | psd3-transitions | hylograph-transitions | (part of selection demo) | Merge into selection? |

**Additional libraries (keep separate):**

| Library | Current | New Name | Notes |
|---------|---------|----------|-------|
| **transitions** | psd3-transitions | hylograph-transitions | Animation/transition helpers |
| **optics** | psd3-optics | hylograph-optics | Lens-based tree traversal |
| **d3-kernel** | psd3-d3-kernel | hylograph-d3-kernel | D3 impl of simulation API |
| **simulation-core** | psd3-simulation-core | hylograph-simulation-core | Abstract simulation API |
| **simulation-halogen** | psd3-simulation-halogen | hylograph-simulation-halogen | Halogen integration |
| **wasm-kernel** | psd3-wasm-kernel | hylograph-wasm-kernel | Rust/WASM impl (separate build) |
| **canvas** | psd3-canvas | hylograph-canvas | Evaluate: keep if used |

### 1.2 Domain Structure

```
hylograph.net/                    # Landing page: "Declarative Visualization for PureScript"
│
├── libs/                         # Library documentation
│   ├── selection/               # Library page + Hylograph Explorer
│   ├── simulation/              # Library page + Force Playground
│   ├── layout/                  # Library page + Layout Gallery
│   ├── graph/                   # Library page + Honeycomb Puzzle
│   └── music/                   # Library page + Anscombe's String Quartet
│
├── docs/                         # Scrollytelling documentation
│   ├── getting-started/         # Quick start guide
│   ├── tutorials/               # Step-by-step tutorials
│   │   └── simpsons-paradox/   # Worked example: data-driven Halogen component
│   ├── how-to/                  # Task-oriented guides
│   └── reference/               # API reference (Antora?)
│
├── dashboard/                    # Interactive dashboard
│   └── (component playground, live examples)
│
└── guide/                        # Interactive HATS tour (hylograph-guide)

live.hylograph.net/              # Backend-required demos (Tunnel to MacMini)
├── code-explorer/               # Corrode Expel
├── sankey/                      # Arid Keystone (full version)
└── tidal/                       # Tilted Radio (if ready)
```

**Key insight**: Simpson's Paradox is a *worked example* in the documentation, not a standalone demo. It shows "how to build a data-driven Halogen visualization component with Hylograph."

### 1.3 Documentation Approach: Scrollytelling

The hylograph.net documentation uses **scrollytelling** - narrative-driven pages where visualizations respond to scroll position:

```
┌─────────────────────────────────────────┐
│  Scrollytelling Page Layout             │
├─────────────────────┬───────────────────┤
│                     │                   │
│  Narrative text     │   Sticky viz      │
│  that scrolls...    │   that updates    │
│                     │   as you scroll   │
│  "First, we create  │                   │
│   a Tree..."        │   [Tree diagram]  │
│                     │                   │
│  "Then we add a     │   [Tree + fold]   │
│   forEach fold..."  │                   │
│                     │                   │
└─────────────────────┴───────────────────┘
```

**Documentation sections:**
- **Getting Started**: Install, hello world, first visualization
- **Tutorials**: Step-by-step builds (Simpson's Paradox is here)
- **How-To**: Task-oriented ("How to add interactivity", "How to animate")
- **Reference**: API docs, type signatures (possibly Antora-generated)

### 1.4 Dashboard

A live **dashboard** at hylograph.net/dashboard/ provides:
- Component playground (try HATS in browser)
- Example gallery with source code
- Performance benchmarks (D3 vs WASM)
- Build status of all libraries

This is where the current MacMini dashboard concept evolves to.

### 1.5 Static Demos (Cloudflare Pages)

| Demo | Source | Notes |
|------|--------|-------|
| Hylograph Explorer | showcases/hylograph-app | Interactive HATS structure viewer |
| Force Playground | site/website (route) | Already in website |
| Layout Gallery | showcases/allergy-outlay | Move to layout lib site |
| Honeycomb Puzzle | showcases/psd3-honeycomb | Move to graph lib site |
| Anscombe's String Quartet | psd3-anscombe-quartet | Move to music lib site |
| Optic Menagerie | showcases/emptier-coinage | Keep standalone or merge |
| Morphism Zoo | showcases/psd3-prim-zoo-mosh | Static, whimsical |
| WASM Force Demo | showcases/wasm-force-demo | Proves WASM backend works |

### 1.6 Hylograph Release Tasks

```
Phase 1: Demo Consolidation
├── [ ] Move Layout Gallery (allergy-outlay) → layout lib site
├── [ ] Move Honeycomb (psd3-honeycomb) → graph lib site
├── [ ] Move Anscombe → music lib site, rename "Anscombe's String Quartet"
├── [ ] Move Simpson's Paradox → docs/tutorials/

Phase 2: Infrastructure
├── [ ] Verify hylograph.net DNS active in Cloudflare
├── [ ] Set up Cloudflare Pages project
├── [ ] Create cloudflare-build Makefile target
├── [ ] Configure Cloudflare Tunnel on MacMini
├── [ ] Test end-to-end deployment

Phase 3: Extract to GitHub (flat repos under afcondon)
├── [ ] Create purescript-hylograph-selection repo
├── [ ] Create purescript-hylograph-simulation repo
├── [ ] Create purescript-hylograph-layout repo
├── [ ] Create purescript-hylograph-graph repo
├── [ ] Create purescript-hylograph-music repo
├── [ ] Create purescript-hylograph-transitions repo
├── [ ] Create purescript-hylograph-optics repo
├── [ ] Create purescript-hylograph-simulation-core repo
├── [ ] Create purescript-hylograph-d3-kernel repo
├── [ ] Create purescript-hylograph-wasm-kernel repo
├── [ ] Create purescript-hylograph-simulation-halogen repo

Phase 4: Rename & Update
├── [ ] Update all module names (PSD3.* → Hylograph.*)
├── [ ] Update all spago.yaml package names
├── [ ] Update all internal imports across repos
├── [ ] Update documentation references

Phase 5: Publish
├── [ ] Publish to PureScript Registry (in dependency order)
├── [ ] Update website branding (PSD3 → Hylograph)
├── [ ] Build scrollytelling documentation
├── [ ] Launch dashboard

Phase 6: Documentation
├── [ ] Getting Started guide
├── [ ] Simpson's Paradox tutorial (scrollytelling)
├── [ ] How-To guides
├── [ ] API reference (Antora or custom)
├── [ ] Test end-to-end
├── [ ] Update website branding (PSD3 → Hylograph)

Phase 4: Documentation
├── [ ] Update Antora docs with new names
├── [ ] Add "Try it live" links to each library page
├── [ ] Create getting started guide
├── [ ] Record demo videos (optional)
```

---

## Part 2: polyglot.purescri.pt (Ecosystem Showcase)

### 2.1 What It Demonstrates

The *Polyglot PureScript* project proves PureScript can target multiple backends:

| Backend | Technology | Demo |
|---------|------------|------|
| **JavaScript** | Standard (browser + Node) | Everything |
| **Python** | PurePy compiler | Grid Explorer, Embedding Explorer |
| **Erlang** | Purerl compiler | Tilted Radio (Tidal) |
| **Lua** | PsLua compiler | Scuppered Ligature (edge router) |
| **WASM** | Rust interop | WASM Force Demo |

### 2.2 Showcase Inventory

#### Tier 1: Flagship Demos (Backend-powered)

| Name | Anagram | Backend | Frontend | Status | Notes |
|------|---------|---------|----------|--------|-------|
| **Code Explorer** | Corrode Expel | Node.js | Halogen | 80% | Real-world app potential |
| **Grid Explorer** | (Hypo-Punter) | PurePy | Halogen | 90% | Great PurePy demo |
| **Embedding Explorer** | (Hypo-Punter) | PurePy | Halogen | 90% | Great PurePy demo |
| **Tidal Editor** | Tilted Radio | Purerl | Halogen | 70% | Algorave demo |
| **Sankey Editor** | Arid Keystone | (optional) | Halogen | 85% | Build management potential |

#### Tier 2: Static Showcases (No backend)

| Name | Anagram | Technology | Status | Notes |
|------|---------|------------|--------|-------|
| **Optic Menagerie** | Emptier Coinage | JS | 100% | Lens visualization |
| **Morphism Zoo** | Prim Zoo Mosh | JS | 100% | Recursion schemes |
| **Simpson's Paradox** | - | JS | 90% | Statistical visualization how-to |
| **Layout Gallery** | Allergy Outlay | JS | 100% | Move to hylograph |
| **WASM Force** | - | Rust+JS | 100% | WASM proof |

#### Tier 3: Infrastructure (Not user-facing)

| Name | Anagram | Technology | Notes |
|------|---------|------------|-------|
| **Edge Router** | Scuppered Ligature | PsLua | Proves Lua backend works |

### 2.3 External Projects to Reference

| Project | Location | Notes |
|---------|----------|-------|
| **purescript-python-new** | Separate repo | PurePy compiler itself |
| **purescript-lua fork** | GitHub | PRs pending (golden tests needed) |
| **purescript-build** | TBD | Build systems à la carte |
| **purescript-diagrams** | TBD | Haskell port |
| **purescript-linear** | TBD | Haskell port |
| **purescript-machines** | TBD | Haskell port |

### 2.4 Domain Structure

```
polyglot.purescri.pt/            # "PureScript Runs Everywhere"
│
├── index.html                   # Hero: backends diagram, quick links
│
├── backends/                    # One page per backend
│   ├── python/                 # PurePy: compiler, ecosystem, demos
│   ├── erlang/                 # Purerl: OTP, websockets, Tidal
│   ├── lua/                    # PsLua: Nginx, edge computing
│   └── wasm/                   # Rust interop: performance, WASM
│
├── showcases/                   # Gallery cards linking to live demos
│   ├── grid-explorer/          → live.hylograph.net/grid-explorer
│   ├── embedding-explorer/     → live.hylograph.net/embedding-explorer
│   ├── tidal-editor/           → live.hylograph.net/tidal
│   └── edge-router/            # (no demo, just explanation)
│
└── ecosystem/                   # Related projects
    ├── hylograph/              → hylograph.net (visualization)
    ├── diagrams/               → purescript-diagrams repo
    ├── linear/                 → purescript-linear repo
    └── machines/               → purescript-machines repo
```

**Key insight**: polyglot.purescri.pt is a *showcase site* ("look what PureScript can do!"), not a documentation site. Documentation lives at hylograph.net.

**Separation of concerns**:
- **hylograph.net**: "How to build visualizations" (docs, tutorials, API reference)
- **polyglot.purescri.pt**: "PureScript compiles to X" (showcases, links, ecosystem map)

### 2.5 PR for purescript-domain

Add to `/Users/afc/work/afc-work/GitHub/purescript-domain/sites.yaml`:

```yaml
polyglot:
  redirect: https://afcondon.github.io/polyglot-purescript
```

Or if using a custom domain later:
```yaml
polyglot:
  mask: https://polyglot.example.com
```

### 2.6 Polyglot Release Tasks

```
Phase 1: Repository Organization
├── [ ] Decide: monorepo vs separate repos for showcases
├── [ ] Create polyglot-purescript landing page repo
├── [ ] Document relationship between polyglot and hylograph
├── [ ] Identify which showcases stay in PSD3-Repos vs move out

Phase 2: PurePy Ecosystem
├── [ ] Verify purescript-python-new is public and documented
├── [ ] Document ee-server and ge-server as examples
├── [ ] Create "Getting Started with PurePy" guide

Phase 3: Lua Ecosystem
├── [ ] Submit golden test PR to purescript-lua
├── [ ] Document Scuppered Ligature as Lua example
├── [ ] Create "PureScript in Nginx" guide

Phase 4: Deploy Landing Page
├── [ ] Create GitHub Pages site
├── [ ] Submit PR to purescript-domain/sites.yaml
├── [ ] Coordinate with Nick Saunders

Phase 5: Documentation
├── [ ] Write overview of each backend
├── [ ] Create architecture diagrams
├── [ ] Add links to all live demos
```

---

## Part 3: Shared Infrastructure

### 3.1 MacMini Services

Current Docker stack serves both projects:

| Service | Port | Used By |
|---------|------|---------|
| edge (Lua router) | 80 | Both |
| website | - | Hylograph |
| ce-backend | 3000 | Both |
| ce-frontend | 8085 | Both |
| ee-backend | 5081 | Polyglot |
| ee-frontend | 8087 | Polyglot |
| ge-backend | 5082 | Polyglot |
| ge-frontend | 8088 | Polyglot |
| tidal-backend | 8083 | Polyglot |
| tidal-frontend | 8084 | Polyglot |
| sankey | 8089 | Hylograph |
| hylograph | - | Hylograph |
| lib-* | - | Hylograph |

### 3.2 Cloudflare Tunnel Configuration

```yaml
# live.hylograph.net - Hylograph backend demos
ingress:
  - hostname: live.hylograph.net
    path: /code-explorer/*
    service: http://localhost:8085
  - hostname: live.hylograph.net
    path: /sankey/*
    service: http://localhost:8089
  - hostname: live.hylograph.net
    path: /tidal/*
    service: http://localhost:8084

# live.polyglot.purescri.pt - Polyglot backend demos (or reuse live.hylograph.net)
ingress:
  - hostname: live.hylograph.net
    path: /grid-explorer/*
    service: http://localhost:8088
  - hostname: live.hylograph.net
    path: /embedding-explorer/*
    service: http://localhost:8087
```

---

## Part 4: Open Questions

### Decisions Made (2026-01-29)

1. **Repository structure**: Flat set of repos on afcondon's GitHub
   - All libraries become `purescript-hylograph-*` repos
   - No monorepo - each library is independent
   - Can transfer to org later if community interest grows

2. **Library consolidation**: Keep kernels separate
   - `transitions` - keep separate (could merge later)
   - `optics` - keep separate (could merge later)
   - `d3-kernel` - keep separate (D3 wrapper for abstract simulation API)
   - `simulation-core` - keep separate
   - `wasm-kernel` - keep separate (Rust build complexity)
   - Rationale: WASM kernel requires Rust toolchain, shouldn't force that on simulation users

3. **Demo embedding** (embed into library repos):
   - Layout Gallery → layout lib
   - Honeycomb → graph lib
   - Force Playground → simulation lib
   - Anscombe → music lib (rename "Anscombe's String Quartet")
   - Hylograph Explorer → selection lib
   - Optic Menagerie → optics lib

4. **Hylograph website extras**:
   - Morphism Zoo → easter egg on hylograph.net (not a polyglot showcase)

5. **Separate showcase repos** (for polyglot.purescri.pt):
   - Code Explorer (corrode-expel) - Node.js backend
   - Grid Explorer (hypo-punter) - PurePy backend
   - Embedding Explorer (hypo-punter) - PurePy backend
   - Tidal Editor (tilted-radio) - Purerl backend
   - Sankey Editor (arid-keystone) - future build tool, will merge with purescript-build
   - Edge Router (scuppered-ligature) - separate repo, IS the Lua backend infrastructure

6. **Documentation**:
   - Simpson's Paradox → docs/tutorials (worked example)

7. **Haskell library ports** (diagrams, linear, machines):
   - Separate repos, not under hylograph umbrella
   - Loosely part of polyglot.purescri.pt showcase

8. **Naming**:
   - Keep anagram codenames as internal/fun names
   - Use descriptive names publicly

### Technical Notes

1. **Registry publishing order** (by dependency):
   - graph → layout → selection → transitions → optics → simulation → music

2. **GitHub**: Start under afcondon, not a trapdoor (can transfer repos later)

---

## Part 5: Timeline

### Phase 1: Foundation (Week 1-2)
- [ ] Finalize library consolidation decisions
- [ ] Set up Cloudflare Pages for hylograph.net
- [ ] Set up Cloudflare Tunnel on MacMini
- [ ] Create polyglot-purescript landing page repo

### Phase 2: Hylograph Release (Week 3-4)
- [ ] Rename all libraries psd3 → hylograph
- [ ] Update all imports and configurations
- [ ] Deploy to hylograph.net
- [ ] Test all demos work

### Phase 3: Polyglot Release (Week 5-6)
- [ ] Build and deploy polyglot.purescri.pt
- [ ] Submit PR to purescript-domain
- [ ] Coordinate with Nick Saunders
- [ ] Submit Lua golden test PR

### Phase 4: Polish & Announce (Week 7-8)
- [ ] Final documentation review
- [ ] Create announcement posts
- [ ] Post to PureScript Discord
- [ ] Post to Reddit/HN if desired

---

## Appendix A: Current Directory Structure

```
PSD3-Repos/
├── visualisation libraries/
│   ├── purescript-psd3-selection      → hylograph-selection
│   ├── purescript-psd3-simulation     → hylograph-simulation
│   ├── purescript-psd3-layout         → hylograph-layout
│   ├── purescript-psd3-graph          → hylograph-graph
│   ├── purescript-psd3-music          → hylograph-music
│   ├── purescript-psd3-transitions    → merge or rename
│   ├── purescript-psd3-optics         → evaluate
│   ├── purescript-psd3-canvas         → evaluate
│   ├── purescript-psd3-d3-kernel      → evaluate
│   ├── purescript-psd3-simulation-core    → merge into simulation
│   ├── purescript-psd3-simulation-halogen → keep
│   ├── purescript-psd3-wasm-kernel    → merge into simulation
│   └── psd3-anscombe-quartet          → move to music lib site
├── showcases/
│   ├── hylograph-app          # Hylograph Explorer (NEW)
│   ├── hylograph-guide        # Interactive tutorial (WIP)
│   ├── corrode-expel          # Code Explorer
│   ├── hypo-punter            # EE + GE (PurePy)
│   ├── psd3-tilted-radio      # Tidal (Purerl)
│   ├── psd3-arid-keystone     # Sankey Editor
│   ├── emptier-coinage        # Optic Menagerie
│   ├── psd3-prim-zoo-mosh     # Morphism Zoo
│   ├── allergy-outlay         # Layout Gallery → move to layout lib
│   ├── psd3-honeycomb         # Honeycomb → move to graph lib
│   ├── simpsons-paradox       # How-to example
│   ├── wasm-force-demo        # WASM proof
│   └── scuppered-ligature     # Edge router (Lua)
├── site/
│   ├── website/               # Main hylograph.net
│   ├── lib-selection/         # Library landing pages
│   ├── lib-simulation/
│   ├── lib-layout/
│   ├── lib-graph/
│   ├── lib-music/
│   └── docs/                  # Antora documentation
└── apps/
    └── shaped-steer           # Full Sankey/build app (separate)
```

## Appendix B: Sites.yaml PR

```yaml
# Add to purescript-domain/sites.yaml
polyglot:
  redirect: https://afcondon.github.io/polyglot-purescript
```

Once the page is ready, change to:
```yaml
polyglot:
  mask: https://afcondon.github.io/polyglot-purescript
```
