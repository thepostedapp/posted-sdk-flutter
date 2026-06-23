import 'package:flutter/services.dart';

import 'detour_flutter_plugin_platform_interface.dart';
import 'src/models.dart';

class MethodChannelDetourFlutterPlugin extends DetourFlutterPluginPlatform {
  final methodChannel = const MethodChannel('detour_flutter_plugin');
  final _eventChannel = const EventChannel('detour_flutter_plugin/links');

  Stream<DetourResult>? _linkStream;

  @override
  Stream<DetourResult> get linkStream {
    _linkStream ??= _eventChannel.receiveBroadcastStream().map(
      (event) => DetourResult.fromMap(event as Map),
    );
    return _linkStream!;
  }

  @override
  Future<void> configure(DetourConfig config) async {
    await methodChannel.invokeMethod<void>('configure', {
      'apiKey': config.apiKey,
      'appID': config.appID,
      'shouldUseClipboard': config.shouldUseClipboard,
      'linkProcessingMode': config.linkProcessingMode.value,
    });
  }

  @override
  Future<DetourResult> resolveInitialLink() async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'resolveInitialLink',
    );
    return DetourResult.fromMap(result ?? {});
  }

  @override
  Future<DetourResult> processLink(String url) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'processLink',
      {'url': url},
    );
    return DetourResult.fromMap(result ?? {});
  }

  @override
  Future<void> logEvent(
    DetourEventName eventName, {
    Map<String, dynamic>? data,
  }) async {
    await methodChannel.invokeMethod<void>('logEvent', {
      'eventName': eventName.rawValue,
      'data': data,
    });
  }

  @override
  Future<void> logRetention(String eventName) async {
    await methodChannel.invokeMethod<void>('logRetention', {
      'eventName': eventName,
    });
  }
}
