#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=""
TOPIC="architecture"
HOST="127.0.0.1"
PORT="0"
SESSION_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --topic)
      TOPIC="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --session-dir)
      SESSION_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR="$PWD"
fi

if [[ -z "$SESSION_DIR" ]]; then
  DATE_UTC="$(date -u +%F)"
  SAFE_TOPIC="$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')"
  SESSION_ID="$$-$(date +%s)"
  SESSION_DIR="$PROJECT_DIR/docs/superpowers/visual-companion/${DATE_UTC}-${SAFE_TOPIC}-${SESSION_ID}"
fi

mkdir -p "$SESSION_DIR"
cp "$PROJECT_DIR/scripts/visual-companion/frame-template.html" "$SESSION_DIR/layout-v1.html"
: > "$SESSION_DIR/events.jsonl"

cat > "$SESSION_DIR/session.json" <<JSON
{
  "status": "active",
  "topic": "$TOPIC",
  "session_id": "$(basename "$SESSION_DIR")",
  "mode": "visual",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "spec_path": "",
  "tools": {
    "figma": false,
    "playwright": false
  }
}
JSON

LOG_FILE="$SESSION_DIR/.server.log"
PID_FILE="$SESSION_DIR/.server.pid"

nohup node "$PROJECT_DIR/scripts/visual-companion/server.cjs" \
  --session-dir "$SESSION_DIR" \
  --host "$HOST" \
  --port "$PORT" > "$LOG_FILE" 2>&1 &

PID=$!
echo "$PID" > "$PID_FILE"

SERVER_URL=""

for _ in $(seq 1 50); do
  if [[ -f "$SESSION_DIR/.server-info" ]]; then
    SERVER_URL="$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$SESSION_DIR/.server-info" | head -n1 | sed -E 's/.*"([^"]+)"/\1/')"
    break
  fi

  if ! kill -0 "$PID" >/dev/null 2>&1; then
    echo "{\"status\":\"failed\",\"error\":\"server exited\",\"session_dir\":\"$SESSION_DIR\"}" >&2
    exit 1
  fi

  sleep 0.1
done

if [[ -z "$SERVER_URL" ]]; then
  echo "{\"status\":\"timeout\",\"error\":\"server startup timed out\",\"session_dir\":\"$SESSION_DIR\"}" >&2
  exit 1
fi

if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS "$SERVER_URL/health" >/dev/null 2>&1; then
    echo "{\"status\":\"failed\",\"error\":\"health check failed\",\"session_dir\":\"$SESSION_DIR\",\"url\":\"$SERVER_URL\"}" >&2
    exit 1
  fi
fi

cat "$SESSION_DIR/.server-info"
exit 0
