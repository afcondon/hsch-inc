# JavaScript — the reference

<p class="meta-row"><strong>Target:</strong> JavaScript (browser &amp; Node) ·
<strong>Lineage:</strong> compiler-integrated (this <em>is</em> <code>purs</code>) ·
<strong>By:</strong> the PureScript core team ·
<strong>Status:</strong> reference, definitional ·
<strong>Repo:</strong> <a href="https://github.com/purescript/purescript">purescript/purescript</a></p>

The JavaScript backend is built into the compiler: `purs` lowers CoreFn to
CoreImp and emits optimized ES modules. Its virtue is **being everywhere** —
and being the semantic reference every other backend measures against. The
browser and Node are the same code generator in two habitats; what differs is
the runtime and FFI ecosystem, and therefore which programs make sense.

## At a glance

| | Browser | Node |
|---|---|---|
| **ADT values** | constructor functions + `instanceof`, fields `value0…` | same |
| **Records** | JS objects | same |
| **Int** | double wrapped `\|0` → int32 | same |
| **Strings** | UTF-16 code units | same |
| **Effect** | nullary thunk; MagicDo collapses binds | same |
| **TCO** | optimizer: self-tail-calls → `while` loops | same |
| **Concurrency** | event loop, workers | event loop, worker_threads |
| **Native niche** | DOM/UI (Halogen, react bindings) | servers, CLIs, tooling |
| **Library coverage** | entire registry | entire registry |

Because it's the reference, its quirks become the spec the others must decide
whether to honour — most consequentially **int32 `Int`** (which overflows on
`sumTo 1000000`) and **UTF-16 strings**.

## Also in this habitat

[`purs-backend-es`](https://github.com/aristanetworks/purescript-backend-optimizer)
(Faubion / Arista) is an *optimizing* JS generator built on the shared
backend-optimizer IR — same habitat, different generator. It belongs on the
matrix as a control column.
