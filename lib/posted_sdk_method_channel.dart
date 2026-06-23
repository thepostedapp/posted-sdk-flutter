import 'package:flutter/services.dart';

import 'posted_sdk_platform_interface.dart';
import 'src/models.dart';

class MethodChannelPostedSdk extends PostedSdkPlatform {
  final methodChannel = const MethodChannel('posted_sdk');
  final _eventChannel = const EventChannel('posted_sdk/links');

  Stream<PostedResult>? _linkStream;

  @override
  Stream<PostedResult> get linkStream {
    _linkStream ??= _eventChannel.receiveBroadcastStream().map(
      (event) => PostedResult.fromMap(event as Map),
    );
    return _linkStream!;
  }

  @override
  Future<void> configure(PostedConfig config) async {
    await methodChannel.invokeMethod<void>('configure', {
      'apiKey': config.apiKey,
      'appID': config.appID,
      'shouldUseClipboard': config.shouldUseClipboard,
      'linkProcessingMode': config.linkProcessingMode.value,
    });
  }

  @override
  Future<PostedResult> resolveInitialLink() async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'resolveInitialLink',
    );
    return PostedResult.fromMap(result ?? {});
  }

  @override
  Future<PostedResult> processLink(String url) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'processLink',
      {'url': url},
    );
    return PostedResult.fromMap(result ?? {});
  }

  @override
  Future<void> logEvent(
    PostedEventName eventName, {
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
