# posted_sdk

Flutter plugin for mobile attribution and deferred deep linking. `posted_sdk` wraps the native Detour SDKs for Android and iOS, giving Flutter apps access to deferred deep links that survive the Play Store or App Store install flow, along with Universal/App Links and custom scheme links in a single unified API.

## Installation

### Package

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  posted_sdk: ^2.0.0
```

Then run `flutter pub get`.

### Native SDK dependencies

This plugin uses native Detour SDK implementations:

- Android: `com.swmansion.detour:detour-sdk:1.1.0`
- iOS: `Detour` CocoaPod `~> 1.1.0` (pulled automatically via the plugin podspec)

#### Android

Make sure your Android repositories can resolve `com.swmansion.detour:detour-sdk` (for example via `google()` and `mavenCentral()` in your project repositories block).

#### iOS

The native iOS SDK is resolved automatically as a CocoaPods dependency. Just run:

```sh
cd ios && pod install && cd ..
```

### Requirements

- Dart: `^3.11.1`
- Flutter: `>=3.3.0`
- Android: min SDK 24
- iOS: 13.0+

## Usage

### Recommended: `PostedService`

`PostedService` is the recommended integration layer. It extends `ChangeNotifier` and merges initial and runtime link handling into a single pending intent with explicit consume semantics.

<details>
<summary>PostedService example</summary>

```dart
import 'package:posted_sdk/posted_sdk.dart';

final posted = PostedService();

@override
void initState() {
  super.initState();
  posted.addListener(_onPostedChanged);
  _startPosted();
}

Future<void> _startPosted() async {
  await posted.start(
    const PostedConfig(
      apiKey: '<REPLACE_WITH_YOUR_API_KEY>',
      appID: '<REPLACE_WITH_APP_ID_FROM_PLATFORM>',
    ),
  );
}

void _onPostedChanged() {
  final intent = posted.pendingIntent;
  if (intent == null) return;

  // Navigate once, then mark as consumed.
  // context.go(intent.link.route);
  posted.consumePendingIntent();
}

@override
void dispose() {
  posted.removeListener(_onPostedChanged);
  posted.dispose();
  super.dispose();
}
```

</details>

### Low-level API: `PostedSdk`

For full manual control, use `PostedSdk` directly:

<details>
<summary>PostedSdk example</summary>

```dart
import 'package:posted_sdk/posted_sdk.dart';

final sdk = PostedSdk();

final initial = await sdk.resolveAppLaunch(
  const PostedConfig(
    apiKey: '<REPLACE_WITH_YOUR_API_KEY>',
    appID: '<REPLACE_WITH_APP_ID_FROM_PLATFORM>',
  ),
);
final stream = sdk.linkStream;
```

</details>

### Link processing mode

Use `linkProcessingMode` to control which link sources the SDK handles:

| Value                                    | Universal/App links | Deferred links | Custom scheme links |
| ---------------------------------------- | ------------------- | -------------- | ------------------- |
| `PostedLinkProcessingMode.all` (default) | ✅                  | ✅             | ✅                  |
| `PostedLinkProcessingMode.webOnly`       | ✅                  | ✅             | ❌                  |
| `PostedLinkProcessingMode.deferredOnly`  | ❌                  | ✅             | ❌                  |

### Custom scheme runtime links

Custom scheme links require `linkProcessingMode: PostedLinkProcessingMode.all` and native registration on each platform.

<details>
<summary>Native registration</summary>

Android (`AndroidManifest.xml`):

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="myapp" />
</intent-filter>
```

iOS (`Info.plist`):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

Test commands:

```sh
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "myapp://products/42?source=scheme" \
  <your.package.name>

# iOS Simulator
xcrun simctl openurl booted "myapp://products/42?source=scheme"
```

</details>

## Analytics

<details>
<summary>Analytics example</summary>

```dart
await posted.logEvent(
  PostedEventName.purchase,
  data: {'value': 9.99, 'currency': 'USD'},
);

await posted.logRetention('week_1');
```

</details>

## Types

### `PostedConfig`

<details>
<summary>PostedConfig</summary>

```dart
class PostedConfig {
  final String apiKey;
  final String appID;
  final bool shouldUseClipboard;                   // default: true
  final PostedLinkProcessingMode linkProcessingMode; // default: PostedLinkProcessingMode.all
}
```

</details>

### `PostedIntent`

<details>
<summary>PostedIntent</summary>

```dart
class PostedIntent {
  final PostedLink link;
  final PostedIntentSource source;  // initial, runtime, or manual
  final DateTime receivedAt;
}

enum PostedIntentSource { initial, runtime, manual }
```

</details>

