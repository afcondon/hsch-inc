# PureScript to Lua compilation test
#
# This is a minimal test demonstrating pslua (purescript-lua) compilation.
# Uses pure PureScript without FFI dependencies.
#
# For full Effect/Console support, you need:
# - Old spago (with dhall support) or manual package setup
# - purescript-lua-package-sets for Lua FFI implementations
# - See: https://github.com/Unisay/purescript-lua-package-sets

PSLUA := $(HOME)/work/afc-work/PSD3-Repos/purescript-lua/.stack-work/install/aarch64-osx/ff2c5124808bbebe37a60d63d95c1572490c2d5c85ba7b1bc0d5263622a6f7ad/9.6.6/bin/pslua

.PHONY: all clean build compile-lua test

all: build compile-lua

# Step 1: Compile PureScript to CoreFn (using purs directly)
build:
	purs compile -g corefn src/**/*.purs

# Step 2: Compile CoreFn to Lua
compile-lua:
	mkdir -p dist
	$(PSLUA) \
		--ps-output output \
		--lua-output-file dist/main.lua \
		--entry Main.main

# Run the compiled Lua (requires lua installed)
test:
	@if command -v lua >/dev/null 2>&1; then \
		echo "Running: lua dist/main.lua"; \
		lua dist/main.lua; \
	elif command -v lua5.4 >/dev/null 2>&1; then \
		echo "Running: lua5.4 dist/main.lua"; \
		lua5.4 dist/main.lua; \
	elif command -v luajit >/dev/null 2>&1; then \
		echo "Running: luajit dist/main.lua"; \
		luajit dist/main.lua; \
	else \
		echo "No Lua interpreter found. Install lua, lua5.4, or luajit."; \
		echo "Output at: dist/main.lua"; \
		cat dist/main.lua; \
	fi

clean:
	rm -rf output dist
