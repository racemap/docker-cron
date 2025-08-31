#!/usr/bin/env bash
set -euo pipefail

# Ensure crond is available
if ! command -v crond >/dev/null 2>&1; then
  if command -v busybox >/dev/null 2>&1; then
    ln -sf "$(command -v busybox)" /usr/bin/crond
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null
    apt-get install -y busybox >/dev/null
    ln -sf /bin/busybox /usr/bin/crond
  else
    echo "crond not available, skipping watch_config test" >&2
    exit 0
  fi
fi

# Ensure config parser is accessible at /app
if [ ! -e /app ]; then
  ln -s "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/app" /app
fi

# busybox crond expects /var/spool/cron/crontabs; map it to /etc/crontabs
if [ ! -e /var/spool/cron/crontabs ]; then
  mkdir -p /var/spool/cron
  mkdir -p /etc/crontabs
  ln -s /etc/crontabs /var/spool/cron/crontabs
fi

TMPDIR=$(mktemp -d)
CONFIG="$TMPDIR/config.json"
LOG="$TMPDIR/run.log"
RUN_PID=0

cleanup() {
  if [ "$RUN_PID" -ne 0 ]; then
    pkill -P "$RUN_PID" >/dev/null 2>&1 || true
    kill "$RUN_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

cat >"$CONFIG" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo first", "interval": "* * * * *"}
  ]
}
CFG

CONFIG_FILE="$CONFIG" bash ./run.sh >"$LOG" 2>&1 &
RUN_PID=$!

# Allow initial generation
sleep 2

grep -q "echo first" /etc/crontabs/root

# Remove config file and ensure watcher keeps running
rm "$CONFIG"

sleep 7

kill -0 "$RUN_PID"

grep -q "configuration file.*missing" "$LOG"

# Recreate config file with different command
cat >"$CONFIG" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo second", "interval": "* * * * *"}
  ]
}
CFG

sleep 7

grep -q "echo second" /etc/crontabs/root

echo "watch_config test passed"
