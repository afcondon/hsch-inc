# Two roads to a fast backend: the PureScript optimizer IR vs hand-rolled compiler passes

*Reference-hub post. Companion to [backend-comparison.md](./backend-comparison.md)
and [adding-a-backend.md](./adding-a-backend.md). Grounded in actually building
both halves for the Go backend (`psgo`) — a Phase 1 hand-written CoreFn→Go
emitter, and a Phase 2 backend that consumes the optimizer IR — and taking the
latter to full conformance.*

## The question

You have a working but slow backend: a CoreFn→target source-emitter where every
value is boxed, every function is a curried unary closure, and every type-class
method goes through a dictionary lookup. You want it fast. There are two roads,
and the choice is more consequential than it first looks:

- **Path A — hand-roll optimization passes on your own AST.** Keep your existing
  compiler (in our case a Haskell program consuming CoreFn JSON) and write your
  own inliner, uncurrier, dead-code pass, etc. The reference is **purerl**, whose
  `CodeGen/Optimizer/{Inliner,MagicDo,Memoize,Unused}` are living proof you can
  hand-write a solid optimizer suite for a CoreFn-derived backend.
- **Path B — consume `purescript-backend-optimizer`.** Faubion/Arista's
  backend-agnostic optimizer ingests CoreFn and emits an *already-optimized* IR —
  uncurrying and inlining done — that downstream backends walk. Its flagship
  consumer is `purs-backend-es`; `purescm` (Chez) and `purescript-backend-erl`
  are others.

## The surprise that decides the shape

**`purescript-backend-optimizer` is written in PureScript, not Haskell.** Its IR
(`PureScript.Backend.Optimizer.Syntax.BackendSyntax` / `Semantics.NeutralExpr`),
its build driver (`Builder.buildModules`), and its codegen contract are all
PureScript. A consumer is therefore a *PureScript* program (as `backend-es` and
`purescm` are), with the optimizer pulled in as an ordinary PureScript package.

This means Path B is **not** "teach my existing Haskell compiler to read a
different IR." It's a *second codebase in a different language*. If your current
backend is Haskell-on-CoreFn (like ours, like Jurist/purepy), Path B forks the
project:

- **Path A** keeps one Haskell codebase; the boxed/`any` path stays as the
  fallback and correctness oracle. Cost: you re-implement the uncurrying and
  inlining the optimizer would have handed you.
- **Path B** is a new PureScript backend that shares only the *conformance
  corpus* with your existing one (not code). Cost: two languages, two build
  toolchains. Benefit: uncurrying + inlining + dead-code elimination arrive for
  free, and you only write codegen + a runtime.

For a backend that's already a CoreFn source-emitter, this is the crux: Path B
buys reuse but spends a language boundary.

## What the optimizer IR actually hands you

Reading the IR is the fastest way to see the value. `BackendSyntax` is the
post-optimization tree, and several nodes encode work you'd otherwise do yourself:

- **Uncurrying, pre-collected.** `Abs (NonEmptyArray params) body` and
  `App f (NonEmptyArray args)` — multi-argument lambdas and saturated
  applications arrive grouped, not as nested unary closures. Plus
  `UncurriedAbs`/`UncurriedApp` (and effect variants) for FFI `Fn`/`EffectFn`.
- **Typed primitive operators.** Arithmetic and comparison are
  `PrimOp (Op2 (OpIntNum OpAdd) …)`, `OpStringAppend`, `OpIntOrd OpLt`, … —
  *not* `Semiring`/`Eq`/`Ord` dictionary lookups. A meaningful slice of dictionary
  elimination, for the primitive cases, is **already done**. You emit native
  arithmetic directly.
- **`Effect` special-cased.** `EffectBind` / `EffectPure` / `EffectDefer` —
  MagicDo is built in, so `do` blocks become straight-line sequencing instead of
  towers of bind closures.
- **De Bruijn levels** (`Local _ (Level n)`) for trivially-unique local names.
- **Whole-program dead-code elimination** and **inlining** (driven by `@inline`
  directives) already applied.

The headline: *even a naïve walk of this IR beats a naïve walk of CoreFn* — fewer
closures, native primops, no Effect-monad overhead — before you write a single
optimization of your own.

## What it does NOT hand you (and where the names mislead)

A caveat the reference hub must make loud: **purerl, backend-erl, and purescm all
target dynamically-typed runtimes (Erlang, Scheme). None of them monomorphise or
do concrete typing.** The optimizer eliminates *primitive* dictionary dispatch and
uncurries, but:

- **Polymorphic dictionary-passing remains.** Non-primitive type-class methods
  still go through dictionary values at runtime.
