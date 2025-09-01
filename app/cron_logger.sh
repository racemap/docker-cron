#!/usr/bin/env bash
# Wrapper script to log cron job execution

# Ensure PATH is set for cron environment
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Log function that outputs to stdout (will appear in docker logs)
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [cron-job] $*"
}

# Always log that the script was called for debugging
log "Cron logger script called with args: $*"

# Check if command was provided
if [ $# -eq 0 ]; then
  log "ERROR: No command provided to cron logger"
  exit 1
fi

# Log the command being executed
log "Executing: $*"

# Execute the command and capture both stdout and stderr
# Use bash -c to properly execute complex commands
if output=$(bash -c "$*" 2>&1); then
  # Command succeeded
  log "Command completed successfully"
  if [ -n "$output" ]; then
    echo "$output"
  fi
  exit 0
else
  # Command failed
  exit_code=$?
  log "Command failed with exit code: $exit_code"
  if [ -n "$output" ]; then
    echo "$output"
  fi
  exit $exit_code
fi
