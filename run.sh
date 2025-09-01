#!/usr/bin/env bash
set -euo pipefail
# Enable strict error handling: exit on errors, undefined variables, and
# failures within pipelines.

CONFIG_PARSER_PATH=${CONFIG_PARSER_PATH:-/app/config_parser.sh}
CRONTABS_DIR=${CRONTABS_DIR:-/etc/crontabs}
export CRONTABS_DIR
CONFIG_FILE=${CONFIG_FILE:-'/app/config.json'}
export CONFIG_FILE

# Logging function - logfmt format to match supercronic
log() {
  echo "time=\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\" level=info msg=\"$*\" component=docker-cron" >&2
}

log_error() {
  echo "time=\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\" level=error msg=\"$*\" component=docker-cron" >&2
}

log_warn() {
  echo "time=\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\" level=warn msg=\"$*\" component=docker-cron" >&2
}

log "========================================="
log "Docker Cron Container Starting"
log "========================================="
log "Config parser path: $CONFIG_PARSER_PATH"
log "Crontabs directory: $CRONTABS_DIR"
log "Config file: ${CONFIG_FILE}"

# Set verbose logging if requested
if [ "${CRON_VERBOSE:-false}" = "true" ]; then
  log "Verbose logging enabled"
  export CRON_VERBOSE=true
fi

# Log detected environment variables
log "Scanning for CMD_* and INTERVAL_* environment variables..."
env_count=0
while IFS= read -r var; do
  log "Found: $var"
  env_count=$((env_count + 1))
done < <(env | grep -E '^(CMD_|INTERVAL_)' | sort)

if [ $env_count -eq 0 ]; then
  log "No CMD_* or INTERVAL_* environment variables found"
else
  log "Found $env_count environment variables"
fi

generate_cron() {
  log "Generating cron configuration..."
  if bash "$CONFIG_PARSER_PATH"; then
    log "Cron configuration generated successfully"
  else
    log_error "Failed to generate cron configuration"
    exit 1
  fi
}

reload_crond() {
  if [ -n "${CROND_PID:-}" ] && kill -0 "$CROND_PID" 2>/dev/null; then
    log "Reloading supercronic daemon (PID: $CROND_PID)"
    # Supercronic automatically reloads when the crontab file changes
    # But we restart it to be sure
    log "Stopping supercronic daemon for restart..."
    kill "$CROND_PID" 2>/dev/null || true
    wait "$CROND_PID" 2>/dev/null || true
    
    log "Starting new supercronic daemon..."
    # Use same environment variables for consistency
    supercronic "$CRONTABS_DIR/root" &
    CROND_PID=$!
    log "New supercronic daemon started with PID: $CROND_PID"
    
    # Verify new supercronic is running
    sleep 1
    if kill -0 "$CROND_PID" 2>/dev/null; then
      log "Supercronic daemon restart: HEALTHY"
    else
      log_error "Supercronic daemon restart: FAILED"
      exit 1
    fi
  else
    log_warn "Supercronic daemon not running or PID not available"
  fi
}

watch_config() {
  local file="$1"
  log "Starting config file watcher for: $file"
  
  if command -v inotifywait >/dev/null 2>&1; then
    log "Using inotifywait for file monitoring"
    inotifywait -m -e close_write,move,delete "$file" |
      while read -r path events filename; do
        log "Config file changed (events: $events), regenerating cron..."
        generate_cron
        reload_crond
      done || {
        log_warn "inotifywait monitoring stopped"
        true
      }
  else
    log "inotifywait not available, using MD5 polling (5 second intervals)"
    local prev
    prev="$(md5sum "$file" 2>/dev/null | awk '{print $1}' || true)"
    log "Initial file hash: $prev"
    
    while sleep 5; do
      local curr
      curr="$(md5sum "$file" 2>/dev/null | awk '{print $1}' || true)"
      if [ "$curr" != "$prev" ]; then
        log "Config file changed (hash: $prev -> $curr), regenerating cron..."
        prev="$curr"
        generate_cron
        reload_crond
      fi
    done
  fi
}

# Generate cron entries from environment/config
log "Initial cron configuration generation..."
generate_cron

log "Starting supercronic daemon..."
# Configure supercronic logging based on CRON_VERBOSE setting
if [ "${CRON_VERBOSE:-false}" = "true" ]; then
  log "Verbose logging enabled"
  log "Command: supercronic /etc/crontabs/root"
  supercronic "$CRONTABS_DIR/root" &
else
  log "Command: supercronic /etc/crontabs/root"
  # Use standard supercronic logging (logfmt format)
  supercronic "$CRONTABS_DIR/root" &
fi
CROND_PID=$!
log "Crond daemon started with PID: $CROND_PID"

# Verify supercronic is running
sleep 1
if kill -0 "$CROND_PID" 2>/dev/null; then
  log "Supercronic daemon health check: HEALTHY"
else
  log_error "Supercronic daemon health check: FAILED"
  exit 1
fi

if [ -n "${CONFIG_FILE}" ] && [ -f "${CONFIG_FILE}" ]; then
  log "Starting config file watcher for: ${CONFIG_FILE}"
  watch_config "$CONFIG_FILE" &
  WATCHER_PID=$!
  log "Config file watcher started with PID: $WATCHER_PID"
else
  log "No config file to watch"
fi

# Signal handler for graceful shutdown
cleanup() {
  log "========================================="
  log "Received shutdown signal, cleaning up..."
  log "========================================="
  
  if [ -n "${WATCHER_PID:-}" ] && kill -0 "$WATCHER_PID" 2>/dev/null; then
    log "Stopping config file watcher (PID: $WATCHER_PID)"
    kill "$WATCHER_PID" 2>/dev/null || true
  fi
  
  if [ -n "${CROND_PID:-}" ] && kill -0 "$CROND_PID" 2>/dev/null; then
    log "Stopping supercronic daemon (PID: $CROND_PID)"
    kill "$CROND_PID" 2>/dev/null || true
    wait "$CROND_PID" 2>/dev/null || true
  fi
  
  log "Docker cron container shutdown complete"
  exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

log "Signal handlers set up for graceful shutdown"
log "Docker cron container is now running"
log "Waiting for supercronic daemon to exit..."
wait "$CROND_PID"
log "Supercronic daemon has exited"
