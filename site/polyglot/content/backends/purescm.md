# purescm — Chez Scheme

<p class="meta-row"><strong>Target:</strong> Chez Scheme (a Racket port has been investigated) ·
<strong>Lineage:</strong> optimizer-IR consumer ·
<strong>By:</strong> Nathan Faubion / Arista <em>(confirm before publish)</em> ·
<strong>Status:</strong> experimental ·
<strong>Repo:</strong> <a href="https://github.com/aristanetworks/purescm">aristanetworks/purescm</a> <em>(verify)</em></p>

purescm consumes the
[backend-optimizer](https://github.com/aristanetworks/purescript-backend-optimizer)
IR (uncurrying, inlining) rather than rolling its own, and emits R6RS Scheme
libraries for Chez. Chez CS is a high-performance Scheme; the backend borrows
its compiler and runtime.

A thorough internal investigation exists into **porting purescm to Racket**
(Racket CS is built on Chez, so the bytecode-level performance is similar) — see
the digest in our knowledge base. That port is a *different* effort from
Fabrizio Ferrai's [Purkt](purkt/), despite the name collision; keep the two
straight.

> This page is a stub. Full column — semantic divergence table, FFI notes — to
> be filled from observed facts once purescm is run through the differential
> suite. Attribution and repo link to be confirmed.
