#!/usr/bin/env bash
set -e

# Generate cron entries from environment/config
bash /app/config_parser.sh
# Start cron daemon in the foreground
crond -f -l 2
