# PureScript backends: a comparison

Seed material for a future comparison site covering the whole backend
family. This table covers the five backends we have local checkouts and
working knowledge of: the reference JS backend in its two habitats
(browser, Node), purerl (Erlang/BEAM), purescript-julia (Jurist), and
katsujukou's purescript-backend-wasm (Wasm GC). To be added as the site
project spins up: purescript-native (Go, cloned at
`purescript-backends/purescript-native`), the from-scratch Python
backend (`purescript-python-new`), purs-backend-es (the optimizing JS
backend — same habitat as JS, different generator, which makes it a
useful control column), and Fabrizio's upcoming Racket backend.

A note on framing: "backend" mixes two axes — *code generator* and
*runtime habitat*. Browser and Node share purs's JS code generator and
differ only in runtime and FFI ecosystem; purerl and Jurist are separate
code generators consuming CoreFn. The table keeps all four columns
because the *experienced* differences (FFI surface, concurrency, what
programs make sense) follow the habitat, not just the generator.

## The table

| | JS (browser) | JS (Node) | purerl (BEAM) | Jurist (Julia) | Wasm (katsujukou) |
|---|---|---|---|---|---|
| **Code generator** | purs itself (CoreFn → CoreImp → optimized ES modules) | same | standalone `purerl`, consumes CoreFn JSON | standalone `purejl` (Haskell), consumes CoreFn JSON | standalone compiler **written in PureScript**, consumes CoreFn JSON + externs.cbor, emits one Wasm GC module via Binaryen |
| **Status** | reference, definitional | reference | production-mature (id3as media streaming); maintained package sets | experimental, weekend-shaped; core libs working | experimental, advancing fast (25 ADRs, CI, benchmarks); agent-assisted development |
| **Semantics vs reference** | — is the reference | — | diverges by design (Int, strings); own test suites | **422/426 differential tests byte-identical**; 4 documented divergences | same-source benchmarks vs purs JS and purs-backend-es; Int is i32 (JS-aligned) |
| **Functions** | curried unary; optimizer inlines/uncurries hot paths | same | curried funs; arity-optimized top-level variants | curried unary closures, `(f)(x)(y)` | uniform `eqref` calling convention; partial/over-application supported; aggressive inlining + higher-order specialization |
| **ADT values** | constructor functions + `instanceof` dispatch, fields `value0…` | same | tagged tuples, atom tag: `{just, X}` | tag-tuples: `("Just", x)`, tag at `[1]` | struct *subtypes* of a tag-only `$Data` base; enum-like ADTs as unboxed `i31`; scalar fields unboxed in-struct |
| **Newtypes** | erased | erased | erased | erased | erased |
| **Records** | JS objects | same | Erlang maps (atom keys) | `Dict{String,Any}` + `merge` | `$Rec` struct of parallel arrays: interned label-ids + values; polymorphic update (ADR-0023) |
| **Typeclass dictionaries** | JS objects; common instances inlined by the optimizer | same | maps | `Dict{String,Any}` keyed by member name | **eliminated** — positional specialization (ADR-0007), recursive instance groups handled |
| **Int** | double wrapped `\|0` → int32 | same | **bignum** (arbitrary precision) | **Int64** (Bits/pow do apply JS `ToInt32`) | **i32** (true 32-bit, JS-aligned); boxed `$Int` struct, unboxed to raw `i32` by the optimizer |
| **Number** | IEEE double | same | float (double) | Float64; `show` reproduces JS `toString` placement rules | f64 (boxed `$Num`, unboxed by the optimizer) |
| **Strings** | UTF-16 code units | same | UTF-8 binaries | UTF-8 `String`; CodeUnits API is codepoint-based (BMP-identical) | UTF-8 bytes in a Wasm GC array |
| **Effect** | nullary thunk; MagicDo collapses binds | same | nullary funs | nullary thunk | native lowering — collapses to constant-stack loops; whole-program purity analysis (ADRs 0015/0018/0019) |
| **TCO** | purs optimizer: self-tail-calls → `while` loops | same | **native BEAM TCO, including mutual recursion** | trampoline mirroring purs's optimizer: self-tail-calls → dispatch loops (verified 10⁸) | tail-call elimination in codegen; survives deep recursion where both JS backends overflow (`bintreeBfs`) |
| **Mutual recursion (unbounded)** | MonadRec idiom | same | free (native TCO) | MonadRec idiom (matches JS) | TCE in codegen (extent: see ADRs) |
| **Lazy/recursive bindings** | runtime lazy thunks | same | similar runtime support | `_runtime_lazy` thunks, smart Rec partition | recursive let-bindings supported; pure CAFs as globals instantiated at start (ADR-0006) |
| **FFI unit** | `.js` ES module per PS module | same | `.erl` module per PS module | `Module_foreign.jl` included *inside* the generated module | curated `ulib/` `.wat` per core module + user FFI with marshalling from **reconstructed foreign signatures** (externs.cbor, ADR-0016) |
| **Concurrency story** | event loop, workers | event loop, worker_threads | **processes + OTP supervision — the raison d'être** | Tasks/threads available; designed role is a *leaf service*, not coordinator | the host's (browser/Node); fully sandboxed |
| **Native niche** | DOM/UI (Halogen, react bindings) | servers, CLIs, tooling | soft-realtime distributed systems, live supervision trees | numerics: hot kernels in Julia FFI leaves (DiffEq, DynamicalSystems, Catlab), PS as typed thin skin | portable sandboxed compute; hot kernels *in the same habitat as JS* — the performance backend |
| **Library coverage** | entire registry | entire registry | large curated package sets | prelude/effect/console/arrays/st/strings/foldable-traversable/integers/numbers/unfoldable/enums; Regex stubbed | curated `ulib` subset (Array/Eq/Ord/Show/Foldable/Functor/Int/CodeUnits, …) |
| **Perf shape** | V8 JIT is excellent for closure-heavy code | same | not numeric; superb latency/IO | curried-Dict glue ~325 ns/iter (measured); numerics belong behind the FFI seam | fastest of three on every benchmark; 5–8× JS on allocation/pattern-match-heavy, ~1.6× on arithmetic (steady-state, post-warmup) |
| **In this ecosystem** | Hylograph showcases, Halogen apps | HTTPurple APIs, build tooling | purerl-tidal: TidalCycles scheduling on BEAM | Hylograph compute leaves (Marginalia 219) | newly cloned (`purescript-backends/purescript-backend-wasm`); candidate matrix column; benchmark methodology to adopt |

