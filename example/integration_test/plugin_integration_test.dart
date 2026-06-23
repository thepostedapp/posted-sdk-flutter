import 'package:detour_flutter_plugin/detour_flutter_plugin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('detour_flutter_plugin');

  testWidgets('configure + resolveInitialLink bridge contract', (
    WidgetTester _,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'configure':
              return null;
            case 'resolveInitialLink':
              return {'processed': true, 'link': null};
            default:
              return null;
          }
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final plugin = DetourFlutterPlugin();
    await plugin.configure(
      const DetourConfig(apiKey: 'api-key', appID: 'app-id'),
    );

    final result = await plugin.resolveInitialLink();
    expect(result.processed, true);
    expect(result.link, isNull);
  });
}
