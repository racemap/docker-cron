#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=docker-cron-test
LOG_FILE=test.log
TEMP_CONFIG=config.env

cleanup() {
  rm -f "$TEMP_CONFIG" "$LOG_FILE"
}
trap cleanup EXIT

# Build docker image
 docker build -t "$IMAGE_NAME" .

# Create temporary config file
cat > "$TEMP_CONFIG" <<'CFG'
CMD_1="echo hello from cron"
INTERVAL_1="* * * * *"
CFG

# Run config parser inside container and display generated crontab
 docker run --rm -v "$(pwd)/$TEMP_CONFIG:/config.env" -e CONFIG_FILE=/config.env --entrypoint /bin/sh "$IMAGE_NAME" -c '/app/config_parser.sh; cat /etc/crontabs/root' | tee "$LOG_FILE"

# Verify expected command is present in log
grep -q "echo hello from cron" "$LOG_FILE"

echo "Test completed successfully"
