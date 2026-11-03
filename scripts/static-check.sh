#!/usr/bin/env bash
# Static gate — posted-sdk-flutter.
set -euo pipefail
echo "▶ analyze + format (BLOCKING)"
flutter pub get >/dev/null
flutter analyze
dart format --output=none --set-exit-if-changed lib test example/lib example/test

# Guard: reject stale references to the old GitHub org (postedapp); correct org is thepostedapp.
# The search pattern does not appear in thepostedapp URLs so there are no false positives.
echo "▶ org-url guard: no stale old-org references (BLOCKING)"
STALE_PATTERN='github\.com/postedapp'
if MATCHES=$(git grep -n -- "$STALE_PATTERN" -- ':!scripts/static-check.sh'); then
  echo "✗ stale old-org URL found — update to github.com/thepostedapp:"
  echo "$MATCHES"
  exit 1
fi

echo "✓ static gate passed (flutter test runs in CI)"
