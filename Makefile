# PSD3 Ecosystem - Unified Polyglot Build System
# ================================================
#
# Builds the complete PSD3 visualization ecosystem:
# - PureScript libraries (JS target)
# - PureScript showcase apps (JS bundles)
# - PurePy backends (Python via purepy)
# - Purerl backend (Erlang via purerl)
# - Rust WASM kernel
# - TypeScript VSCode extension
#
# Usage:
#   make all        - Build everything
#   make libs       - Build core libraries only
#   make apps       - Build showcase apps only
#   make clean      - Remove all build artifacts
#   make help       - Show all targets
#
# Prerequisites:
#   spago, purs, purepy, purerl, rebar3, wasm-pack, cargo, npm, node, tsc

SHELL := /bin/bash
.ONESHELL:

# ============================================================================
# TOOL PATHS
# ============================================================================
# Override these if tools are in non-standard locations

# PurePy (PureScript → Python)
PUREPY := $(shell find $(CURDIR)/purescript-python-new/.stack-work -name purepy -type f 2>/dev/null | grep "/bin/" | head -1)
ifeq ($(PUREPY),)
PUREPY := purepy
endif

# Purerl (PureScript → Erlang)
PURERL := $(HOME)/bin/purerl
ifeq ($(wildcard $(PURERL)),)
PURERL := purerl
endif

# wasm-pack (Rust → WASM)
WASM_PACK := $(HOME)/.cargo/bin/wasm-pack
ifeq ($(wildcard $(WASM_PACK)),)
WASM_PACK := wasm-pack
endif

# Rustup-managed Rust (ensure rustup's rust is used, not Homebrew's)
CARGO_BIN := $(HOME)/.cargo/bin
RUST_PATH := $(CARGO_BIN):$(PATH)

# pslua (PureScript → Lua)
PSLUA := $(shell find $(CURDIR)/purescript-lua/.stack-work -name pslua -type f 2>/dev/null | grep "/bin/" | head -1)
ifeq ($(PSLUA),)
PSLUA := pslua
endif

# ============================================================================
# DIRECTORIES
# ============================================================================

# Directories (with spaces - requires careful quoting)
VIS_LIBS := visualisation libraries
SHOWCASES := showcases
SITE := site
APPS := apps

# ============================================================================
# PHONY TARGETS
# ============================================================================

.PHONY: all libs apps clean help
.PHONY: lib-graph lib-layout lib-selection lib-music lib-simulation
.PHONY: lib-showcase-shell lib-simulation-halogen
.PHONY: app-wasm app-embedding-explorer app-sankey app-hylograph app-minard minard-site-explorer spider-analyze spider-compare spider-html app-tilted-radio
.PHONY: app-edge app-emptier-coinage app-simpsons app-nn
.PHONY: wasm-kernel
.PHONY: npm-install npm-install-embedding-explorer npm-install-minard
.PHONY: ee-server ge-server ee-website ge-website landing
.PHONY: minard-database minard-server minard-frontend minard-vscode-ext
.PHONY: purerl-tidal ps-tidal
.PHONY: lib-sites lib-site-selection lib-site-simulation lib-site-layout
.PHONY: lib-site-graph lib-site-music lib-site-shell
.PHONY: website content

# ============================================================================
# TOP-LEVEL TARGETS
# ============================================================================

all: libs apps
	@echo "============================================"
	@echo "PSD3 Ecosystem build complete!"
	@echo "============================================"

# ============================================================================
# LIBRARIES
# ============================================================================

# Build all libraries in dependency order
# Layer 1 → Layer 2 → Layer 3 → Layer 4
# Note: psd3-tree was removed; libraries now depend directly on tree-rose from registry
libs: lib-graph lib-layout lib-selection lib-music lib-simulation \
      lib-showcase-shell lib-simulation-halogen
	@echo "All libraries built successfully"

# Layer 1: Foundation (depends on tree-rose from registry, no PSD3 dependencies)
lib-graph:
	@echo "Building hylograph-graph..."
	cd "$(VIS_LIBS)/purescript-hylograph-graph" && spago build

lib-layout:
	@echo "Building hylograph-layout..."
	cd "$(VIS_LIBS)/purescript-hylograph-layout" && spago build

# Layer 2: Depends on psd3-graph
lib-selection: lib-graph
	@echo "Building hylograph-selection..."
	cd "$(VIS_LIBS)/purescript-hylograph-selection" && spago build

# Layer 3: Depends on psd3-selection
lib-music: lib-selection
	@echo "Building hylograph-music..."
	cd "$(VIS_LIBS)/purescript-hylograph-music" && spago build

lib-simulation: lib-selection
	@echo "Building hylograph-simulation..."
	cd "$(VIS_LIBS)/purescript-hylograph-simulation" && spago build

lib-showcase-shell: lib-selection
	@echo "Building hylograph-showcase-shell..."
	cd "$(SITE)/showcase-shell" && spago build

# Layer 4: Depends on psd3-simulation
lib-simulation-halogen: lib-simulation
	@echo "Building hylograph-simulation-halogen..."
	cd "$(VIS_LIBS)/purescript-hylograph-simulation-halogen" && spago build

# Demo app in visualisation libraries (depends on simulation)
lib-astar-demo: lib-simulation lib-graph
	@echo "Building hylograph-astar-demo..."
	cd "$(VIS_LIBS)/hylograph-astar-demo" && spago build

# ============================================================================
# SHOWCASE APPLICATIONS
# ============================================================================

apps: app-wasm app-embedding-explorer app-sankey app-hylograph app-minard minard-site-explorer app-tilted-radio app-edge app-emptier-coinage
	@echo "All applications built successfully"

# ----------------------------------------------------------------------------
# WASM Force Demo
# ----------------------------------------------------------------------------

app-wasm: wasm-kernel lib-simulation
	@echo "Building wasm-force-demo PureScript..."
	cd "$(SHOWCASES)/wasm-force-demo" && spago build
	@echo "Bundling wasm-force-demo..."
	cd "$(SHOWCASES)/wasm-force-demo" && spago bundle --module Main --outfile dist/bundle.js

wasm-kernel:
	@echo "Building force-kernel (Rust → WASM)..."
	cd "$(SHOWCASES)/wasm-force-demo/force-kernel" && PATH="$(RUST_PATH)" $(WASM_PACK) build --target web --out-dir ../pkg

