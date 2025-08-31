#!/usr/bin/env bash
set -euo pipefail

bash tests/config_parser_test.sh
bash tests/watch_config_test.sh

echo "All tests passed"
