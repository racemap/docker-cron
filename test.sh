#!/usr/bin/env bash
set -euo pipefail

for test_file in tests/*_test.sh; do
  echo "Running $test_file"
  bash "$test_file"
  echo
done

echo "All tests passed"
