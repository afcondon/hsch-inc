# Same code, two runtimes

[Writing a backend](/resources/) documents the promise from the *suite*
side — how to make a backend pass the differential-conformance tests. This
page documents it from the *application* side: what actually happens when you
take a substantial program written for one runtime and run it, unchanged, on
another. This is where "PureScript everywhere" meets the floor — and the seams
are worth naming, because they are the same seams every cross-runtime sharing
hits.

## Set the bar correctly first

It is worth being clear about what kind of promise this is, because the famous
one — Java's "write once, run anywhere" — is a *much* tamer problem. The JVM
ships the *same bytecode* to the *same runtime* (a JVM) on different hardware.
The runtime is the constant; only the chip underneath changes.

What happens here is categorically wilder: the **same source** compiled to
**genuinely different runtimes** — V8's event loop, BEAM's process scheduler,
Julia's JIT and GC, CPython's interpreter — and possibly different hardware on
top of *that*. There is no shared runtime holding the line. Measured against
that bar, the remarkable thing is not that a little leaks; it is how
extraordinarily much travels untouched.

> Keeping it real. The promise mostly pays out — thousands of lines of
> non-trivial logic, written for one runtime, running byte-for-byte-equivalent
> on another, across runtimes that share nothing but a calling convention the
> compiler invents. It is *mostly*, not *entirely*, and the residue is small
> and predictable. Knowing the seams in advance turns a surprise into a
> checklist — and the checklist is short precisely because so much just works.

## The worked example

The example is real. **Triggerfish** (a JS/Halogen app) needed TidalCycles
mini-notation: turn `"bd*3 ~ bd(3,8)"` into scheduled events. That parser +
pattern engine already existed — written for **BEAM/purerl**, in purerl-tidal.
So we vendored it (~3,900 lines across 12 modules) into a JS app and asked the
promise to pay out.

It largely did. Everything below is the part that *didn't* travel for free.

## Where it held: the pure core travels for free

The entire closure — the combinator parser, the AST, the `Pattern = State ->
Array Event` query model over `Data.Rational` time, the evaluator, the chord
and notation tables — is Prelude-family PureScript. It compiled against the JS
registry and ran with **zero logic changes**. `queryArc (parse "bd*3") 0 1`
returns onsets at exactly `0, 1/3, 2/3`; `bd(3,7)` gives a true septuplet
euclid; `[bd sn] cp` nests correctly. Rational time means no float drift across
the runtime boundary.

This is the promise delivered: non-trivial logic, written for Erlang, running
identically on V8. Everything below is the residue.

## Seam 1 — FFI is the boundary, and it does not cross

The one `foreign import` in the whole closure was a `readFloat :: String ->
Number`, backed by an Erlang module calling `string:to_float`. On JS that
foreign module simply does not exist; the code cannot load.

The fix was **not** to write a JS shim. It was to delete the FFI and call
`Data.Number.fromString` — a library function the `numbers` package already
provides on every runtime. The seam moved from our code (one obligation per
target runtime, forever) to the library's (already discharged by its
maintainers).

> **Rule.** Every `foreign import` in shared code is a portability debt with one
> line-item per runtime you target. Before writing one, check whether a
> Prelude-family library already exposes the operation — you inherit its
> per-runtime ports instead of owning yours. Reserve FFI for the genuine runtime
> edge (DOM, BEAM processes, OS) and keep it out of the shared core entirely, or
> behind a thin per-runtime module the shared core imports by name.

`readFloat` failed this test: it was a hand-rolled FFI for something
`Data.Number.fromString` does portably. It was invisible on BEAM because the
Erlang shim was right there. It surfaced the instant the code changed runtimes.

## Seam 2 — package-set drift: same source, two package universes

purerl-tidal is pinned to the purerl package set (`erl-0.15.3-20220629`). The
JS app is on the registry set `73.3.0`. These are not the same library
universe, and the BEAM set trails the JS registry by years. The vendored source
would not compile until these were reconciled:

| purerl set (what the source said) | JS registry 73.3.0 (what it needs) |
|---|---|
| `Text.Parsing.Parser` | `Parsing` (renamed in `parsing` v9) |
| `Text.Parsing.Parser.Combinators` | `Parsing.Combinators` |
| `Text.Parsing.Parser.String` | `Parsing.String` |
| `Text.Parsing.Parser.Pos (Position)` | `Parsing` (`Position` gained an `index` field) |
| `Text.Parsing.Parser.Token (alphaNum, digit, letter)` | `Parsing.String.Basic` (the `Token` module was gutted) |
| `…String (skipSpaces)` | `Parsing.String.Basic` |
| `Math (cos, floor, pi, sin, sqrt)` | `Data.Number` (`Math` removed from core) |

The reconciliation is mechanical — import-path renames, no logic — but it is
**mandatory**, and there is no automatic translation layer. "Same code"
required hand-editing the import block of five modules. None of this is a
language failure; it is an ecosystem-versioning seam, and it is the seam most
likely to *widen* over time, because the purerl set is community-maintained and
lags the registry's churn.