# ----------------------------------------------------------------------------
# Embedding Explorer (PurePy + JS frontends)
# ----------------------------------------------------------------------------

app-embedding-explorer: ee-server ge-server ee-website ge-website landing
	@echo "Embedding Explorer build complete"

npm-install-embedding-explorer:
	@echo "Installing npm dependencies for embedding-explorer..."
	cd "$(SHOWCASES)/hypo-punter" && npm install --ignore-scripts

# Embedding Explorer Python backend (standalone workspace)
ee-server: npm-install-embedding-explorer
	@echo "Building ee-server (PurePy)..."
	cd "$(SHOWCASES)/hypo-punter/ee-server" && spago build
	@echo "Transpiling to Python..."
	cd "$(SHOWCASES)/hypo-punter/ee-server" && $(PUREPY) output output-py
	@echo "Copying FFI files..."
	cp "$(SHOWCASES)/hypo-punter/ee-server/src/Data/UMAP.py" \
	   "$(SHOWCASES)/hypo-punter/ee-server/output-py/data_u_m_a_p_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ee-server/src/Data/GloVe.py" \
	   "$(SHOWCASES)/hypo-punter/ee-server/output-py/data_glo_ve_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ee-server/src/Server/Flask.py" \
	   "$(SHOWCASES)/hypo-punter/ee-server/output-py/server_flask_foreign.py"

# Grid Explorer Python backend (standalone workspace)
ge-server: npm-install-embedding-explorer
	@echo "Building ge-server (PurePy)..."
	cd "$(SHOWCASES)/hypo-punter/ge-server" && spago build
	@echo "Transpiling to Python..."
	cd "$(SHOWCASES)/hypo-punter/ge-server" && $(PUREPY) output output-py
	@echo "Copying FFI files..."
	cp "$(SHOWCASES)/hypo-punter/ge-server/src/Grid/PowerFlow.py" \
	   "$(SHOWCASES)/hypo-punter/ge-server/output-py/grid_power_flow_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ge-server/src/Grid/Cascade.py" \
	   "$(SHOWCASES)/hypo-punter/ge-server/output-py/grid_cascade_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ge-server/src/Grid/Contingency.py" \
	   "$(SHOWCASES)/hypo-punter/ge-server/output-py/grid_contingency_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ge-server/src/Grid/Metrics.py" \
	   "$(SHOWCASES)/hypo-punter/ge-server/output-py/grid_metrics_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ge-server/src/Server/Flask.py" \
	   "$(SHOWCASES)/hypo-punter/ge-server/output-py/server_flask_foreign.py"

# Embedding Explorer frontend (run from workspace root for correct path resolution)
ee-website: npm-install-embedding-explorer
	@echo "Building ee-website..."
	cd "$(SHOWCASES)/hypo-punter" && spago build -p ee-website
	@echo "Bundling ee-website..."
	cd "$(SHOWCASES)/hypo-punter" && spago bundle -p ee-website

# Grid Explorer frontend (run from workspace root for correct path resolution)
ge-website: npm-install-embedding-explorer
	@echo "Building ge-website..."
	cd "$(SHOWCASES)/hypo-punter" && spago build -p ge-website
	@echo "Bundling ge-website..."
	cd "$(SHOWCASES)/hypo-punter" && spago bundle -p ge-website

# Landing page (Hypo-Punter) (run from workspace root for correct path resolution)
landing: npm-install-embedding-explorer
	@echo "Building landing page..."
	cd "$(SHOWCASES)/hypo-punter" && spago build -p landing
	@echo "Bundling landing page..."
	cd "$(SHOWCASES)/hypo-punter" && spago bundle -p landing

# ----------------------------------------------------------------------------
# Sankey Editor (psd3-arid-keystone)
# ----------------------------------------------------------------------------

app-sankey: lib-layout lib-selection
	@echo "Installing npm dependencies for sankey editor..."
	cd "$(SHOWCASES)/psd3-arid-keystone" && npm install
	@echo "Building sankey editor..."
	cd "$(SHOWCASES)/psd3-arid-keystone" && spago build
	@echo "Bundling sankey editor..."
	cd "$(SHOWCASES)/psd3-arid-keystone" && spago bundle -p hylograph-sankey-editor --module Main --outfile demo/bundle.js

# ----------------------------------------------------------------------------
# Hylograph (Interactive HATS Explorer)
# ----------------------------------------------------------------------------

app-hylograph: lib-selection
	@echo "Installing npm dependencies for hylograph..."
	cd "$(SHOWCASES)/hylograph-app" && npm install
	@echo "Building hylograph..."
	cd "$(SHOWCASES)/hylograph-app" && spago build
	@echo "Bundling hylograph..."
	cd "$(SHOWCASES)/hylograph-app" && spago bundle -p hylograph-app --module Main --outfile public/bundle.js

# ----------------------------------------------------------------------------
# Minard (Code Cartography - promoted from Corrode Expel)
# ----------------------------------------------------------------------------

app-minard: npm-install-minard minard-server minard-frontend minard-vscode-ext
	@echo "Minard build complete"

npm-install-minard:
	@echo "Installing npm dependencies for minard..."
	cd "$(APPS)/minard" && npm install
	cd "$(APPS)/minard/database" && npm install
	cd "$(APPS)/minard/vscode-extension" && npm install

# Note: minard-database contains pre-built DuckDB data, no build needed
# The loader/ directory can regenerate it if needed

minard-server: npm-install-minard
	@echo "Building minard-server..."
	cd "$(APPS)/minard" && spago build -p minard-server

minard-frontend: npm-install-minard lib-layout lib-selection lib-simulation
	@echo "Building minard-frontend..."
	cd "$(APPS)/minard" && spago build -p minard-frontend
	@echo "Bundling minard-frontend..."
	cd "$(APPS)/minard/frontend" && spago bundle --module CE2.Main --outfile public/bundle.js
	@echo "Adding cache-busting timestamp..."
	@TIMESTAMP=$$(date +%s); \
	sed -i '' "s|bundle.js[^\"]*\"|bundle.js?v=$$TIMESTAMP\"|g" "$(APPS)/minard/frontend/public/index.html"; \
	echo "  bundle.js?v=$$TIMESTAMP"

minard-vscode-ext: npm-install-minard
	@echo "Building Minard VSCode extension..."
	cd "$(APPS)/minard/vscode-extension" && npx tsc -p ./

