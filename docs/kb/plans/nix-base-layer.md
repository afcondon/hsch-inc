# Nix as the substrate's base layer — adoption plan

**Decided 2026-07-18** (AFC, in the warrant belief-premises session):
Nix is **mandated** as the substrate's provisioning floor — toolchains,
hermetic artifact builds, and tree identity — on every machine the
substrate reaches. Two machines today; the design assumes arbitrary
scale (data-centers, heterogeneous distributed fleets), so nothing in
the bootstrap may be Mac-specific by construction. The two Macs are
merely the **first replication pair**.

**The boundary that makes the mandate safe** (from the warrant
tree-outputs discussion): Nix is mandated as *infrastructure policy*,
never as an architectural dependency of the reasoning layer. Warrant's
journal/engine stay Nix-independent (degradation clause); the coupling
points are exactly three, all seams:

1. **Hash-compatible trees** — warrant's tree-manifest digests will be
   NAR hashes, so warrant and Nix agree on the identity of any tree.
2. **Projectable derivations** — "is this CanMake Nix-expressible?" is
   a computable predicate (ContentAddressed tool, declared inputs, no
   beliefs/actions, hermetic-shaped recipe).
3. **Pluggable realiser** — warrant's exec seam gains a Nix realiser;
   with Nix mandated it is always available, so **warrant never grows
   sandboxing, hashing infra, GC, or a cache**. That is the
   de-duplication the mandate buys.

Division of labour: **Quartermaster owns the mandate** (ensure Nix,
pin the flake, verify readiness — provisioning); **Bosun** keeps
running what's aboard; **warrant** reasons above both. Nix's
granularity is coarse (whole derivations) — spago/purerl incremental
inner loops stay outside Nix by design.

## Phase A — MBP, first machine (2026-07-19)

1. **Install Nix** via the Determinate Systems installer (survives
   macOS updates, handles the /nix volume + synthetic.conf dance,
   flakes on by default, clean uninstall). Needs interactive sudo —
   AFC runs it, Claude preps and verifies:

   ```
   curl -fsSL https://install.determinate.systems/nix | sh -s -- install
   ```

2. **The substrate flake**, at `ShapedSteer/quartermaster/flake.nix`
   (the flake IS Quartermaster's artifact: the pinned toolchain
   manifest). Inputs: nixpkgs (pinned via flake.lock) +
   `purescript-overlay` (thomashoneyman — purs/spago/purs-tidy pinned,
   aarch64-darwin supported). Dev shells:
   - `#purescript` — purs, spago, purs-tidy (the lingua franca shell)
   - `#rust` — rustc, cargo (es9-daemon, link-spike, msm)
   - `#erlang` — erlang, rebar3 (purerl-tidal)
   - `#node` — node LTS (bundlers, daemons)

3. **Acceptance test on the MBP**: `nix develop <qm>#purescript -c
   spago test` inside `afc-work/warrant` — the suite that exists must
   pass with tools supplied *entirely* by the flake. Capture the
   store-path manifest (`nix path-info` per tool) as the machine's
   provisioning fingerprint.

## Phase B — teach Quartermaster, replicate to the Mini

Follow Quartermaster's own proven pattern (build/publish were shell-
proven live first, then folded into the typed CLI):

4. **`scripts/qm-nix.sh`** with three subcommands, host-agnostic,
   local-or-ssh via the same Target discipline as `verify`:
   - `verify [host]` — nix present? version? flakes enabled? /nix
     healthy? Report per-host readiness (the seam signal Bosun style).
   - `ensure [host]` — install via DetSys if absent. **The one manual
     step per machine**: sudo needs a terminal (`ssh -t`); flag, don't
     hide. Idempotent — re-running on a provisioned host is a no-op.
   - `sync [host]` — realize the flake's dev shells on the target at
     the same flake.lock rev; emit the store-path manifest.

5. **Provision the Mini**: `qm-nix.sh ensure andrews-mac-mini` (AFC on
   the sudo prompt), then `sync`, then `verify`.

6. **The replication test** — the point of the exercise, two levels:
   - *Identity*: same flake.lock ⇒ **identical store paths** on both
     machines. Diff the two manifests; any divergence is a finding.
   - *Substitution*: `nix copy --to ssh://andrews-mac-mini <closure>`
     — build once on the MBP, the Mini receives the closure without
     rebuilding. This is build-once-ship (Quartermaster's existing
     charter) with Nix as the transport, and the seed of the
     self-hosted binary cache (Mini as substituter — later).

7. **Fold into the CLI** as `quartermaster nix <verify|ensure|sync>`
   once script-proven (PureScript + Go foreign twins, per house
   pattern).

## Out of scope (deliberately)

- **nix-darwin / launchd management** — collides with Bosun's turf;
  needs its own seam conversation. Not now.
- **Converting any project build to a Nix derivation** — the flake
  provides *toolchains*, projects build exactly as before.
