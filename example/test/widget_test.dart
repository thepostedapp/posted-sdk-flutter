import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posted_sdk_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('posted_sdk');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  testWidgets('example reports the install on launch', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('posted_sdk Example'), findsOneWidget);
    expect(find.textContaining('Install report finished'), findsOneWidget);
    expect(calls.map((c) => c.method), ['reportInstall']);
  });
}
