# Serving the Mycroft/Cluedo demo from a static Cloudflare site

*2026-07-25. Plan for putting in-browser z3 — the `mycroft-z3-wasm`
backend — on Cloudflare Pages. The backend itself is built and green
in Node; this is the serving story.*

## Why this is possible at all

The one hard constraint is that the `z3-solver` WASM build uses
pthreads, so it needs `SharedArrayBuffer`, which browsers only enable
on a **cross-origin-isolated** page. That requires two response
headers:

```
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

Cloudflare Pages supports exactly this via a `_headers` file at the
site root — so a *static* deployment works; no worker, no server
code. (`COEP: require-corp` also means every subresource must be
same-origin or CORP-tagged: self-host all assets, no third-party CDN
tags on the demo page.)

Local development uses `wrangler pages dev`, which honours `_headers`
— plain `http-server` cannot set them, which is why the :3026 flow
can't host this as-is.

## Staged build

**Stage A — proof-of-concept page (small, de-risks the bundling).**
A minimal page in `purescript-mycroft` (new `web-demo/` package or
plain esbuild entry) that:

1. bundles a PS entry point calling `newZ3WasmSolver` and running the
   SmtLib integration beats (sat/model, scopes, enum, unsat core);
2. renders pass/fail + timings as text.

The known risk to burn down here is **bundling `z3-solver` for the
browser**: its emscripten artifacts (`z3-built.js`, `z3-built.wasm`,
worker script) must be copied as static assets next to the bundle and
resolvable at runtime — esbuild will not inline them. Expect an
`--external:` + asset-copy step in the build script, and check how
`z3-solver` locates its wasm (import.meta.url-relative) under
bundling. This is the only genuinely unknown ground in the plan.

**Stage B — the Cluedo oracle pane.** Kibitzer's frontend gains an
SMT pane driven by `mycroft-z3-wasm` (the game replay is pure
PureScript — `simulate` runs client-side, so no data files):

- beat 1 as a live chart: gap-over-time as the game scrubs (the
  monotone entailment cache from the CLI demo carries over);
- beat 2 on click: any undecided claim → its countermodel rendered as
  a full alternate deal;
- beat 3 per derived fact: proof events beside the unsat core.

**Stage C — deploy.** Build the static site into `cloudflare-sites/`
alongside the existing targets and create a Pages project for it
(`_headers` included in the built output). Candidate identity: a
`baskerville` or `kibitzer` Pages project rather than a path under an
existing site — headers apply project-wide and the isolation
requirement shouldn't leak onto pages that don't need it.

## Notes

- One WASM worker pool per page; `shutdownZ3Wasm` is irrelevant in
  the browser (page lifetime = pool lifetime).
- The WASM z3 is slower than native (~2-5×) and the .wasm is ~25 MB —
  fine for a demo page with a loading indicator; preload it.
- cvc5 has no equivalent WASM npm story; the browser backend is
  z3-only, which the `Transport` seam makes explicit rather than
  load-bearing.
