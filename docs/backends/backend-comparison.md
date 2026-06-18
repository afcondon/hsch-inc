# PureScript backends: a comparison

Seed material for the backend **reference hub** on the polyglot site — an
authoritative map of the whole PureScript backend constellation, not just a
showcase. The table below fully fills the five backends we have local checkouts
and working knowledge of: the reference JS backend in its two habitats (browser,
Node), purerl (Erlang/BEAM), purescript-julia (Jurist), and katsujukou's
purescript-backend-wasm (Wasm GC). Newly landed and captured under *Recent
additions* (below the table): a from-scratch Go backend (`psgo`, spike verified
2026-06-13 — **distinct** from Arvanitis's native-Go in `purescript-native`), and
the rebooted Python backend (`purepy`, now at differential parity). Still to fold
in as full columns: purs-backend-es (optimizing JS — a useful control column, same
habitat, different generator), purescm (Chez Scheme), and Fabrizio's Racket
backend (Purkt).

A note on framing: "backend" mixes two axes — *code generator* and
*runtime habitat*. Browser and Node share purs's JS code generator and
differ only in runtime and FFI ecosystem; purerl and Jurist are separate
code generators consuming CoreFn. The table keeps all four columns
because the *experienced* differences (FFI surface, concurrency, what
programs make sense) follow the habitat, not just the generator.

A second axis the hub must make explicit — *generator architecture* — because
the names collide. Three easily-conflated things:

- **`purerl`** — a *compiler-integrated* Erlang backend that runs its own
  PureScript frontend and carries its **own** hand-written optimizer.
- **`purescript-backend-optimizer`** (Faubion/Arista) — a *separate,
  backend-agnostic* tool that emits an optimized IR (uncurrying, inlining) for
  downstream backends; its flagship consumer is `purs-backend-es`.
- **`purescript-backend-erl`** and **`purescm`** (Chez Scheme) — backends that
  *consume that IR* rather than rolling their own optimizer.

So backends sort into three lineages: **compiler-integrated** (purerl),
**CoreFn-JSON source-emitters** (Jurist, purepy, psgo, purescript-native, lua),
and **optimizer-IR consumers** (purs-backend-es, backend-erl, purescm) — plus the
Wasm GC outlier (consumes CoreFn *and* externs.cbor). This lineage predicts what a
backend can cheaply do: e.g. whole-program **monomorphisation** lives naturally on
the optimizer-IR path, so a performance-oriented backend tends to sit there.

## The table

| | JS (browser) | JS (Node) | purerl (BEAM) | Jurist (Julia) | Wasm (katsujukou) |
|---|---|---|---|---|---|
| **Code generator** | purs itself (CoreFn → CoreImp → optimized ES modules) | same | standalone `purerl`, consumes CoreFn JSON | standalone `purejl` (Haskell), consumes CoreFn JSON | standalone compiler **written in PureScript**, consumes CoreFn JSON + externs.cbor, emits one Wasm GC module via Binaryen |
| **Status** | reference, definitional | reference | production-mature (id3as media streaming); maintained package sets | experimental but at 422/426 differential parity; core libs working | experimental, advancing fast (25 ADRs, CI, benchmarks); agent-assisted development |
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

## Recent additions (2026-06-13)

Not yet woven into the main table as full columns; captured here as they land.

### Go — `psgo` (this project, from-scratch)

A new CoreFn-JSON source-emitter, **distinct** from Arvanitis's native-Go in
`purescript-native`. Cut from the Jurist/purepy skeleton with statement-oriented
codegen grafted from purerl's AST/Pretty (Go has no ternary/expression-`if`).
**Spike verified GREEN 2026-06-13:** `purs → CoreFn → psgo → gofmt → go run`,
byte-identical to the JS backend on a hand-written module.

| | psgo (Go) |
|---|---|
| **Code generator** | standalone Haskell, consumes CoreFn JSON; emits one file/module, `gofmt` post-pass |
| **Status** | reference backend in progress; spike GREEN; full corpus walk = Phase 1 |
| **Semantics vs reference** | inherits Jurist's ledger (Int64, UTF-8) → targets differential parity modulo `INT64`/`ASTRAL` |
| **Functions** | curried unary closures, `f.(func(any) any)(x)` |
| **ADT values** | tagged struct `V{Tag string; Fields []any}` |
| **Newtypes / Records / Dicts** | erased / `map[string]any` / `map[string]any` |
| **Int / Number / String** | `int`(64) / `float64` / `string` (UTF-8) |
| **Effect** | `func() any` thunk |
| **TCO** | trampoline (port of Jurist's dispatch-loop); planned at `Test.Recursion` |
| **Module layout** | flat package, mangled top-level names — **no loader** (Go toolchain orders init) |
| **Native niche** | single static binary, goroutines, Go-library interop — the *idiom*, not raw speed |
| **Perf shape** | `any`-boxing + curried-closure tax (the reference cost). **Phase 2** = monomorphisation + inlining + concrete typing — wanted by a real customer (Mark Eibes) |

See `purescript-backends/purescript-go/PLAN.md` (two-phase) and
`purescript-go-day-one-plan.md` (architecture + the honest psgo comparison, §0.5).

### Python — `purepy` (rebooted)

Rebooted from scratch on the Jurist architecture (ADR-0001) and reached **422/426
byte-identical** — the same score as Jurist on the shared corpus — with
module-level **lambda lifting** (ADR-0002) to clear CPython's parenthesis-nesting
cap. Int is Python bignum, `str` is Unicode codepoints; diverges from JS like the
others (`INT64`/`ASTRAL` ledger). Ready to fold in as a full column.

### Racket — Purkt (Fabrizio Ferrai)

Status per Fabrizio (Discord, 24/05/2026): "a bit stumped" — **scope expanded to
self-hosting** the backend, which pulled in filesystem/IO and fanned out into
"~10 different libraries to publish"; he's untangling them to publish tidily,
"and that takes time." So: active, but blocked on the self-hosting scope +
library-publishing tail rather than core compiler design. The design doc is not in
this tree — source it from Fabrizio directly, and treat as in-flux.

## For the comparison site (separate project)

- Full columns still to add: purs-backend-es (optimizing JS control), purescm
  (Chez Scheme), purescript-native (C++/Go), purescript-lua, and Racket/Purkt when
  it lands. Go and Python now have data — promote them from *Recent additions* into
  the main table.
- **Group columns by generator lineage** (compiler-integrated / source-emitter /
  optimizer-IR consumer / Wasm) per the framing note above — it predicts capability.
- **Get attributions right before publishing.** purescm is credited to Nathan
  Faubion/Arista in `kb/research/purescript-alternative-backends-comparison.md` —
  confirm before asserting; likewise confirm Purkt authorship/status with Fabrizio.
- Each cell wants a footnote link to evidence — for Jurist, most rows link to
  `test-suite/` results or README sections.
- The "run the same program" strip — one small PS module, its output on every
  backend — **already exists**: it's the shared `Test.*` differential corpus. The
  psgo spike's byte-identical JS↔Go `Trivial` run is literally the first new cell.
