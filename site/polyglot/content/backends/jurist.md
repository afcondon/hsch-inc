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

## The exhibits

**One description, four denotations** (`examples/numexpr-edsl`). The doctrine
is *descriptions across, handles back*: a typed PureScript term crosses the
seam once, and Julia denotes it natively. The state space and parameters are
PureScript **rows**, so the right-hand side is written `s.x`, `p.sigma` — and a
misspelt `s.q` is a compile error rather than a silent `NaN`.

What Julia then does with the description is the point, because these are
things the alternatives cannot do:

- **ModelingToolkit** simplifies the system and derives the **analytic
  Jacobian** — no derivative is ever written in PureScript — and SciML's
  polyalgorithm auto-switches to a stiff method, solving Robertson cleanly.
- A row-typed **differential-algebraic** system (a double pendulum in Cartesian
  coordinates) types the constraint lambda to return `Record alg`, so exactly
  one constraint per rod tension: a well-posed index-1 DAE *by construction*.
  `Rodas5P` holds the rods to ~1e-8 through fully chaotic motion. `scipy`'s
  `solve_ivp` cannot do this at all — it has no algebraic-variable support.
- **Symbolics + Latexify** differentiate an expression and hand the derivative
  back as LaTeX. Descriptions across, *descriptions back*: what returns is
  mathematics you can read.
- **IntervalRootFinding** does not merely find roots, it **proves** them — each
  bracketed in a guaranteed enclosure, certified unique, the search exhaustive.
  "No roots" is itself a proof; `x² + 1` is proven to have none.

The same description also runs on **Node** and the **BEAM** via a pure
PureScript integrator, and the Julia-compiled function matches that reference
interpreter byte-for-byte. `core`'s entire foreign surface is **six
transcendental primitives** — everything else is description.

**Stability Atlas** (`examples/stability-atlas`) demonstrates something
different and is worth reading as such: browser and compute service share
**one** `Atlas.Protocol` codec, compiled to JavaScript at one end and Julia at
the other. A Julia-only service would need a hand-written JS client and a
schema maintained twice; here client/server drift is a compile error on both
ends, and the `parity-node` / `parity-jl` runs prove the two codecs agree
byte-for-byte. Its fixed-step sweep additionally cross-checks a threaded
hand-written Julia kernel against the portable PureScript denotation, and they
agree to **0.0** over 5000 steps — an optimisation proven faithful to its
reference.

## A measured caveat

Generated Julia is **not** fast, and the doctrine above exists because of it.
Measured 2026-07-30 on identical source (`bench-node` / `bench-jl`): 2M RK4
steps cost ~290–480 ms on Node and ~27,600 ms through `purejl` — about **70×
slower** — while hand-written type-annotated Julia does the same work in 79 ms.
The cause is type instability: curried closures, per-iteration tuple
allocation, and callees arriving as closure values defeat Julia's
specialising JIT, which is precisely the machinery Julia's speed depends on.

So hot loops must not be compiled PureScript. Put them in the library, or in a
hand-written kernel checked against a portable reference — which is what both
exhibits do. Full diagnosis in the backend repo's
`docs/PERFORMANCE-FINDING-2026-07-30.md`.

## In this ecosystem

Jurist is the compute-leaf backend for Hylograph (Marginalia 219) — numeric
work pushed behind a typed FFI seam while the visualization layer stays in JS.
