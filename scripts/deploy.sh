#!/usr/bin/env bash
# Deploy NixOS configurations using deploy-rs.
# Usage: ./scripts/deploy.sh [server-x86|server-arm] [--dry-run] [--debug]

set -euo pipefail

TARGET=""
EXTRA_ARGS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") <target> [options]

Targets:
  server-x86    Deploy to x86_64 server
  server-arm    Deploy to aarch64/ARM server

Options:
  --dry-run     Check what would change without applying
  --debug       Enable verbose deploy-rs output
  --help        Show this help message

Examples:
  $(basename "$0") server-x86
  $(basename "$0") server-x86 --dry-run
  $(basename "$0") server-arm --debug
EOF
}

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    server-x86|server-arm)
      TARGET="$arg"
      ;;
    --dry-run)
      EXTRA_ARGS+=("--dry-activate")
      ;;
    --debug)
      EXTRA_ARGS+=("--debug-logs")
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Error: no target specified." >&2
  usage >&2
  exit 1
fi

# Validate flake before deploying
echo "==> Validating flake..."
nix flake check

echo "==> Deploying .#${TARGET}..."
deploy "${EXTRA_ARGS[@]}" ".#${TARGET}"
