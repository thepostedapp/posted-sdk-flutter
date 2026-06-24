import 'dart:async';

import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePostedPlatform extends PostedSdkPlatform
    with MockPlatformInterfaceMixin {
  FakePostedPlatform({required this.initialResult, required this.manualResult});

  final StreamController<PostedResult> _runtimeController =
      StreamController<PostedResult>.broadcast();

  final PostedResult initialResult;
  final PostedResult manualResult;

  int configureCalls = 0;

  @override
  Future<void> configure(PostedConfig config) async {
    configureCalls += 1;
  }

  @override
  Stream<PostedResult> get linkStream => _runtimeController.stream;

  @override
  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) async {}

  @override
  Future<void> logRetention(String eventName) async {}

  @override
  Future<PostedResult> processLink(String url) async {
    return manualResult;
  }

  @override
  Future<PostedResult> resolveInitialLink() async {
    return initialResult;
  }

  void emitRuntime(PostedResult result) {
    _runtimeController.add(result);
  }

  Future<void> close() async {
    await _runtimeController.close();
  }
}

const _config = PostedConfig(
  apiKey: 'api-key',
  appID: 'app-id',
  shouldUseClipboard: true,
  linkProcessingMode: PostedLinkProcessingMode.all,
);

PostedResult _resultFor(String route, PostedLinkType type) {
  return PostedResult(
    processed: true,
    link: PostedLink(
      url: 'https://detour.dev$route',
      route: route,
      pathname: route.split('?').first,
      params: const {},
      type: type,
    ),
  );
}

void main() {
  test('start() sets readiness and publishes initial intent', () async {
    final platform = FakePostedPlatform(
      initialResult: _resultFor(
        '/promo?campaign=spring',
        PostedLinkType.deferred,
      ),
      manualResult: const PostedResult(processed: true, link: null),
    );

    final service = PostedService(platform: platform);

    await service.start(_config);

    expect(platform.configureCalls, 1);
    expect(service.isStarted, true);
    expect(service.isInitialLinkProcessed, true);
    expect(service.pendingIntent, isNotNull);
    expect(service.pendingIntent?.source, PostedIntentSource.initial);
    expect(service.pendingIntent?.link.route, '/promo?campaign=spring');

    service.consumePendingIntent();
    expect(service.pendingIntent, isNull);

    await service.stop();
    await platform.close();
    service.dispose();
  });

  test(
    'suppresses short-window duplicates between initial and runtime',
    () async {
      final link = _resultFor('/details?id=1', PostedLinkType.verified);
      final platform = FakePostedPlatform(
        initialResult: link,
        manualResult: const PostedResult(processed: true, link: null),
      );

      final service = PostedService(
        platform: platform,
        duplicateSuppressionWindow: const Duration(milliseconds: 120),
      );

      await service.start(_config);
      service.consumePendingIntent();

      platform.emitRuntime(link);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.pendingIntent, isNull);

      platform.emitRuntime(
        _resultFor('/details?id=2', PostedLinkType.verified),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.pendingIntent, isNotNull);
      expect(service.pendingIntent?.source, PostedIntentSource.runtime);
      expect(service.pendingIntent?.link.route, '/details?id=2');

      service.consumePendingIntent();
      await Future<void>.delayed(const Duration(milliseconds: 130));

      platform.emitRuntime(link);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.pendingIntent, isNotNull);
      expect(service.pendingIntent?.link.route, '/details?id=1');

      await service.stop();
      await platform.close();
      service.dispose();
    },
  );

  test('processLink can emit manual intent optionally', () async {
    final manual = _resultFor('/manual', PostedLinkType.scheme);
    final platform = FakePostedPlatform(
      initialResult: const PostedResult(processed: true, link: null),
      manualResult: manual,
    );

    final service = PostedService(platform: platform);
    await service.start(_config);

    expect(service.pendingIntent, isNull);

    await service.processLink('detour://manual', emitIntent: false);
    expect(service.pendingIntent, isNull);

    await service.processLink('detour://manual', emitIntent: true);
    expect(service.pendingIntent, isNotNull);
    expect(service.pendingIntent?.source, PostedIntentSource.manual);
    expect(service.pendingIntent?.link.route, '/manual');

    await service.stop();
    await platform.close();
    service.dispose();
  });
}
