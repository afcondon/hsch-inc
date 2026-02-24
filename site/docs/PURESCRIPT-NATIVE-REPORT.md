# purescript-native Analysis Report

**Repository:** https://github.com/andyarvanitis/purescript-native
**Author:** Andy Arvanitis
**Last Updated:** December 10, 2020 (4+ years dormant)
**Target PureScript Version:** 0.13.8 (current is 0.15.x)

## Overview

purescript-native is a PureScript backend that compiles to native executables via C++ or Go as intermediate languages. It's architecturally similar to pslua (which we just worked with) - both read PureScript's CoreFn JSON output and generate target language code.

There are two backends on separate branches:
- **pscpp** (cpp branch, default) - generates C++11
- **psgo** (golang branch) - generates Go

## Architecture

```
PureScript Source
       │
       ▼ (purs compiler)
    CoreFn JSON
       │
       ▼ (pscpp/psgo)
  IL (Intermediate)
       │
       ├── Optimizer (Inliner, TCO, MagicDo)
       │
       ▼
  C++ / Go Source
       │
       ▼ (clang/gcc/go)
  Native Binary
```

### Source Structure

```
purescript-native/
├── app/Main.hs              # Entry point
├── src/
│   ├── CodeGen/IL.hs        # CoreFn → IL translation
│   ├── CodeGen/IL/
│   │   ├── Common.hs        # Shared utilities
│   │   ├── Printer.hs       # IL → C++ pretty printer
│   │   └── Optimizer/
│   │       ├── Inliner.hs   # Function inlining
│   │       ├── TCO.hs       # Tail call optimization
│   │       └── MagicDo.hs   # Do-notation optimization
│   └── Tests.hs
└── runtime/
    ├── purescript.h         # Core runtime types
    ├── purescript.cpp       # Runtime implementation
    ├── functions.h          # Function wrapper templates
    ├── dictionary.h         # Record/dictionary type
    └── recursion.h          # Recursive binding support
```

## C++ Runtime Model

### The `boxed` Type

All PureScript values are represented as a `boxed` type:

```cpp
class boxed {
    std::shared_ptr<void> shared;  // Heap-allocated values
    union {
        int _int_;
        double _double_;
        bool _bool_;
    };
    // ...
};
```

Key design decisions:
- **Reference counting** via `std::shared_ptr` (no GC)
- **Primitives** (int, double, bool) stored in union for efficiency
- **Heap values** (strings, arrays, records, functions) via shared_ptr

### Type Mappings

| PureScript | C++ |
|------------|-----|
| `Int` | `int` (in union) |
| `Number` | `double` (in union) |
| `Boolean` | `bool` (in union) |
| `String` | `std::string` (heap) |
| `Array a` | `std::vector<boxed>` (heap) |
| `{ ... }` | `dict_t` custom map (heap) |
| `a -> b` | `fn_t` function wrapper (heap) |
| `Effect a` | `eff_fn_t` thunk wrapper (heap) |

### Memory Management

Uses C++11 reference counting (`std::shared_ptr`):
- Automatic cleanup when refcount hits zero
- No stop-the-world GC pauses
- Potential for retain cycles with mutual recursion (compiler emits warnings)

```cpp
// Generated code uses shared_ptr automatically
boxed myValue = std::make_shared<string>("hello");
// Automatically freed when no more references
```

## FFI Model

FFI uses C++ macros:

```cpp
FOREIGN_BEGIN(Data_String)

exports["length"] = [](const boxed& s) -> boxed {
    return static_cast<int>(unbox<string>(s).length());
};

exports["charAt"] = [](const boxed& i_) -> boxed {
    return [=](const boxed& s_) -> boxed {
        // implementation
    };
};

FOREIGN_END
```

Separate FFI library: https://github.com/andyarvanitis/purescript-native-cpp-ffi

## Comparison with pslua

