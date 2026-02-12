#!/bin/bash
# deploy-remote.sh - Deploy PSD3 Docker stack to remote host
#
# Usage:
#   ./scripts/deploy-remote.sh user@macmini
#   ./scripts/deploy-remote.sh user@macmini ~/psd3
#   ./scripts/deploy-remote.sh user@macmini ~/psd3 --build-only
#
# Prerequisites:
#   - SSH access to remote host (key-based auth recommended)
#   - Docker installed on remote host
#   - rsync installed on both machines
#
# This script rsyncs the local build artifacts to the remote host
# and builds Docker images there. No git required on remote.

set -e

HOST="${1:-}"
REMOTE_DIR="${2:-~/psd3}"
BUILD_ONLY="${3:-}"

# PATH for remote commands (Docker Desktop on macOS needs /usr/local/bin)
REMOTE_PATH="export PATH=/usr/local/bin:/opt/homebrew/bin:\$PATH"

# Get the workspace root (script is in purescript-polyglot/scripts/, go up two levels)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}==>${NC} $1"; exit 1; }

if [ -z "$HOST" ]; then
    echo "PSD3 Remote Deployment Script"
    echo "=============================="
    echo ""
    echo "Usage: $0 user@host [remote_dir] [--build-only]"
    echo ""
    echo "Arguments:"
    echo "  user@host     SSH destination (required)"
    echo "  remote_dir    Path on remote host (default: ~/psd3)"
    echo "  --build-only  Build images but don't start containers"
    echo ""
    echo "Examples:"
    echo "  $0 admin@macmini.local"
    echo "  $0 admin@192.168.1.100 /opt/psd3"
    echo "  $0 admin@macmini.local ~/psd3 --build-only"
    echo ""
    echo "Prerequisites:"
    echo "  1. SSH key-based authentication to remote host"
    echo "  2. Docker installed on remote host"
    echo "  3. Build locally first: make apps"
    exit 1
fi

info "PSD3 Remote Deployment"
echo "  Host: $HOST"
echo "  Remote dir: $REMOTE_DIR"
echo "  Local repo: $REPO_ROOT"
echo ""

# Check SSH connectivity
info "Testing SSH connection..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$HOST" "echo 'SSH OK'" 2>/dev/null; then
    error "Cannot connect to $HOST. Check SSH configuration."
fi

# Check Docker on remote
info "Checking Docker on remote..."
if ! ssh "$HOST" "$REMOTE_PATH && docker --version" 2>/dev/null; then
    error "Docker not found on $HOST. Please install Docker first."
fi

# Ensure remote directory exists
info "Creating remote directory..."
ssh "$HOST" "mkdir -p $REMOTE_DIR"

# Rsync only the directories referenced by docker-compose.yml
# The workspace has many sibling repos; we only sync what's needed for Docker builds.
info "Syncing files to remote (this may take a while on first run)..."

RSYNC_OPTS=(-avz --delete \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.spago' \
    --exclude='.stack-work' \
    --exclude='__pycache__' \
    --exclude='.mypy_cache' \
    --exclude='*.pyc' \
    --exclude='.DS_Store' \
    --exclude='output' \
)

# docker-compose.yml itself
rsync "${RSYNC_OPTS[@]}" "$REPO_ROOT/docker-compose.yml" "$HOST:$REMOTE_DIR/"

# CodeExplorer (minard, type-explorer, site-explorer)
rsync "${RSYNC_OPTS[@]}" "$REPO_ROOT/CodeExplorer/" "$HOST:$REMOTE_DIR/CodeExplorer/"

# Showcases (edge router, tilted-radio, hypo-punter, sankey, wasm, optics, zoo, layouts, hylograph)
rsync "${RSYNC_OPTS[@]}" "$REPO_ROOT/purescript-hylograph-showcases/" "$HOST:$REMOTE_DIR/purescript-hylograph-showcases/"

# Ports (purerl-tidal backend)
rsync "${RSYNC_OPTS[@]}" "$REPO_ROOT/purescript-ports/purerl-tidal/" "$HOST:$REMOTE_DIR/purescript-ports/purerl-tidal/"

# Polyglot (website, blog, library doc sites)
rsync "${RSYNC_OPTS[@]}" "$REPO_ROOT/purescript-polyglot/site/" "$HOST:$REMOTE_DIR/purescript-polyglot/site/"
rsync "${RSYNC_OPTS[@]}" "$REPO_ROOT/purescript-polyglot/blog/" "$HOST:$REMOTE_DIR/purescript-polyglot/blog/"

# Build Docker images on remote
info "Building Docker images..."
ssh "$HOST" "$REMOTE_PATH && cd $REMOTE_DIR && docker compose build"

if [ "$BUILD_ONLY" = "--build-only" ]; then
    info "Build complete (--build-only specified, not starting containers)"
    exit 0
fi

# Start the stack
info "Starting Docker stack..."
ssh "$HOST" "$REMOTE_PATH && cd $REMOTE_DIR && docker compose up -d"

# Show status
info "Deployment complete!"
echo ""
ssh "$HOST" "$REMOTE_PATH && cd $REMOTE_DIR && docker compose ps"
echo ""
info "Access the application at: http://$HOST/"
