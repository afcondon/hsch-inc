# Build Skill

Thin wrapper over the Makefiles that assemble the Hylograph ecosystem.

## Usage

```
/build                 # Show `make help` output
/build all             # Build everything reachable from the top-level Makefile
/build <target>        # Run `make <target>` (e.g. website, blog, lib-sites)
/build check           # Verify prerequisites (tools, bundles)
/build fix             # Diagnose a failed build and propose a fix
```

## Arguments

$ARGUMENTS

## Ground rules

**Builds are a Makefile, not a skill.** The deterministic substrate is `/Users/afc/work/afc-work/Makefile` (top-level, cross-repo orchestration) and `purescript-polyglot/Makefile` (website + blog + lib-sites). Either is canonical — this skill just invokes and diagnoses.

**Never run raw `spago bundle`** for services in these repos — the Makefiles handle the `-p <pkg>`, `--outfile`, and co-location requirements. Raw spago invocations risk writing bundles to the wrong path (see `/purescript-ecosystem` → Bundling for the Browser).

For deploying after a build, use `/deploy`. Never start containers from this skill.

## Parsing the request

- **No args / "status"**: `make -C /Users/afc/work/afc-work help` and `make -C /Users/afc/work/afc-work check-tools` (if the target exists).
- **Named target**: run `make -C <repo-root> <target>` for the repo whose Makefile defines it. Top-level targets (`polyglot`, `website`, `blog`, `lib-sites`, `docker-*`) are at `/Users/afc/work/afc-work/Makefile`. Polyglot-specific targets can also be invoked directly from `purescript-polyglot/`.
- **"check"**: `make check-tools` + `make verify-bundles` at the appropriate level.
- **"fix"**: read the last build's stderr and apply the patterns in "Diagnosing build failures" below.

## Before running any target

```bash
make -C <repo-root> -n <target> 2>&1 | head -10
```

A dry-run confirms the target exists and shows what it will actually do. If the target is missing, *add it to the Makefile* following existing patterns rather than working around it with one-off shell commands.

## Diagnosing build failures

Failures fall into a small number of shapes. Identify which kind before patching:

| Symptom | Likely cause | Fix |
|---|---|---|
| `purs: not found` / node missing | Tool not on PATH | Check `make check-tools`. Install missing tools. |
| PureScript compile error (type mismatch, name not in scope) | Source error | Read the error, fix the source. Use `/purescript` for language-level idioms. |
| Bundle written to unexpected path | `--outfile` relative-to-package footgun | See `/purescript-ecosystem` → Bundling. Invoke from package dir or use absolute path. Fix the Makefile. |
| FFI file lookup fails | Naming/co-location wrong | See `/purescript-tooling`. JS FFI must be alongside .purs, same basename. For alt backends (Python, Erlang), naming differs — `/purescript-tooling` has the rules. |
| `Missing dependency` at bundle time | `npm install` not run in the package | `cd` into the package, `npm install`. |
| `ld.so` / `cargo` error | Non-PureScript build step (Rust loader, etc.) | Check the target's prerequisites. `/deploy reload-db` has the Minard loader rebuild flow. |

## Makefile conventions worth preserving

- **Bundle filename**: commonly `bundle.js` (Minard) or `index.js` (PWYF). The HTML's `<script src>` is the source of truth — the Makefile must write to the path the HTML loads.
- **Co-location**: the bundle must live next to the `index.html` that loads it. `../public/bundle.js` from a `src/` bundler config lands it correctly.
- **Adding a new target**: copy the shape of an existing one. Maintain dependency order (libs before apps, shared-shell before per-lib sites, etc.).

## Why this skill is short

Everything declarative about "how this repo builds" is in the Makefile — don't duplicate it here. Everything about "what to do when PureScript complains" is in `/purescript` and `/purescript-ecosystem` and `/purescript-tooling` — those are the language/ecosystem skills, invoked when diagnosing. This file only holds the invocation shape, the parsing rules, and the failure-triage table. Adding a build target means editing the Makefile, not this doc.

## Related skills

- `/deploy` — run/stop services locally and remotely (reads Marginalia)
- `/purescript` — PureScript language idioms and common pitfalls
- `/purescript-ecosystem` — package selection, bundling, serving
- `/purescript-tooling` — spago workspace setup, FFI naming conventions