- **Concrete typing / unboxing is yours to invent.** Turning monomorphic code
  into real `int`/`float64`/`string`/struct-ADTs — so the *target's* own inliner
  and escape analysis can fire — is genuinely new ground for a PureScript backend.
  The conceptual references are **MLton** (whole-program monomorphise +
  defunctionalize) and **Rust** (monomorphised generics), not any existing PS
  backend.

So Path B gets you transform **(A) uncurrying** and a chunk of **(B) dictionary
elimination** for free; full **(B) monomorphisation** and **(C) concrete typing**
sit on top of *either* path and are equally novel on both.

## What Path B cost in practice

We built the Go consumer (`backend-go`) and took it to **full conformance — all
10 corpus modules green** (8 byte-identical to the JS reference, 2 differing only
on a documented INT64/ASTRAL ledger) — in a single focused session. Concretely:

- **Scaffolding was cheap.** A spago package depending on the optimizer (local
  `path` package), a verbatim port of `backend-es`'s generic `basicBuildMain`
  driver (it references only optimizer modules — nothing ES-specific), and a
  `codegenModule :: CodegenOptions -> BackendModule -> Dodo.Doc` walk. It built
  against the optimizer and emitted plausible Go for ~200 modules almost
  immediately.
- **The runtime ported across.** Our existing `any`-runtime shim catalogue
  (`prelude.go`) transferred almost verbatim as `runtime.go`; the deltas were a
  new helper ABI and the Effect thunk model.

The friction — useful to know going in — was **not** the optimizer; it was the
target-representation tensions that any `any`-boxed backend hits, surfaced by the
IR's shape:

1. **Short-circuit is load-bearing.** The optimizer emits `isTag Just &&
   p(field0)` *relying* on `&&` not evaluating the right operand when the left is
   false (it would index a missing constructor field). A naïve "lower every op to
   a strict helper call" crashes here — `&&`/`||` must emit native short-circuit.
2. **You can't type-assert a concrete value.** Go forbids `x.(T)` when `x` is
   already concretely typed, but PrimOp operands are *sometimes* concrete
   (literals, other primop results) and sometimes boxed. Routing operands through
   `any`-taking helpers that assert internally (and box concretes) resolves it
   uniformly — at the cost of inlining-to-native-operators becoming a later pass.
3. **Lazy init for cyclic dictionary CAFs.** The same `$runtime_lazy` analog the
   non-optimized backend needed; here a distinct thunk type lets a single `force`
   serve both generated bindings and direct-value foreign shims.
4. **Whole-program build model.** The optimizer processes *all* modules, so you
   compile the whole closure at once (vs per-entry pruning) and must supply
   foreign shims for the entire surface your corpus touches — more than a small
   test corpus exercises.

None of these are optimizer problems; they're "emitting a real target from a
boxed IR" problems, and Path A would meet every one of them too.

## The trade-off, summarized

| | **Path A — hand-rolled passes** | **Path B — optimizer IR** |
|---|---|---|
| Language | Stays in your compiler's language (Haskell, for us) | PureScript (the optimizer is PureScript) |
| Codebases | One | Two (share the corpus, not code) |
| Uncurrying / inlining / DCE | You write it | Free |
| Primitive dict-elim | You write it | Free (typed PrimOps) |
| Polymorphic monomorphisation | You write it | You write it |
| Concrete typing / unbox | You write it | You write it |
| Reference to copy | purerl's `CodeGen/Optimizer/*` | `backend-es`, `purescm` |
| Boxed fallback / oracle | Same codebase | Separate codebase |
| Risk | Re-implementing solved transforms | A language boundary + whole-program build |

## Recommendation

- **Lean Path B if** you want the optimizer's uncurrying/inlining without
  reimplementing it, you're comfortable with a PureScript backend alongside your
  existing one, and especially if a collaborator is already on the optimizer-IR
  path (you compose with their work). Empirically it reached conformance fast and
  the IR did real work.
- **Lean Path A if** staying in one language/codebase matters more than reusing
  uncurrying, or if your backend is compiler-integrated like purerl (where an
  external PureScript tool is an awkward fit). You keep one boxed oracle and grow
  passes on it.

Either way, the two hard, *novel* transforms — whole-program monomorphisation and
concrete typing/unboxing — are the same amount of new work on both roads. Path B
just means you don't pay again for the transforms the ecosystem has already
solved.

---

*Status (2026-06-13): `psgo` Phase 1 (hand-written Haskell emitter) is the
conformance oracle; `backend-go` (Path B, optimizer IR) passes the same corpus.
Next is benchmarking the IR's win and the genuinely-new transforms (native
multi-arg uncurrying, then monomorphisation/concrete typing).*
