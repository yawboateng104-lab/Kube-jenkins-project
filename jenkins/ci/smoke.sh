#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-inference.local}"
PORT="${PORT:-80}"

# If you're using port-forward, set PORT=8080 etc.
BASE_URL="http://${HOST}:${PORT}"

echo "Smoke test BASE_URL=$BASE_URL"

echo "== Normal traffic (should hit PROD) =="
curl -fsS "${BASE_URL}/health" | cat
echo
curl -fsS "${BASE_URL}/version" | cat
echo

echo "== Canary traffic (should hit GREEN when header is set) =="
curl -fsS -H "X-Canary: true" "${BASE_URL}/health" | cat
echo
curl -fsS -H "X-Canary: true" "${BASE_URL}/version" | cat
echo
