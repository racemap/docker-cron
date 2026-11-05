#!/usr/bin/env bash
set -euo pipefail

PWD="$(pwd)"
workdir=""
pid=""

cleanup() {
  [[ -n "$pid" ]] && pkill -P "$pid" 2>/dev/null || true
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  [[ -n "$workdir" ]] && pkill -f "$workdir" 2>/dev/null || true
  [[ -n "$workdir" ]] && rm -rf "$workdir"
  return 0
}
trap cleanup EXIT

fail() {
  echo "$1" >&2
  echo "--- run.log" >&2
  cat "$workdir/run.log" >&2 || true
  exit 1
}

write_config() {
  cat >"$1" <<CFG
{
  "jobs": [
    {"cmd": "$2", "interval": "$3"}
  ]
}
CFG
}

wait_for_crontab() {
  expected="$2 $PWD/app/cron_logger.sh $1"
  # MD5 polling runs every 5 seconds; inotify answers within one.
  for _ in {1..20}; do
    [[ "$(cat "$workdir/crontabs/root" 2>/dev/null)" == "$expected" ]] && return 0
    sleep 0.5
  done
  fail "crontab mismatch, expected: $expected, actual: $(cat "$workdir/crontabs/root" 2>/dev/null)"
}

test_watch_config_updates_crontab() {
  workdir=$(mktemp -d)
  mkdir -p "$workdir/bin" "$workdir/config"
  cat >"$workdir/bin/supercronic" <<'CRON'
#!/usr/bin/env bash
trap 'echo reloaded >>"$(dirname "$0")/../reloads"' USR2
while true; do sleep 1; done
CRON
  chmod +x "$workdir/bin/supercronic"

  local config="$workdir/config/config.json"
  write_config "$config" "/bin/echo hi" "* * * * *"

  PATH="$workdir/bin:$PATH" CONFIG_FILE="$config" CRONTABS_DIR="$workdir/crontabs" \
    CONFIG_PARSER_PATH="$PWD/app/config_parser.sh" bash run.sh >"$workdir/run.log" 2>&1 &
  pid=$!

  wait_for_crontab "/bin/echo hi" "* * * * *"

  local marker="Initial file hash:"
  command -v inotifywait >/dev/null 2>&1 && marker="Watches established."
  for _ in {1..50}; do
    grep -q "$marker" "$workdir/run.log" 2>/dev/null && break
    sleep 0.1
  done
  grep -q "$marker" "$workdir/run.log" || fail "file watcher did not start"

  # An in-place write keeps the inode.
  write_config "$config" "/bin/date" "*/5 * * * *"
  wait_for_crontab "/bin/date" "*/5 * * * *"

  # git and atomic saves replace the file with a new inode.
  write_config "$workdir/config/.config.json.tmp" "/bin/true" "*/7 * * * *"
  mv "$workdir/config/.config.json.tmp" "$config"
  wait_for_crontab "/bin/true" "*/7 * * * *"

  # supercronic reloads in place; restarting it from the watcher ended the container.
  sleep 1
  kill -0 "$pid" 2>/dev/null || fail "run.sh exited after a reload"
  # The stub's bash merges signals that arrive within one sleep, so count at least one.
  [[ -s "$workdir/reloads" ]] || fail "supercronic was not told to reload"
}

test_watch_config_updates_crontab

echo "All watch_config tests passed"
