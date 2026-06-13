# Writing a PureScript backend

PureScript's compiler emits **CoreFn** — a small, untyped, functional
intermediate representation — and hands it off. Everything downstream is a
backend: a program that reads CoreFn (as JSON, or via the compiler's own
plumbing) and produces code for some other runtime. This page collects
everything we've gathered building columns for the differential matrix —
the contract, the rules that cost us time, and the prior-art shelf.

> Counterexamples are first-class content. The thesis of this whole project
> is that divergences between backends are *enumerable*. Finding one is a
> result, not an embarrassment.

## The three lineages

Backends sort into three families, and the lineage predicts what a backend
can cheaply do:

- **Compiler-integrated** — runs its own PureScript frontend and carries its
  own optimizer (e.g. `purerl`).
- **CoreFn-JSON source-emitters** — consume `purs`'s CoreFn JSON and print
  target source directly (Jurist, purepy, psgo, purescript-native, lua).
- **Optimizer-IR consumers** — consume the optimized IR from
  [`purescript-backend-optimizer`](https://github.com/aristanetworks/purescript-backend-optimizer)
  (uncurrying, inlining) rather than rolling their own (purs-backend-es,
  purescript-backend-erl, purescm).

Whole-program **monomorphisation** lives naturally on the optimizer-IR path,
so a performance-oriented backend tends to sit there. The Wasm GC backend is
an outlier — it consumes CoreFn *and* `externs.cbor` to reconstruct foreign
signatures for boundary marshalling.

## Making a slow backend fast: two roads

Most CoreFn source-emitters start the same way — every value boxed, every
function a curried unary closure, every type-class method a dictionary lookup.
Correct, but slow. There are two roads to speed, and the choice is more
consequential than it looks (we know because for the Go backend we built the
slow boxed emitter, then a Path-B consumer taken to full conformance — the
emitter kept as the byte-identical oracle, Path A scoped against purerl but not
built).

- **Path A — hand-roll passes on your own AST.** Keep your existing compiler
  and write your own inliner, uncurrier, dead-code pass. The reference is
  **purerl**, whose `CodeGen/Optimizer/{Inliner,MagicDo,Memoize,Unused}` is
  living proof you can hand-write a solid optimizer for a CoreFn backend.
- **Path B — consume `purescript-backend-optimizer`.** It ingests CoreFn and
  emits an *already-optimized* IR — uncurrying and inlining done — that you
  walk. Flagship consumer `purs-backend-es`; also `purescm`, `backend-erl`.

**The surprise that decides the shape:** the optimizer is **written in
PureScript, not Haskell**. So Path B isn't "teach my Haskell compiler a new
IR" — it's a *second codebase in a different language*, sharing only the
conformance corpus with your existing backend (not code).

**What the IR hands you for free:** multi-arg lambdas/apps pre-grouped
(uncurrying), **typed primitive operators** (`OpIntNum OpAdd`, `OpStringAppend`
— native arithmetic, not `Semiring`/`Eq` dictionary lookups), `Effect`
special-cased (MagicDo built in), de Bruijn levels, and whole-program DCE +
inlining. *Even a naïve walk of this IR beats a naïve walk of CoreFn.*

**What it does NOT hand you** — and the names mislead here, because purerl,
backend-erl and purescm all target dynamically-typed runtimes: **polymorphic
dictionary-passing remains**, and **concrete typing / unboxing is yours to
invent** (the references are MLton and Rust, not any PS backend). Those two —
whole-program monomorphisation and concrete typing — are equally novel work on
*both* roads.

| | **Path A — hand-rolled** | **Path B — optimizer IR** |
|---|---|---|
| Language | your compiler's (e.g. Haskell) | PureScript |
| Codebases | one | two (share corpus, not code) |
| Uncurrying / inlining / DCE | you write it | free |
| Primitive dict-elim | you write it | free (typed PrimOps) |
| Monomorphisation / unboxing | you write it | you write it |
| Reference to copy | purerl `CodeGen/Optimizer/*` | `backend-es`, `purescm` |
| Boxed fallback / oracle | same codebase | separate codebase |

**Lean Path B** if you want the uncurrying/inlining without reimplementing it,
you're comfortable with a PureScript backend alongside your existing one, and
especially if a collaborator is already on the optimizer-IR path (you compose
with their work). **Lean Path A** if staying in one language matters more, or
if your backend is compiler-integrated like purerl (where an external
PureScript tool is an awkward fit). Either way, the boxed-to-real-target
frictions — short-circuit `&&`/`||` must stay native, lazy init for cyclic
dictionary CAFs, the whole-program build model — are *target* problems both
roads meet.

## The contract

"Adding a backend" to the differential suite means, concretely:

1. **Build path** — compile the suite's `Test/*.purs` modules to runnable
   artifacts on your backend. The suite is deliberately FFI-free beyond the
   core libraries, so the only foreign code you need is your backend's own
   core-library shims.
2. **Runner** — a pure subprocess `run_<backend>(module) -> (stdout, error)`,
   plus the module-name mapping. No shared state.
3. **Divergence curation** — every non-identical line is either a fix (your
   shim is wrong) or a `KNOWN_DIVERGENCES` entry with a prefix naming the
   cause (`INT64-`, `ASTRAL-`, `BIGNUM-`, `FLOATFMT-`, …) *and* a sentence in
   your README. An uncurated divergence is a failure.
4. **Results as data** — one JSONL record per (program, backend, test). The
   site renders from this; don't emit prose summaries only.
5. **Regression** — the existing columns must still pass.

## Ground rules (learned the hard way)

- **Read the real JS foreign modules** (`.spago/p/<pkg>/src/**/*.js`), never
  another backend's shims. The `.js` file is the spec; the `foreign import`
  declarations give you arities.
- **JS arity tolerance does not port.** JS foreigns call `f()` on functions
  CoreFn types as 1-ary. Your shim must pass the argument explicitly. Grep the
  JS for zero-arg calls.
- **Some "foreign-looking" names are PureScript-defined.** `mkFn1`/`runFn1`
  are written in PureScript; shimming them collides with the generated module
  body. Trust the `corefn.json` `foreign` array, nothing else.
- **The reference is not always right.** `sumTo 0 1000000` overflows on the JS
  backend (int32 wrap). When your backend's answer is better, document the
  divergence — don't cripple your runtime to match.
- **Number formatting is the biggest hidden surface.** JS
  `Number.prototype.toString` placement rules (decimal within
  1e-6 ≤ |n| < 1e21, exponential outside, `.0` suffix via Show) have to be
  reimplemented on every backend. Run `Test.Numbers` early.
- **Sort stability is tested.** JS `sortByImpl` is a stable merge sort. Check
  what your backend's shim actually does.
- **Watch inverted sign conventions.** `ordArrayImpl`'s length tiebreak is
  inverted (the PureScript caller re-inverts). Any foreign whose sign is
  consumed inverted is a trap.
- **Reuse stack snapshots.** For Haskell-based backends, copy `stack.yaml`
  *and* `stack.yaml.lock` from a sibling that already builds — the lock pins
  the snapshot key. Without it, ~25 min rebuild; with it, ~90 s.

## The differential suite

The harness diffs every backend against the reference (JS) **and** pairwise
where both diverge the same way — bignum backends should agree with *each
other*, which is itself a checkable claim. The registry of backends is the
clean extension point:

```python
BACKENDS = {
    "js":     Backend(build=build_js,     run=run_js, ref=True),
    "julia":  Backend(build=build_julia,  run=run_julia),
    "erl":    Backend(build=build_erl,    run=run_erl),
    # default: all available — probe toolchains, skip missing with a
    # SKIPPED record, never a silent drop.
}
```

`KNOWN_DIVERGENCES` is keyed `(module, test) -> {backend_or_class: expected}`,
where divergence *classes* (`bignum`, `utf8`) beat per-backend entries
wherever they apply.

## Prior-art shelf

- **The comparison** — [the backend family](/#backends), one page each, with
  the semantic divergence table.
- **Reference implementation of the column-adding process** — Jurist's
  `test-suite/` (the harness currently lives there; generalizing it into this
  repo is part of the site build).
- **purepy's `cross_backend_test.py`** — prior art for this exact task, with a
  curated KNOWN_DIVERGENCES set worth porting rather than rediscovering.
- **katsujukou's Wasm backend** — the best-documented in the family (25 ADRs,
  CI, benchmarks). Adopt its **ADR discipline**, its **externs.cbor signature
  reconstruction** for typed FFI marshalling, and its **benchmark
  methodology** (same source, timed across generators, steady-state).
- [`purescript-backend-optimizer`](https://github.com/aristanetworks/purescript-backend-optimizer)
  — the shared optimization IR, if you're building an optimizer-IR consumer.

## Definition of done

- All suite modules run on the new backend; counts reported.
- Zero uncurated divergences; every curated one has a prefix, a per-backend
  (or per-class) expectation, and a README sentence.
- JSONL results emitted; existing columns still green.
- The comparison table column updated from *observed facts*, not documentation
  folklore — cite test names where the table makes a checkable claim.
