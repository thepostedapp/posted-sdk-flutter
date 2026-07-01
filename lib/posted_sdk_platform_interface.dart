import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'posted_sdk_method_channel.dart';
import 'posted_sdk_noop.dart';
import 'src/models.dart';
import 'src/supported_platform.dart';

abstract class PostedSdkPlatform extends PlatformInterface {
  PostedSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static PostedSdkPlatform _instance = isSupportedPlatform
      ? MethodChannelPostedSdk()
      : NoopPostedSdk();

  static PostedSdkPlatform get instance => _instance;

  static set instance(PostedSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> configure(PostedConfig config) {
    throw UnimplementedError('configure() has not been implemented.');
  }

  Future<PostedResult> resolveInitialLink() {
    throw UnimplementedError('resolveInitialLink() has not been implemented.');
  }

  /// Resolves app launch attribution via the 3.0.0 facade (fire-once, cached).
  Future<PostedResult> resolveAppLaunch(PostedConfig config) {
    throw UnimplementedError('resolveAppLaunch() has not been implemented.');
  }

  /// Re-arms fire-once; next [resolveAppLaunch] call performs a fresh network call.
  Future<void> resetSession() {
    throw UnimplementedError('resetSession() has not been implemented.');
  }

  Future<PostedResult> processLink(String url) {
    throw UnimplementedError('processLink() has not been implemented.');
  }

  Stream<PostedResult> get linkStream {
    throw UnimplementedError('linkStream has not been implemented.');
  }

  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) {
    throw UnimplementedError('logEvent() has not been implemented.');
  }

  Future<void> logRetention(String eventName) {
    throw UnimplementedError('logRetention() has not been implemented.');
  }
}
