# psgo — Go

<p class="meta-row"><strong>Target:</strong> Go ·
<strong>Lineage:</strong> CoreFn-JSON source-emitter (standalone Haskell) ·
<strong>By:</strong> this project (from-scratch) ·
<strong>Status:</strong> reference backend in progress — spike GREEN (2026-06-13) ·
<strong>Repo:</strong> in-ecosystem (<code>purescript-backends/purescript-go</code>)</p>

A from-scratch Go source-emitter — **distinct** from Andy Arvanitis's native-Go
in [`purescript-native`](native/). Cut from the Jurist / purepy skeleton with
statement-oriented codegen grafted from purerl's AST/Pretty layer (Go has no
ternary or expression-`if`, so the emitter is statement-first). The virtue it
borrows is the **Go idiom**: single static binaries, goroutines, and
Go-library interop — not raw speed, at least not yet.

**Spike verified GREEN:** `purs → CoreFn → psgo → gofmt → go run`, byte-identical
to the JS backend on a hand-written module.

## At a glance

| | psgo |
|---|---|
| **Functions** | curried unary closures, `f.(func(any) any)(x)` |
| **ADT values** | tagged struct `V{Tag string; Fields []any}` |
| **Records / Dicts** | `map[string]any` |
| **Int / Number / String** | `int` (64) / `float64` / `string` (UTF-8) |
| **Effect** | `func() any` thunk |
| **TCO** | trampoline (port of Jurist's dispatch loop) |
| **Module layout** | flat package, mangled names — **no loader** (Go orders init) |
| **Native niche** | single static binary, goroutines, Go interop |
| **Perf shape** | `any`-boxing + curried-closure tax — the reference cost |

## Roadmap

Two-phase. **Phase 1** is the full corpus walk to differential parity (it
inherits Jurist's ledger — Int64, UTF-8 — so it targets parity modulo
`INT64` / `ASTRAL`). **Phase 2** is monomorphisation + inlining + concrete
typing to shed the `any`-boxing tax — wanted by a real customer. See
`purescript-go/PLAN.md`.
