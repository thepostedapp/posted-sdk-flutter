## 3.0.0

First public release under the `posted_sdk` / Posted brand, and the **attribution-first reshape** of
the public API: the primary entry point is now `configure` + `resolveAppLaunch` (+ optional
`logEvent`/`logRetention`). See [Migrating from 2.x to 3.0](./README.md#migrating-from-2x-to-30) for
upgrade steps.

### Added

* **`resolveAppLaunch(PostedConfig config)`** on `PostedSdk` — single unified cold-start attribution
  entry point; replaces `resolveInitialLink()`. Takes `config` directly, so no prior `configure()`
  call is required. **Fire-once per install:** the result is cached after the first successful call
  and returned on every subsequent call; the native layer persists the fire-once flag and cached
  result across app updates, and only a reinstall or an explicit `resetSession()` call re-arms it.
  Returns the same `PostedResult` as before — no result-shape change.
* `resetSession()` on `PostedSdk` — re-arms the fire-once cache so the next `resolveAppLaunch` call
  performs a fresh resolution.
* Example app now registers the `posted://` custom URL scheme (Android intent-filter + iOS
  `Info.plist`), with host-app registration documented in the example README.

### Changed

* X-SDK marker header bumped to `flutter/3.0.0`.
* Rebranded package metadata to Posted domains: `homepage` → `https://posted.app`, `repository`/`issue_tracker` → `github.com/thepostedapp/posted-sdk-flutter`, podspec contact → `yuriy@postedapp.com`. Replaced legacy `godetour.*` domains with `posted.app` / `posted.link` across the example app, docs, and sample keys (`POSTED_API_KEY` / `POSTED_APP_ID`).
* One-shot match-link resolution (clickId/fingerprint → `{link}`) is unchanged — this release
  reshapes the client-side entry point only; there is no contract or backend change.

### Deprecated

* `resolveInitialLink()` on `PostedSdk` → use `resolveAppLaunch(config)` instead. Now forwards
  internally into `resolveAppLaunch`; still throws `StateError` if called before `configure()`. Kept
  as a shim for one release cycle, **removed in the next major (4.0)**.
* `processLink(String url)` on `PostedSdk` → use `resolveAppLaunch(config)` for cold-start
  attribution instead. Kept as a shim for one release cycle, **removed in the next major (4.0)**.
  (Does not affect `PostedService.processLink(url)`, a distinct, still-supported method for handling
  an arbitrary runtime URL.)

### Removed

* **Breaking:** the deprecated `Detour*` type-alias / re-export shims and the un-prefixed `LinkType` / `LinkProcessingMode` aliases introduced in 2.0.0. These lived for one minor cycle; code must now use the `Posted*` names (`PostedSdk`, `PostedService`, `PostedConfig`, `PostedResult`, `PostedLink`, `PostedIntent`, `PostedIntentSource`, `PostedEventName`, `PostedLinkType`, `PostedLinkProcessingMode`, `PostedSdkPlatform`, `MethodChannelPostedSdk`). See the migration table in the README.
* No `PostedSdk` methods were hard-removed from the public surface in this release — `resolveInitialLink()`
  and `processLink()` move out of the recommended attribution-first surface into the deprecated shims
  above and are scheduled for outright removal in 4.0.

## 2.0.0

* **Breaking:** Package renamed from `detour_flutter_plugin` to `posted_sdk`.
* **Breaking:** All public Dart symbols renamed with `Posted` prefix (`DetourFlutterPlugin` → `PostedSdk`, `DetourService` → `PostedService`, `DetourConfig` → `PostedConfig`, `DetourResult` → `PostedResult`, `DetourLink` → `PostedLink`, `DetourEventName` → `PostedEventName`, `LinkType` → `PostedLinkType`, `LinkProcessingMode` → `PostedLinkProcessingMode`, etc.).
* **Breaking:** Method channel renamed from `detour_flutter_plugin` to `posted_sdk`; event channel from `detour_flutter_plugin/links` to `posted_sdk/links`.
* **Breaking:** Native pluginClass renamed to `PostedFlutterPlugin` on both iOS and Android.
* **Breaking:** Android package renamed from `com.swmansion.detour` to `com.postedapp.posted`.
* **Breaking:** iOS/Android Flutter marker class renamed from `DetourFlutterMarker` to `PostedFlutterMarker`.
* Deprecated type-alias shims provided for all renamed public symbols — will be removed in v3.0.

## 1.2.0

* Improve universal link analytics.
* Update native SDK requirements to Android `1.1.0` and iOS `1.1.0`.

## 1.1.1

* Override native `X-SDK` header to `flutter/<plugin-version>` when requests are made via the Flutter wrapper.
* Update native SDK requirements to Android `1.0.1` and iOS `1.0.2`.

## 1.1.0

* iOS native SDK is now consumed via CocoaPods (`Detour ~> 1.0.1`) instead of bundled source files.
* Remove embedded iOS SDK sources (`ios/Sources/Detour/`).
* Improve example app with configurable placeholders and setup documentation.

## 1.0.1

* Fix Android Maven dependency coordinates to `com.swmansion.detour:detour-sdk`.

## 1.0.0

* Refactor plugin into a thin bridge over native Detour SDKs.
* Android now consumes `com.swmansion.detour:detour-sdk` instead of embedded native implementation.
* iOS now consumes `Detour` CocoaPod instead of embedded native implementation.
* Remove Flutter API methods without 1:1 native equivalent: `mountAnalytics`, `unmountAnalytics`, `resetSession`.
* `logEvent` now accepts only predefined `DetourEventName` values.
* Refresh unit/integration/example tests to match the current API.
* Add `DetourService` helper for routing-safe integration (`resolveInitialLink` + `linkStream` merge, consume semantics, short duplicate suppression window).
