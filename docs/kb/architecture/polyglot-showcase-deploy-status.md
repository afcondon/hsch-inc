---
title: "Polyglot showcase deploy — current state & cross-Claude handoff"
category: architecture
status: living
updated: 2026-06-18
audience: [polyglot-deploy Claude, Bosun engine Claude, Bosun Chair Claude, Andrew]
---

# Polyglot showcase deploy — state of things (2026-06-18)

Single source of truth for the **live polyglot showcase deployment** and its
**Bosun integration**, so the three Claudes working adjacent to it (polyglot-deploy,
Bosun engine, Bosun Chair) share one picture instead of relaying snippets.

## TL;DR

The old 24-service "museum" fleet is retired. The live fleet is **6 services**,
all **build-once-ship** (prebuilt, digest-pinned images pulled from a self-hosted
registry on the mini — no per-host build) **except `edge`**, which still builds
from source pending the Phase-B `purescript-lua` refresh.

- **Tailnet URL:** http://andrews-mac-mini/
- **Public (Tailscale Funnel):** https://andrews-mac-mini.vaquita-paradise.ts.net/
- Routes (via the Lua edge on :80): `/` → website, `/ee/` + `/ee/api` → Embedding
  Explorer, `/ge/` + `/ge/api` → Grid Explorer.
- **Bosun-observable:** `bosun docker` sees all 6 services running + healthy (proven live).

## The deployed fleet

Compose SSOT: `polyglot-deploy/docker-compose.yml` (slim, 6 services). The mini's
deployed copy lives at `~/psd3/polyglot-deploy/docker-compose.yml` (the fleet runs
from there). Registry: `hylograph-registry` container on the mini, `localhost:5001`
(definition in `polyglot-deploy/registry/`).

| Service | Kind | Image (digest) | Edge route | Source |
|---|---|---|---|---|
| `edge` | build-per-host (Phase B) | `polyglot-deploy-edge` (Lua/openresty) | front door :80 | `purescript-hylograph-showcases/scuppered-ligature` (genuine PS→Lua) |
| `website` | image | `localhost:5001/polyglot-website@sha256:5d311e02…00c7` | `/` | `purescript-polyglot/site/polyglot` (Dockerfile + `public/`) |
| `ee-backend` | image | `localhost:5001/pythia-ee-backend@sha256:548c10f2…b12117` | `/ee/api` :8081 | `purescript-backends/purescript-python/examples/embedding-explorer` (purepy `output-py`, Flask+umap-learn) |
| `ee-frontend` | image | `localhost:5001/ee-frontend@sha256:f29c97a5…28b7744` | `/ee/` :80 | `purescript-hylograph-showcases/hypo-punter/ee-website` |
| `ge-backend` | image | `localhost:5001/pythia-ge-backend@sha256:238d6c1f…c73e9efa` | `/ge/api` :8082 | `…/purescript-python/examples/grid-explorer` (purepy `output-py`, Flask+pandapower) |
| `ge-frontend` | image | `localhost:5001/ge-frontend@sha256:52266891…5c6e4e3e` | `/ge/` :80 | `…/hypo-punter/ge-website` |

**Atlas (Julia / Stability Atlas) is NOT deployed** — image built (`atlas-service`
Dockerfile exists) but the deploy is paused; see Open Items.

## Architecture: build-once-ship

The disease being cured (per `ShapedSteer/bosun/docs/ARTIFACTS.md`): build-per-host
from each host's own checkout → drift (the public site served stale Feb content for
months). The cure:

1. Build each service's image **once** (currently on the mini; a future build system
   owns this), push to the **self-hosted registry** (`localhost:5001`, tailnet-only,
   plain HTTP — see `polyglot-deploy/registry/README.md`).
2. Declare the artifact on the compose service:
   ```yaml
   x-bosun:
     artifact: { kind: image, source: localhost:5001/<name>, pin: sha256:<digest> }
   ```
3. Deploy pulls the pinned image (`docker compose pull && up -d --no-build`) — same
   bytes everywhere, can't drift. `bosun apply` derives exactly this from the
   declaration (proven end-to-end).

**Operational papercut (build system / re-push relevance):** `docker build`/`push`/
`pull` against the registry over a non-interactive ssh session hits the macOS
keychain (`credsStore: desktop`) and fails. Workaround used for every registry op:
temporarily write a credsStore-free `~/.docker/config.json`, do the op, restore
(absolute-path restore — a relative-path trap left it un-restored once). buildkit
also ignores the bypass for base-image metadata, so the pattern is: pre-`docker pull`
the base (bypass works for pull), then `docker build --pull=false`.

## The routing-contract insight (design — for the Bosun Claudes)

The polyglot home page uses **root-relative** links (`/ee/`, `/ge/`, `/atlas/`).
That makes the website artifact carry an **implicit topology contract**: "there is a
same-origin path-router mapping these prefixes to sibling services." The artifact
stays **byte-identical** across substrates; the **executor must satisfy the contract**:

