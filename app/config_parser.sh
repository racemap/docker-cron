#!/usr/bin/env bash
set -euo pipefail

CRONTABS_DIR=${CRONTABS_DIR:-/etc/crontabs}

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [config_parser] $*" >&2
}

log "Starting config parser"
log "Using crontabs directory: $CRONTABS_DIR"

if [ -n "${CONFIG_FILE:-}" ]; then
  log "Config file specified: ${CONFIG_FILE}"
  if [ ! -f "${CONFIG_FILE:-}" ]; then
    log "ERROR: Config file ${CONFIG_FILE:-} not found"
    log "Please ensure the file exists and is mounted correctly in the container"
    echo "Config file ${CONFIG_FILE:-} not found" >&2
    exit 1
  fi
  if [ ! -r "${CONFIG_FILE:-}" ]; then
    log "ERROR: Config file ${CONFIG_FILE:-} is not readable"
    echo "Config file ${CONFIG_FILE:-} is not readable" >&2
    exit 1
  fi
  log "Reading config file: ${CONFIG_FILE}"
  i=1
  job_count=0
  while read -r job; do
    cmd_var="CMD_$i"
    interval_var="INTERVAL_$i"
    cmd="$(echo "$job" | jq -r '.cmd // empty')"
    interval="$(echo "$job" | jq -r '.interval // empty')"
    
    log "Processing job $i from config file: cmd='$cmd', interval='$interval'"
    
    if [ -z "${!cmd_var+x}" ] && [ -n "$cmd" ]; then
      export "$cmd_var=$cmd"
      log "Set $cmd_var from config file"
    elif [ -n "${!cmd_var+x}" ]; then
      log "Environment variable $cmd_var already set, skipping config file value"
    fi
    
    if [ -z "${!interval_var+x}" ] && [ -n "$interval" ]; then
      export "$interval_var=$interval"
      log "Set $interval_var from config file"
    elif [ -n "${!interval_var+x}" ]; then
      log "Environment variable $interval_var already set, skipping config file value"
    fi
    
    i=$((i + 1))
    job_count=$((job_count + 1))
  done < <(jq -c '.jobs // [] | .[]' "${CONFIG_FILE:-}" 2>/dev/null || { log "ERROR: Failed to parse JSON config file"; exit 1; })
  log "Processed $job_count jobs from config file"
else
  log "No config file specified, using only environment variables"
fi

lines=()
i=1
log "Collecting cron jobs from environment variables..."
while :; do
  cmd_var="CMD_$i"
  interval_var="INTERVAL_$i"
  cmd="${!cmd_var:-}"
  interval="${!interval_var:-}"
  if [ -z "$cmd" ] && [ -z "$interval" ]; then
    log "No more jobs found at index $i"
    break
  fi
  if [ -z "$cmd" ] || [ -z "$interval" ]; then
    log "ERROR: Missing $cmd_var or $interval_var"
    echo "Missing $cmd_var or $interval_var" >&2
    exit 1
  fi
  log "Job $i: '$interval $cmd'"
  lines+=("$interval $cmd")
  i=$((i + 1))
done

total_jobs=$((i - 1))
log "Found $total_jobs cron jobs total"

log "Creating crontabs directory: $CRONTABS_DIR"
mkdir -p "$CRONTABS_DIR"

log "Writing crontab to $CRONTABS_DIR/root"
printf "%s\n" "${lines[@]}" > "$CRONTABS_DIR/root"

log "Crontab contents:"
cat "$CRONTABS_DIR/root" | while IFS= read -r line; do
  log "  $line"
done

# Validate crontab syntax (basic check)
if [ ${#lines[@]} -gt 0 ]; then
  log "Crontab validation: ${#lines[@]} entries written"
  if [ -r "$CRONTABS_DIR/root" ] && [ -s "$CRONTABS_DIR/root" ]; then
    log "Crontab file validation: PASSED (file exists and is not empty)"
  else
    log "ERROR: Crontab file validation: FAILED (file missing or empty)"
    exit 1
  fi
else
  log "WARNING: No cron jobs configured"
fi

log "Config parser completed successfully"