- **Warrant's Nix realiser** — follows once tree outputs land; it
  gets a guaranteed substrate from this plan rather than a hopeful
  one.

## Risks

- macOS updates vs the /nix volume (DetSys mitigates; `verify` must
  catch a broken store, not just absence).
- sudo-over-ssh for `ensure` — accepted as the one interactive step
  per machine; do NOT engineer around it with stored credentials.
- Xcode CLT remains a host dependency outside Nix for some native
  builds (cpal/CoreAudio); `verify` should probe it on macOS hosts —
  precedent for the general truth that `verify` composes host facts
  beyond Nix itself.
- purescript-overlay pin vs registry package-set expectations: the
  flake's purs/spago must match what spago.yaml package sets assume;
  pin deliberately, record in the flake.

## Related work (reviewed 2026-07-18, AFC's pointers)

- **purs-nix** (github.com/purs-nix/purs-nix): manages PureScript
  projects *entirely* in Nix — replaces spago, its own extended
  package set, and `output/` as an immutable derivation. This is
  precisely the road we ruled out: moving the build-knowledge layer
  into Nix costs incremental compilation (their output derivation is
  whole-project, non-incremental — our "coarse granularity" prediction
  confirmed in the field) and forks the package-set model away from
  the registry. Two things worth borrowing all the same: (1) their
  fork-before-the-PR-lands package workflow answers exactly the pain
  we hit with registry 73.3.0 pinning stale hylograph versions
  (extraPackages path deps are our current workaround); (2) their
  `output`-as-derivation is an existence proof for warrant's
  Nix-realiser projection — "spago build's tree as one derivation" is
  already being done, so the Tree-outputs → NAR-hash → realiser path
  has a working precedent. Self-labelled unstable; another reason to
  keep spago as the interface and Nix as the floor.
- **purenix** (github.com/purenix-org/purenix, stale): a
  PureScript→Nix BACKEND — CoreFn → Nix source, same method as the
  Jurist/Pythia/Gnomon family. Not needed for this plan (dev-shell
  flakes are simple, hand-written Nix). But the idea slots straight
  into the backends thesis: when Quartermaster's Nix layer grows real
  logic (fleet generation, per-host config), that logic could be
  written in PureScript and compiled to Nix — a future family member
  built the Jurist way (ADR discipline + differential conformance),
  with purenix as prior art/starting corpus rather than a dependency.
  **AFC 2026-07-18: adopted, named `Nyx`** — Marginalia 259, someday,
  child of PureScript Backends (130). Scout findings: 748 lines of
  Haskell (6 modules), core untouched since 2022-08 but pinned to
  purs ^>=0.15 (the current era), .nix FFI files co-located per
  module, has its own flake. Reference clone at `GitHub/purenix`.
  Decided path: **rebuild the family way** — from-scratch CoreFn→Nix
  generator on the Jurist skeleton (the Pythia method), purenix kept
  as corpus and conformance oracle (`nix eval` both outputs — the
  family's cheapest oracle). Sheds the Haskell toolchain, aligned
  with PureScript-in-PureScript on the horizon (Fabrizio's Racket
  backend) and Quartermaster's own Node-free-via-Gnomon precedent.

## Success criteria

Tomorrow ends with: Nix on both machines; one flake, one lock; warrant's
suite green inside `#purescript` on both; identical store-path
manifests; one closure copied MBP→Mini without rebuild; `qm-nix.sh
verify` green against both hosts.

## Status: EXECUTED 2026-07-19 — all criteria met

Both machines PROVISIONED (Determinate Nix 3.21.7). Flake at
quartermaster (330aab5), script-proven mandate (29caf8e), replication
fixes + artifacts (2d08d41). Warrant's suite green in `#purescript` on
the MBP; order-theory's law suite green on the Mini from cold (warrant
has path-dep siblings, so the standalone library was the Mini's
acceptance vehicle). Identical 29-path manifests, independently
evaluated. Signed closures copied MBP→Mini without rebuild.

**Learned in execution** (things the plan didn't predict):

- **The substrate signing key** — the Mini's daemon rightly refused
  unsigned overlay-built paths, forcing `substrate-1` into existence:
  private half in `~/.config/nix` on the build machine, public half in
  the repo, trusted via one line in each host's `nix.custom.conf`.
  Not in the plan; first brick of the self-hosted binary cache, laid
  a phase early.
- **Reachability ≠ absence** — an ssh auth failure (fleet usernames
  differ: afc/andrew) initially reported "nix ABSENT" for a host that
  was merely refusing the default user. `verify` now checks
  reachability first with its own exit code. The general lesson is
  warrant's own totality lesson wearing ops clothes: "could not
  observe" must never be reported as a world-fact.
- One sudo terminal moment per machine held true (install + key-trust
  are the same moment); ssh config alias added for the username split.
