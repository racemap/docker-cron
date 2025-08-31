#!/usr/bin/env bash
set -e

if [ -n "$CONFIG_FILE" ]; then
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not found" >&2
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
    [ -z "$line" ] && continue
    key="$(echo "${line%%=*}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
    value="$(echo "${line#*=}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
    if [ -z "${!key+x}" ]; then
      export "$key=$value"
    fi
  done < "$CONFIG_FILE"
fi

lines=()
i=1
while :; do
  cmd_var="CMD_$i"
  interval_var="INTERVAL_$i"
  cmd="${!cmd_var}"
  interval="${!interval_var}"
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

mkdir -p /etc/crontabs
printf "%s\n" "${lines[@]}" > /etc/crontabs/root
