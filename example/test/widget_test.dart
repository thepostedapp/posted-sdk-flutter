import 'package:posted_sdk_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('posted_sdk');
  const eventsChannel = MethodChannel('posted_sdk/links');

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

    expect(find.text('posted-sdk Flutter Example'), findsOneWidget);
    expect(find.textContaining('Status: Ready'), findsOneWidget);
  });
}