> **Rule.** Cross-runtime sharing assumes either (a) compatible package sets, or
> (b) a budget for import reconciliation that grows with the version gap. If you
> intend to share a module long-term, prefer the oldest-common API surface, or
> vendor with the expectation of periodic re-sync. (We vendored under the
> original namespace precisely so a future re-sync against the rig is a clean
> diff.)

## Seam 3 — the abstraction's own holes

Worth separating from the two above because it is *not* a runtime seam: even
running identical source on both runtimes, the engine's own behaviour is a fixed
point — and it has holes. Mini-notation elongation (`bd@3`, `bd _ _ sn`) is a
silent no-op in this interpreter: the weights are ignored and the events come
out equal-spaced (verified empirically). This would fail the same way on BEAM;
it is not a portability failure.

But it is the same *shape* of failure — promise vs. delivery. The surface
language advertises a feature the implementation does not honour. Anyone relying
on cross-runtime *parity* with the original Haskell Tidal will assume an
elongation semantics that is present on neither runtime.

> **Rule.** "Compiles and runs on both" is not "behaves identically on both,"
> and neither is "behaves as the abstraction claims." These are three separate
> guarantees. Only the differential-conformance suite checks the second; only
> tests against the spec check the third. Cross-runtime confidence requires all
> three, not just a green compile.

## Seam 4 — the JSON library is part of the boundary too

Seam 1 was one `foreign import`. The same logic scales up to an entire library
— and JSON is where it bites first, because JSON is usually *how the two
runtimes talk to each other*. Argonaut — `argonaut-core`, `argonaut-codecs`,
`codec-argonaut`, the default JSON stack on the JS side — does not exist on
purerl. This is not an unfinished port; it is structural. `argonaut-core`'s
`Json` type *is* the value returned by JavaScript's `JSON.parse`, and its
primitives are `.js` FFI. There is no Erlang representation to link against, so
nothing built on it compiles on the BEAM.

The fix is Seam 1's rule applied at library scale: don't port Argonaut, reach
for the library that already ports. On purerl that is **`simple-json`** or
**`yoga-json`** (backed by the `jsx` Erlang library — `{jsx, "3.1.0"}` in
`rebar.config`), or **`erl-jsone`**, an Argonaut-shaped wrapper built for the
BEAM. purerl-tidal's own wire codec is `simple-json`/`jsx`: `writeJSON` /
`readJSON` over the engine record, with `jsx` doing the encode/decode in Erlang.

The non-obvious part is the *shared* case. If a codec module has to compile on
both runtimes — one definition, used by the JS frontend and the purerl engine
alike — then neither Argonaut (JS-only) nor `erl-jsone` (purerl-only) can be it.
Only `simple-json` / `yoga-json` carry FFI for *both* targets, so they are the
only choice for a genuinely shared codec. If instead each side owns its own
codec and only the serialized string crosses the wire, the constraint relaxes —
pick the best library per runtime and agree on the wire shape.

> **Rule.** Your serialization library is FFI too. The default JSON stack on one
> runtime may not exist on the other, and JSON is usually the thing on the wire
> *between* them — so this is the seam you hit first when two runtimes have to
> talk. For a shared codec module, use a library with FFI on every target you
> build (`simple-json` / `yoga-json`). For a string-only boundary, let each side
> choose and pin the wire format instead.

## The structural answer: isolate what varies

The seams above all point the same way: a cross-runtime codebase is healthiest
when **the parts that vary by runtime are named, separated, and small**, and the
shared core is everything else. This is exactly the directory discipline the
backend-suite work converged on — a layout that keeps `shared/` source apart
from the per-runtime `native/` edges and the `divergences/` ledger, so the thing
you vendor is the pure core and nothing else.

The same instinct shows up in the deployment tooling: the polyglot deploy path
isolates the one *build-from-source* service from the prebuilt images, because
that is the part whose behaviour is runtime-specific. The lesson generalises
past code into infrastructure — find the seam, draw a box around it, and keep
the box as small as you can.

## Checklist for code meant to run on more than one runtime

1. **Zero FFI in the shared core.** Push every `foreign import` to a library
   that already ports, or to a thin per-runtime edge module. An FFI in shared
   code is a debt counted per target.
2. **Pin compatible package sets, or budget import reconciliation.** The gap is
   mechanical to close but never closes itself, and it grows.
3. **Differential-test behaviour, don't infer it from a green build.** Same
   source + same compile ≠ same events. The conformance suite exists for exactly
   this; an app sharing code across runtimes wants the same discipline on its own
   hot paths.
4. **Pick a serialization library that ports.** JSON is usually the wire between
   runtimes, and the default stack (Argonaut) is JS-only. A *shared* codec module
   needs FFI on every target (`simple-json` / `yoga-json`); a string-only
   boundary just needs an agreed wire format, so each side can choose its own.

## See also

- [Writing a backend](/resources/) — the suite-side view. "Ground rules
  (learned the hard way)" and the purerl package-set warning are the mirror of
  Seam 2 here.
- [The backend family](/#backends) — where each runtime sits, and the
  divergence ledger Seam 3 feeds.
