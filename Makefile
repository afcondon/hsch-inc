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
.PHONY: app-wasm app-embedding-explorer app-sankey app-code-explorer app-tilted-radio
.PHONY: app-timber-lieder app-edge app-emptier-coinage
.PHONY: wasm-kernel
.PHONY: npm-install npm-install-embedding-explorer npm-install-code-explorer
.PHONY: ee-server ge-server ee-website ge-website landing
.PHONY: ce-database ce-server ce2-website vscode-ext
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
	@echo "Building psd3-graph..."
	cd "$(VIS_LIBS)/purescript-psd3-graph" && spago build

lib-layout:
	@echo "Building psd3-layout..."
	cd "$(VIS_LIBS)/purescript-psd3-layout" && spago build

# Layer 2: Depends on psd3-graph
lib-selection: lib-graph
	@echo "Building psd3-selection..."
	cd "$(VIS_LIBS)/purescript-psd3-selection" && spago build

# Layer 3: Depends on psd3-selection
lib-music: lib-selection
	@echo "Building psd3-music..."
	cd "$(VIS_LIBS)/purescript-psd3-music" && spago build

lib-simulation: lib-selection
	@echo "Building psd3-simulation..."
	cd "$(VIS_LIBS)/purescript-psd3-simulation" && spago build

lib-showcase-shell: lib-selection
	@echo "Building psd3-showcase-shell..."
	cd "$(SITE)/showcase-shell" && spago build

# Layer 4: Depends on psd3-simulation
lib-simulation-halogen: lib-simulation
	@echo "Building psd3-simulation-halogen..."
	cd "$(VIS_LIBS)/purescript-psd3-simulation-halogen" && spago build

# Demo app in visualisation libraries (depends on simulation)
lib-astar-demo: lib-simulation lib-graph
	@echo "Building psd3-astar-demo..."
	cd "$(VIS_LIBS)/psd3-astar-demo" && spago build

# ============================================================================
# SHOWCASE APPLICATIONS
# ============================================================================

apps: app-wasm app-embedding-explorer app-sankey app-code-explorer app-tilted-radio app-timber-lieder app-edge app-emptier-coinage
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
	cd "$(SHOWCASES)/hypo-punter" && npm install

# Embedding Explorer Python backend
ee-server: npm-install-embedding-explorer
	@echo "Building ee-server (PurePy)..."
	cd "$(SHOWCASES)/hypo-punter/ee-server" && spago build
	@echo "Transpiling to Python..."
	cd "$(SHOWCASES)/hypo-punter" && $(PUREPY) output ee-server/output-py
	@echo "Copying FFI files..."
	cp "$(SHOWCASES)/hypo-punter/ee-server/src/Data/UMAP.py" \
	   "$(SHOWCASES)/hypo-punter/ee-server/output-py/data_u_m_a_p_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ee-server/src/Data/GloVe.py" \
	   "$(SHOWCASES)/hypo-punter/ee-server/output-py/data_glo_ve_foreign.py"
	cp "$(SHOWCASES)/hypo-punter/ee-server/src/Server/Flask.py" \
	   "$(SHOWCASES)/hypo-punter/ee-server/output-py/server_flask_foreign.py"

# Grid Explorer Python backend
ge-server: npm-install-embedding-explorer
	@echo "Building ge-server (PurePy)..."
	cd "$(SHOWCASES)/hypo-punter/ge-server" && spago build
	@echo "Transpiling to Python..."
	cd "$(SHOWCASES)/hypo-punter" && $(PUREPY) output ge-server/output-py
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

# Embedding Explorer frontend
ee-website: npm-install-embedding-explorer
	@echo "Building ee-website..."
	cd "$(SHOWCASES)/hypo-punter/ee-website" && spago build
	@echo "Bundling ee-website..."
	cd "$(SHOWCASES)/hypo-punter/ee-website" && spago bundle

# Grid Explorer frontend
ge-website: npm-install-embedding-explorer
	@echo "Building ge-website..."
	cd "$(SHOWCASES)/hypo-punter/ge-website" && spago build
	@echo "Bundling ge-website..."
	cd "$(SHOWCASES)/hypo-punter/ge-website" && spago bundle

# Landing page (Hypo-Punter)
landing: npm-install-embedding-explorer
	@echo "Building landing page..."
	cd "$(SHOWCASES)/hypo-punter/landing" && spago build
	@echo "Bundling landing page..."
	cd "$(SHOWCASES)/hypo-punter/landing" && spago bundle

