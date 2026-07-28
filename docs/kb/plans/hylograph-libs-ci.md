---
title: CI for the Hylograph libraries
category: plan
status: planned
tags: [hylograph, ci, github-actions, testing, release-engineering, technical-debt]
created: 2026-07-28
summary: None of the 18 Hylograph library packages has any CI, and 17 of them are published to the PureScript registry. Surveys the current state and proposes a single reusable workflow rather than 18 copies of the same file.
---

# CI for the Hylograph libraries

## The finding

Surveyed on 2026-07-28, prompted by noticing that removing an obsolete
GitHub Pages workflow from `hylograph-selection` had taken the last file
under its `.github/`.

That turned out to understate it. **No Hylograph library has ever had CI.**

| | Count |
|---|---|
| Packages in `purescript-hylograph-libs` | 18 |
| Published to the PureScript registry | 17 |
| With a `test/` directory | 7 |
| **With any CI workflow** | **0** |

Not a regression to repair — an absence to fill. Seventeen published
libraries, seven test suites that run only when somebody remembers to run
them locally, and nothing that would notice a break between one manual
`spago test` and the next.

The stakes are higher for published packages than for applications. A
broken application is noticed by whoever runs it. A broken library is
noticed by a consumer, at a distance, usually while they are trying to do
something else — and in this ecosystem the consumers are other repos in
`afc-work` that pull from the registry, so the feedback loop runs through a
publish.

## Why this is worth doing properly rather than quickly

Two days of work on the `Internal` namespace and the dead `SimNode` types
(see `research/hylograph-public-api-leaks.md`) turned up defects that a
build alone would not have caught, but also several that it would:

- The `hylograph-graph-json` adapter compiled against a type it could never
  be handed to. A build in the *example* caught it; a build in the library
  did not. CI running `spago build` on the worked example would have.
- `hylograph-simulation` and `hylograph-simulation-halogen` both declared
  `license: MIT` for five releases while shipping no licence text. A
  release-preconditions check catches that in a second.
- `hylograph-selection`'s demo subpackage carries nine warnings-as-errors
  that nobody was tripping over, because nobody built the demo.

So the target is not merely "does it compile". It is the set of things that
are cheap to check mechanically and expensive to discover downstream.

## Do not write eighteen copies of the same file

This deserves stating plainly, because the obvious implementation is the
wrong one and it is the exact failure mode this codebase has been paying
down all week.

Eighteen near-identical `ci.yml` files is a duplication that will drift.
Within a month, three of them will have a fix the other fifteen lack, and
nobody will know which three — which is precisely the story of
`type SimNode = SimulationNode` appearing independently in three codebases.

GitHub Actions supports **reusable workflows** (`on: workflow_call`). One
canonical workflow lives in a single repository; each library gets a
four-line caller:

```yaml
# .github/workflows/ci.yml in each library
name: CI
on: [push, pull_request]
jobs:
  ci:
    uses: afcondon/<central-repo>/.github/workflows/purescript-lib.yml@main
    with:
      has-tests: true
```

Fixes land once. The per-repo file is small enough that drift is visible.

An open question is where the canonical workflow should live —
`tools-for-agents/` already hosts the canonical PureScript skills package
and has precedent as the shared-infrastructure home, but a dedicated
`purescript-ci` repo may be cleaner since Actions resolves reusable
workflows by repo reference.

## What the workflow should do

Roughly, in increasing order of cost:

1. `spago build` — the floor.
2. `spago test` where a `test/` directory exists (7 of 18). Test for
   *`.purs` files under* `test/`, not for the directory: `hylograph-optics`
   had an empty `test/` (removed 2026-07-28) which inflated the original
   count to 8 and would have made a directory-existence check run
   `spago test` on a package with no `Test.Main`, failing the job.
3. **Publish preconditions**, for the 17 published packages: `publish:`
   block present, LICENSE file present *and matching the declared license*,
   every dependency carrying a version range. All three have already been
   violated in this ecosystem.
