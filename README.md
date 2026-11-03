# posted_sdk

`posted_sdk` reports app installs to Posted. The backend matches each install to the ad click that led to it and reports it back to the ad network as a conversion.

The SDK has one function, `Posted.reportInstall()`. Call it on every app launch. It sends the report once per install.

- [Requirements](#requirements)
- [Get your app ID and API key](#get-your-app-id-and-api-key)
- [1. Install](#1-install)
- [2. Report the install](#2-report-the-install)
- [3. Verify the integration](#3-verify-the-integration)
- [Configuration](#configuration)
- [Data collected](#data-collected)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

## Requirements

- Flutter 3.24+ / Dart 3.5+
- iOS 13.0+, Android 7.0+ (API 24)
- The plugin wraps the native Posted SDKs: `PostedSDK` 1.0.0 on iOS (CocoaPods) and `com.postedapp:posted-sdk` 1.0.0 on Android (Maven Central). Both are pulled in automatically. On web and desktop the SDK does nothing.

## Get your app ID and API key

Both come from the Posted dashboard at [app.postedapp.com/dashboard/settings](https://app.postedapp.com/dashboard/settings), under **Posted SDK**.

1. Under **Apps**, click **Add app**, fill in the form and submit it. The dashboard generates the **app ID** (`app_…`) for the new app.
2. Under **API keys**, click **Create key**. Copy the key when it is shown; it is not displayed again.

Pass these as `appID` and `apiKey` in `PostedConfig`. One API key works for all apps in your account.

## 1. Install

```sh
flutter pub add posted_sdk
```

Then rebuild the native app (`flutter run`). On iOS, `pod install` runs as part of the build.

## 2. Report the install

Call `Posted.reportInstall()` once per launch, as early as possible: in `main()` before `runApp`, or in your root widget's `initState`.

```dart
import 'package:posted_sdk/posted_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Posted.reportInstall(
    const PostedConfig(
      apiKey: '<YOUR_API_KEY>',
      appID: '<YOUR_APP_ID>',
    ),
  );
  runApp(const MyApp());
}
```

You don't need to `await` it. It never throws, and it doesn't block app startup.

## 3. Verify the integration

1. Run the app with a **fresh install**. Uninstalling clears the SDK's storage, so a reinstall reports again.
2. Watch the native logs. On Android, filter Logcat by the `PostedApiClient` tag; on iOS, filter Console by the `com.postedapp.posted` subsystem. On success you'll see `Install reported`. On failure, a line starting with `[Posted:INSTALL_ERROR]` (see [Troubleshooting](#troubleshooting)).

## Configuration

```dart
Posted.reportInstall(PostedConfig config) → Future<void>
```

| Field    | Type     | Required | Description                                            |
| -------- | -------- | -------- | ------------------------------------------------------ |
| `apiKey` | `String` | Yes      | API key from the dashboard, **Posted SDK → API keys**. |
| `appID`  | `String` | Yes      | App ID from the dashboard, **Posted SDK → Apps**.      |

The native SDKs store two keys, both prefixed with `Posted_`: the "install reported" flag and a device ID. If the app is uninstalled and reinstalled, the install is reported again.

## Data collected

The install report is one `POST` to `attr.postedapp.com/api/install`, sent once per install by the native SDK. The backend uses the fields below to match the install to an earlier ad click on the same device.

| Field                                    | Source                                                             |
| ---------------------------------------- | ------------------------------------------------------------------ |
| `platform`                               | `ios` or `android`                                                 |
| `model`, `manufacturer`, `systemVersion` | `UIDevice` on iOS, `android.os.Build` on Android                   |
| `screenWidth`, `screenHeight`, `scale`   | Screen size in points / dp and the display scale                   |
| `locale`, `timezone`                     | The device's preferred language and current time zone              |
| `userAgent`                              | `WKWebView` user agent on iOS, the `http.agent` property on Android |
| `timestamp`                              | Current time in milliseconds                                       |
| `device_id`                              | A random UUID generated once per install                           |
| `clickId`                                | Android only: `click_id` from the Play install referrer, when present |

The SDK never reads the clipboard, never collects the IDFA or advertising ID, and does not request App Tracking Transparency permission.

## Troubleshooting

| Log line                                                   | Meaning                                                                                              |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Install reported`                                         | Success. Nothing more is sent for this install.                                                      |
| `[Posted:INSTALL_ERROR] Failed to report install: 401`     | Wrong `apiKey` or `appID`. Check the credentials in the dashboard.                                   |
| `[Posted:INSTALL_ERROR] Failed to report install: 4xx/5xx` | The backend rejected the report. The SDK retries on the next launch.                                 |
| `[Posted:INSTALL_ERROR] Error reporting install`           | No network, or the native plugin was called with blank credentials. The SDK retries on the next launch. |
| `posted_sdk: current platform is not supported`            | Running on web or desktop. The call is a no-op there.                                                |
| Nothing logged                                             | The install was already reported on an earlier launch. Uninstall and reinstall to report again.      |

## Example app

See [example](example/README.md) for a minimal app that calls `Posted.reportInstall()` on launch.

## Support

Found a bug or have a question? [Open an issue](https://github.com/thepostedapp/posted-sdk-flutter/issues).