# ----------------------------------------------------------------------------
# Minard Site Explorer (route analysis tool - part of Minard)
# ----------------------------------------------------------------------------

minard-site-explorer:
	@echo "Building minard-site-explorer (route analysis tool)..."
	cd "$(APPS)/minard/site-explorer" && npm install
	cd "$(APPS)/minard/site-explorer" && spago build
	@echo "Minard Site Explorer build complete"
	@echo "Run with: cd apps/minard/site-explorer && node run.js"

spider-analyze: minard-site-explorer
	@echo "Spidering deployed site at http://100.101.177.83..."
	cd "$(APPS)/minard/site-explorer" && node run.js spider http://100.101.177.83
	@echo ""
	@echo "Results written to apps/minard/site-explorer/"

spider-compare: minard-site-explorer
	@echo "Comparing static analysis with live spidering..."
	cd "$(APPS)/minard/site-explorer" && node run.js compare ../../../site/website http://100.101.177.83
	@echo ""
	@echo "Results written to apps/minard/site-explorer/"

spider-html: minard-site-explorer
	@echo "Generating HTML report..."
	cd "$(APPS)/minard/site-explorer" && node run.js html ../../../site/website http://100.101.177.83
	@echo "Report: apps/minard/site-explorer/site-explorer.html"

# ----------------------------------------------------------------------------
# Tilted Radio (Tidal Editor - Purerl + PureScript)
# ----------------------------------------------------------------------------

app-tilted-radio: purerl-tidal ps-tidal
	@echo "Tilted Radio build complete"

# Erlang backend
purerl-tidal:
	@echo "Building purerl-tidal (Erlang backend)..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purerl-tidal" && spago build
	@echo "Transpiling to Erlang..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purerl-tidal" && $(PURERL)
	@echo "Compiling Erlang (rebar3 deps)..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purerl-tidal" && rebar3 compile
	@echo "Compiling purerl output to BEAM..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purerl-tidal" && find output -name "*.erl" -exec erlc -o ebin {} \;

# PureScript frontend
ps-tidal: lib-layout lib-selection lib-simulation lib-showcase-shell
	@echo "Building purescript-psd3-tidal..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purescript-psd3-tidal" && spago build
	@echo "Bundling purescript-psd3-tidal..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purescript-psd3-tidal" && spago bundle

# ----------------------------------------------------------------------------
# Emptier Coinage (Optics Showcase)
# ----------------------------------------------------------------------------

app-emptier-coinage: lib-layout lib-selection
	@echo "Building emptier-coinage..."
	cd "$(SHOWCASES)/emptier-coinage" && spago build
	@echo "Bundling emptier-coinage..."
	cd "$(SHOWCASES)/emptier-coinage" && spago bundle --platform browser --bundle-type app --outfile public/bundle.js

# ----------------------------------------------------------------------------
# Scuppered Ligature (Edge Layer - Lua)
# ----------------------------------------------------------------------------

app-edge:
	@echo "Building scuppered-ligature (PureScript → Lua)..."
	cd "$(SHOWCASES)/scuppered-ligature" && spago build
	@echo "Compiling to Lua..."
	@if [ -x "$(PSLUA)" ]; then \
		cd "$(SHOWCASES)/scuppered-ligature" && $(PSLUA) --foreign-path lua-ffi --ps-output output --lua-output-file dist/edge.lua --entry Main; \
	else \
		echo "WARNING: pslua not found, skipping Lua compilation"; \
		echo "  Install from: https://github.com/Unisay/purescript-lua"; \
		echo "  Existing dist/edge.lua will be used"; \
	fi

# ----------------------------------------------------------------------------
# Simpson's Paradox (HATS Showcase)
# ----------------------------------------------------------------------------

app-simpsons: lib-selection lib-simulation
	@echo "Building simpsons-paradox..."
	cd "$(SHOWCASES)/simpsons-paradox" && spago build
	@echo "Bundling simpsons-paradox..."
	cd "$(SHOWCASES)/simpsons-paradox" && spago bundle --module Simpsons.Main --outfile public/bundle.js

# ----------------------------------------------------------------------------
# Hylograph-NN (Neural Network Diagrams via Catamorphism)
# ----------------------------------------------------------------------------

app-nn: lib-selection lib-simulation lib-simulation-halogen
	@echo "Building hylograph-nn..."
	cd "$(SHOWCASES)/hylograph-nn" && spago build
	@echo "Bundling hylograph-nn..."
	cd "$(SHOWCASES)/hylograph-nn" && spago bundle --module Main --outfile public/bundle.js

# ============================================================================
# LIBRARY DOCUMENTATION SITES
# ============================================================================
# Landing pages for each PSD3 library, served at /psd3/<lib>/

# Generate Main.purs from library READMEs
lib-site-generate:
	@echo "Generating Halogen pages from library READMEs..."
	node tools/readme-to-halogen.mjs all

# Build all library sites
lib-sites: lib-site-shell lib-site-selection lib-site-simulation lib-site-layout lib-site-graph lib-site-music
	@echo "All library sites built successfully"

# Shared shell component (dependency for all lib sites)
lib-site-shell:
	@echo "Building lib-shell (shared component)..."
	cd "$(SITE)/lib-shell" && spago build

# Individual library sites
lib-site-selection: lib-site-shell
	@echo "Building lib-selection site..."
	cd "$(SITE)/lib-selection" && spago build
	@echo "Bundling lib-selection..."
	cd "$(SITE)/lib-selection" && spago bundle --module Main --outfile public/bundle.js

lib-site-simulation: lib-site-shell
	@echo "Building lib-simulation site..."
	cd "$(SITE)/lib-simulation" && spago build
	@echo "Bundling lib-simulation..."
	cd "$(SITE)/lib-simulation" && spago bundle --module Main --outfile public/bundle.js

lib-site-layout: lib-site-shell
	@echo "Building lib-layout site..."
	cd "$(SITE)/lib-layout" && spago build
	@echo "Bundling lib-layout..."
	cd "$(SITE)/lib-layout" && spago bundle --module Main --outfile public/bundle.js

lib-site-graph: lib-site-shell
	@echo "Building lib-graph site..."
	cd "$(SITE)/lib-graph" && spago build
	@echo "Bundling lib-graph..."
	cd "$(SITE)/lib-graph" && spago bundle --module Main --outfile public/bundle.js

