#!/bin/bash
set -e

echo "Pulling latest code..."
git pull
git submodule update --remote

echo "Rebuilding and restarting services..."
docker compose up -d --build

echo "Cleaning up old images..."
docker image prune -f

echo "Done."
