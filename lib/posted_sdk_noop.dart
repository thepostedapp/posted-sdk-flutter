import 'package:flutter/foundation.dart';

import 'posted_sdk_platform_interface.dart';
import 'src/models.dart';

/// No-op implementation used on platforms where posted_sdk is not supported
/// (web, macOS, Linux, Windows).
class NoopPostedSdk extends PostedSdkPlatform {
  @override
  Future<void> reportInstall(PostedConfig config) async {
    debugPrint(
        'posted_sdk: current platform is not supported, install not reported');
  }
}
