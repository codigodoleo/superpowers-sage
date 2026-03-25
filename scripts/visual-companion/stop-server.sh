#!/usr/bin/env bash
set -euo pipefail

SESSION_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -z "$SESSION_DIR" ]]; then
  echo "Usage: stop-server.sh --session-dir <path>" >&2
  exit 1
fi

PID_FILE="$SESSION_DIR/.server.pid"
SESSION_FILE="$SESSION_DIR/session.json"

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE")"
  if kill -0 "$PID" >/dev/null 2>&1; then
    kill "$PID" >/dev/null 2>&1 || true
    sleep 0.2
    if kill -0 "$PID" >/dev/null 2>&1; then
      kill -9 "$PID" >/dev/null 2>&1 || true
    fi
  fi
  rm -f "$PID_FILE"
fi

if [[ -f "$SESSION_FILE" ]]; then
  NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  node -e '
const fs = require("fs");
const file = process.argv[1];
const now = process.argv[2];
const data = JSON.parse(fs.readFileSync(file, "utf8"));
data.status = "stopped";
data.stopped_at = now;
fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n", "utf8");
' "$SESSION_FILE" "$NOW"
  echo "{\"type\":\"server-stopped\",\"timestamp\":\"$NOW\"}" >> "$SESSION_DIR/events.jsonl"
fi

echo "{\"status\":\"stopped\",\"session_dir\":\"$SESSION_DIR\"}"
