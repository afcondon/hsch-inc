# Focus Management for Claude Sessions

**Category**: howto
**Status**: active
**Created**: 2026-02-03
**Tags**: docker, workflow, claude, deployment

## Problem

Running the full PSD3 stack (~20 containers) consumes ~15GB memory. More critically, Claude's context loss across sessions led to inconsistent deployment patterns:
- Ad-hoc HTTP servers instead of Docker
- Random ports instead of edge routing
- Full stack deployments when only one service needed
- Confusion about deployment targets (local vs MacMini)

## Solution

A **focus system** that:
1. Runs only relevant containers via Docker Compose profiles
2. Creates a `.claude-focus` file that Claude reads at session start
3. Updates skills to require checking focus before build/deploy

## Quick Start

```bash
# Before starting a Claude session, set your focus
make focus-minard    # For code cartography work

# Check current focus
make focus-status

# Stop everything
make focus-stop
```

## Available Profiles

| Profile | Containers | Target | Use Case |
|---------|------------|--------|----------|
| `core` | edge, website | local | Minimal baseline (~2) |
| `minard` | + minard-frontend, minard-backend, site-explorer | local | Code cartography |
| `tidal` | + tidal-frontend, tidal-backend | local | Music/algorave |
| `hypo` | + ee-*, ge-* | local | Embedding/Grid explorers |
| `sankey` | + sankey | local | Sankey editor |
| `wasm` | + wasm-demo | local | Rust/WASM work |
| `libs` | + lib-* | local | Library documentation sites |
| `showcases` | + optics, zoo, layouts, hylograph | local | Other showcases |
| `full` | Everything | **remote** | Full stack on MacMini |

## Deployment Targets

The `.claude-focus` file includes a `target` field that determines where deployments go:

- **`target: local`** - Deploy to local Docker on MacBook Pro
- **`target: remote`** - Deploy to MacMini (for `focus-full`)

When `target: remote`:
- `/deploy <service>` deploys to MacMini by default
- Local Docker containers are stopped
- Test URL is `http://100.101.177.83/...`
- Build happens locally, deploy goes to MacMini

## How It Works

### 1. Make Target Sets Focus

Running `make focus-minard`:
- Writes `.claude-focus` with profile info and service list
- Stops all running containers (`docker compose down`)
- Starts only minard profile containers (`docker compose --profile minard up -d`)

### 2. Claude Reads Focus File

The `.claude-focus` file contains:
```yaml
profile: minard
test_url: http://localhost/code/

services:
  - edge
  - website
  - minard-frontend
  - minard-backend
  - site-explorer
```

### 3. Skills Enforce Focus

The `/build` and `/deploy` skills have "Step 0: Check Focus" that requires:
- Reading `.claude-focus` before any operation
- Asking before building/deploying services outside current focus

## URLs Stay Consistent

All profiles route through edge on port 80:
- `http://localhost/` - website
- `http://localhost/code/` - minard
- `http://localhost/tidal/` - tidal
- etc.

Services not in the current profile return 502 (informative, not broken).

## Workflow Example

```bash
# Morning: working on minard (local)
make focus-minard
# Start Claude session, work on code cartography
# Deploys go to local Docker, test at http://localhost/code/

# Afternoon: switch to tidal (local)
make focus-tidal
# Restart Claude session, work on music features
# Deploys go to local Docker, test at http://localhost/tidal/

# Need full stack for integration testing (remote)
make focus-full
# Restart Claude session
# Local containers stopped
# Builds happen locally, deploys go to MacMini
# Test at http://100.101.177.83/
```

## Memory Impact

| Scenario | Approximate Memory |
|----------|-------------------|
| Full stack (20 containers) | ~15GB |
| Single profile (5 containers) | ~4-6GB |
| Core only (2 containers) | ~2GB |

Note: Docker Desktop's VM doesn't release memory automatically. Restart Docker Desktop to reclaim memory when switching to smaller profiles.

## Troubleshooting

### Claude ignores focus
- Restart Claude session after running `make focus-*`
- Check that `.claude-focus` exists and has correct content

### Containers not starting
- Run `docker compose --profile <name> up -d` manually
- Check `docker compose ps` for status
- Check `docker compose logs <service>` for errors

### 502 errors for a service
- Service not in current profile (expected behavior)
- Or service failed to start - check logs

### Edge container won't start
- Old nginx config with static upstreams? Rebuild: `docker compose build --no-cache edge`

## Files Modified

- `docker-compose.yml` - Added profiles to all services
- `CLAUDE.md` - Added Focus Management and Absolute Prohibitions sections
- `.claude/commands/build.md` - Added Step 0: Check Focus
- `.claude/commands/deploy.md` - Added Step 0: Check Focus
- `showcases/scuppered-ligature/nginx.conf` - Removed static upstreams for dynamic resolution
- `Makefile` - Added focus-* targets

## Related

- `CLAUDE.md` - Main instructions including focus rules
- `/deploy` skill - Deployment workflow
- `/build` skill - Build workflow
