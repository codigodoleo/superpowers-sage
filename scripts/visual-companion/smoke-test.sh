#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-$PWD}"
TOPIC="smoke-test"

START_JSON="$(bash "$PROJECT_DIR/scripts/visual-companion/start-server.sh" --project-dir "$PROJECT_DIR" --topic "$TOPIC")"

SESSION_DIR="$(echo "$START_JSON" | grep -o '"session_dir"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*"([^"]+)"/\1/')"
URL="$(echo "$START_JSON" | grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed -E 's/.*"([^"]+)"/\1/')"

if [[ -z "$SESSION_DIR" || -z "$URL" ]]; then
  echo "Smoke test failed: could not parse session_dir/url" >&2
  exit 1
fi

curl -fsS "$URL/health" >/dev/null

curl -fsS -X POST "$URL/event" \
  -H 'content-type: application/json' \
  -d '{"type":"choice","section":"smoke","choice":"ok","source":"smoke-test"}' >/dev/null

curl -fsS -X POST "$URL/layout" \
  -H 'content-type: application/json' \
  -d '{"section":"smoke","html":"<!doctype html><html><body><h1>Smoke</h1></body></html>"}' >/dev/null

if [[ ! -f "$SESSION_DIR/events.jsonl" ]]; then
  echo "Smoke test failed: events.jsonl not found" >&2
  exit 1
fi

if ! grep -q '"section":"smoke"' "$SESSION_DIR/events.jsonl"; then
  echo "Smoke test failed: no smoke events recorded" >&2
  exit 1
fi

bash "$PROJECT_DIR/scripts/visual-companion/stop-server.sh" --session-dir "$SESSION_DIR" >/dev/null

echo "Smoke test passed"
echo "session_dir=$SESSION_DIR"
