import 'dart:async';

import 'package:flutter/foundation.dart';

import '../posted_sdk_platform_interface.dart';
import 'models.dart';

/// Origin of a resolved link emitted by [PostedService].
enum PostedIntentSource {
  /// Link resolved from cold-start flow via `resolveInitialLink()`.
  initial,

  /// Link resolved from runtime listener (`linkStream`).
  runtime,

  /// Link resolved from explicit `processLink(url)` call.
  manual,
}

/// A single navigation intent produced by [PostedService].
class PostedIntent {
  const PostedIntent({
    required this.link,
    required this.source,
    required this.receivedAt,
  });

  final PostedLink link;
  final PostedIntentSource source;
  final DateTime receivedAt;

  String get dedupeKey => '${link.type.name}|${link.url.toLowerCase()}';
}

/// High-level orchestration layer for routing-safe posted-sdk integration.
///
/// This service merges initial and runtime results into a single pending
/// intent and exposes readiness state with explicit consume semantics.
class PostedService extends ChangeNotifier {
  PostedService({
    PostedSdkPlatform? platform,
    this.duplicateSuppressionWindow = const Duration(seconds: 2),
  }) : _platform = platform ?? PostedSdkPlatform.instance;

  final PostedSdkPlatform _platform;

  /// Time window used to suppress duplicate initial/runtime emissions for the
  /// same link key (`type|url`).
  final Duration duplicateSuppressionWindow;

  final Map<String, DateTime> _recentEmissions = {};

  StreamSubscription<PostedResult>? _runtimeSubscription;

  bool _started = false;
  bool _isInitialLinkProcessed = false;
  PostedIntent? _pendingIntent;

  bool get isStarted => _started;

  /// `true` after initial resolve flow has completed (with or without link).
  bool get isInitialLinkProcessed => _isInitialLinkProcessed;

  /// Last pending intent waiting to be consumed by the app's navigation layer.
  PostedIntent? get pendingIntent => _pendingIntent;

  /// Starts the SDK flow:
  /// 1. configures native SDK,
  /// 2. subscribes runtime stream,
  /// 3. resolves initial link.
  ///
  /// Safe to call multiple times; only first call starts the service.
  Future<void> start(PostedConfig config) async {
    if (_started) return;

    await _platform.configure(config);
    _started = true;

    _runtimeSubscription = _platform.linkStream.listen((result) {
      _registerResult(result, source: PostedIntentSource.runtime);
    });

    final initial = await _platform.resolveInitialLink();
    _registerResult(initial, source: PostedIntentSource.initial);

    _isInitialLinkProcessed = true;
    notifyListeners();
  }

  /// Processes an arbitrary URL through native SDK and optionally emits
  /// a navigation intent.
  Future<PostedResult> processLink(
    String url, {
    bool emitIntent = true,
  }) async {
    final result = await _platform.processLink(url);
    if (emitIntent) {
      _registerResult(result, source: PostedIntentSource.manual);
    }
    return result;
  }

  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) {
    return _platform.logEvent(eventName, data: data);
  }

  Future<void> logRetention(String eventName) {
    return _platform.logRetention(eventName);
  }

  /// Marks pending intent as consumed.
  void consumePendingIntent() {
    if (_pendingIntent == null) return;
    _pendingIntent = null;
    notifyListeners();
  }

  /// Stops runtime subscription.
  Future<void> stop() async {
    await _runtimeSubscription?.cancel();
    _runtimeSubscription = null;
    _started = false;
    _isInitialLinkProcessed = false;
    _pendingIntent = null;
    _recentEmissions.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _runtimeSubscription?.cancel();
    super.dispose();
  }

  void _registerResult(
    PostedResult result, {
    required PostedIntentSource source,
  }) {
    final link = result.link;
    if (link == null) return;

    final now = DateTime.now();
    _evictExpiredDedupeEntries(now);

    final intent = PostedIntent(link: link, source: source, receivedAt: now);

    final previous = _recentEmissions[intent.dedupeKey];
    if (previous != null &&
        now.difference(previous) <= duplicateSuppressionWindow) {
      return;
    }

    _recentEmissions[intent.dedupeKey] = now;
    _pendingIntent = intent;
    notifyListeners();
  }

  void _evictExpiredDedupeEntries(DateTime now) {
    if (_recentEmissions.isEmpty) return;

    final toRemove = <String>[];
    _recentEmissions.forEach((key, timestamp) {
      if (now.difference(timestamp) > duplicateSuppressionWindow) {
        toRemove.add(key);
      }
    });

    for (final key in toRemove) {
      _recentEmissions.remove(key);
    }
  }
}
