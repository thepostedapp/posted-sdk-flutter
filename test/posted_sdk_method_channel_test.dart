import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelPostedSdk();
  const channel = MethodChannel('posted_sdk');

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          calls.add(methodCall);
          switch (methodCall.method) {
            case 'resolveInitialLink':
              return {
                'processed': true,
                'link': {
                  'url': 'https://detour.dev/promo?campaign=spring',
                  'route': '/promo?campaign=spring',
                  'pathname': '/promo',
                  'params': {'campaign': 'spring'},
                  'type': 'verified',
                },
              };
            case 'processLink':
              return {'processed': true, 'link': null};
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('configure sends expected payload', () async {
    await platform.configure(
      const PostedConfig(
        apiKey: 'api-key',
        appID: 'app-id',
        shouldUseClipboard: false,
        linkProcessingMode: PostedLinkProcessingMode.webOnly,
      ),
    );

    expect(calls, hasLength(1));
    expect(calls.first.method, 'configure');
    expect(calls.first.arguments, {
      'apiKey': 'api-key',
      'appID': 'app-id',
      'shouldUseClipboard': false,
      'linkProcessingMode': 'web-only',
    });
  });

  test('resolveInitialLink maps native payload into PostedResult', () async {
    final result = await platform.resolveInitialLink();

    expect(result.processed, true);
    expect(result.link, isNotNull);
    expect(result.link?.route, '/promo?campaign=spring');
    expect(result.link?.pathname, '/promo');
    expect(result.link?.params['campaign'], 'spring');
    expect(result.link?.type, PostedLinkType.verified);
  });

  test('logEvent sends enum raw value', () async {
    await platform.logEvent(
      PostedEventName.addToCart,
      data: {'sku': 'ABC-123'},
    );

    expect(calls, hasLength(1));
    expect(calls.first.method, 'logEvent');
    expect(calls.first.arguments, {
      'eventName': 'add_to_cart',
      'data': {'sku': 'ABC-123'},
    });
  });

  test('logRetention forwards custom retention name', () async {
    await platform.logRetention('home_screen_viewed');

    expect(calls, hasLength(1));
    expect(calls.first.method, 'logRetention');
    expect(calls.first.arguments, {'eventName': 'home_screen_viewed'});
  });

  test('processLink sends url without mutation', () async {
    final result = await platform.processLink(
      'https://godetour.dev/u/launch?campaign=spring',
    );

    expect(calls, hasLength(1));
    expect(calls.first.method, 'processLink');
    expect(calls.first.arguments, {
      'url': 'https://godetour.dev/u/launch?campaign=spring',
    });
    expect(result.processed, true);
    expect(result.link, isNull);
  });

  test('logEvent with null data passes null in data field', () async {
    await platform.logEvent(PostedEventName.login);

    expect(calls, hasLength(1));
    expect(calls.first.method, 'logEvent');
    expect(calls.first.arguments, {'eventName': 'login', 'data': null});
  });
}
