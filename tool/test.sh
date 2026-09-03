#!/usr/bin/env bash
# Runs the test suite and prints only the summary and any failures.
#
# `flutter test`'s default reporter emits one line per test transition, which
# buries failures. Usage: tool/test.sh [path ...]
set -uo pipefail

flutter test --reporter=expanded "$@" 2>&1 \
  | grep -vE '^\s*$' \
  | awk '
      /\[E\]/            { failing = 1 }
      failing            { print; next }
      /All tests passed/ { print }
      /Some tests failed/{ print }
      /^[0-9]+:[0-9]+ \+[0-9]+ -[1-9]/ { print }
    '
