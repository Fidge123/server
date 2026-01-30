#!/usr/bin/env bash
# Deploy NixOS configuration to a remote server using deploy-rs
#
# Usage:
#   ./scripts/deploy.sh <target> [options]
#
# Examples:
#   ./scripts/deploy.sh server-x86           # Deploy to x86_64 server
#   ./scripts/deploy.sh server-arm           # Deploy to ARM server
#   ./scripts/deploy.sh server-x86 --dry-run # Check without applying
#   ./scripts/deploy.sh server-x86 --debug   # Verbose output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $(basename "$0") <target> [options]

Deploy NixOS configuration to a remote server.

Targets:
  server-x86    Deploy to x86_64-linux server
  server-arm    Deploy to aarch64-linux server

Options:
  --dry-run     Check deployment without applying changes
  --debug       Enable verbose output
  --help        Show this help message

Initial Installation:
  For first-time installation on a fresh server, use nixos-anywhere:
  
    nix run github:nix-community/nixos-anywhere -- \\
      --flake .#server-x86 \\
      root@YOUR_SERVER_IP

Examples:
  $(basename "$0") server-x86              # Deploy to x86_64 server
  $(basename "$0") server-arm --dry-run    # Check ARM deployment
  $(basename "$0") server-x86 --debug      # Deploy with verbose output
EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
TARGET=""
DRY_RUN=""
DEBUG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        server-x86|server-arm)
            TARGET="$1"
            shift
            ;;
        --dry-run)
            DRY_RUN="--dry-activate"
            shift
            ;;
        --debug)
            DEBUG="--debug-logs"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate target
if [[ -z "$TARGET" ]]; then
    log_error "No target specified"
    usage
    exit 1
fi

# Check if deploy-rs is available
if ! command -v deploy &> /dev/null; then
    log_warn "deploy-rs not found in PATH"
    log_info "Running with nix develop shell..."
    cd "$REPO_ROOT"
    exec nix develop --command "$0" "$TARGET" $DRY_RUN $DEBUG
fi

# Run deployment
cd "$REPO_ROOT"

log_info "Deploying to $TARGET..."

if [[ -n "$DRY_RUN" ]]; then
    log_info "Dry-run mode: changes will NOT be applied"
fi

# Build deploy command
DEPLOY_CMD="deploy .#$TARGET $DRY_RUN $DEBUG"

log_info "Running: $DEPLOY_CMD"
eval "$DEPLOY_CMD"

if [[ -z "$DRY_RUN" ]]; then
    log_info "Deployment to $TARGET completed successfully!"
else
    log_info "Dry-run completed. Run without --dry-run to apply changes."
fi
