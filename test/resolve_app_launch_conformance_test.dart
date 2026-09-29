import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';
import 'package:posted_sdk/posted_sdk_platform_interface.dart';

/// resolveAppLaunch conformance (POS-440, extends the POS-25 harness).
///
/// Scope note: `posted-backend-contract.yaml` governs the HTTP wire between
/// the *native* SDKs and the backend. Dart's [PostedSdk.resolveAppLaunch]
/// never makes that HTTP call itself — [MethodChannelPostedSdk.resolveAppLaunch]
/// only invokes the `resolveAppLaunch` platform-channel method; the embedded
/// native iOS/Android SDK performs the actual `/api/link/match-link` request
/// (both the `DeterministicMatch`/`ProbabilisticFingerprint` request `oneOf`
/// and the `LinkResponse` reply). That wire conformance is exercised by the
/// posted-sdk-android / posted-sdk-ios conformance suites, not here.
///
/// What *is* Flutter's contract to keep stable is the Dart<->native
/// method-channel boundary: the outgoing arg map [MethodChannelPostedSdk]
/// sends, and the [PostedResult] it decodes from whatever map native returns
/// for both match-link outcomes (a matched link and a no-match). These tests
/// drive the public [PostedSdk] facade (not the deprecated
/// `resolveInitialLink`/`processLink` shims) through a real `MethodChannel`
/// mock, so they fail if either side of that boundary drifts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('posted_sdk');
  const config = PostedConfig(
    apiKey: 'api-key',
    appID: 'app-id',
    shouldUseClipboard: true,
    linkProcessingMode: PostedLinkProcessingMode.all,
  );

  final calls = <MethodCall>[];
  Map<String, dynamic>? nativeResponse;

  setUp(() {
    calls.clear();
    PostedSdkPlatform.instance = MethodChannelPostedSdk();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          calls.add(methodCall);
          return nativeResponse;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('matched-link branch: public resolveAppLaunch sends the stable arg map '
      'and decodes a contract-valid PostedResult', () async {
    nativeResponse = {
      'processed': true,
      'link': {
        'url': 'https://posted.link/app/promo?ref=spring',
        'route': '/promo?ref=spring',
        'pathname': '/promo',
        'params': {'ref': 'spring'},
        'type': 'deferred',
      },
    };

    final sdk = PostedSdk();
    final result = await sdk.resolveAppLaunch(config);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'resolveAppLaunch');
    expect(calls.single.arguments, {
      'apiKey': 'api-key',
      'appID': 'app-id',
      'shouldUseClipboard': true,
      'linkProcessingMode': 'all',
    });

    expect(result.processed, true);
    expect(result.link, isNotNull);
    expect(result.link?.type, PostedLinkType.deferred);
    expect(result.link?.route, '/promo?ref=spring');
    expect(result.link?.params['ref'], 'spring');
  });

  test('no-match branch: public resolveAppLaunch decodes a contract-valid '
      'PostedResult with a null link', () async {
    nativeResponse = {'processed': true, 'link': null};

    final sdk = PostedSdk();
    final result = await sdk.resolveAppLaunch(config);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'resolveAppLaunch');
    expect(result.processed, true);
    expect(result.link, isNull);
  });
}
