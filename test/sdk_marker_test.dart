import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// X-SDK marker guards.
///
/// The native SDKs read a marker shipped by this plugin and send its value as
/// the `X-SDK` header, so installs are attributed to `flutter/<version>`
/// rather than the bare `ios/…` or `android/…`. These source guards assert
/// that every declared version equals the pubspec version; the native CI jobs
/// execute the real resolvers.
void main() {
  late String pubspecVersion;

  setUpAll(() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');
    pubspecVersion = match!.group(1)!;
  });

  test('pubspec version is a bare semver', () {
    expect(pubspecVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });

  test('iOS marker declares flutter/<pubspec version>', () {
    final source =
        File('ios/Classes/PostedFlutterMarker.swift').readAsStringSync();
    final match = RegExp(r'sdkHeaderValue\s*=\s*"([^"]+)"').firstMatch(source);
    expect(match?.group(1), 'flutter/$pubspecVersion');
  });

  test('iOS podspec version matches the pubspec', () {
    final source = File('ios/posted_sdk.podspec').readAsStringSync();
    final match = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(source);
    expect(match?.group(1), pubspecVersion);
  });

  test('Android plugin version matches the pubspec and feeds the marker', () {
    final source = File('android/build.gradle.kts').readAsStringSync();
    final version =
        RegExp(r'^version\s*=\s*"([^"]+)"', multiLine: true).firstMatch(source);
    expect(version?.group(1), pubspecVersion);
    expect(source, contains('"flutter/\$version"'));
  });
}
