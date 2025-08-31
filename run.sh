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
    local dir="$(dirname "$file")"
    local base="$(basename "$file")"
    inotifywait -m -e close_write,move,create,delete "$dir" --format '%e %f' |
      while read -r events fname; do
        [ "$fname" = "$base" ] || continue
        if echo "$events" | grep -qE 'DELETE|MOVED_FROM'; then
          echo "Warning: configuration file '$file' missing, skipping cron generation" >&2
        elif [ -f "$file" ]; then
          generate_cron
          reload_crond
        fi
      done || true
  else
    local prev
    if [ -f "$file" ]; then
      prev="$(md5sum "$file" 2>/dev/null | awk '{print $1}' || true)"
    else
      prev="missing"
      echo "Warning: configuration file '$file' missing, skipping cron generation" >&2
    fi
    while sleep 5; do
      if [ ! -f "$file" ]; then
        if [ "$prev" != "missing" ]; then
          prev="missing"
          echo "Warning: configuration file '$file' missing, skipping cron generation" >&2
        fi
        continue
      fi
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
if [ -n "${CONFIG_FILE:-}" ]; then
  if [ -f "$CONFIG_FILE" ]; then
    generate_cron
  else
    echo "Warning: configuration file '$CONFIG_FILE' missing, skipping cron generation" >&2
  fi
else
  generate_cron
fi

crond -f -l 2 &
CROND_PID=$!

if [ -n "${CONFIG_FILE:-}" ]; then
  watch_config "$CONFIG_FILE" &
fi

wait "$CROND_PID"
