# posted_sdk — Example App

This example demonstrates a full `PostedService` integration covering all three link types:

- **Deferred link** — resolved on first launch after install
- **Universal/App Link** — http/https link handled while the app is installed
- **Custom scheme link** — e.g. `posted://products/42`

The app displays separate intent cards for initial, runtime, and manually processed links, and includes buttons for triggering analytics events.

## Prerequisites

You need a Posted account with an app configured for both Android and iOS. Sign up at [posted.app](https://posted.app/auth/signup) if you haven't already.

## Setup

### 1. Create your app in the Posted Dashboard

You will need:

- **Android:** package name `com.example.posted_sdk_example` and the SHA256 fingerprint of your debug keystore:
  ```sh
  keytool -list -v \
    -keystore ~/.android/debug.keystore \
    -alias androiddebugkey \
    -storepass android -keypass android \
    | grep "SHA256"
  ```
  > Each developer must register their own fingerprint — debug certificates are machine-specific.

- **iOS:** bundle ID `com.example.postedSdkExample` and your Apple Team ID (found in Xcode under Runner → Signing & Capabilities, or at [developer.apple.com/account](https://developer.apple.com/account))

### 2. Add your credentials

```sh
cp .env.example .env
# Edit .env with your POSTED_API_KEY and POSTED_APP_ID
```

### 3. Configure link domains and schemes

- **iOS Associated Domains** — replace `YOUR_DOMAIN` in `ios/Runner/Runner.entitlements` with your Posted link domain (e.g. `applinks:yourapp.posted.link`). Append `?mode=developer` during development to bypass Apple's CDN cache.
- **Android App Link host** — update `<data android:host="...">` in `android/app/src/main/AndroidManifest.xml`.
- **Custom scheme** — this example pre-registers the `posted` scheme (`posted://…`) in both
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. Change it to your
  app-specific scheme for your own app (see [Custom scheme for host apps](#custom-scheme-for-host-apps)).

### 4. iOS signing

Open `ios/Runner.xcworkspace` in Xcode, select the **Runner** target → **Signing & Capabilities**, and set your Team.

### 5. Install dependencies and run

```sh
flutter pub get
flutter run -d <device-id>
```

iOS only — install CocoaPods first:

```sh
cd ios && pod install && cd ..
```

## Custom scheme for host apps

Custom scheme links require `linkProcessingMode: PostedLinkProcessingMode.all` and native
registration on each platform. This example registers the `posted` scheme so `posted://…`
links open the app; host apps should register their own scheme the same way.

**Android** (`android/app/src/main/AndroidManifest.xml`, inside the launcher `<activity>`):

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="posted" />
</intent-filter>
```

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>posted</string>
    </array>
  </dict>
</array>
```

## Testing

### Deferred link

Uninstall the app, copy a link from the Posted Dashboard, open it on the device, then install and launch — the deferred link resolves on first open and appears in the **Initial Intent** card.

### Universal/App Link

Trigger while the app is running:

```sh
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "https://<your-link-domain>/<link-token>" \
  com.example.posted_sdk_example

# iOS — open the link in Safari or Notes on the device
```

The **Runtime Intent** card updates with type `verified`.

### Custom scheme

```sh
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "posted://products/42?source=scheme" \
  com.example.posted_sdk_example

# iOS Simulator
xcrun simctl openurl booted "posted://products/42?source=scheme"
```

The **Runtime Intent** card updates with type `scheme`.

### Manual processing

Tap **Process Test Link** in the app to call `processLink()` directly. The result appears in the **processLink() Result** card.

### Analytics

Use the **Log Event** and **Log Retention** buttons to fire analytics events. Events appear under **Analytics → Events** in the [Posted Dashboard](https://posted.app). For local debugging on Android:

```sh
adb logcat | grep -i posted
```
