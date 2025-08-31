#!/usr/bin/env bash
set -euo pipefail
# Enable strict error handling: exit on errors, undefined variables, and
# failures within pipelines.

generate_cron() {
  bash /app/config_parser.sh
}

reload_crond() {
  kill -HUP "$CROND_PID" 2>/dev/null || true
}

watch_config() {
  local file="$1"
  if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -m -e close_write,move,delete "$file" |
      while read -r _; do
        generate_cron
        reload_crond
      done || true
  else
    local prev
    prev="$(md5sum "$file" 2>/dev/null | awk '{print $1}' || true)"
    while sleep 5; do
      local curr
      curr="$(md5sum "$file" 2>/dev/null | awk '{print $1}' || true)"
      if [ "$curr" != "$prev" ]; then
        prev="$curr"
        generate_cron
        reload_crond
      fi
    done
  fi
}

# Generate cron entries from environment/config
generate_cron

crond -f -l 2 &
CROND_PID=$!

if [ -n "${CONFIG_FILE:-}" ] && [ -f "${CONFIG_FILE:-}" ]; then
  watch_config "$CONFIG_FILE" &
fi

wait "$CROND_PID"
