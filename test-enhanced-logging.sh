#!/usr/bin/env bash

echo "Testing enhanced logging features..."
echo

echo "1. Testing environment variables only:"
echo "docker run --rm -e CMD_1='echo Hello from env' -e INTERVAL_1='*/1 * * * *' docker-cron-test"
echo

echo "2. Testing config file only:"
echo "docker run --rm -v \$(pwd)/example/config.json:/app/config.json -e CONFIG_FILE=/app/config.json docker-cron-test"
echo

echo "3. Testing environment override of config file:"
echo "docker run --rm -v \$(pwd)/example/config.json:/app/config.json -e CONFIG_FILE=/app/config.json -e CMD_1='Override from env' docker-cron-test"
echo

echo "4. Testing error handling with missing config file:"
echo "docker run --rm -e CONFIG_FILE=/nonexistent/config.json docker-cron-test"
echo

echo "5. Testing multiple jobs:"
echo "docker run --rm -e CMD_1='echo Job 1' -e INTERVAL_1='*/1 * * * *' -e CMD_2='date' -e INTERVAL_2='*/2 * * * *' docker-cron-test"
echo

echo "Run any of these commands to see the enhanced logging in action!"
