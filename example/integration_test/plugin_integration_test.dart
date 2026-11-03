import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:posted_sdk/posted_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('posted_sdk');

  testWidgets('reportInstall bridge contract', (WidgetTester _) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await Posted.reportInstall(
      const PostedConfig(apiKey: 'api-key', appID: 'app-id'),
    );

    expect(calls.single.method, 'reportInstall');
    expect(calls.single.arguments, {'apiKey': 'api-key', 'appID': 'app-id'});
  });
}
