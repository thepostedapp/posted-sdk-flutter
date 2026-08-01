import 'package:flutter/foundation.dart';

import 'src/models.dart';
import 'posted_sdk_platform_interface.dart';

export 'src/models.dart';
export 'src/posted_service.dart';

class PostedSdk {
  PostedResult? _cachedLaunchResult;
  Future<PostedResult>? _inFlightResolution;
  PostedConfig? _config;

  /// Debug/test-only observability: incremented each time a caller reuses an
  /// in-flight resolution instead of starting a new one. Lets a regression
  /// that reintroduces a second platform call surface as a test failure
  /// instead of failing silently. Cross-platform parity with iOS's
  /// `PostedLogger.debug` "de-dup, awaiting in-flight resolution" signal
  /// (POS-246). Not part of the public SDK contract.
  @visibleForTesting
  int debugCoalescedResolutionCount = 0;

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
  ///
  /// In-flight single-flight de-dup: if several callers invoke this method
  /// concurrently on first launch — before the resolution has completed and the
  /// fire-once cache is populated — they all await the *same* in-flight
  /// resolution, so exactly one platform/network call is made and every caller
  /// receives an identical result.
  Future<PostedResult> resolveAppLaunch(PostedConfig config) async {
    _config = config;
    // Fire-once cache: subsequent calls in-session return the cached result.
    final cached = _cachedLaunchResult;
    if (cached != null) {
      return cached;
    }
    // Single-flight de-dup: reuse an already-running resolution. The check and
    // the store below run with no `await` between them, so racing callers
    // cannot both pass the null-check and start a second resolution.
    final inFlight = _inFlightResolution;
    if (inFlight != null) {
      if (kDebugMode) {
        debugCoalescedResolutionCount++;
        debugPrint(
          'posted-sdk: resolveAppLaunch de-dup — awaiting in-flight '
          'resolution instead of starting a new one.',
        );
      }
      return inFlight;
    }
    final resolution = _resolveOnce(config);
    _inFlightResolution = resolution;
    return resolution;
  }

  /// Performs a single resolution, populating the fire-once cache on success and
  /// always clearing the in-flight handle so a failed resolution re-arms rather
  /// than being cached permanently.
  Future<PostedResult> _resolveOnce(PostedConfig config) async {
    try {
      final result = await PostedSdkPlatform.instance.resolveAppLaunch(config);
      _cachedLaunchResult = result;
      return result;
    } finally {
      _inFlightResolution = null;
    }
  }

  /// Re-arms fire-once: clears the Dart-session cache and calls native
  /// resetSession so the next [resolveAppLaunch] performs a fresh resolution.
  Future<void> resetSession() async {
    _cachedLaunchResult = null;
    _inFlightResolution = null;
    await PostedSdkPlatform.instance.resetSession();
  }

  /// Resolves the initial attribution link. **Deprecated** — use
  /// [resolveAppLaunch] instead.
  ///
  /// **Ordering requirement:** [configure] must be called before this method.
  /// Calling without a prior [configure] throws a [StateError] in all build
  /// modes (debug and release). In release builds Dart strips `assert`
  /// statements, so this method uses an explicit guard — callers get an
  /// actionable error message rather than a bare null-check crash.
  ///
  /// Migration:
  /// ```dart
  /// // Before (deprecated — configure() required separately)
  /// await sdk.configure(config);
  /// final result = await sdk.resolveInitialLink();
  ///
  /// // After — config is passed directly, no prior configure() needed
  /// final result = await sdk.resolveAppLaunch(config);
  /// ```
  @Deprecated(
    'Use resolveAppLaunch(config) instead. resolveInitialLink() will be '
    'removed in the next major release.',
  )
  Future<PostedResult> resolveInitialLink() {
    debugPrint(
      'posted-sdk: resolveInitialLink() is deprecated. '
      'Use resolveAppLaunch(config) instead.',
    );
    if (_config == null) {
      throw StateError(
        'posted-sdk: configure() must be called before resolveInitialLink(). '
        'Migrate to resolveAppLaunch(config) to avoid this requirement.',
      );
    }
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
