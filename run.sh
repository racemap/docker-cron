#!/usr/bin/env bash
set -e

# Start cron daemon in the foreground
crond -f -l 2