| Aspect | pslua | pscpp |
|--------|-------|-------|
| Target | Lua | C++11 |
| Output | Interpreted | Native binary |
| Memory | Lua GC | Reference counting |
| Last update | Active (2024) | Dormant (2020) |
| PureScript version | 0.15.x compatible | 0.13.8 |
| FFI format | Lua tables | C++ macros |
| Runtime deps | Lua/LuaJIT | C++ stdlib only |
| Use case | Embedding (nginx, games) | Standalone apps, perf-critical |

## Current State Assessment

### Strengths
1. **True native compilation** - no runtime interpreter needed
2. **Portable C++11** - works on many platforms (tested on macOS, Windows, Linux, Raspberry Pi)
3. **Predictable performance** - no GC pauses, reference counting is deterministic
4. **Good optimizer** - TCO, inlining, MagicDo optimizations
5. **Clean architecture** - well-structured Haskell codebase

### Weaknesses
1. **Dormant** - 4+ years without updates
2. **Outdated** - targets PureScript 0.13.8 (current is 0.15.x with significant changes)
3. **CoreFn changes** - PureScript's CoreFn format has evolved
4. **Missing ecosystem** - FFI library would need updates for newer PS packages

### Revival Effort Estimate

To bring purescript-native up to date would require:

1. **Update to current PureScript** (significant)
   - CoreFn format changes between 0.13 → 0.15
   - New language features (qualified do, visible type applications, etc.)
   - Likely 1-2 weeks of focused work

2. **Update FFI library** (moderate)
   - Core packages have changed APIs
   - New packages to support
   - Ongoing maintenance burden

3. **Test suite updates** (moderate)
   - Golden tests against new PS version
   - Verify all optimizations still work

4. **Build system modernization** (minor)
   - Update stack.yaml / cabal
   - Possibly migrate to current spago

## Interesting Implementation Details

### Tail Call Optimization

The TCO implementation (`Optimizer/TCO.hs`) converts tail-recursive functions to loops:

```cpp
// Before TCO
boxed factorial(const boxed& n) {
    if (n == 0) return 1;
    return n * factorial(n - 1);  // Not tail recursive anyway, but illustrative
}

// After TCO (for actual tail recursive code)
boxed factorial(const boxed& n, const boxed& acc) {
    while (true) {
        if (n == 0) return acc;
        // Loop instead of recurse
        n = n - 1;
        acc = n * acc;
    }
}
```

### Constructor Representation

ADT constructors use object literals with a boolean tag:

```cpp
// data Maybe a = Nothing | Just a
// Nothing compiles to:
dict_t{ {"Nothing", true} }

// Just 42 compiles to:
dict_t{ {"Just", true}, {"value0", 42} }
```

Pattern matching checks the tag:
```cpp
if (unbox<dict_t>(val)["Just"]) {
    auto value0 = unbox<dict_t>(val)["value0"];
    // ...
}
```

## Potential Use Cases (if revived)

1. **CLI tools** - native executables without runtime deps
2. **Embedded systems** - runs on resource-constrained devices (Pi tested)
3. **Performance-critical code** - predictable, no GC latency
4. **C/C++ interop** - easy to call existing C/C++ libraries
5. **Game development** - integrate with C++ game engines

## Go Backend (golang branch)

The Go backend takes a different approach:
- Uses Go's garbage collector instead of reference counting
- Leverages Go's excellent tooling and cross-compilation
- May be easier to maintain due to Go's stability

Worth investigating separately if native compilation is desired.

## Conclusion

purescript-native is an impressive but dormant project. The architecture is sound and similar to pslua, but significant work would be needed to bring it up to date with current PureScript.

For the PSD3 project, **pslua is the better choice** for alternative backend exploration because:
1. It's actively maintained
2. We've already contributed fixes
3. Lua/OpenResty is a great fit for the edge layer use case

However, purescript-native could be valuable if there's ever a need for true native PureScript compilation - the groundwork is solid, it just needs modernization.
