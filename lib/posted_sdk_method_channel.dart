import 'package:flutter/services.dart';

import 'posted_sdk_platform_interface.dart';
import 'src/models.dart';

/// [PostedSdkPlatform] backed by the `posted_sdk` method channel.
class MethodChannelPostedSdk extends PostedSdkPlatform {
  final methodChannel = const MethodChannel('posted_sdk');

  @override
  Future<void> reportInstall(PostedConfig config) async {
    await methodChannel.invokeMethod<void>('reportInstall', {
      'apiKey': config.apiKey,
      'appID': config.appID,
    });
  }
}
