---
title: "Hylograph Deployment Plan"
category: plan
status: active
tags: [hylograph, cloudflare, tailscale, deployment, infrastructure]
created: 2026-01-27
updated: 2026-02-05
summary: Deployment architecture for Hylograph ecosystem - Cloudflare Pages for static sites, TailScale Funnel on MacMini for backends.
---

# Hylograph Deployment Plan

## Overview

Deploy the Hylograph ecosystem using:
- **Static content** → Cloudflare Pages (free tier)
- **Backend demos** → TailScale Funnel → MacMini Docker

Initial audience: friends and PureScript Discord community. All repos will be public.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         hylograph.net                                    │
│                     (Cloudflare DNS + CDN)                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────┐                          │
│  │          Cloudflare Pages (Static)         │                          │
│  │                                            │                          │
│  │  hylograph.net         4-quadrant docs     │                          │
│  │  blog.hylograph.net    Hylographic blog    │                          │
│  │  polyglot.hylograph.net  Demo gallery      │                          │
│  │                                            │                          │
│  └────────────────────────────────────────────┘                          │
│                                                                          │
│  ┌────────────────────────────────────────────┐                          │
│  │       TailScale Funnel (MacMini)           │                          │
│  │                                            │                          │
│  │  *.tail[...].ts.net                        │                          │
│  │   ├─ /code    Minard (Node.js + DuckDB)    │                          │
│  │   ├─ /ee      Embedding Explorer (Python)  │                          │
│  │   ├─ /ge      Grid Explorer (Python)       │                          │
│  │   └─ /tidal   Tidal Editor (Erlang)        │                          │
│  │                                            │                          │
│  └────────────────────────────────────────────┘                          │
│                                                                          │
│  ┌────────────────────────────────────────────┐                          │
│  │       Vanity Redirects (purescri.pt)       │                          │
│  │                                            │                          │
│  │  polyglot.purescri.pt → polyglot.hylograph.net                        │
│  │  hylograph.purescri.pt → hylograph.net                                │
│  │                                            │                          │
│  └────────────────────────────────────────────┘                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Domain Structure

### Cloudflare Pages (Static Sites)

| URL | Content | Source | Cloudflare Project |
|-----|---------|--------|-------------------|
| `hylograph.net` | Library docs (4-quadrant) | `site/hylograph-net` | hylograph-docs |
| `blog.hylograph.net` | Hylographic blog | `blog/` | hylograph-blog |
| `polyglot.hylograph.net` | Demo gallery website | `site/website` | hylograph-polyglot |

### TailScale Funnel (Backend Demos)

| Path | Backend | Service |
|------|---------|---------|
| /code | Node.js + DuckDB | Minard code cartography |
| /ee | Python (PurePy) | Embedding Explorer |
| /ge | Python (PurePy) | Grid Explorer |
| /tidal | Erlang (Purerl) | Tidal music editor |

### Vanity Redirects

Configured via Nick Saunders' purescri.pt forwarder:

| Vanity URL | Target |
|------------|--------|
| `polyglot.purescri.pt` | `polyglot.hylograph.net` |
| `hylograph.purescri.pt` | `hylograph.net` |

## Content Inventory

### Static Sites (Cloudflare Pages)

| Site | Build Command | Output Directory |
|------|---------------|------------------|
| Docs (hylograph.net) | `./build.sh` | `site/hylograph-net/public` |
| Blog (blog.hylograph.net) | `make blog` | `blog/public` |
| Polyglot (polyglot.hylograph.net) | `make website` | `site/website/public` |

### Backend Demos (MacMini Docker)

| Demo | Backend Tech | Notes |
|------|--------------|-------|
| Minard | Node.js + DuckDB | Code cartography, requires database |
| Embedding Explorer | Python (PurePy) | Vector embeddings |
| Grid Explorer | Python (PurePy) | Grid visualization |
| Tidal Editor | Erlang (Purerl) | Music patterns, complex setup |

## Implementation Steps

### Phase 1: Cloudflare Pages Setup

#### 1.1 Create Three Cloudflare Pages Projects

In Cloudflare Dashboard → Pages → Create project:

**Project 1: hylograph-docs**
- Connect to GitHub: `purescript-polyglot` repo
- Build command: `cd site/hylograph-net && ./build.sh`
- Output directory: `site/hylograph-net/public`
- Custom domain: `hylograph.net`

**Project 2: hylograph-blog**
- Connect to GitHub: `purescript-polyglot` repo
- Build command: `make blog`
- Output directory: `blog/public`
- Custom domain: `blog.hylograph.net`

**Project 3: hylograph-polyglot**
- Connect to GitHub: `purescript-polyglot` repo
- Build command: `make website`
- Output directory: `site/website/public`
- Custom domain: `polyglot.hylograph.net`

