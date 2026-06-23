import 'package:flutter/foundation.dart';

import 'src/models.dart';
import 'detour_flutter_plugin_platform_interface.dart';

/// No-op implementation used on platforms where Detour is not supported
/// (web, macOS, Linux, Windows). All methods return safe defaults.
class NoopDetourFlutterPlugin extends DetourFlutterPluginPlatform {
  @override
  Future<void> configure(DetourConfig config) async {
    debugPrint(
      'Detour: current platform is not supported, skipping initialization',
    );
  }

  @override
  Future<DetourResult> resolveInitialLink() async {
    return const DetourResult(processed: true);
  }

  @override
  Future<DetourResult> processLink(String url) async {
    return const DetourResult(processed: false);
  }

  @override
  Stream<DetourResult> get linkStream => const Stream.empty();

  @override
  Future<void> logEvent(
    DetourEventName eventName, {
    Map<String, dynamic>? data,
  }) async {}

  @override
  Future<void> logRetention(String eventName) async {}
}
