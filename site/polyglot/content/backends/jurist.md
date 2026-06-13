# Jurist — Julia

<p class="meta-row"><strong>Target:</strong> Julia ·
<strong>Lineage:</strong> CoreFn-JSON source-emitter (<code>purejl</code>, Haskell) ·
<strong>By:</strong> this project ·
<strong>Status:</strong> experimental — 422/426 differential parity ·
<strong>Repo:</strong> in-ecosystem (<code>purescript-backends/purescript-julia</code>)</p>

Jurist borrows **Julia's numeric stack** — the JIT, the array ecosystem,
DiffEq / DynamicalSystems / Catlab. The design role is a *leaf service*:
PureScript as a typed thin skin over hot numeric kernels that live in Julia FFI
leaves. Its divergences follow the family philosophy — take the host's better
number and string types, document the seam, and prove everything else identical
with a differential suite.

It is the reference implementation of this whole column-adding process; the
differential harness currently lives in its `test-suite/`.

## At a glance

| | Jurist |
|---|---|
| **Functions** | curried unary closures, `(f)(x)(y)` |
| **ADT values** | tag-tuples: `("Just", x)`, tag at `[1]` |
| **Records** | `Dict{String,Any}` + `merge` |
| **Typeclass dictionaries** | `Dict{String,Any}` keyed by member name |
| **Int** | **Int64** (Bits/pow apply JS `ToInt32`) |
| **Number** | Float64; `show` reproduces JS `toString` placement rules |
| **Strings** | UTF-8 `String`; CodeUnits API is codepoint-based (BMP-identical) |
| **TCO** | trampoline mirroring purs's optimizer (verified 10⁸) |
| **Lazy bindings** | `_runtime_lazy` thunks, smart Rec partition |
| **Native niche** | numerics — hot kernels in Julia FFI leaves; PS as typed skin |
| **Perf shape** | curried-Dict glue ~325 ns/iter (measured); numerics behind the FFI seam |

## Divergences

**422 of 426** differential tests are byte-identical to the JS reference, with
**4 documented divergences**. `Int` is Int64 (so `INT64-` tests give exact
answers like the other non-JS backends); strings are UTF-8 codepoints
(`ASTRAL-` tests agree with BEAM/Python). The `Number` `show` path
reimplements JS's `toString` placement rules exactly.

## In this ecosystem

Jurist is the compute-leaf backend for Hylograph (Marginalia 219) — numeric
work pushed behind a typed FFI seam while the visualization layer stays in JS.
