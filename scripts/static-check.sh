#!/usr/bin/env bash
# Static gate — posted-sdk-flutter.
# NOTE: this repo requires Dart ^3.11.1, whose VM needs macOS >= 14. The dev host is macOS 12.6,
# so `flutter analyze`/`dart` cannot run here. ALL correctness for this plugin is verified in CI.
# This local gate is intentionally a no-op so the agent workflow stays uniform.
set -euo pipefail
echo "ℹ Flutter correctness runs in CI (Dart ^3.11.1 needs macOS >=14; host is 12.6)."

# Guard: reject stale references to the old GitHub org (postedapp); correct org is thepostedapp.
# The search pattern does not appear in thepostedapp URLs so there are no false positives.
echo "▶ org-url guard: no stale old-org references (BLOCKING)"
STALE_PATTERN='github\.com/postedapp'
if MATCHES=$(git grep -n -- "$STALE_PATTERN" -- ':!scripts/static-check.sh'); then
  echo "✗ stale old-org URL found — update to github.com/thepostedapp:"
  echo "$MATCHES"
  exit 1
fi

echo "✓ static gate skipped locally — see CI for analyze/test"
