import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'detour_flutter_plugin_method_channel.dart';
import 'detour_flutter_plugin_noop.dart';
import 'src/models.dart';
import 'src/supported_platform.dart';

abstract class DetourFlutterPluginPlatform extends PlatformInterface {
  DetourFlutterPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static DetourFlutterPluginPlatform _instance = isSupportedPlatform
      ? MethodChannelDetourFlutterPlugin()
      : NoopDetourFlutterPlugin();

  static DetourFlutterPluginPlatform get instance => _instance;

  static set instance(DetourFlutterPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> configure(DetourConfig config) {
    throw UnimplementedError('configure() has not been implemented.');
  }

  Future<DetourResult> resolveInitialLink() {
    throw UnimplementedError('resolveInitialLink() has not been implemented.');
  }

  Future<DetourResult> processLink(String url) {
    throw UnimplementedError('processLink() has not been implemented.');
  }

  Stream<DetourResult> get linkStream {
    throw UnimplementedError('linkStream has not been implemented.');
  }

  Future<void> logEvent(
    DetourEventName eventName, {
    Map<String, dynamic>? data,
  }) {
    throw UnimplementedError('logEvent() has not been implemented.');
  }

  Future<void> logRetention(String eventName) {
    throw UnimplementedError('logRetention() has not been implemented.');
  }
}
