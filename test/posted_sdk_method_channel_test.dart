import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelPostedSdk();
  const channel = MethodChannel('posted_sdk');

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reportInstall invokes the native method with apiKey and appID',
      () async {
    await platform.reportInstall(
      const PostedConfig(apiKey: 'api-key', appID: 'app-id'),
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'reportInstall');
    expect(calls.single.arguments, {'apiKey': 'api-key', 'appID': 'app-id'});
  });

  test('reportInstall surfaces a native error to the caller', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'INVALID_ARGS');
    });

    await expectLater(
      platform.reportInstall(const PostedConfig(apiKey: '', appID: '')),
      throwsA(isA<PlatformException>()),
    );
  });
}
