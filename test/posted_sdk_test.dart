import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';
import 'package:posted_sdk/posted_sdk_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class MockPostedSdkPlatform
    with MockPlatformInterfaceMixin
    implements PostedSdkPlatform {
  PostedConfig? configuredWith;
  PostedEventName? loggedEventName;
  Map<String, dynamic>? loggedEventData;
  String? retentionEvent;

  @override
  Future<void> configure(PostedConfig config) async {
    configuredWith = config;
  }

  @override
  Stream<PostedResult> get linkStream => const Stream<PostedResult>.empty();

  @override
  Future<void> logEvent(
    PostedEventName eventName, {
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
  Future<PostedResult> processLink(String url) async {
    return const PostedResult(processed: true, link: null);
  }

  @override
  Future<PostedResult> resolveInitialLink() async {
    return const PostedResult(processed: true, link: null);
  }
}

void main() {
  final initialPlatform = PostedSdkPlatform.instance;

  tearDown(() {
    PostedSdkPlatform.instance = initialPlatform;
  });

  test('MethodChannelPostedSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPostedSdk>());
  });

  test('logEvent forwards typed enum to platform implementation', () async {
    final plugin = PostedSdk();
    final fakePlatform = MockPostedSdkPlatform();
    PostedSdkPlatform.instance = fakePlatform;

    await plugin.logEvent(
      PostedEventName.purchase,
      data: {'currency': 'USD', 'value': 12.5},
    );

    expect(fakePlatform.loggedEventName, PostedEventName.purchase);
    expect(fakePlatform.loggedEventData?['currency'], 'USD');
  });
}