4. Warnings — `hylograph-selection`'s demo had nine pre-existing
   violations, since fixed (2026-07-28), so warnings-as-errors is now
   viable from day one rather than something to phase in.

**A caveat that changes what "green" means.** Those nine warnings had been
errors — the demo sets `build.strict: true` — and nobody noticed, because
**spago's incremental build does not re-report them**. `spago build` on a
warm `output/` prints `Errors 0` and exits successfully; the failure only
appears when the affected modules are actually recompiled. Any CI that
caches `output/` between runs will inherit this and report success on code
that does not compile from scratch. Either do not cache `output/`, or make
the job a clean build.

Eight packages ship JavaScript FFI (`selection` alone has 21 `.js` files),
so the runner needs Node, not just the PureScript toolchain. `setup-node`
plus `purescript/setup-purescript` or the equivalent Nix devShell — this
monorepo already uses `nix-direnv` in at least one package, which may be
the more reproducible route.

## Two things the survey turned up in passing — both since resolved

**`hylograph-components` was not a git repository.** It had a full
`publish:` block naming `afcondon/purescript-hylograph-components` while
being neither under version control nor on the registry — seventeen working
modules existing in exactly one place, with a *public* repo
(`hylograph-demos`) depending on them by relative path.

Fixed the same day: initialised, licensed, and pushed to
<https://github.com/afcondon/purescript-hylograph-components>. Its
`test:` block was also removed — it declared `main: Test.Main` with no
`test/` directory, so `spago test` failed outright. **Published to the
registry as 0.1.0 on 2026-07-28**, which required declaring `aff`,
`enums` and `tuples` (transitive via halogen, so `spago build` never
minded) and correcting the licence: the LICENSE had been copied wholesale
from `hylograph-selection`, ISC section and all, crediting d3-zoom for a
module this package does not contain. Now plain MIT.

**`hylograph-selection/.github/` held only a `.DS_Store`.** Directory
removed; CI is deferred to the Brunel work below rather than added
piecemeal.

## Status / Next Steps

- [ ] Decide where the canonical reusable workflow lives
- [ ] Write it: build, conditional test, publish-precondition checks
- [x] Fix the nine pre-existing warnings in `hylograph-selection/demo` —
      done 2026-07-28. All nine were import hygiene in four chapter
      modules, bar one genuine shadowing (`Chapter3.dataTree` rebound
      `svgW`/`svgH` to different values than the top-level bindings other
      trees in the file use). The demo now builds clean under
      `build.strict: true`, so CI can enforce warnings from day one.
- [ ] Add the caller workflow to each library — 18 repos, now that
      `hylograph-components` has one
- [x] Resolve `hylograph-components` — repo created and pushed, and
      published to the registry as 0.1.0, both 2026-07-28
- [ ] Consider extending the same workflow to `purescript-hylograph-demos`,
      which has the same absence. **Not** `purescript-hylograph-showcases`:
      it is largely superseded (simple demos now aggregated in
      `hylograph-demos`, the interesting ones on the polyglot site,
      `psd3-tilted-radio` obsoleted by the Atlantis work) and is not under
      version control at all, so there is nowhere to put a workflow.

## Where this should land: Brunel

Deferred deliberately rather than done piecemeal — and the likely home is
**Brunel** (`plans/minard-for-operations.md` §6b), not a standalone chore.

Brunel already models the provision, build and process strata across the
whole portfolio. "Does this repo have CI, when did it last pass, does its
published version match HEAD, does its licence file match the declared
licence" is the same *kind* of question as "is this service running", asked
one stratum over. It wants to be a column in the cartography rather than a
checklist beside it — a **release stratum** alongside the three that exist.

That also solves the eighteen-copies problem structurally rather than by
discipline: if the fact lives in the cartography, there is one place for it
by construction.

Related: `research/hylograph-public-api-leaks.md` for the defects that
prompted this, and its postscript on detection tooling more generally —
CI is the crudest and most reliable member of that family.
