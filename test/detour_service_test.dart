import 'dart:async';

import 'package:detour_flutter_plugin/detour_flutter_plugin.dart';
import 'package:detour_flutter_plugin/detour_flutter_plugin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeDetourPlatform extends DetourFlutterPluginPlatform
    with MockPlatformInterfaceMixin {
  FakeDetourPlatform({required this.initialResult, required this.manualResult});

  final StreamController<DetourResult> _runtimeController =
      StreamController<DetourResult>.broadcast();

  final DetourResult initialResult;
  final DetourResult manualResult;

  int configureCalls = 0;

  @override
  Future<void> configure(DetourConfig config) async {
    configureCalls += 1;
  }

  @override
  Stream<DetourResult> get linkStream => _runtimeController.stream;

  @override
  Future<void> logEvent(
    DetourEventName eventName, {
    Map<String, dynamic>? data,
  }) async {}

  @override
  Future<void> logRetention(String eventName) async {}

  @override
  Future<DetourResult> processLink(String url) async {
    return manualResult;
  }

  @override
  Future<DetourResult> resolveInitialLink() async {
    return initialResult;
  }

  void emitRuntime(DetourResult result) {
    _runtimeController.add(result);
  }

  Future<void> close() async {
    await _runtimeController.close();
  }
}

const _config = DetourConfig(
  apiKey: 'api-key',
  appID: 'app-id',
  shouldUseClipboard: true,
  linkProcessingMode: LinkProcessingMode.all,
);

DetourResult _resultFor(String route, LinkType type) {
  return DetourResult(
    processed: true,
    link: DetourLink(
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
    final platform = FakeDetourPlatform(
      initialResult: _resultFor('/promo?campaign=spring', LinkType.deferred),
      manualResult: const DetourResult(processed: true, link: null),
    );

    final service = DetourService(platform: platform);

    await service.start(_config);

    expect(platform.configureCalls, 1);
    expect(service.isStarted, true);
    expect(service.isInitialLinkProcessed, true);
    expect(service.pendingIntent, isNotNull);
    expect(service.pendingIntent?.source, DetourIntentSource.initial);
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
      final link = _resultFor('/details?id=1', LinkType.verified);
      final platform = FakeDetourPlatform(
        initialResult: link,
        manualResult: const DetourResult(processed: true, link: null),
      );

      final service = DetourService(
        platform: platform,
        duplicateSuppressionWindow: const Duration(milliseconds: 120),
      );

      await service.start(_config);
      service.consumePendingIntent();

      platform.emitRuntime(link);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.pendingIntent, isNull);

      platform.emitRuntime(_resultFor('/details?id=2', LinkType.verified));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.pendingIntent, isNotNull);
      expect(service.pendingIntent?.source, DetourIntentSource.runtime);
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
    final manual = _resultFor('/manual', LinkType.scheme);
    final platform = FakeDetourPlatform(
      initialResult: const DetourResult(processed: true, link: null),
      manualResult: manual,
    );

    final service = DetourService(platform: platform);
    await service.start(_config);

    expect(service.pendingIntent, isNull);

    await service.processLink('detour://manual', emitIntent: false);
    expect(service.pendingIntent, isNull);

    await service.processLink('detour://manual', emitIntent: true);
    expect(service.pendingIntent, isNotNull);
    expect(service.pendingIntent?.source, DetourIntentSource.manual);
    expect(service.pendingIntent?.link.route, '/manual');

    await service.stop();
    await platform.close();
    service.dispose();
  });
}