lib-site-music: lib-site-shell
	@echo "Building lib-music site..."
	cd "$(SITE)/lib-music" && spago build
	@echo "Bundling lib-music..."
	cd "$(SITE)/lib-music" && spago bundle --module Main --outfile public/bundle.js

# ============================================================================
# SERVE TARGETS (for dev-dashboard integration)
# ============================================================================

.PHONY: serve-wasm serve-ee serve-ee-backend serve-ge serve-ge-backend
.PHONY: serve-sankey serve-minard serve-minard-backend
.PHONY: serve-tidal serve-tidal-backend serve-astar serve-landing
.PHONY: serve-website serve-dashboard

# Default ports (can be overridden: make serve-ee PORT=9087)
PORT ?= 8080

# Dev Dashboard
serve-dashboard:
	@echo "Starting Dev Dashboard on port 9000..."
	cd "$(SITE)/dashboard" && node server.js

# WASM Force Demo
serve-wasm: app-wasm
	@echo "Serving WASM Force Demo on port $(PORT)..."
	cd "$(SHOWCASES)/wasm-force-demo" && python3 -m http.server $(PORT)

# Embedding Explorer
serve-ee: ee-website
	@echo "Serving Embedding Explorer Frontend on port $(PORT)..."
	cd "$(SHOWCASES)/hypo-punter/ee-website/public" && python3 -m http.server $(PORT)

serve-ee-backend: ee-server
	@echo "Starting Embedding Explorer Backend on port 5081..."
	cd "$(SHOWCASES)/hypo-punter/ee-server" && \
		python3 -c "import sys; sys.path.insert(0, 'output-py'); from main import main; main()()"

# Grid Explorer
serve-ge: ge-website
	@echo "Serving Grid Explorer Frontend on port $(PORT)..."
	cd "$(SHOWCASES)/hypo-punter/ge-website/public" && python3 -m http.server $(PORT)

serve-ge-backend: ge-server
	@echo "Starting Grid Explorer Backend on port 5082..."
	cd "$(SHOWCASES)/hypo-punter/ge-server" && \
		python3 -c "import sys; sys.path.insert(0, 'output-py'); from main import main; main()()"

# Hypo-Punter Landing
serve-landing: landing
	@echo "Serving Hypo-Punter Landing on port $(PORT)..."
	cd "$(SHOWCASES)/hypo-punter/landing/public" && python3 -m http.server $(PORT)

# Sankey Editor
serve-sankey: app-sankey
	@echo "Serving Sankey Editor on port $(PORT)..."
	cd "$(SHOWCASES)/psd3-arid-keystone/demo" && python3 -m http.server $(PORT)

# Hylograph (HATS Explorer)
serve-hylograph: app-hylograph
	@echo "Serving Hylograph on port $(PORT)..."
	cd "$(SHOWCASES)/hylograph-app/public" && python3 -m http.server $(PORT)

# Minard (Code Cartography)
serve-minard: minard-frontend
	@echo "Serving Minard Frontend on port $(PORT)..."
	cd "$(APPS)/minard/frontend/public" && python3 -m http.server $(PORT)

serve-minard-backend: minard-server
	@echo "Starting Minard Backend on port 3000..."
	cd "$(APPS)/minard/server" && node run.js

# Tidal Editor (Tilted Radio)
serve-tidal: ps-tidal
	@echo "Serving Tidal Frontend on port $(PORT)..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purescript-psd3-tidal" && python3 -m http.server $(PORT)

serve-tidal-backend: purerl-tidal
	@echo "Starting Tidal Erlang Backend..."
	cd "$(SHOWCASES)/psd3-tilted-radio/purerl-tidal" && rebar3 shell

# A* Demo
serve-astar: lib-astar-demo
	@echo "Serving A* Demo on port $(PORT)..."
	cd "$(VIS_LIBS)/hylograph-astar-demo" && python3 -m http.server $(PORT)

# Content Generation (Markdown → Halogen)
content:
	@echo "Generating Halogen from Markdown..."
	@if [ -d "content" ] && [ -n "$$(find content -name '*.md' 2>/dev/null)" ]; then \
		node tools/md-to-halogen/index.js --dir content --out-dir $(SITE)/website/src/Content; \
	else \
		echo "  No markdown files in content/, skipping."; \
	fi

# Demo Website
website: content
	@echo "Building demo-website..."
	cd "$(SITE)/website" && spago build
	@echo "Bundling demo-website..."
	cd "$(SITE)/website" && spago bundle -p demo-website --module Hylograph.Main --outfile public/bundle.js
	@echo "Adding cache-busting version to bundle.js..."
	@TIMESTAMP=$$(date +%s); \
	sed -i.bak 's|bundle\.js[^"]*"|bundle.js?v='$$TIMESTAMP'"|g' "$(SITE)/website/public/index.html" && \
	rm -f "$(SITE)/website/public/index.html.bak"
	@echo "  Bundle version: $$(grep -o 'bundle.js?v=[0-9]*' $(SITE)/website/public/index.html)"

serve-website: website
	@echo "Starting server at http://localhost:$(PORT)/#/home"
	cd "$(SITE)/website/public" && python3 -m http.server $(PORT)

# ============================================================================
# CLEAN
# ============================================================================

clean:
	@echo "Cleaning build artifacts..."
	# PureScript output directories
	find . -name "output" -type d -not -path "*/node_modules/*" -exec rm -rf {} + 2>/dev/null || true
	find . -name ".spago" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "spago.lock" -delete 2>/dev/null || true
	# PurePy output
	find . -name "output-py" -type d -exec rm -rf {} + 2>/dev/null || true
	# Purerl/Erlang output
	find . -name "_build" -type d -exec rm -rf {} + 2>/dev/null || true
	# Clean ebin contents but preserve directory (needed for purerl builds)
	find . -name "ebin" -type d -exec sh -c 'rm -f "$$1"/*.beam "$$1"/*.bea* 2>/dev/null' _ {} \; 2>/dev/null || true
	# WASM output
	rm -rf "$(SHOWCASES)/wasm-force-demo/pkg" 2>/dev/null || true
	rm -rf "$(SHOWCASES)/wasm-force-demo/force-kernel/target" 2>/dev/null || true
	rm -rf "$(SHOWCASES)/wasm-force-demo/force-kernel/pkg" 2>/dev/null || true
	# Bundle outputs
	rm -f "$(SHOWCASES)/wasm-force-demo/dist/bundle.js" 2>/dev/null || true
	rm -f "$(SHOWCASES)/psd3-arid-keystone/demo/bundle.js" 2>/dev/null || true
	# TypeScript output
	rm -rf "$(APPS)/minard/vscode-extension/out" 2>/dev/null || true
	@echo "Clean complete"

