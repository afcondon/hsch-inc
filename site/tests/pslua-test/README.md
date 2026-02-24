# PureScript Lua Test

Minimal test demonstrating the PureScript to Lua compilation pipeline using
[pslua](https://github.com/Unisay/purescript-lua).

## Quick Start

```bash
make all      # Compile PureScript -> CoreFn -> Lua
make test     # Run the compiled Lua (requires lua installed)
```

## Pipeline

1. **PureScript -> CoreFn**: `purs compile -g corefn`
2. **CoreFn -> Lua**: `pslua --ps-output output --lua-output-file dist/main.lua`

## Current Limitations

This test uses **pure PureScript without FFI dependencies**. For full
Effect/Console support, you need:

1. **Old spago** with dhall support, OR manual package downloads
2. **purescript-lua-package-sets** for Lua FFI implementations
3. Lua FFI files alongside PureScript sources

### FFI Pattern

pslua expects Lua foreign files in this format:

```lua
-- Module.lua (next to Module.purs)
return {
  foreignName = (function(arg)
    return function()
      -- effect body
    end
  end)
}
```

## References

- [purescript-lua](https://github.com/Unisay/purescript-lua) - The Lua backend
- [purescript-lua-package-sets](https://github.com/Unisay/purescript-lua-package-sets) - Package set with Lua FFI
- pslua is built from source in `/purescript-lua/` using Stack
