# purescript-backend-wasm — Wasm GC

<p class="meta-row"><strong>Target:</strong> WebAssembly GC (via Binaryen) ·
<strong>Lineage:</strong> consumes CoreFn JSON + <code>externs.cbor</code> ·
<strong>By:</strong> katsujukou ·
<strong>Status:</strong> experimental, advancing fast ·
<strong>Repo:</strong> <a href="https://github.com/katsujukou/purescript-backend-wasm">katsujukou/purescript-backend-wasm</a> <em>(verify before publish)</em></p>

The novel case in the family. Where every other backend borrows a *habitat*
virtue, the Wasm backend borrows a *substrate* virtue — Wasm GC structs,
sandboxing, portability — and competes **in the same habitat as JS**, beating
V8's own JS output *on V8 itself*. It is the first family member whose
differentiation is **performance, not habitat**.

The compiler is itself **written in PureScript**, driving the Binaryen JS API.
It is the best-documented backend in the family: 25 ADRs, CI, in-repo
benchmarks — a methodology the rest of the family is adopting.

## How it wins

| | purescript-backend-wasm |
|---|---|
| **Functions** | uniform `eqref` calling convention; partial/over-application; aggressive inlining + higher-order specialization |
| **ADT values** | struct *subtypes* of a tag-only `$Data` base; enum-like ADTs as unboxed `i31`; scalar fields unboxed in-struct |
| **Records** | `$Rec` struct of parallel arrays: interned label-ids + values; polymorphic update |
| **Typeclass dictionaries** | **eliminated** — positional specialization (ADR-0007) |
| **Int / Number** | true `i32` / `f64`, boxed then **unboxed by the optimizer** |
| **Strings** | UTF-8 bytes in a Wasm GC array |
| **Effect** | native lowering → constant-stack loops; whole-program purity analysis |
| **TCO** | tail-call elimination in codegen; survives recursion where both JS backends overflow |
| **Perf shape** | fastest of three on every benchmark; **5–8× JS** on allocation/pattern-match-heavy, **~1.6×** on arithmetic (steady-state) |

The performance comes from *representation*: unboxed scalars, struct-subtyped
ADTs, and eliminated dictionaries via positional specialization.

## Inputs &amp; coverage

It consumes CoreFn JSON **and** `externs.cbor`, reconstructing foreign
signatures from externs for boundary marshalling (ADR-0016). The curated
`ulib/` FFI covers a *subset* of the core libraries (Array / Eq / Ord / Show /
Foldable / Functor / Int / CodeUnits, …) — the differential matrix is allowed
holes here; silent shrinkage is the only failure.

## Divergences

Few in principle. `Int` is true i32 (JS-aligned), so `INT64-` tests should
match **JS**, not the bignum backends. Strings are UTF-8 internally but the
CodeUnits API semantics want differential discovery; `Number` formatting at the
JS boundary is worth probing early.

## What to learn from it

ADR discipline, externs-driven typed FFI marshalling, and a benchmark
methodology — the same source timed across three code generators, post-warmup,
graphs in-repo. That *is* this site's "run the same program everywhere" strip,
already practiced.
