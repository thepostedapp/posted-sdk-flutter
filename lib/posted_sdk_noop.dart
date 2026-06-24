import 'package:flutter/foundation.dart';

import 'src/models.dart';
import 'posted_sdk_platform_interface.dart';

/// No-op implementation used on platforms where posted-sdk is not supported
/// (web, macOS, Linux, Windows). All methods return safe defaults.
class NoopPostedSdk extends PostedSdkPlatform {
  @override
  Future<void> configure(PostedConfig config) async {
    debugPrint(
      'posted-sdk: current platform is not supported, skipping initialization',
    );
  }

  @override
  Future<PostedResult> resolveInitialLink() async {
    return const PostedResult(processed: true);
  }

  @override
  Future<PostedResult> processLink(String url) async {
    return const PostedResult(processed: false);
  }

  @override
  Stream<PostedResult> get linkStream => const Stream.empty();

  @override
  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) async {}

  @override
  Future<void> logRetention(String eventName) async {}
}
