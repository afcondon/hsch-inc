# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Design Philosophy

**Declarative over imperative**: PSD3 takes control from D3 - we use D3's mathematical algorithms (force simulation, scales, layouts) but manage state and rendering declaratively through PureScript. Code describes *what* visualizations look like, not *how* to mutate them.

**Prefer public libraries**: Use packages from the current Spago registry rather than reinventing. Only build custom solutions for truly novel domains.

**Code quality standards**: Everything is either library code or demo code - both must be principled, idiomatic PureScript. No quick hacks. Code should serve as documentation of best practices.

## Repository Structure

```
PSD3-Repos/
├── visualisation libraries/    # Core publishable PSD3 libraries
├── site/                       # Demo infrastructure
│   ├── website/                # Halogen demo site
│   ├── dashboard/              # Dev dashboard (Node.js)
│   ├── react-proof/            # React integration proof
│   ├── showcase-shell/         # Reusable Halogen demo shell
│   ├── styling/                # psd3.css house style
│   └── docs/                   # Antora documentation
├── showcases/                  # Showcase applications
│   ├── hypo-punter/            # PurePy demos (EE + GE)
│   ├── corrode-expel/          # Code explorer
│   ├── psd3-tilted-radio/      # Tidal/Purerl algorave
│   ├── psd3-arid-keystone/     # Sankey editor
│   └── wasm-force-demo/        # Rust WASM demo
├── apps/                       # Full applications (not showcases)
│   └── shaped-steer/           # Spreadsheet/build/WASM app
├── _external/                  # Music ecosystem (separate project)
│   ├── tarot-music/
│   └── ES-config/
├── tools/                      # Build tools
├── scripts/                    # Utility scripts
└── purescript-python-new/      # PurePy compiler (convenience)
```

## Build Commands

### Unified Build System (Makefile)
```bash
make all              # Build everything
make libs             # Build core libraries only
make apps             # Build showcase apps only
make check-tools      # Verify prerequisites
make help             # Show all targets
make dashboard        # Start dev dashboard on :9000
```

### Standard PureScript (JavaScript target)
```bash
spago build          # Compile
spago bundle         # Bundle for browser
spago test           # Run tests
```

### PurePy (Python target)
```bash
spago build && purepy output output-py && cp src/*_foreign.py output-py/
```

### Purerl (Erlang target)
```bash
spago build && purerl && rebar3 compile
```

### Dev Dashboard
```bash
make dashboard        # Or: cd site/dashboard && node server.js
```

## Architecture

```
SHOWCASE APPLICATIONS
  Corrode Expel | Hypo-Punter | Arid Keystone | Tilted Radio
        ↓
FRAMEWORK INTEGRATIONS
  psd3-simulation-halogen | Halogen (site/website)
        ↓
DOMAIN LAYER
  psd3-music | psd3-simulation (force)
        ↓
CORE LAYER
  psd3-selection (DOM + HATS AST)
        ↓
COMPUTATION LAYER
  psd3-layout | psd3-graph
```

**HATS** (Hylomorphic Abstract Tree Syntax) is the new declarative AST in psd3-selection for describing visualization trees. It enables multiple interpreters (D3, English descriptions, Mermaid diagrams) from a single specification.

## Anagram Codenames

- **Hypo-Punter** = Pure Python (PurePy showcase)
- **Corrode Expel** = Code Explorer
- **Arid Keystone** = Sankey Editor
- **Tilted Radio** = Tidal Editor
- **Shaped Steer** = Spreadsheet (full app, not showcase)

## spago.yaml Path Conventions

Projects reference PSD3 libraries via workspace `extraPackages`. Paths vary by nesting:
- Site projects: `path: "../visualisation libraries/purescript-psd3-*"`
- Showcases: `path: "../../visualisation libraries/purescript-psd3-*"`
- Nested showcases: `path: "../../../visualisation libraries/purescript-psd3-*"`

## FFI Patterns

Effects are thunks (zero-argument functions) across all backends:

**JavaScript**: `export const readFile = path => () => fs.readFileSync(path, 'utf8');`

**Python**:
```python
def readFile(path):
    def effect():
        with open(path) as f:
            return f.read()
    return effect
```

**Erlang**:
```erlang
readFile(Path) ->
  fun() -> {ok, Content} = file:read_file(Path), Content end.
```

Multi-argument functions must be curried: `def add(x): return lambda y: x + y`

## Module Naming (Alternative Backends)

- **Python**: `Data.Array` → `data_array.py`, FFI → `data_array_foreign.py`
- **Erlang**: `Foo.Bar` → `foo_bar@ps`, FFI → `foo_bar@foreign`

## PureScript Gotchas (Differs from Haskell)

These catch even experienced Haskellers:

| Function | Haskell | PureScript | Fix |
|----------|---------|------------|-----|
| `sqrt` | In `Prelude` via `Floating` | `Data.Number.sqrt` (explicit import) | `import Data.Number (sqrt)` |
| `scanl` | Includes initial value: `scanl (+) 0 [1,2,3] = [0,1,3,6]` | **Excludes** initial value: `scanl (+) 0 [1,2,3] = [1,3,6]` | Prepend initial: `[0] <> scanl (+) 0 xs` |
| `show` for `Number` | Shows decimal | May show scientific notation | Use `Number.Format` for control |

