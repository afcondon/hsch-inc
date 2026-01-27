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

# Get the repo root (where this script lives is scripts/, go up one level)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Rsync the repo (excluding heavy/dev-only stuff)
info "Syncing files to remote (this may take a while on first run)..."
rsync -avz --delete \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='.spago' \
    --exclude='.stack-work' \
    --exclude='__pycache__' \
    --exclude='.mypy_cache' \
    --exclude='*.pyc' \
    --exclude='.DS_Store' \
    --exclude='purescript-lua' \
    --exclude='purescript-python-new' \
    --exclude='_external' \
    "$REPO_ROOT/" "$HOST:$REMOTE_DIR/"

# Build Docker images on remote
info "Building Docker images..."
ssh "$HOST" "$REMOTE_PATH && cd $REMOTE_DIR && docker-compose build"

if [ "$BUILD_ONLY" = "--build-only" ]; then
    info "Build complete (--build-only specified, not starting containers)"
    exit 0
fi

# Start the stack
info "Starting Docker stack..."
ssh "$HOST" "$REMOTE_PATH && cd $REMOTE_DIR && docker-compose up -d"

# Show status
info "Deployment complete!"
echo ""
ssh "$HOST" "$REMOTE_PATH && cd $REMOTE_DIR && docker-compose ps"
echo ""
info "Access the application at: http://$HOST/"
