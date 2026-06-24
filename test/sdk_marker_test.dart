import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
        'ios/Classes/DetourFlutterMarker.swift',
      ).readAsStringSync();
      expect(
        marker,
        contains('sdkHeaderValue = "flutter/$pubspecVersion"'),
        reason:
            'iOS DetourFlutterMarker must emit flutter/$pubspecVersion as the X-SDK header value',
      );
    });

    test('Android build.gradle.kts version matches pubspec', () {
      final gradle = File('android/build.gradle.kts').readAsStringSync();
      expect(
        gradle,
        contains('version = "$pubspecVersion"'),
        reason:
            'android/build.gradle.kts version must match pubspec.yaml ($pubspecVersion)',
      );
    });

    test('Android BuildConfig derives FLUTTER_SDK_HEADER_VALUE from version', () {
      final gradle = File('android/build.gradle.kts').readAsStringSync();
      // Verifies the pattern `"flutter/$version"` is present so the injected
      // BuildConfig value tracks the gradle version automatically.
      expect(
        gradle,
        contains('"flutter/\$version"'),
        reason:
            'Android FLUTTER_SDK_HEADER_VALUE must be derived as "flutter/\$version" in build.gradle.kts',
      );
    });

    test('vendored contract fixture lists flutter/1.2.0 as the X-SDK example', () {
      final contract = File(
        'test/fixtures/detour-backend-contract.yaml',
      ).readAsStringSync();
      expect(
        contract,
        contains('flutter/1.2.0'),
        reason:
            'Vendored contract fixture must include flutter/1.2.0 as an X-SDK header example — '
            're-vendor test/fixtures/detour-backend-contract.yaml if the contract has changed',
      );
    });
  });
}
