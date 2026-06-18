# Agent Skills and Deployment Data Model

**Status**: active (proposal + current-state audit)
**Date**: 2026-04-14
**Scope**: How agent skills, project-local slash commands, and Marginalia interact across the `afc-work` tree. Proposes an extension of Marginalia's `servers` model to make deployment a query rather than a skill.

## Summary

Three overlapping mechanisms currently encode "how do I build/run/deploy this thing":

1. **Per-project slash commands** (`.claude/commands/*.md`) — prose instructions the agent interprets.
2. **Canonical agent skills** (`tools-for-agents/*-skills/` + symlinks) — domain knowledge reusable across projects.
3. **Marginalia `servers` registry** (`/api/ports`) — declarative data: port, URL, `startCommand`, description, per project.

The three overlap badly. Port tables duplicated in multiple slash commands drift from each other and from Marginalia; prerequisites and troubleshooting live in commands where they can't be queried; canonical skills have drifted consumer copies. The proposal in this doc is to let each mechanism do what it's good at:

| Concern | Best mechanism |
|---|---|
| "What runs where, with what command" | Marginalia (data) |
| "What stepwise orchestration across multiple projects" | Makefile (deterministic) |
| "How do I interpret this build failure / choose this package / bundle this frontend" | Skills (adaptive) |

Slash commands become a thin typing convenience, not a knowledge store. Marginalia gains an `environment` dimension so "how do I deploy X to Y" becomes a lookup.

## Current-state inventory (April 2026)

### Slash commands under `~/work/afc-work`

| Path | Purpose | Assessment |
|---|---|---|
| `music/producing-with-your-feet/.claude/commands/ps.md` | Build/bundle/serve Pedal Explorer | **Deleted** — fully covered by Marginalia `startCommand` + PureScript ecosystem skill |
| `.claude/commands/deploy.md` | CodeExplorer deploy (local native) | Port table duplicates + drifts from Marginalia; troubleshooting prose valuable but misplaced |
| `purescript-polyglot/.claude/commands/build.md` | Wrapper over PSD3 Makefile | Thin wrapper over deterministic Makefile; adaptive value is build-failure diagnosis + `.claude-focus` awareness |
| `purescript-polyglot/.claude/commands/deploy.md` | Hylograph local + MacMini remote deploy | Only local record of MacMini IP, docker path override, rsync flow; port tables stale |
| `purescript-polyglot/.claude/commands/feature.md` | Feature branch coord | Repo-specific, keep |
| `purescript-polyglot/.claude/commands/css-review.md` | CSS review checklist | Repo-specific, keep |
| `purescript-polyglot/.claude/commands/plan-stack.md` | Plan stack management | General idiom, could be a skill |
| `CodeExplorer/.claude/commands/annotate.md` (+ duplicate in `minard/`) | Minard semantic annotation workflow | Domain feature, not tooling — keep |
| `GitHub/beads/.claude/commands/handoff.md` | External repo, not ours | N/A |
| `archived/PSD3-Repos/.claude/commands/*` | Archived | N/A |

### Canonical skills

| Path | Git | Contents |
|---|---|---|
| `tools-for-agents/purescript-skills/` | Yes (`afcondon/purescript-agent-skills`) | purescript, purescript-ecosystem, purescript-tooling, fp-police |
| `tools-for-agents/duckdb-skills/` | **No** (should be) | duckdb-gotchas |
| `agent-teams/project-tracker/.claude/skills/` | Yes (project-tracker repo) | marginalia, what-next |

### Consumer locations (at time of writing)

| Path | Status after cleanup |
|---|---|
| `~/.claude/skills/` | Symlinks for marginalia, what-next |
| `~/work/afc-work/.claude/skills/` | Now symlinks to `tools-for-agents/purescript-skills/` (was drifted plain files; `purescript-tooling.md` added) |
| `agent-teams/project-tracker/.claude/skills/` | Has its own purescript copies — left alone (repo may be cloned elsewhere) |
| `purescript-hylograph-libs/purescript-hylograph-selection/.claude/skills/` | Has purescript + hylograph-specific copies — left alone (pinned to repo) |

**Drift lesson**: when you edit a skill, edit the canonical in the git-managed dir. Consumer directories should be symlinks unless there's a concrete reason a repo needs its own copy (e.g. it will be cloned and used standalone).

## Deterministic vs adaptive: the intended balance

Claude Code is strong at *adaptive* work — reading errors, picking the right fix, navigating unfamiliar code. That strength is also the failure mode: when adaptive tooling stands in for structure, two things happen in prose-encoded commands:

1. **It drifts.** Port tables copied into three command files diverge the moment any one of them is edited.
2. **It re-derives.** Each session reconstructs the same "how do I start this" plan from prose, at token cost, sometimes with subtle variations.

