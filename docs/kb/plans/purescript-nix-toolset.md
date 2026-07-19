# The PureScript build-dedup toolset: pantry

*2026-07-19. Companion to `minard-for-operations.md` (§3 quartermaster,
§5.0) — the toolset track that runs alongside the package-set
homogenization sweep.*

## The problem, measured

122 spago `output/` dirs across afc-work hold 58,530 compiled-module
instances with only 3,773 distinct module names (`Data.Array` ×117).
Upper bound on dedup: ~90% of 6.77 GB. Plus 0.92 GB of `.spago` dep
sources duplicated per-project (not even hardlinked). The win requires
sharing *compiled packages* across projects — wrapping whole
`spago build`s in Nix derivations shares nothing.

## The mechanism (spike-proven 2026-07-19)

Two facts make sharing almost free with STOCK spago + purs:

1. `output/cache-db.json` keys modules by **relative** source path
   (`.spago/p/control-6.0.0/src/…`) with values
   `[timestamp, contentHash]`.
2. Spago normalizes registry package source timestamps to **epoch**
   (`1970-01-01T06:00:00Z`) — so cache entries for registry deps are
   **deterministic across projects and machines**.

Therefore: compile a set's dependencies ONCE into a "universe"
output, then **seed** each project's `output/` with an APFS clonefile
copy (`cp -Rc`, copy-on-write). `purs` validates the cloned cache
entries and compiles only the project's own modules.

Spike numbers: cold build of a halogen project = 498 modules / 7.4s;
seeded build = 1 module / 0.6s. Disk: dep modules are never modified
after seeding, so clones share extents — the marginal cost of the
Nth project on a set is ~its own modules only.

## The tool

`quartermaster/scripts/pantry.mjs` (prototype, working):

- `pantry universe <set>` — union the dependencies of every afc-work
  project on that set (or `--deps a,b,c`), build one universe under
  `~/.cache/ps-pantry/<set>-purs-<version>/`. Keyed by
  (package set × purs version) — externs compatibility.
- `pantry seed <dir> [--force]` — clonefile the universe into the
  project's `output/`.
- `pantry status` — list universes.

This is why homogenization matters: 15 different package sets = 15
universes = little sharing. One set (77.13.1) = one universe serving
~100 projects.

## The Nix mapping (next)

The universe IS the derivation scheme:

- **Universe-as-derivation**: fixed inputs (package set version, purs
  version, dep source tarballs with registry integrity hashes) → the
  compiled universe output. Coarse but honest: one derivation shared
  by every project on the set.
- **Project builds seed from the store**: a project derivation clones
  the universe output (or overlays it read-only) and compiles its own
  sources. `spago.lock` supplies exact versions + sha256 integrity —
  everything a fetcher needs, no IFD.
- **Per-package derivations** (the purs-nix-style fine grain) become
  an *optimization inside* the universe later — chain packages in
  topological order, each derivation seeding from its deps' outputs.
  Same trick, smaller grain. Evaluate purs-nix prior art before
  building this layer.
- Path-dep libraries (hylograph-*) are not in the universe; v2 can
  chain lib outputs into consumer seeds the same way.

## Caveats / to verify

- `purs` rewrites `cache-db.json` per build — the clone diverges by
  that one file (fine; it's small).
- Universe must be a *superset* of the project's deps; missing
  packages simply compile locally (graceful degradation).
- Timestamp normalization is spago behavior — pin with a test so a
  spago upgrade can't silently break seeding.
- Local `src/` timestamps are NOT normalized (correct — they change).
- purs version bump = new universe key = full rebuild (correct).

## Sequencing

1. Homogenization sweep (agents, running) → one set across afc-work.
2. `pantry universe 77.13.1` for real; `pantry seed` adopted in dev
   loops (Makefiles / bosun serve start commands).
3. Reclaim: delete old per-project `output/` dirs (regenerable);
   expected recovery ~5–6 GB immediately, more as node_modules and
   `.spago` sharing land.
4. Universe-as-derivation in the quartermaster flake; `quartermaster
   provision` emits journal facts (Brunel §3).
5. Minard-for-Nix renders the effect: project marks shrink as their
   regenerable state collapses into the shared universe.
