#!/usr/bin/env bash
# Shared hook utilities for superpowers-sage
# Source this file at the top of hook scripts for logging and debug support

# Configuration from environment variables
HOOK_DEBUG="${SUPERPOWERS_SAGE_HOOK_DEBUG:-0}"
HOOK_LOG="${SUPERPOWERS_SAGE_HOOK_LOG:-.superpowers-sage/hooks.log}"
HOOK_NAME="${HOOK_NAME:-unknown}"

# Ensure log directory exists
if [ "$HOOK_LOG" != "/dev/null" ] && [ -n "$HOOK_LOG" ]; then
  LOG_DIR="$(dirname "$HOOK_LOG")"
  mkdir -p "$LOG_DIR" 2>/dev/null || true
fi

# Logging function: writes to log file and optionally to stderr in debug mode
hook_log() {
  local level="$1"
  local status="$2"
  local message="$3"
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$(date)")
  local log_entry="[$timestamp] [$HOOK_NAME] [$level] HOOK_STATUS=$status: $message"
  
  # Write to log file
  if [ "$HOOK_LOG" != "/dev/null" ] && [ -n "$HOOK_LOG" ]; then
    echo "$log_entry" >> "$HOOK_LOG" 2>/dev/null || true
  fi
  
  # Output to stderr in debug mode
  if [ "$HOOK_DEBUG" = "1" ]; then
    echo "$log_entry" >&2
  fi
}

# Info-level log (non-blocking)
hook_info() {
  hook_log "INFO" "ok" "$1"
}

# Warning-level log (skip detected, but expected)
hook_warn() {
  hook_log "WARN" "skip" "$1"
}

# Error-level log (something failed, but hook isn't blocking)
hook_error() {
  hook_log "ERROR" "warn" "$1"
}

# Check if a command exists and is available
hook_require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    hook_warn "$cmd CLI not found in PATH"
    return 1
  fi
  return 0
}

# Check if a file exists
hook_require_file() {
  local file="$1"
  local friendly_name="${2:-$file}"
  if [ ! -f "$file" ]; then
    hook_warn "$friendly_name not found at $file"
    return 1
  fi
  return 0
}

# Run a command with error capture
hook_run() {
  local cmd="$1"
  local cmd_name="${2:-$cmd}"
  
  if [ "$HOOK_DEBUG" = "1" ]; then
    hook_info "Executing: $cmd_name"
  fi
  
  if output=$(eval "$cmd" 2>&1); then
    if [ "$HOOK_DEBUG" = "1" ] && [ -n "$output" ]; then
      hook_info "Output from $cmd_name: $output"
    fi
    return 0
  else
    local exit_code=$?
    hook_error "$cmd_name failed with exit code $exit_code"
    if [ "$HOOK_DEBUG" = "1" ]; then
      hook_info "Failed command output: $output"
    fi
    return $exit_code
  fi
}

# Extract JSON value (used by several hooks)
hook_json_extract() {
  local json="$1"
  local key="$2"
  echo "$json" | grep -o "\"$key\":[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/\"$key\":[[:space:]]*\"//" | sed 's/"$//'
}