## Build Conventions (MANDATORY)

### Rule Zero: Makefile Only
**ALL builds go through `make`.** Never run raw `spago bundle`, `purepy`, `purerl`, or backend-specific commands directly. The Makefile handles the complexity of 6+ backends.

If a make target is missing, broken, or out of date, **fix the Makefile first**.

Why: In this polyglot environment, "most probable build command" guesses are often wrong. The Makefile encodes the actual conventions.

### Browser Targets (JS)

**Co-location rule**: `index.html` and its bundle (`bundle.js` or `index.js`) MUST be in the same directory.

| Pattern | index.html | bundle | serve from |
|---------|-----------|--------|------------|
| Standard | `public/index.html` | `public/bundle.js` | `public/` |
| Demo | `demo/index.html` | `demo/bundle.js` | `demo/` |
| Root | `index.html` | `index.js` | project root |

**Verification**: After bundling, check that the script src in index.html matches the actual bundle filename and location.

**Bundle naming**: MUST be `bundle.js`. No exceptions.

**spago.yaml vs Makefile**: When Makefile provides explicit `--outfile`, it overrides spago.yaml. Both must agree on the final location.

### PurePy Targets (Python)

```
project/
├── src/
│   ├── Main.purs
│   └── Module.py          # Foreign file
├── output/                 # spago build output
└── output-py/             # purepy transpile output
    ├── main.py
    └── module_foreign.py  # Copied from src/
```

**FFI convention**: `src/Foo/Bar.py` → `output-py/foo_bar_foreign.py`

The Makefile handles the copy step. Don't manually copy foreign files.

### Purerl Targets (Erlang)

```
project/
├── src/                   # PureScript source
├── output/                # spago build output
├── src/                   # Erlang output (purerl)
└── _build/                # rebar3 output
```

**Build sequence**: `spago build` → `purerl` → `rebar3 compile`

### WASM Targets (Rust)

WASM projects don't use PureScript bundles for the browser. The Rust/wasm-pack output goes to `pkg/` and is imported directly as ES module.

### Lua Targets

Output via `pslua --ps-output output`. Foreign files use Lua-specific packages from `github.com/Unisay/purescript-lua-*`.

### When Debugging Bundle Issues

Before assuming browser caching:
1. Verify the bundle file exists at the expected location
2. Verify index.html references the correct filename
3. Check Makefile for the actual `--outfile` path
4. Run `make <target>` not raw `spago bundle`

## Deployment Policy (MANDATORY)

**Always use full Docker deployment.** Never spin up ad-hoc HTTP servers (`python -m http.server`, etc.) for testing. This eliminates:
- PID file management and stale processes
- Port conflicts requiring `lsof` to debug
- Bundles going to wrong locations
- Confusion about which URL to test

### Two Deployment Targets

| Target | Machine | Port | Command |
|--------|---------|------|---------|
| **Local** (default) | MacBook Pro | 80 | `docker compose up -d` |
| **Remote** | MacMini | 80 | rsync + SSH docker commands |

**Default is always local Docker.** The full stack runs on the MacBook Pro.

### Local Deployment Workflow

```bash
# 1. Build the artifact
make <target>           # e.g., make app-minard, make website

# 2. Rebuild and restart the container
docker compose build --no-cache <service>
docker compose up -d <service>

# 3. Test at http://localhost/<path>
```

### Remote Deployment Workflow

```bash
# 1. Build locally
make <target>

# 2. Rsync to MacMini
rsync -avz --delete <local-path>/ andrew@100.101.177.83:~/psd3/<remote-path>/

# 3. Rebuild container on MacMini
ssh andrew@100.101.177.83 "cd ~/psd3 && /usr/local/bin/docker compose build --no-cache <service> && /usr/local/bin/docker compose up -d <service>"
```

### Key Points

- **Containers bake in files at build time** - rsync updates host files but container has old files until rebuilt
- **Always rebuild containers after code changes** - never assume rsync alone is sufficient
- **Use cache busters** - verify `bundle.js?v=<timestamp>` in index.html matches what's served
- **Local Docker is the source of truth** for testing - if it works locally, deploy to remote

## Focus Management (MANDATORY)

The `.claude-focus` file at the repo root tells Claude which services matter for the current session. **You MUST read this file at session start and before any build/deploy operation.**

### How It Works

1. User runs `make focus-<profile>` before starting a Claude session
2. This updates `.claude-focus` and starts only the relevant containers
3. Claude reads `.claude-focus` to understand which services to build/deploy

### Available Profiles

