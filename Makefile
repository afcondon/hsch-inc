# Polyglot PureScript - Website & Blog
# =====================================
#
# Builds the main website and visualization blog.
# Showcases and apps are in separate repos with their own Makefiles.
#
# Usage:
#   make all       - Build everything
#   make website   - Build the main website
#   make blog      - Build the hylographic blog
#   make clean     - Remove build artifacts
#   make help      - Show all targets

SHELL := /bin/bash
.ONESHELL:

# ============================================================================
# DIRECTORIES
# ============================================================================

SITE := site
BLOG := blog

# ============================================================================
# PHONY TARGETS
# ============================================================================

.PHONY: all website blog lib-sites clean help
.PHONY: lib-site-shell lib-site-selection lib-site-simulation
.PHONY: lib-site-layout lib-site-graph lib-site-music
.PHONY: serve-website serve-blog check-tools
.PHONY: worklog-feed serve-worklog

# ============================================================================
# TOP-LEVEL TARGETS
# ============================================================================

all: website blog
	@echo "============================================"
	@echo "Build complete!"
	@echo "============================================"

# ============================================================================
# WEBSITE
# ============================================================================

website:
	@echo "Building website..."
	cd "$(SITE)/website" && spago build
	@echo "Bundling website..."
	cd "$(SITE)/website" && spago bundle -p demo-website --module Hylograph.Main --outfile public/bundle.js
	@echo "Adding cache-busting version..."
	@TIMESTAMP=$$(date +%s); \
	sed -i.bak 's|bundle\.js[^"]*"|bundle.js?v='$$TIMESTAMP'"|g' "$(SITE)/website/public/index.html" && \
	rm -f "$(SITE)/website/public/index.html.bak"
	@echo "Website build complete"

serve-website: website
	@echo "Starting website at http://localhost:3040"
	cd "$(SITE)/website/public" && python3 -m http.server 3040

# ============================================================================
# BLOG (Hylographic)
# ============================================================================

blog:
	@echo "Building blog (hylographic)..."
	cd "$(BLOG)" && spago build
	@echo "Bundling blog..."
	cd "$(BLOG)" && spago bundle --module Hylographic.Main --outfile public/bundle.js
	@echo "Adding cache-busting version..."
	@TIMESTAMP=$$(date +%s); \
	if [ -f "$(BLOG)/public/index.html" ]; then \
		sed -i.bak 's|bundle\.js[^"]*"|bundle.js?v='$$TIMESTAMP'"|g' "$(BLOG)/public/index.html" && \
		rm -f "$(BLOG)/public/index.html.bak"; \
	fi
	@echo "Blog build complete"

serve-blog: blog
	@echo "Starting blog at http://localhost:3041"
	cd "$(BLOG)/public" && python3 -m http.server 3041

# ============================================================================
# LIBRARY DOCUMENTATION SITES
# ============================================================================

lib-sites: lib-site-shell lib-site-selection lib-site-simulation lib-site-layout lib-site-graph lib-site-music
	@echo "All library sites built"

lib-site-shell:
	@echo "Building lib-shell..."
	cd "$(SITE)/lib-shell" && spago build

lib-site-selection: lib-site-shell
	@echo "Building lib-selection site..."
	cd "$(SITE)/lib-selection" && spago build
	cd "$(SITE)/lib-selection" && spago bundle --module Main --outfile public/bundle.js

lib-site-simulation: lib-site-shell
	@echo "Building lib-simulation site..."
	cd "$(SITE)/lib-simulation" && spago build
	cd "$(SITE)/lib-simulation" && spago bundle --module Main --outfile public/bundle.js

lib-site-layout: lib-site-shell
	@echo "Building lib-layout site..."
	cd "$(SITE)/lib-layout" && spago build
	cd "$(SITE)/lib-layout" && spago bundle --module Main --outfile public/bundle.js

lib-site-graph: lib-site-shell
	@echo "Building lib-graph site..."
	cd "$(SITE)/lib-graph" && spago build
	cd "$(SITE)/lib-graph" && spago bundle --module Main --outfile public/bundle.js

lib-site-music: lib-site-shell
	@echo "Building lib-music site..."
	cd "$(SITE)/lib-music" && spago build
	cd "$(SITE)/lib-music" && spago bundle --module Main --outfile public/bundle.js

# ============================================================================
# WORKLOG FEED
# ============================================================================

worklog-feed:
	@python3 scripts/worklog-feed.py

serve-worklog:
	@python3 scripts/worklog-feed.py --serve 8384

# ============================================================================
# UTILITY TARGETS
# ============================================================================

clean:
	@echo "Cleaning build artifacts..."
	find . -name "output" -type d -not -path "*/node_modules/*" -exec rm -rf {} + 2>/dev/null || true
	find . -name ".spago" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "spago.lock" -delete 2>/dev/null || true
	@echo "Clean complete"

check-tools:
	@echo "Checking build prerequisites..."
	@command -v spago >/dev/null 2>&1 && echo "  ✓ spago" || echo "  ✗ spago (required)"
	@command -v purs >/dev/null 2>&1 && echo "  ✓ purs" || echo "  ✗ purs (required)"
	@command -v node >/dev/null 2>&1 && echo "  ✓ node" || echo "  ✗ node (required)"
	@echo ""

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "Polyglot PureScript - Website & Blog"
	@echo "====================================="
	@echo ""
	@echo "Main targets:"
	@echo "  make all            - Build website and blog"
	@echo "  make website        - Build the main website"
	@echo "  make blog           - Build the hylographic blog"
	@echo "  make lib-sites      - Build all library documentation sites"
	@echo "  make clean          - Remove build artifacts"
	@echo ""
	@echo "Serve targets (for local development):"
	@echo "  make serve-website  - Serve website on :3040"
	@echo "  make serve-blog     - Serve blog on :3041"
	@echo ""
	@echo "Library site targets:"
	@echo "  make lib-site-selection"
	@echo "  make lib-site-simulation"
	@echo "  make lib-site-layout"
	@echo "  make lib-site-graph"
	@echo "  make lib-site-music"
	@echo ""
	@echo "Worklog:"
	@echo "  make worklog-feed   - Generate Atom feed from worklog"
	@echo "  make serve-worklog  - Serve feed on :8384 for NetNewsWire"
	@echo ""
	@echo "Utility:"
	@echo "  make check-tools    - Verify prerequisites"
	@echo ""
	@echo "Note: Showcases and apps are in separate repos:"
	@echo "  ../purescript-hylograph-showcases/"
	@echo "  ../CodeExplorer/"
	@echo "  ../ShapedSteer/"
