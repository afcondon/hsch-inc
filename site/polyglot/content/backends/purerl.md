# purerl — Erlang / BEAM

<p class="meta-row"><strong>Target:</strong> Erlang / the BEAM ·
<strong>Lineage:</strong> compiler-integrated (own frontend + optimizer) ·
<strong>By:</strong> id3as ·
<strong>Status:</strong> production-mature ·
<strong>Repos:</strong> <a href="https://github.com/purerl/purerl">purerl/purerl</a> ·
<a href="https://github.com/id3as/purescript-backend-erl">id3as/purescript-backend-erl</a></p>

purerl borrows the BEAM's **process model** — supervision, distribution,
soft-realtime scheduling — and keeps PureScript's type system on top. Its
semantic divergences are *upgrades along the BEAM grain*: arbitrary-precision
integers and binary strings, accepted rather than papered over. It runs in
production at id3as for media streaming, with maintained package sets.

There are two Erlang backends. The original **purerl** is Haskell-based and
reads CoreFn directly with its own hand-written optimizer (compiler-integrated).
The newer **purs-backend-erl** is a PureScript rewrite that consumes the
[backend-optimizer](https://github.com/aristanetworks/purescript-backend-optimizer)
IR (~30–40% faster output). Both are maintained by id3as and FFI-compatible.

## At a glance

| | purerl |
|---|---|
| **Functions** | curried funs; arity-optimized top-level variants |
| **ADT values** | tagged tuples, atom tag: `{just, X}` |
| **Records** | Erlang maps (atom keys) |
| **Typeclass dictionaries** | maps |
| **Int** | **bignum** (arbitrary precision) |
| **Strings** | UTF-8 binaries |
| **TCO** | **native BEAM TCO, including mutual recursion** |
| **Concurrency** | **processes + OTP supervision — the raison d'être** |
| **Native niche** | soft-realtime distributed systems, live supervision trees |
| **Library coverage** | large curated package sets |

## Expected divergences

`Int` is bignum, so the `INT64-` tests give exact answers (JS is the odd one
out). Float printing via `io_lib:format` may differ from JS in exponent zones —
discover it differentially. Strings are UTF-8 binaries, so `ASTRAL-` tests
agree with the other bignum/UTF-8 backends, not JS. The core libs are mature —
expect few shim bugs; most divergence is deliberate grain.

## In this ecosystem

purerl is the scheduling substrate for **purerl-tidal** — TidalCycles ported
to PureScript/Erlang, with live supervision of a per-voice tree.
