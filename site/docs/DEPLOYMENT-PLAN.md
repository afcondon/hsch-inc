# Polyglot PureScript Demo Suite - Deployment Plan

This document outlines the steps to containerize and deploy the full demo suite to a Linode server.

## Architecture Overview

```
                         Internet
                             │
                             ▼
                    ┌─────────────────┐
                    │  Linode Server  │
                    │                 │
┌───────────────────┴─────────────────┴───────────────────┐
│                    Docker Network                        │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  scuppered-ligature (edge/gateway)                 │  │
│  │  - PureScript → Lua → OpenResty                    │  │
│  │  - Port 80 exposed to internet                     │  │
│  │  - Routes requests to backends                     │  │
│  └────────────────────────────────────────────────────┘  │
│           │        │        │        │        │          │
│           ▼        ▼        ▼        ▼        ▼          │
│  ┌──────────┐ ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────┐    │
│  │  tidal   │ │ ee/ge   │ │sankey│ │ code │ │ wasm │    │
│  │ (Erlang) │ │(Python) │ │ (JS) │ │(Node)│ │(Rust)│    │
│  └──────────┘ └─────────┘ └──────┘ └──────┘ └──────┘    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Services Inventory

| Service | Route | Tech Stack | Source Location | Port |
|---------|-------|------------|-----------------|------|
| scuppered-ligature | `*` (gateway) | PureScript/Lua/OpenResty | `site/scuppered-ligature` | 80 |
| tilted-radio | `/tidal/*` | Erlang/OTP | `showcase apps/tilted-radio` | 8083 |
| hypo-punter-ee | `/embed/*` | Python | `showcase apps/psd3-embedding-explorer` | 5081 |
| hypo-punter-ge | `/grid/*` | Python | `showcase apps/psd3-embedding-explorer` | 5082 |
| arid-keystone | `/sankey/*` | Static JS | `showcase apps/sankey-editor` | 8089 |
| corrode-expel-api | `/code/api/*` | Node.js | `showcase apps/code-explorer` | 3000 |
| corrode-expel-ui | `/code/*` | Static JS | `showcase apps/code-explorer` | 8082 |
| wasm-force | `/wasm/*` | Rust/WASM | TBD | 8079 |
| dashboard | `/dashboard/*` | JS | `dev-dashboard` | 9000 |
| landing | `/` | Static | To be created | 8080 |

## Phase 1: Create Dockerfiles

### 1.1 Edge Gateway (DONE)
- Location: `site/scuppered-ligature/docker/Dockerfile`
- Status: Complete and tested

### 1.2 Tilted Radio (Erlang)
```dockerfile
# site/showcase apps/tilted-radio/Dockerfile
FROM erlang:26-alpine

WORKDIR /app
COPY _build/prod/rel/tilted_radio ./
EXPOSE 8083
CMD ["bin/tilted_radio", "foreground"]
```

Prerequisites:
- Ensure rebar3 release builds work
- May need multi-stage build for compilation

### 1.3 Embedding Explorer / Grid Explorer (Python)
```dockerfile
# showcase apps/psd3-embedding-explorer/Dockerfile.ee
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY output-py/ ./output-py/
COPY src/ ./src/
EXPOSE 5081
CMD ["python", "-m", "embedding_explorer"]
```

Similar Dockerfile for Grid Explorer on port 5082.

### 1.4 Sankey Editor (Static)
```dockerfile
# showcase apps/sankey-editor/Dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 8089
```

### 1.5 Code Explorer (Node.js + Static)
```dockerfile
# API Backend
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY dist/ ./dist/
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

```dockerfile
# Frontend (static)
FROM nginx:alpine
COPY build/ /usr/share/nginx/html/
EXPOSE 8082
```

### 1.6 WASM Demo
```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 8079
```

### 1.7 Dashboard
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 9000
CMD ["node", "server.js"]
```

### 1.8 Landing Page
```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 8080
```

## Phase 2: Docker Compose

Create `site/docker-compose.yml`:

```yaml
version: '3.8'

services:
  edge:
    build: ./scuppered-ligature
    ports:
      - "80:80"
    depends_on:
      - tidal
      - ee-backend
      - ge-backend
      - sankey
      - ce-backend
      - ce-frontend
      - wasm
      - dashboard
      - landing

  tidal:
    build: ../showcase apps/tilted-radio
    expose:
      - "8083"

  ee-backend:
    build:
      context: ../showcase apps/psd3-embedding-explorer
      dockerfile: Dockerfile.ee
    expose:
      - "5081"

  ge-backend:
    build:
      context: ../showcase apps/psd3-embedding-explorer
      dockerfile: Dockerfile.ge
    expose:
      - "5082"

  sankey:
    build: ../showcase apps/sankey-editor
    expose:
      - "8089"

  ce-backend:
    build:
      context: ../showcase apps/code-explorer
      dockerfile: Dockerfile.api
    expose:
      - "3000"

  ce-frontend:
    build:
      context: ../showcase apps/code-explorer
      dockerfile: Dockerfile.ui
    expose:
      - "8082"

  wasm:
    build: ../showcase apps/wasm-force
    expose:
      - "8079"

  dashboard:
    build: ./dev-dashboard
    expose:
      - "9000"

  landing:
    build: ./landing
    expose:
      - "8080"
```

## Phase 3: Local Testing

```bash
# Build all containers
cd site
docker-compose build

# Start everything
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f edge

# Test routing
curl http://localhost/
curl http://localhost/tidal
curl http://localhost/embed
# etc.

# Tear down
docker-compose down
```

## Phase 4: Linode Deployment

### 4.1 Server Setup
```bash
# SSH to Linode
ssh root@your-linode-ip

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
apt install docker-compose-plugin

# Create app directory
mkdir -p /opt/polyglot-purescript
```

### 4.2 Deployment Options

**Option A: Build on Server**
```bash
# Clone repo to server
git clone <repo-url> /opt/polyglot-purescript

# Build and run
cd /opt/polyglot-purescript/site
docker-compose up -d --build
```

**Option B: Push to Registry**
```bash
# Local: tag and push images
docker-compose build
docker tag scuppered-ligature:latest your-registry/scuppered-ligature:latest
docker push your-registry/scuppered-ligature:latest
# Repeat for each service

# Server: pull and run
docker-compose pull
docker-compose up -d
```

**Option C: Save/Load Images**
```bash
# Local: save all images
docker save $(docker-compose config --images) > demo-suite.tar

# Transfer to server
scp demo-suite.tar root@your-linode-ip:/opt/

# Server: load and run
docker load < demo-suite.tar
docker-compose up -d
```

### 4.3 SSL/TLS with Let's Encrypt

Add Traefik or Caddy as a reverse proxy in front of the edge:

```yaml
# Add to docker-compose.yml
services:
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.le.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.le.acme.email=your@email.com"
      - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./letsencrypt:/letsencrypt

  edge:
    # ... existing config ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.edge.rule=Host(`polyglot-purescript.org`)"
      - "traefik.http.routers.edge.tls.certresolver=le"
```

## Phase 5: Maintenance

### Health Checks
```yaml
# Add to each service in docker-compose.yml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:PORT/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### Monitoring
- Edge metrics available at `/edge/metrics`
- Consider adding Prometheus + Grafana for visualization

### Updates
```bash
# Pull latest code
git pull

# Rebuild and restart changed services
docker-compose up -d --build

# Or zero-downtime with rolling updates (requires swarm mode)
docker stack deploy -c docker-compose.yml polyglot
```

## Implementation Order

1. [ ] Verify each showcase app builds/runs locally
2. [ ] Create Dockerfile for each service
3. [ ] Create docker-compose.yml
4. [ ] Test full stack locally
5. [ ] Set up Linode server with Docker
6. [ ] Deploy and test
7. [ ] Add SSL/TLS
8. [ ] Set up monitoring

## Notes

- The edge gateway (scuppered-ligature) expects backends at specific hostnames - Docker Compose networking handles this automatically
- Some services may need environment variables for configuration
- Database services (if any) should use Docker volumes for persistence
- Consider resource limits in docker-compose for production
