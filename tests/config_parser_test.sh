#!/usr/bin/env bash
set -euo pipefail

test_writes_crontab_from_config() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cat >"$tmpdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi", "interval": "* * * * *"},
    {"cmd": "/bin/date", "interval": "0 1 * * *"}
  ]
}
CFG

  CONFIG_FILE="$tmpdir/config.json" bash app/config_parser.sh

  local expected=$'* * * * * /bin/echo hi\n0 1 * * * /bin/date'
  local actual
  actual=$(cat /etc/crontabs/root)
  if [[ "$actual" != "$expected" ]]; then
    echo "crontab content mismatch" >&2
    echo "expected:" >&2
    printf '%s\n' "$expected" >&2
    echo "actual:" >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi

  rm -rf "$tmpdir"
  rm -rf /etc/crontabs
}

test_errors_when_missing_pair() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cat >"$tmpdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi"}
  ]
}
CFG
  if CONFIG_FILE="$tmpdir/config.json" bash app/config_parser.sh 2>"$tmpdir/err.log"; then
    echo "script succeeded when it should have failed" >&2
    exit 1
  fi
  if ! grep -q "Missing CMD_1 or INTERVAL_1" "$tmpdir/err.log"; then
    echo "expected error message not found" >&2
    cat "$tmpdir/err.log" >&2
    exit 1
  fi

  rm -rf "$tmpdir"
  rm -rf /etc/crontabs
}

test_env_overrides_config() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cat >"$tmpdir/config.json" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi", "interval": "0 1 * * *"}
  ]
}
CFG

  CMD_1="/bin/date" INTERVAL_1="*/5 * * * *" CONFIG_FILE="$tmpdir/config.json" bash app/config_parser.sh

  local expected=$'*/5 * * * * /bin/date'
  local actual
  actual=$(cat /etc/crontabs/root)
  if [[ "$actual" != "$expected" ]]; then
    echo "crontab content mismatch" >&2
    echo "expected:" >&2
    printf '%s\n' "$expected" >&2
    echo "actual:" >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi

  rm -rf "$tmpdir"
  rm -rf /etc/crontabs
}

test_writes_crontab_from_config
test_errors_when_missing_pair
test_env_overrides_config

echo "All config_parser tests passed"