## Reading the family

The interesting pattern: each non-JS backend exists to borrow a
*runtime virtue* the JS engines don't have, while keeping PureScript's
type system as the lingua franca.

- **purerl** borrows BEAM's process model — supervision, distribution,
  soft-realtime scheduling. Its semantic divergences (bignum Int,
  binary strings) are *upgrades along the BEAM grain*, accepted rather
  than papered over.
- **Jurist** borrows Julia's numeric stack — the JIT, the array
  ecosystem, DiffEq/DynamicalSystems/Catlab. Its divergences (Int64,
  codepoint strings) follow the same philosophy: take the host's better
  number and string types, document the seam, and prove everything else
  identical with a differential suite.
- **purescript-backend-wasm** is the novel case: it borrows a
  *substrate* virtue (Wasm GC structs, sandboxing, portability) and
  competes **in the same habitat as JS** — beating V8's JS output on
  V8 itself (5–8× on allocation-heavy benchmarks) via representation:
  unboxed scalars, struct-subtyped ADTs, eliminated dictionaries. The
  first family member whose differentiation is *performance*, not
  habitat.
- The JS backend's virtue is *being everywhere* — and being the
  semantic reference the others measure against.

The same lens will apply to the additions: Go (static binaries,
goroutines), Python (ubiquity, data tooling), Racket (macros and
language-building).

## For the comparison site (separate project)

- Columns to add: purescript-native (Go), purescript-python-new,
  purescript-racket (when it lands).
- Each cell wants a footnote link to evidence — for Jurist, most rows
  link to `test-suite/` results or README sections.
- A "run the same program" strip — one small PS module, its output and
  timing on every backend — would make the table falsifiable, in the
  spirit of the differential suite.
