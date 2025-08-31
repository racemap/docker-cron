#!/usr/bin/env bash
set -euo pipefail

test_watch_config_updates_crontab() {
  local workdir
  workdir=$(mktemp -d)
  mkdir -p "$workdir/bin" "$workdir/app"
  ln -s "$(command -v busybox)" "$workdir/bin/crond"
  ln -s "$(pwd)/run.sh" "$workdir/app/run.sh"
  ln -s "$(pwd)/app/config_parser.sh" "$workdir/app/config_parser.sh"

  if [[ -e /app ]]; then
    rm -rf /app
  fi
  ln -s "$workdir/app" /app
  local app_link_created=1

  cat >"$workdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi", "interval": "* * * * *"}
  ]
}
CFG

  PATH="$workdir/bin:$PATH" CONFIG_FILE="$workdir/config.json" /app/run.sh &
  local pid=$!

  for _ in {1..50}; do
    [[ -f /etc/crontabs/root ]] && break
    sleep 0.1
  done

  local expected1=$'* * * * * /bin/echo hi'
  local actual
  actual=$(cat /etc/crontabs/root)
  if [[ "$actual" != "$expected1" ]]; then
    echo "initial crontab mismatch" >&2
    kill -- -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$workdir"
    rm -rf /etc/crontabs
    exit 1
  fi

  cat >"$workdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/date", "interval": "*/5 * * * *"}
  ]
}
CFG

  for _ in {1..50}; do
    actual=$(cat /etc/crontabs/root)
    [[ "$actual" == $'*/5 * * * * /bin/date' ]] && break
    sleep 0.2
  done
  if [[ "$actual" != $'*/5 * * * * /bin/date' ]]; then
    echo "updated crontab mismatch" >&2
    kill -- -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$workdir"
    rm -rf /etc/crontabs
    exit 1
  fi

  kill -- -"$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -rf "$workdir"
  rm -rf /etc/crontabs
  if [[ "$app_link_created" -eq 1 ]]; then
    rm /app
  fi
}

test_watch_config_updates_crontab

echo "All watch_config tests passed"