| Profile | Services | Use Case |
|---------|----------|----------|
| `core` | edge, website | Minimal baseline (~2 containers) |
| `minard` | + minard-frontend, minard-backend, site-explorer | Code cartography work |
| `tidal` | + tidal-frontend, tidal-backend | Music/algorave work |
| `hypo` | + ee-*, ge-* | Embedding/Grid explorer work |
| `sankey` | + sankey | Sankey editor work |
| `wasm` | + wasm-demo | Rust/WASM work |
| `libs` | + lib-* | Library documentation sites |
| `showcases` | + optics, zoo, layouts, hylograph | Other showcases |
| `full` | Everything | Full stack (~20 containers) |

### Commands

```bash
make focus-minard   # Switch to minard profile
make focus-status   # Show current focus
make focus-stop     # Stop all containers
```

### Claude: Required Behavior

1. **At session start**: Read `.claude-focus` to understand scope
2. **Before building**: Only build services listed in the focus file
3. **Before deploying**: Only deploy/rebuild containers in the focus file
4. **If user asks for something outside focus**: Ask if they want to switch profiles

## Absolute Prohibitions (MANDATORY)

The following actions are **NEVER acceptable**, regardless of convenience or perceived helpfulness:

### 1. NO Ad-Hoc HTTP Servers

**Never** run `python -m http.server`, `npx serve`, `php -S`, `ruby -run`, or any equivalent.

- All serving goes through Docker containers
- Ad-hoc servers cause port conflicts, stale processes, and deployment confusion
- If you find yourself wanting to spin up a quick server, **stop** and use Docker instead

### 2. NO Custom Ports

Services are accessed through port 80 via the edge router. **Never** tell the user to visit `:8080`, `:3000`, `:5000`, etc. directly.

- Correct: `http://localhost/code/`
- Wrong: `http://localhost:3000/`

### 3. NO Deployment Without Reading Focus

Before any build or deploy operation, **read `.claude-focus`**. Only operate on services listed there unless the user explicitly overrides.

### 4. NO Full Stack When Focus Is Set

If `.claude-focus` specifies a profile other than `full`, do not build or deploy services outside that profile. This wastes resources and causes confusion.

### 5. NO Guessing Deployment Details

If you're unsure how to deploy something, **read the `/deploy` skill** or **ask the user**. Do not invent deployment commands based on what "probably works."

### Why These Rules Exist

These prohibitions exist because context loss across sessions has repeatedly led to:
- Services deployed via ad-hoc servers instead of Docker
- Port conflicts requiring `lsof` debugging
- Bundles deployed to wrong locations
- User confusion about which URL to test
- Full stack running when only one service was needed

Following these rules ensures consistent, predictable deployments.

## Session Logging (MANDATORY)

At the end of substantive sessions, update `docs/worklog/YYYY-MM-DD.md`:

1. **Accomplished**: What was completed
2. **Explored But Not Pursued**: Paths investigated but deliberately set aside, with reasoning (this is critical - these are the things that slip through cracks)
3. **Parking Lot**: Ideas, questions, or tasks surfaced but not addressed
4. **Decisions Made**: Technical or architectural choices with brief rationale
5. **Reports Generated**: Links to any detailed reports
6. **Next Session Setup**: Context needed to resume efficiently

Use `docs/worklog/_TEMPLATE.md` as the template. Multiple sessions on the same day append to the same file with a horizontal rule separator.

**When to log**: Any session involving design decisions, exploration of alternatives, or work that spans multiple concerns. Skip for trivial fixes.

**What makes this valuable**: The "Explored But Not Pursued" and "Parking Lot" sections capture what traditional reports miss - the paths not taken and the ideas that surfaced but weren't addressed.

## Knowledge Base

The `docs/kb/` directory contains classified technical reports:

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

### For Claude: When to Consult the KB

1. **At session start**: If the task involves unfamiliar territory (a showcase you haven't touched, a backend you're unsure about), skim `INDEX.md` for relevant reports.

2. **Before designing**: Check `architecture/` and `plans/` for existing decisions. Don't reinvent what's already been designed.

3. **When stuck**: The `howto/` guides and `reference/` docs often have solutions to common problems.

4. **Key document**: `kb/reference/claude-context.md` is the comprehensive ecosystem reference - consult it for the big picture.

### For Claude: Maintaining the KB

- **After substantive work**: If you produced analysis, design docs, or plans worth preserving, add them to the KB or update `INDEX.md` to point to them.

- **When finding stale docs**: Note in the worklog if a report appears outdated. Don't delete without user confirmation.

- **Promote vs index**: Copy to `kb/` only for key cross-cutting docs. Most reports stay in their source repos and are just indexed.

### For User: Quick Reference

- **Find reports**: `docs/kb/INDEX.md` has everything with status and tags
- **Add new report**: Copy `_TEMPLATE.md`, fill frontmatter, place in appropriate category
- **Print for offline**: Reports are designed to be readable as standalone documents

**Categories**: architecture, plan, research, reference, howto

**Status values**: active, implemented, stale, superseded

## Related Documentation

- `docs/kb/INDEX.md` - Knowledge base index (38 reports)
- `docs/kb/reference/claude-context.md` - Comprehensive ecosystem reference
- `docs/worklog/` - Session logs and work-in-progress context
- Purerl Cookbook: https://purerl-cookbook.readthedocs.io/
