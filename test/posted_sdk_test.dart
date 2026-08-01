import 'dart:async';

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
  int processLinkCalls = 0;
  String? lastProcessLinkUrl;
  PostedResult resolveAppLaunchResult = const PostedResult(
    processed: true,
    link: null,
  );
  bool resetSessionCalled = false;

  /// When set, [resolveAppLaunch] blocks on this gate before completing, so a
  /// test can hold a resolution "in flight" while it fires concurrent callers.
  Completer<void>? resolveAppLaunchGate;

  /// When set, [resolveAppLaunch] throws this after incrementing the call
  /// counter, letting a test exercise the failed-resolution path.
  Object? resolveAppLaunchError;

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
    processLinkCalls++;
    lastProcessLinkUrl = url;
    return const PostedResult(processed: true, link: null);
  }

  @override
  Future<PostedResult> resolveInitialLink() async {
    return const PostedResult(processed: true, link: null);
  }

  @override
  Future<PostedResult> resolveAppLaunch(PostedConfig config) async {
    resolveAppLaunchCalls++;
    if (resolveAppLaunchGate != null) {
      await resolveAppLaunchGate!.future;
    }
    if (resolveAppLaunchError != null) {
      throw resolveAppLaunchError!;
    }
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

  test(
    'resolveAppLaunch returns LINK-PRESENT branch result (verified link)',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/promo?campaign=spring',
        PostedLinkType.verified,
      );
      PostedSdkPlatform.instance = fakePlatform;

      final result = await plugin.resolveAppLaunch(_config);

      expect(result.processed, true);
      expect(result.link, isNotNull);
      expect(result.link?.type, PostedLinkType.verified);
      expect(result.link?.route, '/promo?campaign=spring');
      expect(fakePlatform.resolveAppLaunchCalls, 1);
    },
  );

  test(
    'resolveAppLaunch returns DEFERRED branch result (deferred link)',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/onboarding',
        PostedLinkType.deferred,
      );
      PostedSdkPlatform.instance = fakePlatform;

      final result = await plugin.resolveAppLaunch(_config);

      expect(result.processed, true);
      expect(result.link?.type, PostedLinkType.deferred);
      expect(result.link?.route, '/onboarding');
    },
  );

  test(
    'resolveAppLaunch cache short-circuits: second call does not hit platform',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/campaign',
        PostedLinkType.verified,
      );
      PostedSdkPlatform.instance = fakePlatform;

      final first = await plugin.resolveAppLaunch(_config);
      final second = await plugin.resolveAppLaunch(_config);

      expect(fakePlatform.resolveAppLaunchCalls, 1);
      expect(identical(first, second), true);
    },
  );

  test('concurrent first-launch calls produce exactly one platform call and '
      'identical results', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult = _linkResult(
      '/promo?campaign=spring',
      PostedLinkType.verified,
    );
    // Hold the resolution in flight so both callers race the fire-once cache.
    final gate = Completer<void>();
    fakePlatform.resolveAppLaunchGate = gate;
    PostedSdkPlatform.instance = fakePlatform;

    // Fire two callers concurrently before the first resolution completes.
    final first = plugin.resolveAppLaunch(_config);
    final second = plugin.resolveAppLaunch(_config);

    // Let both callers reach their await points before releasing the gate.
    await Future<void>.delayed(Duration.zero);

    gate.complete();
    final results = await Future.wait([first, second]);

    // Single-flight: exactly one platform/network call, identical results.
    expect(fakePlatform.resolveAppLaunchCalls, 1);
    expect(identical(results[0], results[1]), true);
    expect(results[0].link?.route, '/promo?campaign=spring');
  });

  test(
    'coalesced caller increments the debug-only observability counter',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      final gate = Completer<void>();
      fakePlatform.resolveAppLaunchGate = gate;
      PostedSdkPlatform.instance = fakePlatform;

      expect(plugin.debugCoalescedResolutionCount, 0);

      // Fire two callers concurrently before the first resolution completes.
      final first = plugin.resolveAppLaunch(_config);
      final second = plugin.resolveAppLaunch(_config);
      await Future<void>.delayed(Duration.zero);

      // Only the second, coalesced caller bumps the counter.
      expect(plugin.debugCoalescedResolutionCount, 1);

      gate.complete();
      await Future.wait([first, second]);

      // A later, non-overlapping call hits the fire-once cache, not de-dup.
      await plugin.resolveAppLaunch(_config);
      expect(plugin.debugCoalescedResolutionCount, 1);
    },
  );

  test('failed first-launch resolution clears in-flight handle so a retry '
      're-resolves', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchError = Exception('network down');
    PostedSdkPlatform.instance = fakePlatform;

    await expectLater(
      plugin.resolveAppLaunch(_config),
      throwsA(isA<Exception>()),
    );
    expect(fakePlatform.resolveAppLaunchCalls, 1);

    // In-flight handle must be cleared (not cached) so the next call retries.
    fakePlatform.resolveAppLaunchError = null;
    fakePlatform.resolveAppLaunchResult = _linkResult(
      '/campaign',
      PostedLinkType.verified,
    );
    final result = await plugin.resolveAppLaunch(_config);

    expect(fakePlatform.resolveAppLaunchCalls, 2);
    expect(result.link?.route, '/campaign');
  });

  test('resetSession clears Dart cache and re-arms platform', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult = _linkResult(
      '/campaign',
      PostedLinkType.deferred,
    );
    PostedSdkPlatform.instance = fakePlatform;

    await plugin.resolveAppLaunch(_config);
    expect(fakePlatform.resolveAppLaunchCalls, 1);

    await plugin.resetSession();

    expect(fakePlatform.resetSessionCalled, true);

    await plugin.resolveAppLaunch(_config);
    expect(fakePlatform.resolveAppLaunchCalls, 2);
  });

  // ── Re-arm regressions (POS-354, mirrors Android POS-182) ────────────────

  test('resetSession re-arm: the next resolveAppLaunch makes a fresh platform '
      'call and returns a brand-new result, not the stale cache', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    fakePlatform.resolveAppLaunchResult = const PostedResult(
      processed: true,
      link: null,
    );
    PostedSdkPlatform.instance = fakePlatform;

    final first = await plugin.resolveAppLaunch(_config);
    // Second call is served from cache — proves the fire-once gate is armed.
    final second = await plugin.resolveAppLaunch(_config);
    expect(fakePlatform.resolveAppLaunchCalls, 1);
    expect(identical(first, second), true);

    await plugin.resetSession();
    expect(fakePlatform.resetSessionCalled, true);

    // Only a fresh platform call can satisfy this — the stale cache held
    // the no-link result above.
    fakePlatform.resolveAppLaunchResult = _linkResult(
      '/rearm',
      PostedLinkType.verified,
    );
    final rearmed = await plugin.resolveAppLaunch(_config);

    expect(fakePlatform.resolveAppLaunchCalls, 2);
    expect(rearmed.link?.route, '/rearm');
    expect(identical(rearmed, first), false);
  });

  test(
    'resetSession during an in-flight resolve is honored on the next '
    'resolve: the in-flight call is allowed to complete and cache its '
    'stale result, but the following resolveAppLaunch must clear it and '
    're-resolve rather than serving the stale cache',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/stale',
        PostedLinkType.deferred,
      );
      // Gate enforces overlap deterministically (mock-server handshake), not
      // a delay: the first resolve is held in flight until the test has
      // issued resetSession(), so the reset provably overlaps the resolve.
      final gate = Completer<void>();
      fakePlatform.resolveAppLaunchGate = gate;
      PostedSdkPlatform.instance = fakePlatform;

      final inFlight = plugin.resolveAppLaunch(_config);
      // Let the in-flight call reach the gate before resetting.
      await Future<void>.delayed(Duration.zero);

      await plugin.resetSession();
      expect(fakePlatform.resetSessionCalled, true);

      // Release the in-flight resolve; it completes and caches its (now
      // stale) result — resetSession() does not cancel work in progress.
      gate.complete();
      final staleResult = await inFlight;
      expect(staleResult.link?.route, '/stale');

      // The pending reset must be honored on the *next* resolve: it clears
      // the stale cache and re-resolves, making a fresh platform call
      // rather than serving the just-cached stale value.
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/rearm',
        PostedLinkType.verified,
      );
      final rearmed = await plugin.resolveAppLaunch(_config);

      expect(fakePlatform.resolveAppLaunchCalls, 2);
      expect(rearmed.link?.route, '/rearm');
    },
    skip:
        'Known gap (POS-354 discovery, tracked as POS-459): resetSession() '
        'eagerly clears the Dart-side cache instead of setting a '
        'pending-reset flag applied at the start of the next resolve. A '
        'resolve already in flight when resetSession() is called overwrites '
        'the cleared cache with its stale result when it completes, so the '
        'next resolveAppLaunch() serves the stale value instead of '
        're-resolving. Un-skip once the pending-reset-flag fix (mirroring '
        'the Android POS-181 design) lands in POS-459.',
  );

  test('configure() stores config for use by deprecated shims', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    PostedSdkPlatform.instance = fakePlatform;

    await plugin.configure(_config);

    expect(fakePlatform.configuredWith, _config);
  });

  test(
    'resolveInitialLink() routes through resolveAppLaunch (fire-once shared)',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/onboarding',
        PostedLinkType.deferred,
      );
      PostedSdkPlatform.instance = fakePlatform;

      await plugin.configure(_config);
      // ignore: deprecated_member_use
      final result = await plugin.resolveInitialLink();

      expect(result.link?.route, '/onboarding');
      // Must route through resolveAppLaunch, not the old resolveInitialLink path.
      expect(fakePlatform.resolveAppLaunchCalls, 1);
    },
  );

  test(
    'resolveInitialLink() shares fire-once cache with resolveAppLaunch',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      fakePlatform.resolveAppLaunchResult = _linkResult(
        '/campaign',
        PostedLinkType.verified,
      );
      PostedSdkPlatform.instance = fakePlatform;

      // First call via resolveAppLaunch warms the cache.
      await plugin.resolveAppLaunch(_config);
      expect(fakePlatform.resolveAppLaunchCalls, 1);

      // Deprecated shim must return the cached result — no second platform call.
      // ignore: deprecated_member_use
      await plugin.resolveInitialLink();
      expect(fakePlatform.resolveAppLaunchCalls, 1);
    },
  );

  test(
    'resolveInitialLink() throws StateError when configure() not called first',
    () {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      PostedSdkPlatform.instance = fakePlatform;

      // ignore: deprecated_member_use
      expect(() => plugin.resolveInitialLink(), throwsStateError);
    },
  );

  test(
    'processLink() is deprecated: delegates to platform processLink',
    () async {
      final plugin = PostedSdk();
      final fakePlatform = MockPostedSdkPlatform();
      PostedSdkPlatform.instance = fakePlatform;

      // ignore: deprecated_member_use
      await plugin.processLink('https://example.com/promo');

      expect(fakePlatform.processLinkCalls, 1);
      expect(fakePlatform.lastProcessLinkUrl, 'https://example.com/promo');
    },
  );
}
