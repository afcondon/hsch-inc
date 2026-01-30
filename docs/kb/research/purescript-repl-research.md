# PureScript REPL & Live Coding Environment Research

**Status**: active
**Category**: research
**Created**: 2026-01-29
**Author**: Claude (research session)

## Executive Summary

This document captures research into improving PureScript's interactive development experience. The current PSCi REPL spawns a fresh Node process per expression, preventing state persistence. Rather than just fixing PSCi, we're exploring whether a Bret Victor-style live coding environment (like Haskell for Mac) might be a better goal.

---

## Part 1: Current PSCi Architecture

### The Core Problem

From `purescript/app/Command/REPL.hs:111-118`:

```haskell
eval _ _ = do
  writeFile indexFile "import('./$PSCI/index.js').then(({ $main }) => $main());"
  result <- readNodeProcessWithExitCode nodePath (nodeArgs ++ [indexFile]) ""
```

Each expression evaluation:
1. Compiles a temporary `$PSCI` module (all let bindings + new expression)
2. Generates JavaScript to `.psci_modules/$PSCI/index.js`
3. Spawns a **new Node process** to evaluate
4. Captures stdout, process terminates

**Persists** (Haskell memory): imports, let bindings as AST, externs
**Doesn't persist** (JavaScript): runtime state, connections, mutable variables

### Prior Improvement Attempts

1. **Browser Backend (PR #2199, 2016)** - Merged then removed in v0.15.0
2. **Fabrizio's Socket Server** - Haskell socket server + Node client, abandoned
3. **natefaubion's 2020 Collaboration** - Proposed persistent Node + richer eval protocol, stalled

### psc-ide: The Right Architecture Already Exists

psc-ide (the IDE server) already has:
- Long-running Haskell process with TVar state
- Socket-based protocol
- Fast incremental rebuilds
- Type environment in memory

Missing only: JavaScript evaluation capability

---

## Part 2: Haskell for Mac & Live Coding Environments

*Research in progress...*

---

## Part 3: Bret Victor's Principles

*Research in progress...*

---

## Part 4: Implementation Options

*Research in progress...*

---

## Resources

- [PSCi Remote Connection - Issue #2142](https://github.com/purescript/purescript/issues/2142)
- [Async in PSCi - Issue #2218](https://github.com/purescript/purescript/issues/2218)
- [REPL Improvement Discourse](https://discourse.purescript.org/t/collaborating-on-improving-the-repl-evaluator/1333)
- [psc-ide Design Doc](https://github.com/purescript/purescript/blob/master/psc-ide/DESIGN.org)
