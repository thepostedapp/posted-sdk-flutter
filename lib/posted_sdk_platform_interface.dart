import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'posted_sdk_method_channel.dart';
import 'posted_sdk_noop.dart';
import 'src/models.dart';
import 'src/supported_platform.dart';

/// The platform interface for `posted_sdk`. Apps use [Posted] instead.
abstract class PostedSdkPlatform extends PlatformInterface {
  PostedSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static PostedSdkPlatform _instance =
      isSupportedPlatform ? MethodChannelPostedSdk() : NoopPostedSdk();

  static PostedSdkPlatform get instance => _instance;

  static set instance(PostedSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Reports the install through the native Posted SDK. Completes when the
  /// native report for this launch has finished.
  Future<void> reportInstall(PostedConfig config) {
    throw UnimplementedError('reportInstall() has not been implemented.');
  }
}