Declarative/deterministic substrates (Makefiles, Marginalia data, shell scripts) don't drift and don't re-derive. But they can't replace judgment — no Makefile knows whether a build error wants a missing import or a type-annotation fix.

The working split:

- **Data** (ports, commands, URLs, environments, prerequisites): Marginalia.
- **Orchestration that doesn't vary** (build pipelines, deploy-to-MacMini rsync flow): Makefile targets or shell scripts, invoked by command name.
- **Judgment** (failure diagnosis, skill-matching, choosing a package): agent skills.
- **Typing shortcuts**: slash commands — *thin*, pointing at the above.

The existing `/build`, `/deploy`, `/ps` commands mix all three layers. The refactor target: each layer in its own mechanism, commands thin down to shortcuts.

## Proposed extension: environments in Marginalia

Currently `servers` in Marginalia implicitly means "localhost on this machine." That works for dev, not for the reality that projects in this tree run in ~6 different environments:

- `mbp-native` (MacBook Pro, native processes)
- `mbp-docker` (MacBook Pro, Docker — rare, historically avoided for performance)
- `macmini-native` (MacMini, native processes)
- `macmini-docker` (MacMini, Docker — the remote deploy target)
- `cloudflare-pages` (hylograph.net, static hosting)
- `tailscale-funnel` (MacMini exposed via Tailscale)

### Option A (minimal): add `environment` field to servers

```json
{ "role": "frontend", "port": 3301, "environment": "mbp-native",
  "startCommand": "cd /Users/afc/... && spago bundle ... && npx http-server ..." }
{ "role": "frontend", "port": 80, "environment": "macmini-docker",
  "startCommand": "cd ~/psd3 && docker compose up -d sankey" }
```

One extra string field. `/api/ports` becomes environment-aware. "How do I deploy sankey to macmini?" is:

```
GET /api/projects/<id>/servers?environment=macmini-docker
```

### Option B: environments as a tracked project category

Parent project `infrastructure/environments` with children for each environment. Each environment holds its own metadata: MacMini Tailscale IP, docker path override, remote base dir, DNS config, etc. Server entries reference an environment by id.

### Option C: both

`environment` field on servers is the join key; environment-as-project holds the metadata. Closer to a relational model, more moving parts.

**Recommendation**: start with A. Add environment-as-project when metadata accumulates (the MacMini case already justifies it: Tailscale IP, `/usr/local/bin/docker` path, `~/psd3/` base, SSH user — all of which currently live only in `purescript-polyglot/.claude/commands/deploy.md`).

### What this unlocks

- Slash commands stop duplicating port tables.
- `/deploy <service> <env>` becomes a two-step lookup, not a hand-maintained doc.
- Remote deployment orchestration (rsync + ssh + docker compose) moves into Makefile targets or shell scripts whose existence is registered as the env-specific `startCommand` in Marginalia.
- Per-project prerequisites ("API must launch from `minard/` directory", "DuckDB lock before running loader") move into note fields or a new `prerequisites` field on servers, where they're queryable.

## Marginalia project structure for tracking skills

Created under parent **Agent Skills** (id=162, slug `xray-alpha-xray-alpha`):

- `purescript-agent-skills` (id=163) — the git-managed canonical PureScript skills
- `duckdb-skills` (id=164) — DuckDB gotchas, needs git-init
- `marginalia-skills` (id=165) — marginalia + what-next, canonical in project-tracker repo

Deliberately **not** created: a "project deployment skills" child. Deployment is data (Marginalia servers + environment), not a skill. Failure diagnosis during deployment is covered by existing general skills.

The pre-existing project "Claude Code PureScript skills" (id=33, status=done, currently parented under Polyglot) is the *historical conversion story* — turning the ecosystem-site plan into agent skills. It can stay where it is; the new `purescript-agent-skills` child tracks the ongoing artifact.

## Open items