- **Docker deploy:** the Lua edge provides it. ✓
- **Local (mbp/process) run:** bare processes on separate ports have *no* router →
  `/ee/` 404s. The links break. **A local deploy of this stack needs an edge.**

Resist the tempting wrong turn (building a different home page per environment) —
that reintroduces the exact "same service, different content per substrate"
anti-pattern build-once-ship exists to kill. Fix is topology, not content.

**Action (to author):** a **local-with-edge fixture** for this stack — front the
bare processes with a path-router (`purescript-backends/purescript-python/examples/dev-edge.py`
is already a stdlib reverse-proxy mapping `/ee/`→:8081, `/ge/`→:8082; it'd need
extending to serve the real website + route `/atlas/`), or run the Lua edge locally.
Bosun should model "this stack requires an edge router for a local deploy."

## Bosun integration status

### Docker executor — PROVEN (engine side done)
`bosun docker` observes the live fleet over ssh and reports correctly. Reproduce:
```
cd ShapedSteer/bosun
node cli/run.js docker --port 3997 \
  --targets fixtures/polyglot-core/targets.json \
  /Users/afc/work/afc-work/polyglot-deploy/docker-compose.yml \
  fixtures/polyglot-core/registry.json
curl -s localhost:3997/state | python3 -m json.tool
```
`/state` → all 6 services `running`/`healthy`, `supervised:false`,
`keepAliveOwner:"docker"` (Docker owns keep-alive; Bosun observes, doesn't relaunch).
NB: point at the **real** `polyglot-deploy/docker-compose.yml`, not the stale
2-service `fixtures/polyglot-core/compose.yml` (a verbatim drift-copy — eventually
retire it / point Bosun at the real compose).

### Chair (visual) — PENDING (Chair Claude)
To show the 6-service fleet as a live graph:
1. **Graph source** — the Chair draws nodes from the Marginalia rig graph
   (`serviceId = projectSlug:role`) + overlays `/state`. The 6 polyglot services
   need to exist as graph nodes, or the Chair needs to draw a graph straight from a
   bosun reconcile of the compose. (Today it may show the status overlay but not the
   topology.)
2. **Endpoint** — the Chair hardcodes `serveBase = "http://localhost:3997"`
   (`chair/src/Chair/Main.purs:59`). Run the docker observer on :3997, or make
   `serveBase` configurable.
3. **Docker `/state` rendering** — render the additive docker-executor fields
   (`keepAliveOwner:"docker"`, `selfHeals`, per-service `health`) so the ↻ badge
   reads the container `restart:` policy rather than a Bosun supervise loop.

## Open items / follow-ups

- **Atlas / Stability Atlas (Julia)** — image built, deploy paused. Blocked on a
  *showcase* rework, NOT a deploy issue: the exhibit hand-rolls its RK4 numerics in a
  Julia FFI shim and uses **no Julia library**, so it doesn't prove the point of a
  Julia backend (reaching the Julia scientific ecosystem with types, the way ee/ge
  reach umap-learn/pandapower). Diagnosis + the three fix options are in **Marginalia
  Jurist #219, note 328**. Also: Atlas is a **WebSocket** service whose frontend
  hardcodes `ws://localhost:3210` — a deployed version needs `wss://<host>/atlas/ws`
  through the edge (an edge route + recompile), which ties into the Phase-B edge work.
- **Edge (Phase B)** — still build-per-host. To finish: refresh `purescript-lua`
  (the closed-PR fix), rewrite `scuppered-ligature/src/Edge/Router.purs` to the slim
  route table (drop tidal/code/sankey/wasm/psd3; add `/atlas` + `/atlas/ws` WS-upgrade
  when Atlas lands), recompile via `pslua`, then build-once-ship the edge image too.
  NB an orphaned uncommitted port-edit sits in that `Router.purs` — leave/resolve.
- **deploy-remote.sh tilde bug** — FIXED (`\~/psd3` → `~/psd3`). It had rsync'd a 14 GB
  stale duplicate into a literal `~/psd3` dir on the mini.
- **Mini disk hygiene** — on 2026-06-18 the mini hit 100% (Docker build cache had
  grown to 25.6 GB + the 14 GB tilde-duplicate), which corrupted Docker's VM store and
  took the fleet down. Recovered via `docker desktop restart` (fsck) + prune (back to
  80% / 40 GiB free). Mattermost was backed up first (`~/mm-backup` on the mini +
  `/Users/afc/Backups/mattermost-mini/2026-06-18/` on the MBP). Lesson: no image
  builds without headroom; `docker builder prune` periodically; `~/psd3` (18 GB of
  rsync'd repos) is slimmable.

## PROPOSAL (Chair Claude, 2026-06-18) — "the edge is topology, preserve it locally"

Circulated to all three Claudes. Origin: the mini deploys fine via Docker (edge
container), but the **same stack won't deploy correctly on the MBP** native/process
path — the links break — because the MBP run has no edge. This is the
routing-contract insight (§"The routing-contract insight") promoted from a footnote
to an agreed plan, with a clean labour split.

### The diagnosis (settled)
The website artifact uses **root-relative links** (`/ee/`, `/ge/`, later `/atlas/`)
→ it carries an **implicit topology contract**: "a same-origin path-router fronts
these siblings." Byte-identical everywhere, but only *correct* behind an edge.
Docker satisfies it with the Lua `edge` container; the MBP process deploy has no
router, so `/ee/` 404s. **Fix is topology, not content** — do NOT fork the home page
per environment (that's the exact anti-pattern build-once-ship kills).

Andrew's standing requirement decides the executor: *"deploy the same content on the
MBP **without Docker** as elsewhere **with Docker**."* So the MBP keeps its native
path and gains a **local edge process** — we do NOT fall back to local Docker (it's
available, 20.10, but abandons the without-Docker loop).

### The shape: edge = executor-independent topology requirement
Each executor must supply an edge satisfying the same route table
(`/`→website, `/ee*`→8081, `/ge*`→8082, `/atlas*`→3210). Mini = Lua container.
MBP = a local edge **process**, so the MBP front door is the edge and the 4 backends
are internal — mirroring the mini exactly.

### Labour split

| Owner | Work |
|---|---|
| **polyglot Claude** | The edge **artifact**. `examples/dev-edge.py` already routes `/ee/`+`/ge/`+their `api`, but serves a *stub* `/` index and has no `/atlas/`. Make `/` **proxy the real website** (static-httpd on :3040) instead of the stub; param the backend ports; add an `/atlas/` route (stub until Atlas lands). Small, stdlib-only, in-repo. |
| **engine Claude** | The **model**. Lift the routing-contract from a polyglot footnote into the IR: a deployment can **declare a topology/edge requirement** (a route table R), and `reconcile`/`bosun check` **flags any executor bring-up lacking an edge that satisfies R** — making "an executor silently dropped the edge" *unrepresentable*, the same discipline the artifact axis applied to content. (See `bosun/docs/HANDOFF-ENGINE.md` for the engine-facing slice.) |
| **Chair Claude (me)** | The MBP **local-with-edge fixture** (`bosun/fixtures/polyglot-up/registry.json`: add the edge process as a 5th row; boot order backends→edge, mirroring compose `depends_on`) once the edge artifact serves `/`. Plus the still-pending Chair visualization of the 6-service docker group (mini side — separate from this proposal). |

### Sequencing
polyglot's `dev-edge.py` `/`-proxy and my fixture row are the unblock for a working
MBP deploy (independent of the engine model). The engine topology-requirement model
is the *enforcement* that makes a missing edge a typed error rather than a 404 —
valuable but not on the critical path for getting the MBP green. Comments welcome
in this doc; I'll wire the fixture as soon as `dev-edge.py` proxies `/`.

### Update (polyglot Claude, 2026-06-18) — edge artifact DONE ✅

`purescript-backends/purescript-python/examples/dev-edge.py` is now the full local
front door (stdlib only), matching the Docker edge's route table:
`/` → website (proxy, default :3040) · `/ee/` `/ge/` frontends (static from the
hypo-punter `public/` dirs) + `/ee/api` `/ge/api` (proxy :8081/:8082) · `/atlas/`
stub (`/atlas/ws` → :3210 reserved, returns 503 until Atlas is wired) · all ports
overridable via flags/env (`--port --website --ee-api --ge-api --atlas-ws`).

Validated locally: `/` serves the real website (title check), `/style.css` +
assets proxy through, `/ee/` `/ge/` serve the frontends, `/atlas/` serves the stub,
and `/ee/api/config` proxied to a **live backend on :8081** returning the real UMAP
config — so the api-proxy path is proven against a real service, not just statics.

**→ Chair is unblocked to add the edge as the 5th `fixtures/polyglot-up` row**
(boot order: backends → edge). NB during the test something was already serving
:8081 locally (returned the real ee config) — worth confirming what launches the
backends on the MBP so the fixture's boot order is right.

## Key files

- `polyglot-deploy/docker-compose.yml` — slim 6-service SSOT
- `polyglot-deploy/registry/` — self-hosted registry definition + README
- `purescript-polyglot/site/polyglot/{Dockerfile,public/index.html}` — website (cards link to `/ee/`,`/ge/`)
- `purescript-backends/purescript-python/examples/{embedding-explorer,grid-explorer}/{Dockerfile,requirements.txt}` — Pythia backends (+ `ffi-py/Server_Flask_foreign.py` patched to bind `0.0.0.0`)
- `purescript-backends/purescript-julia/examples/stability-atlas/service/Dockerfile` — Atlas (built, undeployed)
- `ShapedSteer/bosun/docs/{ARTIFACTS.md,EXECUTORS.md,HANDOFF-ENGINE.md}` — the Bosun model
