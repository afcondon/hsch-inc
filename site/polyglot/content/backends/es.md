# purs-backend-es — optimizing JavaScript

<p class="meta-row"><strong>Target:</strong> JavaScript (ES modules) ·
<strong>Lineage:</strong> optimizer-IR consumer (flagship) ·
<strong>By:</strong> Nathan Faubion / Arista ·
<strong>Status:</strong> production ·
<strong>Repo:</strong> <a href="https://github.com/aristanetworks/purescript-backend-optimizer">aristanetworks/purescript-backend-optimizer</a></p>

`purs-backend-es` is the flagship consumer of
[`purescript-backend-optimizer`](https://github.com/aristanetworks/purescript-backend-optimizer)
— a separate, backend-agnostic tool that emits an optimized IR (uncurrying,
inlining) for downstream backends. Same *habitat* as the reference JS backend,
**different generator**: it produces more aggressively optimized JavaScript.

That makes it the natural **control column** for the matrix — it isolates "what
does the shared optimizer IR buy you?" from "what does changing runtime buy
you?". Several other backends (purs-backend-erl, purescm) consume the same IR.

> This page is a stub. Belongs on the matrix as a control column alongside the
> two reference-JS habitats.