1. ✅ **Implement environment field** on Marginalia servers — done 2026-04-14. Added `environment` and `prerequisites` TEXT columns to `project_servers`; plumbed through `ServerRow` decoder/encoder, SQL queries, and POST handler (`server/src/API/Servers.purs`); added to frontend `Server` type, `decodeServer`, and `renderServerRow` with CSS chip for env and italic prereq line. Existing 13 server rows backfilled: all `mbp-native` except the edge router (`macmini-docker`).
2. ✅ **Migrate port tables** — mostly done 2026-04-15. Registered 17 server entries from `purescript-polyglot/.claude/commands/deploy.md`: sankey (api+frontend), purerl-tidal backend, tidal radio frontend, 5 static showcases (wasm-force/lorenz/emptier-coinage/hylograph-app/allergy-outlay), hypo-punter 5 sub-servers (ee-api/ee-frontend/ge-api/ge-frontend/landing) under project 78, ShapedSteer frontend, Polyglot website + blog. All with `environment: "mbp-native"`. **Remaining**: (a) port 3014 prim-zoo-mosh skipped — psd3-prim-zoo-mosh not in Marginalia, needs project creation first; (b) purerl-tidal backend (3012) startCommand is a placeholder — the real incantation lives in the repo README and needs a pass; (c) ShapedSteer path may need verification (registered as `ShapedSteer/shaped-steer/` per deploy.md). Descriptions on all new rows include "Sourced from …deploy.md 2026-04-15 — not retested this session" so future eyes know what hasn't been smoke-tested.
3. ✅ **Decide on prerequisites field** shape — done. Plain freeform TEXT; rendered as an italic line below the server row with a warning glyph. Structured alternatives (array of flag conditions) felt premature; prose handles the observed cases ("API must be stopped before loader runs", "bundle must exist", "cwd must be package dir for DB path resolution") without ceremony.
4. ✅ **Git-init `tools-for-agents/duckdb-skills/`** — done 2026-04-14, one initial commit. The meta-question ("should `tools-for-agents` itself be a meta-repo?") is still open.
5. ✅ **Refactor `/deploy` and `/build` commands** — done 2026-04-15. Three files rewritten:
   - `afc-work/.claude/commands/deploy.md` (CodeExplorer): port tables, start/stop commands, and URL list stripped (all in Marginalia now); Minard API + frontend prerequisites migrated into Marginalia's new `prerequisites` field on the respective server rows; rebuild flows (spago build -p, bundle, loader reload, cargo) kept; troubleshooting kept. ~225 lines → ~100 lines.
   - `purescript-polyglot/.claude/commands/deploy.md` (Hylograph): all localhost port tables stripped; remote MacMini Docker flow kept (not yet migrated to Marginalia); generic service-discovery recipes added so future agents query Marginalia rather than guessing.
   - `purescript-polyglot/.claude/commands/build.md` (PSD3 Build → Build): stale PSD3-Repos references removed, stale `.claude-focus` mechanism removed (file doesn't exist anywhere); thinned to Makefile wrapper + backend-specific failure-triage table, pointing at `/purescript-ecosystem`, `/purescript-tooling`, `/purescript` for the details. "After building deploy via Docker" section removed (that flow is `/deploy` now).
6. ✅ **Plan-stack** — promoted 2026-04-15 to `~/.claude/commands/plan-stack.md` (user-level slash command). It's entirely generic (operates on `~/.claude/plans/`, no PSD3 content), and shaped as an explicit slash command (push/pop/list/clear), so command-level makes more sense than skill-level.
7. ✅ **`spago bundle --outfile` path semantics** — done. Added a "Gotcha" callout to the Bundling for the Browser section in `tools-for-agents/purescript-skills/.claude/skills/purescript-ecosystem.md` (symlinked into consumer dirs). Same gotcha also referenced from the Minard rebuild flow in the refactored CodeExplorer deploy.md.

## Remaining follow-ups (smaller)

- ✅ **Retest** `purerl-tidal` startCommand — done 2026-04-15. Port was actually 8080 (WebSocket), not 3012 as deploy.md claimed; role changed backend→websocket; prerequisites about rebar3 + purerl + sendmidi added.
- ✅ **Retest** `ShapedSteer` :3030 path — done 2026-04-15, `ShapedSteer/shaped-steer/` verified.
- ✅ **Create** `psd3-prim-zoo-mosh` Marginalia project — done 2026-04-15 (id 168, slug `yankee-hotel-oscar-juliet`), :3014 registered.
- ✅ **Implement** the PWYF Infovore store — done 2026-04-15 (Phase 1 + Phase 2 together). See project 166 note 111 for implementation detail.
- **Migrate** per-service MacMini Docker startCommands from `purescript-polyglot/.claude/commands/deploy.md` into Marginalia as `environment=macmini-docker` entries, so the Hylograph deploy doc can shrink further.
- **Synology cron** for Infovore data mirror (TODO note on project 5, id 106).
- **PWYF safety net**: load `latest.json` from the connected folder if localStorage is empty on startup. Closes the "backup fires but is never used" scenario.
- **PWYF non-Chrome fallback**: friendly message in the Folder Backup card when `window.showDirectoryPicker` is undefined (Firefox, Safari).
- ✅ **Marginalia DELETE endpoints** — done 2026-04-15. `DELETE /api/notes/:id` and `DELETE /api/projects/:id/tags?name=<tag>` added, paralleling the existing `DELETE /api/servers/:id`. Still no PUT for notes or tags.

## References

- [Marginalia API skill](~/work/afc-work/agent-teams/project-tracker/.claude/skills/marginalia.md) — authoritative API surface
- `/api/ports` and `/api/ports/suggest` — the port registry
- [afcondon/purescript-agent-skills](https://github.com/afcondon/purescript-agent-skills) — canonical PureScript skills repo
