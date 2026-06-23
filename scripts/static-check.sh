#!/usr/bin/env bash
# Static gate — detour-flutter-plugin.
# NOTE: this repo requires Dart ^3.11.1, whose VM needs macOS >= 14. The dev host is macOS 12.6,
# so `flutter analyze`/`dart` cannot run here. ALL correctness for this plugin is verified in CI.
# This local gate is intentionally a no-op so the agent workflow stays uniform.
set -euo pipefail
echo "ℹ Flutter correctness runs in CI (Dart ^3.11.1 needs macOS >=14; host is 12.6)."
echo "✓ static gate skipped locally — see CI for analyze/test"
