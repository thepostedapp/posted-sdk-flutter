import 'package:detour_flutter_plugin_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('detour_flutter_plugin');
  const eventsChannel = MethodChannel('detour_flutter_plugin/links');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          switch (call.method) {
            case 'configure':
              return null;
            case 'resolveInitialLink':
              return {'processed': true, 'link': null};
            case 'processLink':
              return {'processed': true, 'link': null};
            case 'logEvent':
            case 'logRetention':
              return null;
            default:
              return null;
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventsChannel, null);
  });

  testWidgets('example renders and reaches ready state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Detour Flutter Plugin'), findsOneWidget);
    expect(find.textContaining('Status: Ready'), findsOneWidget);
  });
}
