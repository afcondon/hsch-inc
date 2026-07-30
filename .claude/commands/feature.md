# Feature Branch Skill

Coordinate feature branches across multiple repos in the PSD3 workspace.

## Usage

```
/feature start <name>       # Create feature branch across repos
/feature status [name]      # Show feature state across repos
/feature commit "<message>" # Commit changes across repos on current feature
/feature finish [name]      # Merge feature to main across repos
/feature abandon [name]     # Delete feature branches, discard changes
/feature list               # List active features
```

## Arguments

(parsed from command)

## Instructions

You are the PSD3 feature branch coordinator. This skill helps manage feature branches that span multiple repos in the PSD3 workspace.

### Key Principle: Stateless and Git-Native

This skill does NOT maintain its own state. It queries git to understand the current situation. This means:
- Even if someone does raw git commands, the skill still works
- The skill is a helper/coordinator, not a gatekeeper
- All state is derived from git branch names and working tree status

### Feature Branch Convention

- Feature branches are named `feature/<name>` (e.g., `feature/hats-interpreter`)
- The same branch name is used across all participating repos
- A repo "participates" in a feature if it has a branch with that name

### Repository Locations

All repos are under `/Users/afc/work/afc-work/PSD3-Repos/`:

**Libraries** (in `visualisation libraries/`):
- purescript-psd3-graph
- purescript-psd3-layout
- purescript-psd3-selection
- purescript-psd3-music
- purescript-psd3-simulation
- purescript-psd3-simulation-halogen

**Showcases** (in `showcases/`):
- corrode-expel (Code Explorer)
- hypo-punter (Embedding Explorer + Grid Explorer)
- psd3-arid-keystone (Sankey Editor)
- psd3-tilted-radio (Tidal Editor)
- wasm-force-demo

**Site** (in `site/`):
- website
- showcase-shell

### Commands

#### `/feature start <name>`

1. Check for uncommitted changes across all repos
2. If uncommitted changes exist, warn and list them
3. Create `feature/<name>` branch in repos that have changes OR ask which repos to include
4. Switch to that branch in those repos

```bash
# For each repo with changes or explicitly included:
cd <repo> && git checkout -b feature/<name>
```

#### `/feature status [name]`

If no name given, detect current feature from branch name.

1. For each repo, check:
   - Current branch name
   - Whether `feature/<name>` branch exists
   - Uncommitted changes (staged and unstaged)
   - Commits on feature branch not on main

2. Report:
```
Feature: <name>

Participating repos:
  psd3-selection: 3 commits, clean
  psd3-simulation: 1 commit, 2 modified files
  ce2-website: 2 commits, clean

Not participating (on main):
  psd3-music: clean
  psd3-graph: 1 modified file (!)  <- warning: changes outside feature

Uncommitted changes:
  psd3-simulation:
    M src/PSD3/Simulation.purs
    M src/PSD3/ForceEngine/Setup.purs
```

#### `/feature commit "<message>"`

1. Detect current feature from branch name
2. Find all repos on that feature branch with uncommitted changes
3. For each, stage all changes and commit with the message
4. Add cross-reference to commit message:
   ```
   <message>

   Part of feature/<name>
   ```

```bash
# For each repo with changes on the feature branch:
cd <repo> && git add -A && git commit -m "<message>

Part of feature/<name>"
```

#### `/feature finish [name]`

1. Check all participating repos are clean (no uncommitted changes)
2. For each participating repo:
   - Switch to main
   - Merge feature branch (or squash-merge if requested)
   - Delete feature branch
3. Report summary

```bash
# For each participating repo:
cd <repo> && git checkout main && git merge feature/<name> && git branch -d feature/<name>
```

Ask user: "Squash commits into single commit per repo? (y/n)"

#### `/feature abandon [name]`

1. Confirm with user (destructive operation)
2. For each participating repo:
   - Discard uncommitted changes
   - Switch to main
   - Delete feature branch

```bash
# For each participating repo:
cd <repo> && git checkout main && git branch -D feature/<name>
```

#### `/feature list`

Find all feature branches across all repos:

```bash
# For each repo:
git branch --list 'feature/*'
```

Group by feature name and report:
```
Active features:
  feature/hats-interpreter
    - psd3-selection (3 commits ahead of main)
    - ce2-website (1 commit ahead of main)

  feature/transition-api
    - psd3-selection (5 commits ahead of main)
    - psd3-simulation (2 commits ahead of main)
```

### Error Handling

**Uncommitted changes on main when starting:**
- Warn user and offer to include those repos in the feature

**Repos on different branches:**
- If some repos are on `feature/X` and others on `feature/Y`, warn clearly

**Merge conflicts on finish:**
- Stop and report which repo has conflicts
- User must resolve manually, then re-run finish

### Important Notes

- Always run git commands with full paths or `cd` to the repo first
- Use `git status --porcelain` for machine-readable status
- Use `git rev-list --count main..feature/<name>` to count commits ahead
- Never force-push or rewrite history without explicit user request
- The parent PSD3-Repos directory is also a git repo - be careful not to confuse it with sub-repos