#### 1.2 DNS Configuration

Since hylograph.net is registered with Cloudflare, DNS is already managed there.
Cloudflare Pages automatically configures DNS when you add custom domains.

#### 1.3 Fix build.sh Path

The `site/hylograph-net/build.sh` references an old path. Update:

```bash
# Old
LIBS_DIR="$SITE_DIR/../../visualisation libraries"

# New
LIBS_DIR="$SITE_DIR/../../../purescript-hylograph-libs"
```

### Phase 2: GitHub Actions (Optional)

Cloudflare Pages can build directly from GitHub pushes, but for PureScript builds
you may need GitHub Actions to install spago/purs first.

Create `.github/workflows/deploy-cloudflare.yml`:

```yaml
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install pandoc
        run: sudo apt-get install -y pandoc

      - name: Build docs site
        run: cd site/hylograph-net && ./build.sh

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: hylograph-docs
          directory: site/hylograph-net/public

  deploy-blog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup PureScript
        uses: purescript-contrib/setup-purescript@main
        with:
          purescript: '0.15.15'
          spago: '0.21.0'

      - name: Build blog
        run: make blog

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: hylograph-blog
          directory: blog/public

  deploy-polyglot:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup PureScript
        uses: purescript-contrib/setup-purescript@main
        with:
          purescript: '0.15.15'
          spago: '0.21.0'

      - name: Build website
        run: make website

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: hylograph-polyglot
          directory: site/website/public
```

Required secrets:
- `CLOUDFLARE_API_TOKEN`: Create in Cloudflare Dashboard → API Tokens
- `CLOUDFLARE_ACCOUNT_ID`: Found in Cloudflare Dashboard URL

### Phase 3: TailScale Funnel (MacMini)

TailScale Funnel is already configured on the MacMini. Ensure:

1. Docker services are running (use updated `docker-compose.yml`)
2. Funnel is exposing the correct ports
3. Static sites link to the Funnel URLs for backend demos

#### Funnel Configuration

```bash
# Check current funnel status
tailscale funnel status

# Typical setup (adjust ports as needed)
tailscale funnel 80
```

The Funnel URL will be something like `https://macmini.tail12345.ts.net/`

### Phase 4: Vanity Redirects

Contact Nick Saunders to configure:
- `polyglot.purescri.pt` → `polyglot.hylograph.net`
- `hylograph.purescri.pt` → `hylograph.net`

These are simple HTTP redirects, no hosting required.

### Phase 5: Cross-Linking

Update each site to link to the others:

**On hylograph.net (docs):**
- Link to blog for deeper discussions
- Link to polyglot for live demos
- Note that some demos require backend (link to Funnel URLs)

**On blog.hylograph.net:**
- Link to docs for API reference
- Link to polyglot for interactive examples
- Embed or link to backend demos

**On polyglot.hylograph.net:**
- Link to docs for library details
- Link to blog for context/narrative
- Backend demo links with note about availability

## Cost Analysis

**Cloudflare Free Tier:**
- Pages: Unlimited sites, 500 builds/month, unlimited bandwidth
- DNS: Free
- DDoS protection: Included

**TailScale Free Tier:**
- Funnel: Included
- Up to 100 devices

**Total monthly cost: $0**

(MacMini electricity not counted)

## Reliability Notes

**Cloudflare Pages:**
- High availability, global CDN
- Automatic HTTPS
- Will always be up

**MacMini (TailScale Funnel):**
- No UPS, subject to power cuts
- Acceptable for demo purposes
- Static sites should gracefully indicate when backends are unavailable

Consider adding a simple status indicator or message on static sites:
> "Live demos require backend services. If unavailable, try again later or run locally."

## Migration Checklist

- [ ] Fix `site/hylograph-net/build.sh` path
- [ ] Create Cloudflare Pages project: hylograph-docs
- [ ] Create Cloudflare Pages project: hylograph-blog
- [ ] Create Cloudflare Pages project: hylograph-polyglot
- [ ] Add custom domain: hylograph.net
- [ ] Add custom domain: blog.hylograph.net
- [ ] Add custom domain: polyglot.hylograph.net
- [ ] Set up GitHub Actions (if needed for PureScript builds)
- [ ] Verify TailScale Funnel is running on MacMini
- [ ] Request vanity redirects from Nick Saunders
- [ ] Update cross-links between sites
- [ ] Test all routes end-to-end
- [ ] Announce to PureScript Discord

## Future Considerations

- **Preview deployments**: Cloudflare Pages creates preview URLs for PRs
- **Analytics**: Cloudflare Web Analytics (free, privacy-respecting)
- **UPS for MacMini**: Would improve backend availability
- **Consolidation**: Could merge all three static sites into one Pages project with path-based routing if management becomes cumbersome
