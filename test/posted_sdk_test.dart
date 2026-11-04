import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';
import 'package:posted_sdk/posted_sdk_noop.dart';
import 'package:posted_sdk/posted_sdk_platform_interface.dart';

const _config = PostedConfig(apiKey: 'api-key', appID: 'app-id');

class _RecordingPlatform extends PostedSdkPlatform
    with MockPlatformInterfaceMixin {
  final configs = <PostedConfig>[];
  Object? throwOnReport;

  @override
  Future<void> reportInstall(PostedConfig config) async {
    configs.add(config);
    if (throwOnReport != null) throw throwOnReport!;
  }
}

void main() {
  final initialPlatform = PostedSdkPlatform.instance;

  tearDown(() {
    PostedSdkPlatform.instance = initialPlatform;
  });

  test('default platform instance is the method channel or the no-op', () {
    expect(
      initialPlatform,
      anyOf(isA<MethodChannelPostedSdk>(), isA<NoopPostedSdk>()),
    );
  });

  test('reportInstall forwards the config to the platform', () async {
    final platform = _RecordingPlatform();
    PostedSdkPlatform.instance = platform;

    await Posted.reportInstall(_config);

    expect(platform.configs.single.apiKey, 'api-key');
    expect(platform.configs.single.appID, 'app-id');
  });

  test('reportInstall never throws', () async {
    final platform = _RecordingPlatform()..throwOnReport = StateError('boom');
    PostedSdkPlatform.instance = platform;

    await expectLater(Posted.reportInstall(_config), completes);
  });

  test('no-op platform completes without a native call', () async {
    PostedSdkPlatform.instance = NoopPostedSdk();

    await expectLater(Posted.reportInstall(_config), completes);
  });
}