clean-deps: clean
	@echo "Cleaning dependencies (node_modules)..."
	find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Dependencies cleaned"

# ============================================================================
# PREREQUISITE TESTS
# ============================================================================

.PHONY: test-prereqs test-purerl test-purepy test-wasm verify-bundles

# Test all backend prerequisites
test-prereqs: test-purerl test-purepy test-wasm
	@echo "All prerequisite tests passed!"

# Test Purerl (PureScript → Erlang) toolchain
test-purerl:
	@echo "Testing Purerl toolchain..."
	cd "$(SITE)/tests/purerl-test" && spago build
	cd "$(SITE)/tests/purerl-test" && $(PURERL)
	cd "$(SITE)/tests/purerl-test" && rebar3 compile
	@echo "✓ Purerl test passed"

# Test PurePy (PureScript → Python) toolchain
test-purepy:
	@echo "Testing PurePy toolchain..."
	cd "$(SITE)/tests/purepy-test" && spago build
	cd "$(SITE)/tests/purepy-test" && $(PUREPY) output output-py
	cp "$(SITE)/tests/purepy-test/src/Main.py" "$(SITE)/tests/purepy-test/output-py/main_foreign.py"
	cd "$(SITE)/tests/purepy-test" && python3 -c "import sys; sys.path.insert(0, 'output-py'); from main import main; main()"
	@echo "✓ PurePy test passed"

# Test WASM (Rust → WebAssembly) toolchain
test-wasm:
	@echo "Testing WASM toolchain..."
	cd "$(SITE)/tests/wasm-test" && PATH="$(RUST_PATH)" $(WASM_PACK) build --target web
	@echo "✓ WASM test passed"

# Clean test outputs
clean-tests:
	rm -rf "$(SITE)/tests/purerl-test/output" "$(SITE)/tests/purerl-test/_build" 2>/dev/null || true
	rm -rf "$(SITE)/tests/purepy-test/output" "$(SITE)/tests/purepy-test/output-py" 2>/dev/null || true
	rm -rf "$(SITE)/tests/wasm-test/target" "$(SITE)/tests/wasm-test/pkg" 2>/dev/null || true
	@echo "Test outputs cleaned"

# ============================================================================
# UTILITY TARGETS
# ============================================================================

# Verify browser bundle co-location (bundle.js/index.js/app.js in same dir as index.html)
# Allowed bundle names: bundle.js, index.js, app.js
verify-bundles:
	@echo "Verifying browser bundle co-location..."
	@echo "Required name: bundle.js (no exceptions)"
	@echo ""
	@ERRORS=0; \
	verify_bundle() { \
		local dir="$$1"; \
		local name="$$2"; \
		if [ ! -f "$$dir/index.html" ]; then \
			echo "  ? $$name: no index.html in $$dir"; \
			return; \
		fi; \
		local found=0; \
		for bundle in bundle.js; do \
			if grep -q "$$bundle" "$$dir/index.html" 2>/dev/null; then \
				if [ -f "$$dir/$$bundle" ]; then \
					echo "  ✓ $$name: $$bundle"; \
					found=1; \
					break; \
				else \
					echo "  ✗ $$name: index.html references $$bundle but file MISSING"; \
					ERRORS=1; \
					found=1; \
					break; \
				fi; \
			fi; \
		done; \
		if [ $$found -eq 0 ]; then \
			if grep -qE "(bundle|index|app)\.js" "$$dir/index.html" 2>/dev/null; then \
				echo "  ? $$name: index.html references JS but path may include subdirectory"; \
			else \
				echo "  ? $$name: no standard bundle reference in index.html"; \
			fi; \
		fi; \
	}; \
	echo "Showcases:"; \
	verify_bundle "$(SHOWCASES)/psd3-arid-keystone/demo" "sankey-editor"; \
	verify_bundle "$(SHOWCASES)/hypo-punter/landing/public" "landing"; \
	verify_bundle "$(SHOWCASES)/hypo-punter/ee-website/public" "ee-website"; \
	verify_bundle "$(SHOWCASES)/hypo-punter/ge-website/public" "ge-website"; \
	verify_bundle "$(APPS)/minard/frontend/public" "minard-frontend"; \
	verify_bundle "$(SHOWCASES)/psd3-tilted-radio/purescript-psd3-tidal" "psd3-tidal"; \
	verify_bundle "$(SHOWCASES)/psd3-lorenz-attractor/demo" "lorenz-attractor"; \
	echo ""; \
	echo "Site:"; \
	verify_bundle "$(SITE)/website/public" "demo-website"; \
	verify_bundle "$(SITE)/react-proof/demo" "react-proof"; \
	verify_bundle "$(SITE)/showcase-shell/demo" "showcase-shell-demo"; \
	echo ""; \
	if [ $$ERRORS -eq 1 ]; then \
		echo "ERROR: Bundle verification failed"; \
		exit 1; \
	else \
		echo "✓ All bundles verified"; \
	fi

