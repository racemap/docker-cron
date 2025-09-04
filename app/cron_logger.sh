#!/usr/bin/env bash
# Wrapper script to log cron job execution

# Ensure PATH is set for cron environment
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Logfmt format function to match supercronic
log() {
  echo "time=\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\" level=info msg=\"$*\" component=cron-job"
}

log_error() {
  echo "time=\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\" level=error msg=\"$*\" component=cron-job"
}

# Check if command was provided
if [ $# -eq 0 ]; then
  log_error "No command provided"
  exit 1
fi

# Log execution start if verbose mode is enabled
if [ "${CRON_VERBOSE:-false}" = "true" ]; then
  log "Executing: $*"
fi

# Execute the command and capture both stdout and stderr
# Use bash -c to properly execute complex commands
if output=$(bash -c "$*" 2>&1); then
  # Command succeeded - output the result and optionally log success
  if [ -n "$output" ]; then
    echo "$output"
  fi
  if [ "${CRON_VERBOSE:-false}" = "true" ]; then
    log "Command completed successfully"
  fi
  exit 0
else
  # Command failed - always log failures
  exit_code=$?
  log_error "Command failed with exit code: $exit_code"
  if [ -n "$output" ]; then
    echo "$output"
  fi
  exit $exit_code
fi
