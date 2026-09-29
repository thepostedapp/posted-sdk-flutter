// Contract drift guard (POS-91).
//
// The SDK⇄backend contract is owned by posted-sdk-admin at
// contract/posted-backend-contract.yaml. This repo vendors a pinned copy at
// test/fixtures/posted-backend-contract.yaml so tests can run without
// cross-repo access.
//
// A vendored copy can silently rot. This test pins the canonical sha256 and
// fails loudly when the fixture no longer matches it.
//
// TO RE-VENDOR after the canonical contract changes:
//   1. cp <posted-sdk-admin>/contract/posted-backend-contract.yaml \
//        test/fixtures/posted-backend-contract.yaml
//   2. shasum -a 256 test/fixtures/posted-backend-contract.yaml
//   3. update `canonicalSha256` below with the new digest
//   4. update the matching pins in the sibling SDKs:
//        ios-detour/Tests/PostedSDKTests/ContractConformanceTests.swift (header comment)
//        android-detour/posted-sdk/src/test/resources/fixtures/
//        react-native-detour/packages/react-native-posted-sdk/src/__tests__/__fixtures__/
//
// KNOWN LIMITATION: a pinned checksum detects this vendored copy being edited,
// but NOT the canonical contract drifting ahead of it. Catching that requires
// cross-repo read access in CI, which is deliberately out of scope here.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contract drift guard', () {
    // Canonical contract v1.1.0 — posted-sdk-admin/contract/posted-backend-contract.yaml
    const canonicalSha256 =
        '9a6d4ce0013d4b9de4f2199ce603855890c39e93d605c7195dd8b8275a088bde';
    const fixturePath = 'test/fixtures/posted-backend-contract.yaml';

    test('vendored fixture matches the pinned canonical checksum', () {
      final file = File(fixturePath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Vendored contract fixture is missing at $fixturePath.',
      );

      final actual = sha256.convert(file.readAsBytesSync()).toString();

      expect(
        actual,
        canonicalSha256,
        reason: '\n'
            'Contract drift detected.\n'
            '  expected sha256: $canonicalSha256\n'
            '  actual   sha256: $actual\n'
            '  file           : $fixturePath\n'
            '\n'
            'The vendored contract copy no longer matches the pinned canonical\n'
            'digest. Either the fixture was edited directly (do not do this), or\n'
            'the canonical contract changed and this copy needs re-vendoring.\n'
            'See the re-vendor steps in the header of this file.\n',
      );
    });

    test('vendored fixture declares the expected contract version', () {
      final text = File(fixturePath).readAsStringSync();
      expect(
        text,
        contains('version: 1.1.0'),
        reason: 'Vendored contract is not v1.1.0; re-vendor from canonical.',
      );
    });

    test('vendored fixture targets the postedapp.com API host', () {
      final text = File(fixturePath).readAsStringSync();
      expect(
        text,
        contains('https://attr.postedapp.com'),
        reason: 'Contract must declare attr.postedapp.com as the API server.',
      );
      expect(
        text.contains('godetour.dev'),
        isFalse,
        reason: 'Contract must not reference the third-party godetour.dev host.',
      );
    });
  });
}
