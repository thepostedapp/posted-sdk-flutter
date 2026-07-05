import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// X-SDK marker guards.
///
/// These tests protect the cross-platform contract that the Flutter plugin
/// overrides the native `X-SDK` header to `flutter/<pubspec-version>` (rather
/// than the bare `android/…` / `ios/…` the native SDKs emit on their own).
///
/// They are intentionally *source guards*: the true native resolvers
/// (`PostedFlutterMarker` via `NSClassFromString` on iOS, the injected
/// `BuildConfig.FLUTTER_SDK_HEADER_VALUE` on Android) can only be exercised on
/// a device/emulator, and the current CI pipeline runs the Dart `flutter test`
/// job only — native Swift/Kotlin execution is not gated (see POS-163
/// discovery). A host/integration test that emits a real header is deferred
/// until a native CI job exists.
///
/// To stay useful without that native run, the guards parse the *declared
/// value* out of each source and assert it equals the pubspec-derived
/// expectation. This is tolerant of cosmetic reformatting (whitespace around
/// `=`, line wraps) yet still fails on a real marker/version regression — a
/// wrong value, not merely the absence of an exact substring.
void main() {
  group('X-SDK marker override', () {
    late String pubspecVersion;

    setUpAll(() {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s+(\S+)',
        multiLine: true,
      ).firstMatch(pubspec);
      if (match == null) {
        throw StateError('Failed to parse version from pubspec.yaml');
      }
      pubspecVersion = match.group(1)!;
    });

    test('iOS marker sdkHeaderValue is flutter/<pubspec-version>', () {
      final marker = File(
        'ios/Classes/PostedFlutterMarker.swift',
      ).readAsStringSync();
      // Whitespace-tolerant: capture the string literal assigned to
      // `sdkHeaderValue` and compare the value, not the exact source text.
      final match = RegExp(
        r'sdkHeaderValue\s*=\s*"([^"]*)"',
      ).firstMatch(marker);
      expect(
        match,
        isNotNull,
        reason:
            'iOS PostedFlutterMarker must declare an sdkHeaderValue string '
            'literal (see ios/Classes/PostedFlutterMarker.swift)',
      );
      expect(
        match!.group(1),
        equals('flutter/$pubspecVersion'),
        reason:
            'iOS PostedFlutterMarker.sdkHeaderValue must emit '
            'flutter/$pubspecVersion as the X-SDK header value',
      );
    });

    test('Android build.gradle.kts version matches pubspec', () {
      final gradle = File('android/build.gradle.kts').readAsStringSync();
      // Match the top-level `version = "…"` (anchored at line start so it does
      // not pick up the indented `kotlinVersion` / `flutterSdkHeaderValue`).
      final match = RegExp(
        r'^version\s*=\s*"([^"]*)"',
        multiLine: true,
      ).firstMatch(gradle);
      expect(
        match,
        isNotNull,
        reason:
            'android/build.gradle.kts must declare a top-level version = "…"',
      );
      expect(
        match!.group(1),
        equals(pubspecVersion),
        reason:
            'android/build.gradle.kts version must match pubspec.yaml '
            '($pubspecVersion)',
      );
    });

    test('Android BuildConfig derives FLUTTER_SDK_HEADER_VALUE from version', () {
      final gradle = File('android/build.gradle.kts').readAsStringSync();
      // Verifies the flutter header is *derived* from the gradle version via
      // string interpolation (`"flutter/$version"`) rather than hardcoded, so
      // the injected BuildConfig value tracks the version automatically.
      // Whitespace-tolerant around the assignment.
      expect(
        gradle,
        matches(RegExp(r'=\s*"flutter/\$version"')),
        reason:
            'Android FLUTTER_SDK_HEADER_VALUE must be derived as '
            r'"flutter/$version" in build.gradle.kts (not a hardcoded version)',
      );
    });

    test('vendored contract fixture lists flutter/1.2.0 as the X-SDK example', () {
      final contract = File(
        'test/fixtures/posted-backend-contract.yaml',
      ).readAsStringSync();
      expect(
        contract,
        contains('flutter/1.2.0'),
        reason:
            'Vendored contract fixture must include flutter/1.2.0 as an X-SDK '
            'header example — re-vendor test/fixtures/posted-backend-contract.yaml '
            'if the contract has changed',
      );
    });
  });
}
