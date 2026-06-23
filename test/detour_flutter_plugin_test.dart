import 'package:detour_flutter_plugin/detour_flutter_plugin.dart';
import 'package:detour_flutter_plugin/detour_flutter_plugin_method_channel.dart';
import 'package:detour_flutter_plugin/detour_flutter_plugin_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDetourFlutterPluginPlatform
    with MockPlatformInterfaceMixin
    implements DetourFlutterPluginPlatform {
  DetourConfig? configuredWith;
  DetourEventName? loggedEventName;
  Map<String, dynamic>? loggedEventData;
  String? retentionEvent;

  @override
  Future<void> configure(DetourConfig config) async {
    configuredWith = config;
  }

  @override
  Stream<DetourResult> get linkStream => const Stream<DetourResult>.empty();

  @override
  Future<void> logEvent(
    DetourEventName eventName, {
    Map<String, dynamic>? data,
  }) async {
    loggedEventName = eventName;
    loggedEventData = data;
  }

  @override
  Future<void> logRetention(String eventName) async {
    retentionEvent = eventName;
  }

  @override
  Future<DetourResult> processLink(String url) async {
    return const DetourResult(processed: true, link: null);
  }

  @override
  Future<DetourResult> resolveInitialLink() async {
    return const DetourResult(processed: true, link: null);
  }
}

void main() {
  final initialPlatform = DetourFlutterPluginPlatform.instance;

  tearDown(() {
    DetourFlutterPluginPlatform.instance = initialPlatform;
  });

  test('MethodChannelDetourFlutterPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDetourFlutterPlugin>());
  });

  test('logEvent forwards typed enum to platform implementation', () async {
    final plugin = DetourFlutterPlugin();
    final fakePlatform = MockDetourFlutterPluginPlatform();
    DetourFlutterPluginPlatform.instance = fakePlatform;

    await plugin.logEvent(
      DetourEventName.purchase,
      data: {'currency': 'USD', 'value': 12.5},
    );

    expect(fakePlatform.loggedEventName, DetourEventName.purchase);
    expect(fakePlatform.loggedEventData?['currency'], 'USD');
  });
}
