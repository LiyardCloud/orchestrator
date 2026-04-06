#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$ORCHESTRATOR_DIR")"

echo "=== Pulling orchestrator ==="
git -C "$ORCHESTRATOR_DIR" pull

echo "=== Pulling sibling repos ==="

if [ -d "$ROOT_DIR/dataroom/.git" ]; then
  echo "  Pulling dataroom..."
  git -C "$ROOT_DIR/dataroom" pull
else
  echo "ERROR: $ROOT_DIR/dataroom is not a git repo. Clone it first:"
  echo "  git clone https://github.com/liyard-tls/dataroom.git $ROOT_DIR/dataroom"
  exit 1
fi

if [ -d "$ROOT_DIR/gateway/.git" ]; then
  echo "  Pulling gateway..."
  git -C "$ROOT_DIR/gateway" pull
else
  echo "  (gateway not found — skipping)"
fi

echo "=== Rebuilding and restarting services ==="
docker compose -f "$ORCHESTRATOR_DIR/docker-compose.yml" up -d --build

echo "=== Cleaning up old images ==="
docker image prune -f

echo "Done."
