#!/usr/bin/env bash
set -euo pipefail

test_watch_config_updates_crontab() {
  local workdir
  workdir=$(mktemp -d)
  mkdir -p "$workdir/bin"
  cat >"$workdir/bin/crond" <<'CRON'
#!/usr/bin/env bash
trap '' HUP
while true; do sleep 1; done
CRON
  chmod +x "$workdir/bin/crond"

  cat >"$workdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi", "interval": "* * * * *"}
  ]
}
CFG

  PATH="$workdir/bin:$PATH" CONFIG_FILE="$workdir/config.json" CRONTABS_DIR="$workdir/crontabs" CONFIG_PARSER_PATH="$(pwd)/app/config_parser.sh" bash run.sh >"$workdir/run.log" 2>&1 &
  local pid=$!

  for _ in {1..50}; do
    [[ -f "$workdir/crontabs/root" ]] && break
    sleep 0.1
  done

  local expected1=$'* * * * * /bin/echo hi'
  local actual
  actual=$(cat "$workdir/crontabs/root")
  if [[ "$actual" != "$expected1" ]]; then
    echo "initial crontab mismatch" >&2
    kill "$pid" 2>/dev/null || true
    kill -- -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$workdir"
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
    actual=$(cat "$workdir/crontabs/root")
    [[ "$actual" == $'*/5 * * * * /bin/date' ]] && break
    sleep 0.2
  done
  if [[ "$actual" != $'*/5 * * * * /bin/date' ]]; then
    echo "updated crontab mismatch" >&2
    kill "$pid" 2>/dev/null || true
    kill -- -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$workdir"
    exit 1
  fi

  kill "$pid" 2>/dev/null || true
  kill -- -"$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -rf "$workdir"
}

test_watch_config_updates_crontab

echo "All watch_config tests passed"