# ----------------------------------------------------------------------------
# Sankey Editor (psd3-arid-keystone)
# ----------------------------------------------------------------------------

app-sankey: lib-layout lib-selection
	@echo "Installing npm dependencies for sankey editor..."
	cd "$(SHOWCASES)/psd3-arid-keystone" && npm install
	@echo "Building sankey editor..."
	cd "$(SHOWCASES)/psd3-arid-keystone" && spago build
	@echo "Bundling sankey editor..."
	cd "$(SHOWCASES)/psd3-arid-keystone" && spago bundle -p psd3-sankey-editor --module Main --outfile demo/bundle.js

# ----------------------------------------------------------------------------
# TreeBuilder Demo (psd3-timber-lieder)
# ----------------------------------------------------------------------------

app-timber-lieder: lib-selection
	@echo "Installing npm dependencies for timber-lieder..."
	cd "$(SHOWCASES)/psd3-timber-lieder" && npm install
	@echo "Building timber-lieder..."
	cd "$(SHOWCASES)/psd3-timber-lieder" && spago build
	@echo "Bundling timber-lieder..."
	cd "$(SHOWCASES)/psd3-timber-lieder" && spago bundle --module Main --outfile demo/bundle.js

# ----------------------------------------------------------------------------
# Code Explorer (Corrode Expel)
# ----------------------------------------------------------------------------

app-code-explorer: npm-install-code-explorer ce-server ce2-website vscode-ext
	@echo "Code Explorer build complete"

npm-install-code-explorer:
	@echo "Installing npm dependencies for code-explorer..."
	cd "$(SHOWCASES)/corrode-expel" && npm install
	cd "$(SHOWCASES)/corrode-expel/ce-database" && npm install
	cd "$(SHOWCASES)/corrode-expel/code-explorer-vscode-ext" && npm install

# Note: ce-database contains pre-built DuckDB data, no build needed
# The loader/ directory can regenerate it if needed

ce-server: npm-install-code-explorer
	@echo "Building ce-server..."
	cd "$(SHOWCASES)/corrode-expel" && spago build -p ce-server

ce2-website: npm-install-code-explorer lib-layout lib-selection lib-simulation
	@echo "Building ce2-website..."
	cd "$(SHOWCASES)/corrode-expel" && spago build -p ce2-website
	@echo "Bundling ce2-website..."
	cd "$(SHOWCASES)/corrode-expel/ce2-website" && spago bundle --module CE2.Main --outfile public/bundle.js
	@echo "Adding cache-busting timestamp..."
	@TIMESTAMP=$$(date +%s); \
	sed -i '' "s|bundle.js[^\"]*\"|bundle.js?v=$$TIMESTAMP\"|g" "$(SHOWCASES)/corrode-expel/ce2-website/public/index.html"; \
	echo "  bundle.js?v=$$TIMESTAMP"

vscode-ext: npm-install-code-explorer
	@echo "Building VSCode extension..."
	cd "$(SHOWCASES)/corrode-expel/code-explorer-vscode-ext" && npx tsc -p ./

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
.PHONY: serve-sankey serve-timber-lieder serve-code-explorer serve-code-explorer-backend
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

# TreeBuilder Demo (Timber Lieder)
serve-timber-lieder: app-timber-lieder
	@echo "Serving TreeBuilder Demo on port $(PORT)..."
	cd "$(SHOWCASES)/psd3-timber-lieder/demo" && python3 -m http.server $(PORT)

# Code Explorer
serve-code-explorer: ce2-website
	@echo "Serving Code Explorer Frontend on port $(PORT)..."
	cd "$(SHOWCASES)/corrode-expel/ce2-website/public" && python3 -m http.server $(PORT)

serve-code-explorer-backend: ce-server
	@echo "Starting Code Explorer Backend on port 3000..."
	cd "$(SHOWCASES)/corrode-expel/ce-server" && node run.js

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
	cd "$(VIS_LIBS)/psd3-astar-demo" && python3 -m http.server $(PORT)

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
	cd "$(SITE)/website" && spago bundle -p demo-website --module PSD3.Main --outfile public/bundle.js
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
	rm -rf "$(SHOWCASES)/corrode-expel/code-explorer-vscode-ext/out" 2>/dev/null || true
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
	verify_bundle "$(SHOWCASES)/corrode-expel/ce2-website/public" "ce2-website"; \
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
	@echo "  make app-code-explorer - Code explorer"
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
	@echo "  make serve-code-explorer - Code Explorer"
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
