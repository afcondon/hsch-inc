# A Note on FFI for Alternative PureScript Backends

**From:** A user maintaining projects across purerl (Erlang), purepy (Python), and JS backends

**Context:** I'm working on a visualization ecosystem (PSD3) with showcase applications that demonstrate PureScript compiling to multiple backends. This has surfaced some friction in the current FFI story.

## The Problem

When using any non-JavaScript backend, every `foreign import` requires maintaining **two** FFI files:

1. **A JavaScript stub** - Required by the PureScript compiler during `spago build`, even though it's never executed
2. **The actual backend implementation** - Erlang/Python/Go/etc.

For example, a simple `printLine` foreign import needs:

```
src/Main.purs      -- foreign import printLine :: String -> Effect Unit
src/Main.js        -- Stub: export const printLine = (s) => () => console.log(s);
src/Main.py        -- Real: def printLine(s): return lambda: print(s)
```

## How Backends Currently Cope

**Purerl:** Maintains forked versions of core packages (prelude, effect, console, etc.) with both `.js` and `.erl` files side-by-side. Uses a separate package registry (`erl-0.15.3-20220629`). This works but fragments the ecosystem.

**PurePy:** No maintained package ecosystem. Users must create JS stubs manually for every foreign import, then copy Python FFI files post-build. High friction for adoption.

**Future backends (Go, C++, etc.):** Would face the same choice - fork everything or burden users with stub maintenance.

## Potential Solutions

### 1. Compiler flag to skip FFI validation

```bash
purs compile --no-ffi-check
```

Let backends that handle FFI separately opt out of the JS FFI requirement.

### 2. Multi-backend FFI in spago.yaml

```yaml
package:
  name: my-lib
  foreign:
    javascript: src/FFI.js
    erlang: src/FFI.erl
    python: src/FFI.py
```

Spago selects the appropriate FFI based on the target backend.

### 3. Backend-agnostic FFI specification

A declarative format describing FFI contracts:

```yaml
# ffi.yaml
printLine:
  type: "String -> Effect Unit"
  description: "Print a line to stdout"
  implementations:
    javascript: "export const printLine = (s) => () => console.log(s)"
    erlang: "printLine(S) -> fun() -> io:format(\"~s~n\", [S]) end"
    python: "def printLine(s): return lambda: print(s)"
```

With generators for each backend.

### 4. Unified polyglot package registry

Core packages (prelude, effect, etc.) ship FFI for all maintained backends. One registry, multiple targets.

## The Opportunity

PureScript's CoreFn intermediate representation already enables multiple backends beautifully. The friction is entirely in the FFI story. Solving this would:

- Lower the barrier for new backends
- Enable code sharing across the polyglot ecosystem
- Reduce maintenance burden for backend maintainers
- Make PureScript a compelling choice for "write once, run anywhere" scenarios

## See Also

- [Polyglot PureScript Ecosystem](./CLAUDE-CONTEXT.md) - Overview of the PSD3 multi-backend project
- [PurePy Build System](../showcases/hypo-punter/docs/PUREPY-BUILD-SYSTEM.md) - Detailed FFI patterns for Python backend
- [Purerl Cookbook](https://purerl-cookbook.readthedocs.io/) - Erlang backend documentation

---

*January 2026*