### `PostedResult`

<details>
<summary>PostedResult</summary>

```dart
class PostedResult {
  final bool processed;
  final PostedLink? link;
}
```

</details>

### `PostedLink`

<details>
<summary>PostedLink</summary>

```dart
class PostedLink {
  final String url;
  final String route;
  final String pathname;
  final Map<String, String> params;
  final PostedLinkType type;  // deferred, verified, or scheme
}
```

</details>

### `PostedEventName`

<details>
<summary>PostedEventName</summary>

```dart
enum PostedEventName {
  login, search, share, signUp, tutorialBegin, tutorialComplete,
  reEngage, invite, openedFromPushNotification, addPaymentInfo,
  addShippingInfo, addToCart, removeFromCart, refund, viewItem,
  beginCheckout, purchase, adImpression,
}
```

</details>

## API Reference

### `PostedService`

High-level integration helper (extends `ChangeNotifier`):

- `Future<void> start(PostedConfig config)`
- `bool get isStarted`
- `bool get isInitialLinkProcessed`
- `PostedIntent? get pendingIntent`
- `void consumePendingIntent()`
- `Future<PostedResult> processLink(String url, {bool emitIntent = true})`
- `Future<void> logEvent(PostedEventName eventName, {Map<String, dynamic>? data})`
- `Future<void> logRetention(String eventName)`
- `Future<void> stop()`

### `PostedSdk`

Low-level bridge API:

- `Future<PostedResult> resolveAppLaunch(PostedConfig config)` — preferred entry point; fire-once, result cached
- `Future<void> configure(PostedConfig config)` — sets config without resolving; use when you need to call deprecated shims
- `Future<PostedResult> resolveInitialLink()` *(deprecated — use `resolveAppLaunch(config)` instead; requires `configure()` to be called first or throws `StateError`)*
- `Future<PostedResult> processLink(String url)` *(deprecated — use `resolveAppLaunch(config)` instead)*
- `Stream<PostedResult> get linkStream`
- `Future<void> resetSession()` — re-arms fire-once for the next `resolveAppLaunch` call
- `Future<void> logEvent(PostedEventName eventName, {Map<String, dynamic>? data})`
- `Future<void> logRetention(String eventName)`

## Example

A complete integration example covering deferred links, Universal/App Links, and custom scheme links is in [`example/`](./example). See the [example setup guide](./example/README.md) for step-by-step instructions.

## Migration from `detour_flutter_plugin`

`detour_flutter_plugin` v1.x has been superseded by `posted_sdk` v2.0.0. The 2.0.0 release is a pure rebrand — no behavioral or API-shape changes — so the upgrade is mechanical. See the [`CHANGELOG`](./CHANGELOG.md) for the full list of breaking changes.

### 1. Package name

Update the dependency in your `pubspec.yaml` and your imports:

```yaml
dependencies:
  posted_sdk: ^2.0.0   # was: detour_flutter_plugin
```

```dart
import 'package:posted_sdk/posted_sdk.dart';   // was: package:detour_flutter_plugin/detour_flutter_plugin.dart
```

### 2. Public symbols

All `Detour*` names have `Posted*` equivalents. The old names remain available as deprecated typedef/re-export shims for one minor cycle and are **removed in v3.0.0** — existing code compiles with a deprecation warning until then, so you can migrate incrementally:

| v1 (deprecated, removed in 3.0.0) | v2 |
| --- | --- |
| `DetourService` | `PostedService` |
| `DetourFlutterPlugin` | `PostedSdk` |
| `DetourConfig` | `PostedConfig` |
| `DetourResult` | `PostedResult` |
| `DetourLink` | `PostedLink` |
| `DetourIntent` | `PostedIntent` |
| `DetourIntentSource` | `PostedIntentSource` |
| `DetourEventName` | `PostedEventName` |
| `LinkType` | `PostedLinkType` |
| `LinkProcessingMode` | `PostedLinkProcessingMode` |

### 3. Platform channels

The underlying method and event channel names were renamed. This is internal to the plugin and requires no change for consumers of the Dart API, but is relevant if you have custom platform code, mocks, or tests that reference the channels directly:

| v1 | v2 |
| --- | --- |
| method channel `detour_flutter_plugin` | `posted_sdk` |
| event channel `detour_flutter_plugin/links` | `posted_sdk/links` |

The native `pluginClass` (`PostedFlutterPlugin`), the Android package (`com.postedapp.posted`), and the Flutter marker class (`PostedFlutterMarker`) were also renamed as part of the rebrand; these are internal and do not affect Flutter app code.

---

## License

This library is licensed under [The MIT License](./LICENSE).
