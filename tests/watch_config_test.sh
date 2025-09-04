#!/usr/bin/env bash
set -euo pipefail

PWD="$(pwd)"

test_watch_config_updates_crontab() {
  local workdir
  workdir=$(mktemp -d)
  mkdir -p "$workdir/bin"
  cat >"$workdir/bin/supercronic" <<'CRON'
#!/usr/bin/env bash
trap '' HUP
while true; do sleep 1; done
CRON
  chmod +x "$workdir/bin/supercronic"

  cat >"$workdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi", "interval": "* * * * *"}
  ]
}
CFG

  PATH="$workdir/bin:$PATH" CONFIG_FILE="$workdir/config.json" CRONTABS_DIR="$workdir/crontabs" CONFIG_PARSER_PATH="$(pwd)/app/config_parser.sh" bash run.sh >"$workdir/run.log" 2>&1 &
  local pid=$!

  # Wait for initial crontab file
  local found_crontab=false
  for _ in {1..50}; do
    if [[ -f "$workdir/crontabs/root" ]]; then
      found_crontab=true
      break
    fi
    sleep 0.1
  done

  if [[ "$found_crontab" != "true" ]]; then
    echo "initial crontab file not created" >&2
    kill "$pid" 2>/dev/null || true
    kill -- -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$workdir"
    exit 1
  fi

  # Wait for the file watcher to start monitoring (look for the MD5 hash log entry)
  local watcher_started=false
  for _ in {1..50}; do
    if grep -q "Initial file hash:" "$workdir/run.log" 2>/dev/null; then
      watcher_started=true
      break
    fi
    sleep 0.1
  done
  
  if [[ "$watcher_started" != "true" ]]; then
    echo "file watcher did not start" >&2
    kill "$pid" 2>/dev/null || true
    kill -- -"$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -rf "$workdir"
    exit 1
  fi
  
  # Give it a bit more time to ensure the monitoring loop has started
  sleep 1

  local expected1=$'* * * * * '"$PWD"$'/app/cron_logger.sh /bin/echo hi'
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

  # Wait for crontab update (MD5 polling happens every 5 seconds, so wait at least 6-7 seconds)
  local config_updated=false
  for _ in {1..10}; do
    actual=$(cat "$workdir/crontabs/root")
    if [[ "$actual" == $'*/5 * * * * '"$PWD"$'/app/cron_logger.sh /bin/date' ]]; then
      config_updated=true
      break
    fi
    sleep 1
  done
  
  if [[ "$config_updated" != "true" ]]; then
    echo "updated crontab mismatch" >&2
    echo "Expected: */5 * * * * $PWD/app/cron_logger.sh /bin/date" >&2
    echo "Actual: $actual" >&2
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
