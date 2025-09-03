#!/usr/bin/env bash

# Test MD5 change detection
testfile="/tmp/test_md5_config.json"

cat >"$testfile" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/echo hi", "interval": "* * * * *"}
  ]
}
CFG

echo "Initial file hash:"
md5sum "$testfile"

echo "Updating file..."
cat >"$testfile" <<'CFG'
{
  "jobs": [
    {"cmd": "/bin/date", "interval": "*/5 * * * *"}
  ]
}
CFG

echo "Updated file hash:"
md5sum "$testfile"

rm "$testfile"