# Check that all required tools are installed
check-tools:
	@echo "PSD3 Build Prerequisites Check"
	@echo "==============================="
	@echo ""
	@ERRORS=0; \
	echo "Core tools (required for all builds):"; \
	command -v spago >/dev/null 2>&1 && echo "  ✓ spago: $$(spago --version 2>/dev/null || echo 'installed')" || { echo "  ✗ spago (REQUIRED - install via npm)"; ERRORS=1; }; \
	command -v purs >/dev/null 2>&1 && echo "  ✓ purs: $$(purs --version 2>/dev/null)" || { echo "  ✗ purs (REQUIRED - install PureScript compiler)"; ERRORS=1; }; \
	command -v npm >/dev/null 2>&1 && echo "  ✓ npm: $$(npm --version)" || { echo "  ✗ npm (REQUIRED)"; ERRORS=1; }; \
	command -v node >/dev/null 2>&1 && echo "  ✓ node: $$(node --version)" || { echo "  ✗ node (REQUIRED)"; ERRORS=1; }; \
	echo ""; \
	echo "PurePy tools (for embedding-explorer backends):"; \
	if [ -x "$(PUREPY)" ]; then echo "  ✓ purepy: $$($(PUREPY) --version 2>/dev/null | head -1)"; else echo "  ✗ purepy (build from purescript-python-new/)"; fi; \
	command -v python3 >/dev/null 2>&1 && echo "  ✓ python3: $$(python3 --version)" || echo "  ✗ python3"; \
	echo ""; \
	echo "Purerl tools (for purerl-tidal):"; \
	if [ -x "$(PURERL)" ]; then echo "  ✓ purerl: $(PURERL)"; else echo "  ✗ purerl (download from purerl releases)"; fi; \
	command -v rebar3 >/dev/null 2>&1 && echo "  ✓ rebar3: $$(rebar3 --version 2>/dev/null | head -1)" || echo "  ✗ rebar3"; \
	command -v erl >/dev/null 2>&1 && echo "  ✓ erlang: $$(erl -eval 'io:format(\"~s\", [erlang:system_info(otp_release)]), halt().' -noshell 2>/dev/null)" || echo "  ✗ erlang"; \
	echo ""; \
	echo "pslua tools (for scuppered-ligature edge layer):"; \
	command -v $(PSLUA) >/dev/null 2>&1 && echo "  ✓ pslua: $$($(PSLUA) --version 2>/dev/null | head -1)" || echo "  ○ pslua (optional - from github.com/Unisay/purescript-lua)"; \
	echo ""; \
	echo "WASM tools (for wasm-force-demo):"; \
	if [ -x "$(WASM_PACK)" ]; then echo "  ✓ wasm-pack: $$($(WASM_PACK) --version 2>/dev/null)"; else echo "  ✗ wasm-pack (cargo install wasm-pack)"; fi; \
	command -v cargo >/dev/null 2>&1 && echo "  ✓ cargo: $$(cargo --version)" || echo "  ✗ cargo"; \
	if [ -x "$(HOME)/.cargo/bin/rustup" ]; then \
		WASM_TARGET=$$($(HOME)/.cargo/bin/rustup target list 2>/dev/null | grep "wasm32-unknown-unknown (installed)" || true); \
		if [ -n "$$WASM_TARGET" ]; then echo "  ✓ wasm32 target: installed"; else echo "  ✗ wasm32 target (rustup target add wasm32-unknown-unknown)"; fi; \
	else \
		echo "  ? wasm32 target: rustup not found"; \
	fi; \
	echo ""; \
	echo "TypeScript (for vscode extension):"; \
	command -v tsc >/dev/null 2>&1 && echo "  ✓ tsc: $$(tsc --version)" || echo "  ○ tsc (will use npx)"; \
	echo ""; \
	if [ $$ERRORS -eq 1 ]; then echo "ERROR: Missing required tools"; exit 1; fi; \
	echo "✓ All required tools present"

# Setup prerequisites (interactive helper)
setup:
	@echo "PSD3 Build Setup"
	@echo "================"
	@echo ""
	@echo "This will help you set up missing prerequisites."
	@echo ""
	@echo "1. Core tools (if missing):"
	@echo "   npm install -g spago purescript"
	@echo ""
	@echo "2. PurePy (for Python backends):"
	@echo "   cd purescript-python-new && stack build && stack install"
	@echo ""
	@echo "3. Purerl (for Erlang backend):"
	@echo "   Download from: https://github.com/purerl/purerl/releases"
	@echo "   Place in: ~/bin/purerl"
	@echo ""
	@echo "4. WASM tools (for Rust/WASM):"
	@echo "   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
	@echo "   source ~/.cargo/env"
	@echo "   rustup target add wasm32-unknown-unknown"
	@echo "   cargo install wasm-pack"
	@echo ""
	@echo "5. Erlang/OTP (for purerl):"
	@echo "   brew install erlang rebar3"
	@echo ""
	@echo "6. Python dependencies (for PurePy backends):"
	@echo "   make install-python-deps"
	@echo ""
	@echo "Run 'make check-tools' to verify your setup."

# Install Python dependencies for PurePy backends
install-python-deps:
	@echo "Installing Python dependencies..."
	pip install flask flask-cors umap-learn numpy pandapower networkx

# Show resolved tool paths
show-config:
	@echo "PSD3 Build Configuration"
	@echo "========================"
	@echo ""
	@echo "Directories:"
	@echo "  VIS_LIBS:  $(VIS_LIBS)"
	@echo "  SHOWCASE:  $(SHOWCASES)"
	@echo ""
	@echo "Tool paths:"
	@echo "  PUREPY:    $(PUREPY)"
	@echo "  PURERL:    $(PURERL)"
	@echo "  PSLUA:     $(PSLUA)"
	@echo "  WASM_PACK: $(WASM_PACK)"
	@echo ""
	@echo "To override, run: make PUREPY=/path/to/purepy <target>"

# Print the dependency graph
deps-graph:
	@echo "PSD3 Library Dependency Graph"
	@echo "=============================="
	@echo ""
	@echo "Layer 1 (foundation, depends on tree-rose from registry):"
	@echo "  psd3-graph ──→ tree-rose"
	@echo "  psd3-layout ─→ tree-rose"
	@echo ""
	@echo "Layer 2 (depends on graph):"
	@echo "  psd3-selection ─→ psd3-graph"
	@echo ""
	@echo "Layer 3 (depends on selection):"
	@echo "  psd3-music ─────────→ psd3-selection"
	@echo "  psd3-simulation ────→ psd3-selection"
	@echo "  psd3-showcase-shell → psd3-selection"
	@echo ""
	@echo "Layer 4 (depends on simulation):"
	@echo "  psd3-simulation-halogen → psd3-simulation"

# Generate Sankey-compatible CSV/JSON from Makefile dependencies
deps-csv:
	@node scripts/makefile-to-sankey.js

deps-json:
	@node scripts/makefile-to-sankey.js --json

# Convenience aliases
dashboard: serve-dashboard

# ============================================================================
# DOCKER TARGETS
# ============================================================================

.PHONY: docker-build docker-up docker-down docker-logs docker-clean
.PHONY: docker-prepare docker-deploy docker-status

# Build all Docker images (run 'make apps' first to compile everything)
docker-build:
	@echo "Building Docker images..."
	docker-compose build

# Start the full stack
docker-up:
	@echo "Starting Docker stack..."
	docker-compose up -d
	@echo ""
	@echo "Services starting. Access at:"
	@echo "  http://localhost/           - Landing page"
	@echo "  http://localhost/dashboard  - Dev dashboard"
	@echo "  http://localhost:9000/      - Dashboard (direct)"
	@echo ""
	@echo "Run 'make docker-logs' to follow logs"

