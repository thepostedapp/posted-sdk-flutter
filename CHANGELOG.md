# Changelog

All notable changes to `posted_sdk` are documented here.

## 1.1.1

### Changed

- **`setRevenueCatUserId` is now `Posted.setPurchasesUserId(config, id)`.** Pass
  the RevenueCat or Superwall user ID. The old name is removed.
- Wraps `PostedSDK` 1.1.1 on iOS and `com.postedapp:posted-sdk` 4.1.1 on Android.

## 1.1.0

### Added

- **`Posted.setRevenueCatUserId(config, id)`** — links the RevenueCat app user
  ID to the install, so purchases can be attributed to the campaign. Call it
  after `Purchases.configure(...)`. Sent once per install, retried on later
  calls until the backend accepts it, never throws.

### Changed

- Wraps `PostedSDK` 1.1.0 on iOS and `com.postedapp:posted-sdk` 4.1.0 on
  Android.

## 1.0.2

### Added

- The install report includes `installSource`: `store` for an App Store or
  Google Play install, `development` for debug, TestFlight, ad hoc and emulator
  builds. It's collected by the native SDKs; no Dart API changes.

### Changed

- Wraps `PostedSDK` 1.0.2 on iOS and `com.postedapp:posted-sdk` 4.0.2 on
  Android.

## 1.0.1 — Initial public release

Initial public release of `posted_sdk` for Flutter.

### Public API

- **`Posted.reportInstall(config)`** — reports the install once per install,
  so the backend can match it to the ad click and report the conversion. Call
  it on every launch: it retries on later launches until the backend accepts
  it, never throws, and never reads the clipboard. Android installs include
  the Play install referrer `click_id`.
- **`PostedConfig(apiKey:, appID:)`** — the only configuration.
- **Backend API base**: `attr.postedapp.com`.
- Wraps the native SDKs: `PostedSDK` 1.0.1 on iOS and
  `com.postedapp:posted-sdk` 4.0.1 on Android. On other platforms the call is
  a no-op.
