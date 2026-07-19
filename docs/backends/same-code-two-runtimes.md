# Same code, two runtimes: where the promise leaks

The backend family promises that one PureScript source tree runs on many
runtimes. `adding-a-backend.md` documents that promise from the *suite*
side — how to make a backend pass the differential conformance tests.
This doc documents it from the *application* side: what actually happens
when you take a substantial program written for one runtime and run it,
unchanged, on another.

The worked example is real. Triggerfish (a JS/Halogen app,
`music/live-coding/triggerfish`) needed TidalCycles mini-notation: turn
`"bd*3 ~ bd(3,8)"` into scheduled events. That parser + pattern engine
already exists, written for **BEAM/purerl**, in purerl-tidal
(`music/live-coding/purerl-tidal/src/Tidal/**`). So we vendored it —
~3,900 lines across 12 modules — into a JS app and asked the promise to
pay out.

It largely did. But the seams are worth naming, because they are the
same seams every cross-runtime sharing hits.

## Where it held: the pure core travels for free

The entire closure — `Tidal.Parse.*` (combinator parser),
`Tidal.AST.*`, `Tidal.Pattern.{Types,Core}` (the `Pattern = State ->
Array Event` query model over `Data.Rational` time), `Tidal.Eval.*`,
`Tidal.Chords`, `Tidal.Notation` — is Prelude-family PureScript. It
compiled against the JS registry and ran with **zero logic changes**.
`queryArc (parse "bd*3") 0 1` returns onsets at exactly `0, 1/3, 2/3`;
`bd(3,7)` gives a true septuplet euclid; `[bd sn] cp` nests correctly.
Rational time means no float drift across the runtime boundary. This is
the promise delivered: thousands of lines of non-trivial logic, written
for Erlang, running byte-for-byte-equivalent on V8.

Everything below is the residue — the narrow set of things that did
*not* travel.

## Seam 1 — FFI is the boundary, and it does not cross

The one `foreign import` in the whole closure was
`Tidal.Parse.Class.readFloat :: String -> Number`, backed by an Erlang
module `tidal_parse_class@foreign` (`string:to_float`). On JS that
foreign module simply does not exist; the code cannot load.

The fix was **not** to write a JS shim. It was to delete the FFI and
call `Data.Number.fromString` — a library function the `numbers`
package already provides on every runtime. The seam moved from our code
(one obligation per target runtime, forever) to the library's (already
discharged by its maintainers).

> **Rule.** Every `foreign import` in shared code is a portability debt
> with one line-item per runtime you target. Before writing one, check
> whether a Prelude-family library already exposes the operation — you
> inherit its per-runtime ports instead of owning yours. Reserve FFI for
> the genuine runtime edge (DOM, BEAM processes, OS) and keep it out of
> the shared core entirely, or behind a thin per-runtime module the
> shared core imports by name.

`readFloat` failed this test: it was a hand-rolled FFI for something
`Data.Number.fromString` does portably. It was invisible on BEAM
because the Erlang shim was right there. It surfaced the instant the
code changed runtimes.

## Seam 2 — package-set drift: same source, two package universes

purerl-tidal is pinned to the purerl package set
(`erl-0.15.3-20220629`). The JS app is on the registry set `73.3.0`.
These are not the same library universe, and the BEAM set trails the JS
registry by years. Concretely, the vendored source would not compile
until these were reconciled:

| purerl set (what the source said)      | JS registry 73.3.0 (what it needs) |
|----------------------------------------|------------------------------------|
| `Text.Parsing.Parser`                  | `Parsing` (renamed in `parsing` v9) |
| `Text.Parsing.Parser.Combinators`      | `Parsing.Combinators`              |
| `Text.Parsing.Parser.String`           | `Parsing.String`                   |
| `Text.Parsing.Parser.Pos (Position)`   | `Parsing` (`Position` gained an `index` field) |
| `Text.Parsing.Parser.Token (alphaNum, digit, letter)` | `Parsing.String.Basic` (the `Token` module was gutted) |
| `…String (skipSpaces)`                 | `Parsing.String.Basic`             |
| `Math (cos, floor, pi, sin, sqrt)`     | `Data.Number` (`Math` removed from core) |

The reconciliation is mechanical — import-path renames, no logic — but
it is **mandatory**, and there is no automatic translation layer. "Same
code" required hand-editing the import block of five modules. None of
this is a language failure; it is an ecosystem-versioning seam, and it
is the seam most likely to *widen* over time, because the purerl set is
community-maintained and lags the registry's churn.

> **Rule.** Cross-runtime sharing assumes either (a) compatible package
> sets, or (b) a budget for import reconciliation that grows with the
> version gap. If you intend to share a module long-term, prefer the
> oldest-common API surface, or vendor with the expectation of periodic
> re-sync. (We vendored under the original `Tidal.*` namespace precisely
> so a future re-sync against the rig is a clean diff.)

## Seam 3 — a related, distinct gap: the abstraction's own holes

Worth separating from the two above because it is *not* a runtime seam:
even running identical source on both runtimes, the engine's own
behavior is a fixed point — and it has holes. Mini-notation elongation
(`bd@3`, `bd _ _ sn`) is a silent no-op in this interpreter: the weights
are ignored and the events come out equal-spaced (verified empirically).
This would fail the same way on BEAM; it is not a portability failure.

But it is the same *shape* of failure — promise vs. delivery. The
surface language (mini-notation) advertises a feature the implementation
does not honor. Anyone relying on cross-runtime *parity* with Haskell
Tidal will assume an elongation semantics that is not present on either
runtime. The lesson generalizes:

> **Rule.** "Compiles and runs on both" is not "behaves identically on
> both," and neither is "behaves as the abstraction claims." These are
> three separate guarantees. Only the differential conformance suite
> (`adding-a-backend.md`) checks the second; only tests against the
> spec check the third. Cross-runtime confidence requires all three,
> not just a green compile.

## Checklist for code meant to run on more than one runtime

1. **Zero FFI in the shared core.** Push every `foreign import` to a
   library that already ports, or to a thin per-runtime edge module.
   An FFI in shared code is a debt counted per target.
2. **Pin compatible package sets, or budget import reconciliation.**
   The gap is mechanical to close but never closes itself, and it grows.
3. **Differential-test behavior, don't infer it from a green build.**
   Same source + same compile ≠ same events. The conformance suite
   exists for exactly this; an app sharing code across runtimes wants
   the same discipline on its own hot paths.

## See also

- `adding-a-backend.md` — the suite-side view; "Ground rules (learned
  the hard way)" and the purerl package-set warning are the mirror of
  Seam 2 here.
- `backend-comparison.md` — where each runtime sits in the family.