# Stop all containers
docker-down:
	@echo "Stopping Docker stack..."
	docker-compose down

# Follow logs
docker-logs:
	docker-compose logs -f

# Show status
docker-status:
	@echo "Docker stack status:"
	@docker-compose ps

# Remove all containers and images
docker-clean:
	@echo "Removing Docker containers and images..."
	docker-compose down --rmi all -v

# Full preparation: build apps + build Docker images
docker-prepare: apps docker-build
	@echo ""
	@echo "============================================"
	@echo "Docker images ready!"
	@echo "============================================"
	@docker images | grep -E "^psd3|REPOSITORY"

# Deploy to remote host via SSH
# Usage: make docker-deploy HOST=user@macmini
docker-deploy:
	@if [ -z "$(HOST)" ]; then \
		echo "Usage: make docker-deploy HOST=user@host"; \
		echo ""; \
		echo "This will:"; \
		echo "  1. SSH to the remote host"; \
		echo "  2. Pull latest code from git"; \
		echo "  3. Run 'make docker-prepare'"; \
		echo "  4. Start the Docker stack"; \
		exit 1; \
	fi
	@echo "=== Deploying to $(HOST) ==="
	@echo ""
	@echo "Checking SSH connectivity..."
	@ssh -o ConnectTimeout=5 $(HOST) "echo 'SSH OK'" || { echo "SSH failed"; exit 1; }
	@echo ""
	@echo "Checking Docker on remote..."
	@ssh $(HOST) "docker --version" || { echo "Docker not found on remote"; exit 1; }
	@echo ""
	@echo "Pulling latest code and building..."
	@ssh $(HOST) "cd ~/psd3 && git pull && make docker-prepare && make docker-up"
	@echo ""
	@echo "=== Deployment complete ==="
	@echo "Access at: http://$(HOST)/"

# ============================================================================
# FOCUS MANAGEMENT (for Claude Code sessions)
# ============================================================================
# Switch development focus to a specific profile. This:
# 1. Updates .claude-focus (Claude reads this at session start)
# 2. Stops all containers
# 3. Starts only the containers for the selected profile
#
# Usage: make focus-minard  (before starting a Claude session)

.PHONY: focus-core focus-minard focus-tidal focus-hypo focus-sankey focus-wasm focus-libs focus-showcases focus-full focus-status focus-stop

# Focus: Core only (edge + website)
focus-core:
	@echo "Switching focus to: core"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: core" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile core up -d
	@echo ""
	@echo "Focus set to: core (local)"
	@echo "Test URL: http://localhost/"
	@docker compose ps

# Focus: Minard (Code Cartography)
focus-minard:
	@echo "Switching focus to: minard"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: minard" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/code/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - minard-frontend" >> .claude-focus
	@echo "  - minard-backend" >> .claude-focus
	@echo "  - site-explorer" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile minard up -d
	@echo ""
	@echo "Focus set to: minard (local)"
	@echo "Test URL: http://localhost/code/"
	@docker compose ps

# Focus: Tidal (Tilted Radio)
focus-tidal:
	@echo "Switching focus to: tidal"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: tidal" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/tidal/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - tidal-frontend" >> .claude-focus
	@echo "  - tidal-backend" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile tidal up -d
	@echo ""
	@echo "Focus set to: tidal (local)"
	@echo "Test URL: http://localhost/tidal/"
	@docker compose ps

# Focus: Hypo-Punter (EE + GE)
focus-hypo:
	@echo "Switching focus to: hypo"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: hypo" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/ee/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - ee-frontend" >> .claude-focus
	@echo "  - ee-backend" >> .claude-focus
	@echo "  - ge-frontend" >> .claude-focus
	@echo "  - ge-backend" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile hypo up -d
	@echo ""
	@echo "Focus set to: hypo (local)"
	@echo "Test URLs: http://localhost/ee/  http://localhost/ge/"
	@docker compose ps

# Focus: Sankey Editor
focus-sankey:
	@echo "Switching focus to: sankey"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: sankey" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/sankey/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - sankey" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile sankey up -d
	@echo ""
	@echo "Focus set to: sankey (local)"
	@echo "Test URL: http://localhost/sankey/"
	@docker compose ps

# Focus: WASM Demo
focus-wasm:
	@echo "Switching focus to: wasm"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: wasm" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/wasm/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - wasm-demo" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile wasm up -d
	@echo ""
	@echo "Focus set to: wasm (local)"
	@echo "Test URL: http://localhost/wasm/"
	@docker compose ps

# Focus: Library documentation sites
focus-libs:
	@echo "Switching focus to: libs"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: libs" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/psd3/selection/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - lib-selection" >> .claude-focus
	@echo "  - lib-simulation" >> .claude-focus
	@echo "  - lib-layout" >> .claude-focus
	@echo "  - lib-graph" >> .claude-focus
	@echo "  - lib-music" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile libs up -d
	@echo ""
	@echo "Focus set to: libs (local)"
	@echo "Test URL: http://localhost/psd3/selection/"
	@docker compose ps

# Focus: Other showcases
focus-showcases:
	@echo "Switching focus to: showcases"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: showcases" >> .claude-focus
	@echo "target: local" >> .claude-focus
	@echo "test_url: http://localhost/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - edge" >> .claude-focus
	@echo "  - website" >> .claude-focus
	@echo "  - optics" >> .claude-focus
	@echo "  - zoo" >> .claude-focus
	@echo "  - layouts" >> .claude-focus
	@echo "  - hylograph" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@docker compose --profile showcases up -d
	@echo ""
	@echo "Focus set to: showcases (local)"
	@echo "Test URL: http://localhost/"
	@docker compose ps

