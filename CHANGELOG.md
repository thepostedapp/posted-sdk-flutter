## 3.0.0

First public release under the `posted_sdk` / Posted brand.

* **Breaking:** Removed the deprecated `Detour*` type-alias / re-export shims and the un-prefixed `LinkType` / `LinkProcessingMode` aliases introduced in 2.0.0. These lived for one minor cycle; code must now use the `Posted*` names (`PostedSdk`, `PostedService`, `PostedConfig`, `PostedResult`, `PostedLink`, `PostedIntent`, `PostedIntentSource`, `PostedEventName`, `PostedLinkType`, `PostedLinkProcessingMode`, `PostedSdkPlatform`, `MethodChannelPostedSdk`). See the migration table in the README.
* X-SDK marker header bumped to `flutter/3.0.0`.
* Rebranded package metadata to Posted domains: `homepage` → `https://posted.app`, `repository`/`issue_tracker` → `github.com/thepostedapp/posted-sdk-flutter`, podspec contact → `yuriy@postedapp.com`. Replaced legacy `godetour.*` domains with `posted.app` / `posted.link` across the example app, docs, and sample keys (`POSTED_API_KEY` / `POSTED_APP_ID`).
* Example app now registers the `posted://` custom URL scheme (Android intent-filter + iOS `Info.plist`), with host-app registration documented in the example README.

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
