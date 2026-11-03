# Changelog

All notable changes to `posted_sdk` are documented here.

## 1.0.0 — Initial public release

Initial public release of `posted_sdk` for Flutter.

### Public API

- **`Posted.reportInstall(config)`** — reports the install once per install,
  so the backend can match it to the ad click and report the conversion. Call
  it on every launch: it retries on later launches until the backend accepts
  it, never throws, and never reads the clipboard. Android installs include
  the Play install referrer `click_id`.
- **`PostedConfig(apiKey:, appID:)`** — the only configuration.
- **Backend API base**: `attr.postedapp.com`.
- Wraps the native SDKs: `PostedSDK` 1.0.0 on iOS and
  `com.postedapp:posted-sdk` 1.0.0 on Android. On other platforms the call is
  a no-op.