# Focus: Full stack (everything) - DEPLOYS TO MACMINI, NOT LOCAL
focus-full:
	@echo "Switching focus to: full (REMOTE - MacMini)"
	@echo "# .claude-focus - Current Development Focus" > .claude-focus
	@echo "#" >> .claude-focus
	@echo "# This file tells Claude which services matter for this session." >> .claude-focus
	@echo "# Run \`make focus-<profile>\` to switch focus." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# CLAUDE: You MUST read this file at session start and before any build/deploy." >> .claude-focus
	@echo "# Only build/deploy services listed here unless the user explicitly overrides." >> .claude-focus
	@echo "#" >> .claude-focus
	@echo "# NOTE: Full stack deploys to MacMini, NOT local Docker!" >> .claude-focus
	@echo "# Build locally with make, deploy with /deploy <service> remote" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "profile: full" >> .claude-focus
	@echo "target: remote" >> .claude-focus
	@echo "remote_host: andrew@100.101.177.83" >> .claude-focus
	@echo "remote_path: ~/psd3" >> .claude-focus
	@echo "test_url: http://100.101.177.83/" >> .claude-focus
	@echo "" >> .claude-focus
	@echo "services:" >> .claude-focus
	@echo "  - all (full stack on MacMini)" >> .claude-focus
	@docker compose down --remove-orphans 2>/dev/null || true
	@echo ""
	@echo "============================================"
	@echo "Focus set to: full (REMOTE - MacMini)"
	@echo "============================================"
	@echo ""
	@echo "Local containers stopped. Builds happen locally, deploy to MacMini:"
	@echo "  1. make <target>                    # Build locally"
	@echo "  2. /deploy <service> remote         # Deploy to MacMini"
	@echo "  3. Test at http://100.101.177.83/"
	@echo ""
	@echo "Or deploy everything:"
	@echo "  /deploy all remote"
	@echo ""

# Show current focus
focus-status:
	@echo "Current focus:"
	@echo "=============="
	@if [ -f .claude-focus ]; then \
		grep -E "^profile:|^target:|^test_url:" .claude-focus; \
		echo ""; \
		echo "Services:"; \
		grep -A 20 "^services:" .claude-focus | grep "  -" | head -10; \
	else \
		echo "No focus set (run 'make focus-<profile>')"; \
	fi
	@echo ""
	@echo "Running local containers:"
	@docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || echo "  (none)"

# Stop all containers (no focus)
focus-stop:
	@echo "Stopping all containers..."
	@docker compose down --remove-orphans
	@echo "profile: none" > .claude-focus
	@echo "target: none" >> .claude-focus
	@echo "All local containers stopped"

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "PSD3 Monorepo Build System"
	@echo "=========================="
	@echo ""
	@echo "Main targets:"
	@echo "  make all          - Build everything (libs + apps)"
	@echo "  make libs         - Build all PureScript libraries"
	@echo "  make apps         - Build all applications"
	@echo "  make website      - Build main demo website"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make clean-deps   - Remove node_modules too"
	@echo ""
	@echo "Library targets:"
	@echo "  make lib-graph    - Graph algorithms (depends on tree-rose)"
	@echo "  make lib-layout   - Layout algorithms"
	@echo "  make lib-selection - D3-style selections"
	@echo "  make lib-music    - Music/audio support"
	@echo "  make lib-simulation - Force simulation"
	@echo "  make lib-simulation-halogen - Halogen bindings"
	@echo ""
	@echo "Application targets:"
	@echo "  make app-wasm     - WASM force demo"
	@echo "  make app-embedding-explorer - EE + GE apps"
	@echo "  make app-sankey   - Sankey editor"
	@echo "  make app-minard   - Minard code cartography (frontend + server + vscode)"
	@echo "  make minard-site-explorer - Site explorer (route analysis)"
	@echo "  make spider-analyze     - Spider deployed site for routes"
	@echo "  make spider-compare     - Compare static vs live routes"
	@echo "  make spider-html        - Generate HTML route report"
	@echo "  make app-tilted-radio - Tidal/algorave"
	@echo "  make app-edge     - Edge layer (Lua)"
	@echo ""
	@echo "Library site targets (landing pages at /psd3/<lib>/):"
	@echo "  make lib-sites    - Build all library landing pages"
	@echo "  make lib-site-selection - Selection library site"
	@echo "  make lib-site-simulation - Simulation library site"
	@echo "  make lib-site-layout - Layout library site"
	@echo "  make lib-site-graph - Graph library site"
	@echo "  make lib-site-music - Music library site"
	@echo ""
	@echo "Serve targets (run dev servers):"
	@echo "  make dashboard    - Dev dashboard (:9000)"
	@echo "  make serve-website - Demo website"
	@echo "  make serve-wasm   - WASM demo"
	@echo "  make serve-ee     - Embedding Explorer frontend"
	@echo "  make serve-ge     - Grid Explorer frontend"
	@echo "  make serve-sankey - Sankey Editor"
	@echo "  make serve-minard - Minard (Code Cartography)"
	@echo "  make serve-tidal  - Tidal Editor"
	@echo "  make serve-astar  - A* Demo"
	@echo ""
	@echo "Docker targets:"
	@echo "  make docker-build   - Build all Docker images"
	@echo "  make docker-up      - Start the stack"
	@echo "  make docker-down    - Stop the stack"
	@echo "  make docker-logs    - Follow container logs"
	@echo "  make docker-status  - Show container status"
	@echo "  make docker-prepare - Build apps + Docker images"
	@echo "  make docker-deploy HOST=user@host - Deploy remotely"
	@echo ""
	@echo "Focus targets (for Claude Code sessions):"
	@echo "  make focus-core   - Edge + website only (~2 containers)"
	@echo "  make focus-minard - Code cartography"
	@echo "  make focus-tidal  - Tilted Radio music editor"
	@echo "  make focus-hypo   - Hypo-Punter EE/GE explorers"
	@echo "  make focus-sankey - Sankey editor"
	@echo "  make focus-wasm   - WASM force demo"
	@echo "  make focus-libs   - Library documentation sites"
	@echo "  make focus-showcases - Other showcase apps"
	@echo "  make focus-full   - Everything (~20 containers)"
	@echo "  make focus-status - Show current focus"
	@echo "  make focus-stop   - Stop all containers"
	@echo ""
	@echo "Utility targets:"
	@echo "  make check-tools  - Verify prerequisites"
	@echo "  make verify-bundles - Check bundle co-location"
	@echo "  make test-prereqs - Test all backend toolchains"
	@echo "  make test-purerl  - Test Purerl (Erlang)"
	@echo "  make test-purepy  - Test PurePy (Python)"
	@echo "  make test-wasm    - Test WASM (Rust)"
	@echo "  make setup        - Setup instructions"
	@echo "  make show-config  - Show resolved paths"
	@echo "  make deps-graph   - Show dependency graph"
	@echo "  make deps-csv     - Export dependencies as CSV"
	@echo "  make deps-json    - Export dependencies as JSON"
