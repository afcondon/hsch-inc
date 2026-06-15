# Pythia — Python

<p class="meta-row"><strong>Target:</strong> Python ·
<strong>Lineage:</strong> CoreFn-JSON source-emitter (purepy, Jurist architecture) ·
<strong>By:</strong> this project (Claude-authored, afc-maintained) ·
<strong>Status:</strong> 422/426 differential parity ·
<strong>Repo:</strong> in-ecosystem (<code>purescript-backends/purescript-python</code>)</p>

Pythia borrows Python's **ubiquity and data tooling** — the inverse argument
to most of the family: the libraries are the reason to be there. Rebooted from
scratch on the Jurist architecture (ADR-0001), it reached **422/426
byte-identical** — the same score as Jurist on the shared corpus.

The one structural twist is **module-level lambda lifting** (ADR-0002), needed
to clear CPython's parenthesis-nesting cap that deeply curried code would
otherwise blow.

## At a glance

| | Pythia |
|---|---|
| **Int** | Python bignum |
| **Strings** | `str` — Unicode codepoints |
| **Architecture** | Jurist skeleton + module-level lambda lifting |
| **Build** | spago with `backend.cmd: "true"` for CoreFn, then `purepy output output-py` |

## Divergences

Diverges from JS exactly like the other bignum/UTF-8 backends (`INT64` /
`ASTRAL` ledger): Python `int` is arbitrary precision, so `sumTo 1000000`
gives the exact answer; float repr differs from JS in the usual zones
(`inf` vs `Infinity` if unshimmed); `ASTRAL-` tests agree with Julia and BEAM.
Its own `test-project/cross_backend_test.py` is the prior art for the
column-adding task, with a curated KNOWN_DIVERGENCES set worth porting.
