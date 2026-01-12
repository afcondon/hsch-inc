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
  psd3-react | Halogen (site/website)
        ↓
PRESENTATION LAYER
  psd3-music | psd3-tidal
        ↓
INTERACTION LAYER
  psd3-selection (DOM) | psd3-simulation (force)
        ↓
COMPUTATION LAYER
  psd3-layout | psd3-graph
        ↓
FOUNDATION LAYER
  psd3-tree
```

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

**When creating reports**: Use `_TEMPLATE.md` with YAML frontmatter (title, category, status, tags, summary).

**Categories**: architecture, plan, research, reference, howto

**Status values**: active, implemented, stale, superseded

Reports in sub-repos (showcases/, apps/, etc.) are indexed in `INDEX.md` but remain in their original locations.

## Related Documentation

- `docs/kb/INDEX.md` - Knowledge base index (38 reports)
- `docs/kb/reference/claude-context.md` - Comprehensive ecosystem reference
- `docs/worklog/` - Session logs and work-in-progress context
- Purerl Cookbook: https://purerl-cookbook.readthedocs.io/
