# posted_sdk

Flutter plugin for mobile attribution and deferred deep linking. `posted_sdk` wraps the native Posted SDKs for Android and iOS, giving Flutter apps access to deferred deep links that survive the Play Store or App Store install flow, along with Universal/App Links and custom scheme links in a single unified API.

Upgrading from an earlier version? See [Migrating from 2.x to 3.0](#migrating-from-2x-to-30).

## Installation

### Package

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  posted_sdk: ^3.0.0
```

Then run `flutter pub get`.

### Native SDK dependencies

This plugin uses native Posted SDK implementations:

- Android: `com.postedapp:posted-sdk:4.0.0`
- iOS: `Detour` CocoaPod `~> 1.1.0` (pulled automatically via the plugin podspec)

#### Android

Make sure your Android repositories can resolve `com.postedapp:posted-sdk` (for example via `google()` and `mavenCentral()` in your project repositories block).

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

`linkStream` is the SDK's **canonical continuous-event payload**: every event it emits is a
`PostedResult { bool processed; PostedLink? link }`, where `link` — when present — always carries
the fully parsed `url`, `route`, `pathname`, `params`, and `type`. `link` is `null` only when the
event has nothing attributable (e.g. a plain app open). This is the reference shape for continuous
deep-link delivery across Posted's platform SDKs; React Native's continuous-event stream hoists the
same parsed link fields (plus a top-level `url`) onto its event payload rather than nesting a
`PostedLink`, which is a platform-idiomatic wrapper difference, not a divergence in the underlying
data.

See POS-503 for the cross-platform canonical continuous-event contract, POS-504 for the React
Native child issue that hoists `url` onto the payload, and POS-502 for the cross-platform
consistency matrix.

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
- `Stream<PostedResult> get linkStream` — canonical continuous-event payload; every emitted `PostedResult.link` (when non-null) carries the fully parsed `PostedLink` (`url`/`route`/`pathname`/`params`/`type`)
- `Future<void> resetSession()` — re-arms fire-once for the next `resolveAppLaunch` call
- `Future<void> logEvent(PostedEventName eventName, {Map<String, dynamic>? data})`
- `Future<void> logRetention(String eventName)`

### Continuous deep-link stream (cross-platform surface)

The **continuous deep-link stream** delivers every link the app receives while it is running (warm links). It is a **separate feature from fire-once install attribution**: `resolveAppLaunch` resolves the single deferred/deep link responsible for the install exactly once (cached thereafter), whereas the continuous stream is unrelated to attribution and emits on every warm link for the life of the process. Use `resolveAppLaunch` for attribution; use the stream (or the native warm-link path below) for ongoing in-session navigation.

The stream is an idiomatic convenience exposed **only on the JS/Dart wrappers**, which already sit on top of a framework-level URL event bus (React Native `Linking`, Flutter `EventChannel`). Native iOS/Android apps deliver warm links through platform lifecycle hooks instead — this divergence is **intentional, not a gap**.

| Platform | Continuous stream API | Status | Warm-link path |
|----------|----------------------|--------|----------------|
| Flutter (`PostedSdk`) | `Stream<PostedResult> get linkStream` | ✅ present, non-deprecated (EventChannel-backed) | via `linkStream` |
| React Native (`Posted`) | `addEventListener("url", listener) → PostedUrlSubscription` | ✅ present, non-deprecated (mirrors RN core `Linking`) | via `addEventListener` |
| Android (`Posted`) | — none (intentional) — | ➖ not offered | `PostedDelegate.onNewIntent(intent)` → `resolveAppLaunch()` |
| iOS (`Posted`) | — none (intentional) — | ➖ not offered | Scene/App URL handling (`scene(_:willConnectTo:)`, `openURL`, `continueUserActivity`) → `resolveAppLaunch()` |

**Fire-once vs continuous** — `resolveAppLaunch` fires once per install and returns the attribution result; the continuous stream never participates in attribution and fires on every warm link.

## Example

A complete integration example covering deferred links, Universal/App Links, and custom scheme links is in [`example/`](./example). See the [example setup guide](./example/README.md) for step-by-step instructions.

## Migrating from 2.x to 3.0

`posted_sdk` 3.0.0 reshapes the public API around a single **attribution-first** entry point.
Previously, cold-start attribution required a `configure()` call followed by `resolveInitialLink()`
(or the runtime-only `processLink(url)`); now a single `resolveAppLaunch(config)` call on `PostedSdk`
configures the SDK and resolves the launch attribution in one step. `PostedService.start(config)`
already gives you this and needs no changes.

| Old (2.x)                    | New (3.0)                    | Notes                                     |
| ----------------------------- | ----------------------------- | ------------------------------------------ |
| `configure(config)` + `resolveInitialLink()` | `resolveAppLaunch(config)` | Single call; no separate `configure()` needed. See [§1](#1-resolveinitiallink--resolveapplaunchconfig). |
| `processLink(String url)` *(on `PostedSdk`)* | `resolveAppLaunch(config)` | Deprecated for cold-start attribution only; `PostedService.processLink(url)` is unaffected. See [§2](#2-processlinkstring-url-is-deprecated). |

### 1. `resolveInitialLink()` → `resolveAppLaunch(config)`

```dart
// Before (deprecated)
await sdk.configure(config);
final result = await sdk.resolveInitialLink();

// After
final result = await sdk.resolveAppLaunch(config);
```

`resolveAppLaunch` takes `config` directly — no separate `configure()` call is needed first.

### 2. `processLink(String url)` is deprecated

`PostedSdk.processLink(url)` is deprecated in 3.0.0; use `resolveAppLaunch(config)` for cold-start
attribution instead. This does **not** affect `PostedService.processLink(url)`, which remains fully
supported for handling an arbitrary runtime URL (for example a custom scheme link caught while the
app is already running) — that is a distinct use case from cold-start attribution.

Both `resolveInitialLink()` and `processLink()` are kept as deprecated shims for **one release
cycle** and will be **removed in 4.0** (the next major release).

### 3. No separate `launchContext` parameter on Flutter

Unlike the iOS and Android SDKs, `resolveAppLaunch(config)` on Flutter has no separate
`launchContext` parameter to pass. There is no Dart-side equivalent of native
`AppDelegate`/`SceneDelegate` launch options — the native layer resolves the launch context
internally, so `resolveAppLaunch(config)` is the complete call.

### 4. Fire-once semantics

`resolveAppLaunch` caches its result after the first successful call: the native layer persists the
fire-once flag and the cached result, so the result **survives app updates** — every call after the
first returns the same cached `PostedResult` for a given install. Only a **reinstall**, or an
explicit call to `resetSession()`, re-arms it for a fresh resolution.

---

## License

This library is licensed under [The MIT License](./LICENSE).
