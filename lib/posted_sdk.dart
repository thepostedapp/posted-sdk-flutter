import 'package:flutter/foundation.dart';

import 'src/models.dart';
import 'posted_sdk_platform_interface.dart';

export 'src/models.dart';
export 'src/posted_service.dart';

/// Methods whose deprecation notice has already fired this session. Shared
/// across all [PostedSdk] instances, mirroring the RN `deprecatedShims.ts`
/// module-level de-dup (POS-177).
final Set<String> _warnedDeprecations = <String>{};

/// Prints [message] via [debugPrint] at most once per session for a given
/// [method] key.
void _warnOnce(String method, String message) {
  if (_warnedDeprecations.add(method)) {
    debugPrint(message);
  }
}

/// Test-only re-arm hook: clears the once-per-session de-dup state so a test
/// can re-exercise a deprecation warning. Not part of the public plugin API.
@visibleForTesting
void resetDeprecationWarningsForTest() {
  _warnedDeprecations.clear();
}

class PostedSdk {
  PostedResult? _cachedLaunchResult;
  Future<PostedResult>? _inFlightResolution;
  PostedConfig? _config;

  /// Bumped by [resetSession]. A resolution in flight when a reset happens
  /// captures the generation it started under; if that generation no longer
  /// matches [_generation] by the time it completes, its result is stale and
  /// must not be written back into the cache or in-flight handle (POS-459 /
  /// POS-537, mirroring the Android POS-181 pending-reset design).
  int _generation = 0;

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
    final generation = _generation;
    final resolution = _resolveOnce(config, generation);
    _inFlightResolution = resolution;
    return resolution;
  }

  /// Performs a single resolution, populating the fire-once cache on success and
  /// always clearing the in-flight handle so a failed resolution re-arms rather
  /// than being cached permanently.
  ///
  /// [generation] is the session generation this resolution started under. A
  /// [resetSession] call that lands while the platform call is still pending
  /// bumps [_generation] without waiting for it, so on completion this only
  /// writes the cache / clears the in-flight handle if the generation is
  /// still current — otherwise the result is stale and is returned to the
  /// original caller but discarded from shared state (POS-537).
  Future<PostedResult> _resolveOnce(PostedConfig config, int generation) async {
    try {
      final result = await PostedSdkPlatform.instance.resolveAppLaunch(config);
      if (generation == _generation) {
        _cachedLaunchResult = result;
      }
      return result;
    } finally {
      if (generation == _generation) {
        _inFlightResolution = null;
      }
    }
  }

  /// Re-arms fire-once: clears the Dart-session cache, bumps the session
  /// generation so a resolution already in flight cannot re-poison the cache
  /// with a stale result once it completes, and calls native resetSession so
  /// the next [resolveAppLaunch] performs a fresh resolution.
  Future<void> resetSession() async {
    _generation++;
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
    'removed in 4.0.0.',
  )
  Future<PostedResult> resolveInitialLink() {
    _warnOnce(
      'resolveInitialLink',
      '[Posted] resolveInitialLink() is deprecated and will be removed in '
          '4.0.0. Use resolveAppLaunch() instead.',
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
    'removed in 4.0.0.',
  )
  Future<PostedResult> processLink(String url) {
    _warnOnce(
      'processLink',
      '[Posted] processLink() is deprecated and will be removed in 4.0.0. '
          'Use resolveAppLaunch() instead.',
    );
    return PostedSdkPlatform.instance.processLink(url);
  }

  /// Canonical continuous-event payload: emits a [PostedResult] for every
  /// runtime link event, with [PostedResult.link] — when non-null — carrying
  /// the fully parsed [PostedLink] (`url`/`route`/`pathname`/`params`/`type`).
  /// `link` is null only when the event has nothing attributable (e.g. a
  /// plain app open). This is the reference shape for continuous deep-link
  /// delivery across Detour's platform SDKs.
  ///
  /// See POS-503 for the cross-platform canonical continuous-event contract,
  /// POS-504 for the React Native child (the platform that hoists `url`
  /// instead of nesting [PostedLink]), and POS-502 for the cross-platform
  /// consistency matrix.
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
