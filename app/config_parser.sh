#!/usr/bin/env bash
set -euo pipefail

CRONTABS_DIR=${CRONTABS_DIR:-/etc/crontabs}

if [ -n "$CONFIG_FILE" ]; then
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not found" >&2
    exit 1
  fi
  i=1
  while read -r job; do
    cmd_var="CMD_$i"
    interval_var="INTERVAL_$i"
    cmd="$(echo "$job" | jq -r '.cmd // empty')"
    interval="$(echo "$job" | jq -r '.interval // empty')"
    if [ -z "${!cmd_var+x}" ] && [ -n "$cmd" ]; then
      export "$cmd_var=$cmd"
    fi
    if [ -z "${!interval_var+x}" ] && [ -n "$interval" ]; then
      export "$interval_var=$interval"
    fi
    i=$((i + 1))
  done < <(jq -c '.jobs // [] | .[]' "$CONFIG_FILE")
fi

lines=()
i=1
while :; do
  cmd_var="CMD_$i"
  interval_var="INTERVAL_$i"
  cmd="${!cmd_var:-}"
  interval="${!interval_var:-}"
  if [ -z "$cmd" ] && [ -z "$interval" ]; then
    break
  fi
  if [ -z "$cmd" ] || [ -z "$interval" ]; then
    echo "Missing $cmd_var or $interval_var" >&2
    exit 1
  fi
  lines+=("$interval $cmd")
  i=$((i + 1))
done

mkdir -p "$CRONTABS_DIR"
printf "%s\n" "${lines[@]}" > "$CRONTABS_DIR/root"
