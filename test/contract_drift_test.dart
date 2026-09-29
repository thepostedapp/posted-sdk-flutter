// Contract drift guard (POS-91).
//
// The SDK-backend contract is owned by posted-sdk-admin at
// contract/posted-backend-contract.yaml. This repo vendors a pinned copy at
// test/fixtures/posted-backend-contract.yaml so tests run without cross-repo
// access. A vendored copy can silently rot, so the canonical sha256 is pinned
// here and asserted on every run.
//
// TO RE-VENDOR after the canonical contract changes:
//   1. cp <posted-sdk-admin>/contract/posted-backend-contract.yaml \
//        test/fixtures/posted-backend-contract.yaml
//   2. shasum -a 256 test/fixtures/posted-backend-contract.yaml
//   3. update canonicalSha256 below with the new digest
//   4. update the matching pins in the sibling SDKs (posted-sdk-ios
//      ContractFixtureChecksumTests.swift, posted-sdk-android and
//      posted-sdk-react-native fixtures) so all four move together
//
// KNOWN LIMITATION: a pinned checksum detects this vendored copy being edited,
// but NOT the canonical contract drifting ahead of it. Catching that needs
// cross-repo read access in CI and is deliberately out of scope.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canonical contract v1.1.0 digest.
const canonicalSha256 =
    '9a6d4ce0013d4b9de4f2199ce603855890c39e93d605c7195dd8b8275a088bde';

const fixturePath = 'test/fixtures/posted-backend-contract.yaml';

void main() {
  test('vendored contract matches the pinned canonical checksum', () {
    final file = File(fixturePath);
    expect(file.existsSync(), isTrue);

    final actual = sha256.convert(file.readAsBytesSync()).toString();
    expect(actual, canonicalSha256);
  });

  test('vendored contract declares version 1.1.0', () {
    final text = File(fixturePath).readAsStringSync();
    expect(text, contains('version: 1.1.0'));
  });

  test('vendored contract targets only postedapp.com hosts', () {
    final text = File(fixturePath).readAsStringSync();
    expect(text, contains('https://attr.postedapp.com'));
    final foreign = RegExp(r'https?://([A-Za-z0-9._-]+)')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .where((h) => h != 'postedapp.com' && !h.endsWith('.postedapp.com'))
        .toSet();
    expect(
      foreign,
      isEmpty,
      reason: 'Contract may only reference postedapp.com hosts.',
    );
  });
}
