#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
pubspec_path="$repo_root/pubspec.yaml"
marker_path="$repo_root/ios/Classes/PostedFlutterMarker.swift"

pubspec_version="$(sed -n 's/^version: //p' "$pubspec_path" | head -n 1)"
marker_version="$(sed -n 's/.*sdkHeaderValue = "\(flutter\/[^"]*\)".*/\1/p' "$marker_path" | head -n 1)"
expected_marker_version="flutter/$pubspec_version"

if [[ -z "$pubspec_version" ]]; then
  echo "Failed to read version from $pubspec_path" >&2
  exit 1
fi

if [[ -z "$marker_version" ]]; then
  echo "Failed to read sdkHeaderValue from $marker_path" >&2
  exit 1
fi

if [[ "$marker_version" != "$expected_marker_version" ]]; then
  echo "Version mismatch detected." >&2
  echo "pubspec.yaml: $expected_marker_version" >&2
  echo "PostedFlutterMarker.swift: $marker_version" >&2
  exit 1
fi

echo "iOS marker version matches pubspec.yaml: $marker_version"
