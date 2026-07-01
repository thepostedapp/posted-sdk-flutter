import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';
import 'package:posted_sdk/posted_sdk_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = PostedConfig(
  apiKey: 'api-key',
  appID: 'app-id',
  shouldUseClipboard: true,
  linkProcessingMode: PostedLinkProcessingMode.all,
);

PostedResult _linkResult(String route, PostedLinkType type) => PostedResult(
  processed: true,
  link: PostedLink(
    url: 'https://detour.dev$route',
    route: route,
    pathname: route.split('?').first,
    params: const {},
    type: type,
  ),
);

class MockPostedSdkPlatform
    with MockPlatformInterfaceMixin
    implements PostedSdkPlatform {
  PostedConfig? configuredWith;
  PostedEventName? loggedEventName;
  Map<String, dynamic>? loggedEventData;
  String? retentionEvent;
  int resolveAppLaunchCalls = 0;
  PostedResult resolveAppLaunchResult = const PostedResult(
    processed: true,
    link: null,
  );
  bool resetSessionCalled = false;

  @override
  Future<void> configure(PostedConfig config) async {
    configuredWith = config;
  }

  @override
  Stream<PostedResult> get linkStream => const Stream<PostedResult>.empty();

  @override
  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) async {
    loggedEventName = eventName;
    loggedEventData = data;
  }

  @override
  Future<void> logRetention(String eventName) async {
    retentionEvent = eventName;
  }

  @override
  Future<PostedResult> processLink(String url) async {
    return const PostedResult(processed: true, link: null);
  }

  @override
  Future<PostedResult> resolveInitialLink() async {
    return const PostedResult(processed: true, link: null);
  }

  @override
  Future<PostedResult> resolveAppLaunch(PostedConfig config) async {
    resolveAppLaunchCalls++;
    return resolveAppLaunchResult;
  }

  @override
  Future<void> resetSession() async {
    resetSessionCalled = true;
  }
}

void main() {
  final initialPlatform = PostedSdkPlatform.instance;

  tearDown(() {
    PostedSdkPlatform.instance = initialPlatform;
  });

  test('MethodChannelPostedSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPostedSdk>());
  });

  test('logEvent forwards typed enum to platform implementation', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    PostedSdkPlatform.instance = fakePlatform;

    await plugin.logEvent(
      PostedEventName.purchase,
      data: {'currency': 'USD', 'value': 12.5},
    );

    expect(fakePlatform.loggedEventName, PostedEventName.purchase);
    expect(fakePlatform.loggedEventData?['currency'], 'USD');
  });

  test('resolveAppLaunch returns LINK-PRESENT branch result (verified link)', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult =
        _linkResult('/promo?campaign=spring', PostedLinkType.verified);
    PostedSdkPlatform.instance = fakePlatform;

    final result = await plugin.resolveAppLaunch(_config);

    expect(result.processed, true);
    expect(result.link, isNotNull);
    expect(result.link?.type, PostedLinkType.verified);
    expect(result.link?.route, '/promo?campaign=spring');
    expect(fakePlatform.resolveAppLaunchCalls, 1);
  });

  test('resolveAppLaunch returns DEFERRED branch result (deferred link)', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult =
        _linkResult('/onboarding', PostedLinkType.deferred);
    PostedSdkPlatform.instance = fakePlatform;

    final result = await plugin.resolveAppLaunch(_config);

    expect(result.processed, true);
    expect(result.link?.type, PostedLinkType.deferred);
    expect(result.link?.route, '/onboarding');
  });

  test('resolveAppLaunch cache short-circuits: second call does not hit platform', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult =
        _linkResult('/campaign', PostedLinkType.verified);
    PostedSdkPlatform.instance = fakePlatform;

    final first = await plugin.resolveAppLaunch(_config);
    final second = await plugin.resolveAppLaunch(_config);

    expect(fakePlatform.resolveAppLaunchCalls, 1);
    expect(identical(first, second), true);
  });

  test('resetSession clears Dart cache and re-arms platform', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult =
        _linkResult('/campaign', PostedLinkType.deferred);
    PostedSdkPlatform.instance = fakePlatform;

    await plugin.resolveAppLaunch(_config);
    expect(fakePlatform.resolveAppLaunchCalls, 1);

    await plugin.resetSession();

    expect(fakePlatform.resetSessionCalled, true);

    await plugin.resolveAppLaunch(_config);
    expect(fakePlatform.resolveAppLaunchCalls, 2);
  });
}
