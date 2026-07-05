// Back-compat contract test for the deprecated `Detour*` (and un-prefixed
// `LinkType` / `LinkProcessingMode`) aliases introduced by the posted-sdk
// rebrand (POS-48).
//
// These shims exist for exactly one minor cycle (v2.x) and are scheduled for
// removal in v3.0 (POS-85). Until then they are a public back-compat contract:
// consumers still on the old names must keep compiling and get the renamed
// `Posted*` symbols.
//
// This test fails CI if a shim is removed early, re-pointed at the wrong type,
// or if a constructor/enum-value signature drifts out from under the alias:
//   * Removal          -> the file no longer compiles (unresolved identifier).
//   * Re-pointing      -> the runtime `Type`-identity expectations fail.
//   * Signature drift  -> the alias-constructed instances no longer compile.
//
// When the shims are intentionally dropped in v3.0, delete this file as part of
// that change.

// The whole point of this test is to exercise deprecated members.
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:posted_sdk/posted_sdk.dart';
import 'package:posted_sdk/posted_sdk_method_channel.dart';
import 'package:posted_sdk/posted_sdk_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deprecated aliases resolve to renamed Posted* types', () {
    test(
      'each Detour* / legacy alias is the same Type as its Posted* target',
      () {
        // `Type` equality: a re-pointed typedef fails here at runtime. Uses `==`
        // (guaranteed for `Type` objects) rather than `identical`.
        expect(DetourFlutterPlugin, PostedSdk);
        expect(DetourConfig, PostedConfig);
        expect(DetourResult, PostedResult);
        expect(DetourLink, PostedLink);
        expect(DetourEventName, PostedEventName);
        expect(LinkType, PostedLinkType);
        expect(LinkProcessingMode, PostedLinkProcessingMode);
        expect(DetourService, PostedService);
        expect(DetourIntent, PostedIntent);
        expect(DetourIntentSource, PostedIntentSource);
        expect(DetourFlutterPluginPlatform, PostedSdkPlatform);
        expect(MethodChannelDetourFlutterPlugin, MethodChannelPostedSdk);
      },
    );

    test('aliases are mutually assignable with their Posted* targets', () {
      // Compile-time guard: these assignments only type-check if each alias
      // denotes *exactly* the renamed type (subtype relationships are not
      // enough for the reverse direction).
      const PostedConfig posted = PostedConfig(apiKey: 'k', appID: 'a');
      final DetourConfig asAlias = posted;
      final PostedConfig backAgain = asAlias;
      expect(identical(posted, backAgain), isTrue);
    });
  });

  group('instances built through the deprecated aliases', () {
    test('DetourConfig constructor yields a PostedConfig', () {
      final DetourConfig config = DetourConfig(
        apiKey: 'api-key',
        appID: 'app-id',
        shouldUseClipboard: false,
        linkProcessingMode: LinkProcessingMode.deferredOnly,
      );
      expect(config, isA<PostedConfig>());
      expect(config.apiKey, 'api-key');
      expect(config.linkProcessingMode, PostedLinkProcessingMode.deferredOnly);
    });

    test('DetourLink / DetourResult constructors yield Posted* instances', () {
      final DetourLink link = DetourLink(
        url: 'https://example.com/x',
        route: '/x',
        pathname: 'x',
        params: const {'a': 'b'},
        type: LinkType.deferred,
      );
      expect(link, isA<PostedLink>());
      expect(link.type, PostedLinkType.deferred);

      final DetourResult result = DetourResult(processed: true, link: link);
      expect(result, isA<PostedResult>());
      expect(result.link, same(link));
    });

    test('DetourIntent / DetourIntentSource wire together', () {
      final DetourLink link = DetourLink(
        url: 'https://example.com/y',
        route: '/y',
        pathname: 'y',
        params: const {},
        type: LinkType.verified,
      );
      final DetourIntent intent = DetourIntent(
        link: link,
        source: DetourIntentSource.manual,
        receivedAt: DateTime.utc(2020, 1, 1),
      );
      expect(intent, isA<PostedIntent>());
      expect(intent.source, PostedIntentSource.manual);
    });

    test('DetourService constructor yields a PostedService', () {
      final DetourService service = DetourService();
      addTearDown(service.dispose);
      expect(service, isA<PostedService>());
    });

    test('DetourFlutterPlugin constructor yields a PostedSdk', () {
      final DetourFlutterPlugin plugin = DetourFlutterPlugin();
      expect(plugin, isA<PostedSdk>());
    });

    test('MethodChannelDetourFlutterPlugin is a PostedSdkPlatform', () {
      final DetourFlutterPluginPlatform platform =
          MethodChannelDetourFlutterPlugin();
      expect(platform, isA<PostedSdkPlatform>());
      expect(platform, isA<MethodChannelPostedSdk>());
    });
  });

  group('enum values are reachable and identical through the aliases', () {
    test('DetourEventName values match PostedEventName', () {
      // Enum values are canonical singletons, so identity holds here.
      expect(DetourEventName.purchase, same(PostedEventName.purchase));
      expect(DetourEventName.purchase.rawValue, 'purchase');
      expect(DetourEventName.values, PostedEventName.values);
    });

    test('LinkType values match PostedLinkType', () {
      expect(LinkType.deferred, same(PostedLinkType.deferred));
      expect(LinkType.values, PostedLinkType.values);
    });

    test('LinkProcessingMode values and .value getter match', () {
      expect(
        LinkProcessingMode.webOnly,
        same(PostedLinkProcessingMode.webOnly),
      );
      expect(LinkProcessingMode.webOnly.value, 'web-only');
      expect(LinkProcessingMode.values, PostedLinkProcessingMode.values);
    });

    test('DetourIntentSource values match PostedIntentSource', () {
      expect(DetourIntentSource.initial, same(PostedIntentSource.initial));
      expect(DetourIntentSource.values, PostedIntentSource.values);
    });
  });
}
