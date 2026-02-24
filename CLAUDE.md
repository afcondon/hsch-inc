# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What This Repo Is

**purescript-polyglot** contains the main website and visualization blog for the Hylograph ecosystem. It's part of a multi-repo structure:

| Repository | Purpose |
|------------|---------|
| **purescript-polyglot** (this repo) | Website + Blog |
| `purescript-hylograph-libs` | Core visualization libraries |
| `purescript-hylograph-showcases` | Showcase applications |
| `CodeExplorer` | Minard code cartography app |
| `ShapedSteer` | Spreadsheet/build app |
| `purescript-backends` | Alternative backends (purerl, purepy) |
| `purescript-ports` | Haskell library ports |

## Repository Structure

```
purescript-polyglot/
├── blog/                    # Hylographic - visualization blog
│   ├── src/                 # PureScript source
│   ├── public/              # Static assets + bundle
│   └── posts/               # Blog post content
├── site/
│   ├── website/             # Main demo website
│   ├── lib-*/               # Library documentation sites
│   ├── showcase-shell/      # Reusable Halogen shell component
│   ├── dashboard/           # Dev dashboard
│   └── tests/               # Backend toolchain tests
├── docs/
│   ├── kb/                  # Knowledge base
│   └── worklog/             # Session logs
├── scripts/                 # Utility scripts
├── tools/                   # Build tools
└── spikes/                  # Experimental code
```

## Build Commands

```bash
make all            # Build website and blog
make website        # Build the main website
make blog           # Build the hylographic blog
make lib-sites      # Build library documentation sites
make clean          # Remove build artifacts
make help           # Show all targets
```

### Local Development

```bash
make serve-website  # Serve website on :8080
make serve-blog     # Serve blog on :8081
```

## Design Philosophy

**Declarative over imperative**: We use D3's algorithms but manage state declaratively through PureScript.

**Registry packages**: The hylograph-* libraries are published to the PureScript registry. Projects use versioned dependencies, not relative paths.

**Code quality**: Everything is either library code or demo code - both must be principled, idiomatic PureScript.

## Cross-Repo Dependencies

The blog and website depend on packages in sibling repos via relative paths in `spago.yaml`:

```yaml
# blog/spago.yaml references:
hylograph-prim-zoo-mosh:
  path: "../../purescript-hylograph-showcases/psd3-prim-zoo-mosh"

# site/website/spago.yaml references:
hylograph-tidal:
  path: "../../../purescript-hylograph-showcases/psd3-tilted-radio/purescript-psd3-tidal"
```

These cross-repo references require the sibling repos to be checked out at the expected locations.

## Deployment

Docker orchestration is at the parent directory level (`afc-work/`) where it has visibility of all repos. This repo just builds static bundles.

## Session Logging

At the end of substantive sessions, update `docs/worklog/YYYY-MM-DD.md`:

1. **Accomplished**: What was completed
2. **Explored But Not Pursued**: Paths investigated but set aside
3. **Parking Lot**: Ideas surfaced but not addressed
4. **Decisions Made**: Technical choices with rationale
5. **Next Session Setup**: Context for resuming

## Knowledge Base

The `docs/kb/` directory contains technical documentation:

- `INDEX.md` - Master index of all reports
- `architecture/` - System design documents
- `plans/` - Implementation roadmaps
- `research/` - Analysis and investigations
- `reference/` - Specifications and status docs
- `howto/` - Practical guides
