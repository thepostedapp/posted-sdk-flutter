import 'package:flutter/foundation.dart';

import 'src/models.dart';
import 'src/posted_service.dart';
import 'posted_sdk_platform_interface.dart';
import 'posted_sdk_method_channel.dart';

export 'src/models.dart';
export 'src/posted_service.dart';

class PostedSdk {
  PostedResult? _cachedLaunchResult;
  PostedConfig? _config;

  Future<void> configure(PostedConfig config) {
    _config = config;
    return PostedSdkPlatform.instance.configure(config);
  }

  /// Resolves app launch attribution using the 3.0.0 single-entry-point facade.
  ///
  /// Fire-once: the result is cached after the first call. Subsequent calls in
  /// the same session return the cached result immediately. The native layer
  /// persists the fire-once flag and cached result across app updates; only a
  /// reinstall or [resetSession] call re-arms it.
  Future<PostedResult> resolveAppLaunch(PostedConfig config) async {
    _config = config;
    if (_cachedLaunchResult != null) {
      return _cachedLaunchResult!;
    }
    final result = await PostedSdkPlatform.instance.resolveAppLaunch(config);
    _cachedLaunchResult = result;
    return result;
  }

  /// Re-arms fire-once: clears the Dart-session cache and calls native
  /// resetSession so the next [resolveAppLaunch] performs a fresh resolution.
  Future<void> resetSession() async {
    _cachedLaunchResult = null;
    await PostedSdkPlatform.instance.resetSession();
  }

  @Deprecated(
    'Use resolveAppLaunch(config) instead. resolveInitialLink() will be '
    'removed in the next major release.',
  )
  Future<PostedResult> resolveInitialLink() {
    debugPrint(
      'posted-sdk: resolveInitialLink() is deprecated. '
      'Use resolveAppLaunch(config) instead.',
    );
    assert(_config != null, 'Call configure() before resolveInitialLink().');
    return resolveAppLaunch(_config!);
  }

  @Deprecated(
    'Use resolveAppLaunch(config) instead. processLink() will be '
    'removed in the next major release.',
  )
  Future<PostedResult> processLink(String url) {
    debugPrint(
      'posted-sdk: processLink() is deprecated. '
      'Use resolveAppLaunch(config) instead.',
    );
    return PostedSdkPlatform.instance.processLink(url);
  }

  Stream<PostedResult> get linkStream => PostedSdkPlatform.instance.linkStream;

  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) {
    return PostedSdkPlatform.instance.logEvent(eventName, data: data);
  }

  Future<void> logRetention(String eventName) {
    return PostedSdkPlatform.instance.logRetention(eventName);
  }
}

// Deprecated backward-compat aliases — remove after one minor release cycle (v2.x → v3.0).

@Deprecated('Use PostedSdk instead. Will be removed in v3.0.')
typedef DetourFlutterPlugin = PostedSdk;

@Deprecated('Use PostedConfig instead. Will be removed in v3.0.')
typedef DetourConfig = PostedConfig;

@Deprecated('Use PostedResult instead. Will be removed in v3.0.')
typedef DetourResult = PostedResult;

@Deprecated('Use PostedLink instead. Will be removed in v3.0.')
typedef DetourLink = PostedLink;

@Deprecated('Use PostedEventName instead. Will be removed in v3.0.')
typedef DetourEventName = PostedEventName;

@Deprecated('Use PostedLinkType instead. Will be removed in v3.0.')
typedef LinkType = PostedLinkType;

@Deprecated('Use PostedLinkProcessingMode instead. Will be removed in v3.0.')
typedef LinkProcessingMode = PostedLinkProcessingMode;

@Deprecated('Use PostedService instead. Will be removed in v3.0.')
typedef DetourService = PostedService;

@Deprecated('Use PostedIntent instead. Will be removed in v3.0.')
typedef DetourIntent = PostedIntent;

@Deprecated('Use PostedIntentSource instead. Will be removed in v3.0.')
typedef DetourIntentSource = PostedIntentSource;

@Deprecated('Use PostedSdkPlatform instead. Will be removed in v3.0.')
typedef DetourFlutterPluginPlatform = PostedSdkPlatform;

@Deprecated('Use MethodChannelPostedSdk instead. Will be removed in v3.0.')
typedef MethodChannelDetourFlutterPlugin = MethodChannelPostedSdk;
