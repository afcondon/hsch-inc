# Hylograph Deploy Skill

Deploy Hylograph ecosystem services across environments. **Local = native processes. Remote = Docker on MacMini.**

## Usage

```
/deploy                         # Show local service status
/deploy <service>               # Start service locally (reads Marginalia)
/deploy <service> stop          # Stop locally
/deploy <service> remote        # Deploy service to MacMini (Docker)
/deploy status                  # Show which reserved ports are up locally
/deploy status remote           # Show MacMini container status
/deploy logs <service>          # Tail local logs
/deploy logs <service> remote   # Tail MacMini logs
```

## Arguments

$ARGUMENTS

## Ground rules

**For local dev**: ports, start commands, URLs, environments, and prerequisites live in **Marginalia** (`http://localhost:3100`). Don't duplicate them here. Query:

```bash
curl -s http://localhost:3100/api/ports | jq                      # all services
curl -s http://localhost:3100/api/projects/<id>/servers | jq      # one project
```

Environments currently used: `mbp-native` (all local dev), `macmini-docker` (remote edge + containers).

**Local deployment uses native processes.** Docker brought the MBP to its knees and was removed. Only MacMini uses Docker. If Marginalia's `environment` on a server entry says anything other than `mbp-native`, it's not for local-on-this-machine.

## Service discovery

### Find a service by name
```bash
curl -s http://localhost:3100/api/projects?search=sankey | jq '.projects[] | {id, slug, name}'
```

### Find a service by port
```bash
curl -s http://localhost:3100/api/ports | jq '.servers[] | select(.port == 3011)'
```

### List services by environment
```bash
curl -s http://localhost:3100/api/ports | jq '.servers[] | select(.environment == "mbp-native") | {port, projectName, role}'
```

## 1. Local — native processes

1. Query Marginalia for the service's row
2. Read its `prerequisites` field (may not exist yet on showcase entries; add to the entry when learned)
3. Run the `startCommand` in background, redirecting to `/tmp/marginalia-<slug>-<role>.log`
4. `lsof -i :<port>` to verify it came up

### Starting everything

Iterate `/api/ports` filtered by `environment == "mbp-native"` and run each row's `startCommand`. Skip rows where the port is already in use.

### Stopping

Generic pattern:

```bash
lsof -ti :<port> | xargs kill
```

To stop everything locally: iterate the same filter, kill each port.

## 2. Remote — MacMini Docker

**This flow is not yet fully migrated to Marginalia.** The edge router (`polyglot-deploy`/edge, port 80, `macmini-docker`) is registered, but per-service container orchestration lives here. Migrating these to `environment=macmini-docker` entries is an open task on the agent-skills-and-deployment-model KB doc.

### Config

- **Host**: `andrew@100.101.177.83`
- **Remote path**: `~/psd3/`
- **Docker binary**: `/usr/local/bin/docker` (not in the non-interactive SSH PATH)

### Pattern

```bash
# 1. Build artifacts locally
cd /Users/afc/work/afc-work && make <build-target>

# 2. Rsync artifacts to MacMini
rsync -avz --delete <local-path>/ andrew@100.101.177.83:~/psd3/<remote-path>/

# 3. Rebuild + restart container on MacMini
ssh andrew@100.101.177.83 \
  "cd ~/psd3 && /usr/local/bin/docker compose build --no-cache <service> \
   && /usr/local/bin/docker compose up -d <service>"

# 4. Verify
curl -s -o /dev/null -w "%{http_code}\n" http://100.101.177.83/<path>/
```

### Remote status

```bash
ssh andrew@100.101.177.83 "/usr/local/bin/docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

### Remote logs

```bash
ssh andrew@100.101.177.83 "/usr/local/bin/docker logs --tail 100 <service>"
```

## 3. Troubleshooting

**Port already in use (local)**: `lsof -i :<port>` / `lsof -ti :<port> | xargs kill`.

**Server exits silently**: launch in foreground (no `&`) to see errors.

**DuckDB lock error (Minard)**: something has the database open. `lsof | grep ce-unified.duckdb`, stop it.

**Remote SSH can't find docker**: use the absolute path `/usr/local/bin/docker`.

**Wrong API URL in a frontend**: check `apiBaseUrl` in the frontend's Loader.purs — should be `http://localhost:<port>` for native local, `/code` (or similar path prefix) only for the Docker edge-router case.

## Why this skill is short

Local service data lives in Marginalia. Remote Docker orchestration lives here (for now) because Marginalia doesn't yet carry `macmini-docker` per-service entries beyond the edge router. When those land, this file shrinks further.

Adding a new showcase? `POST /api/projects/<id>/servers` with `environment=mbp-native` + startCommand. Don't edit this file.
