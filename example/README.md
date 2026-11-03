# posted_sdk — Example App

A minimal app that calls `Posted.reportInstall()` on launch and shows when the report for this launch has finished.

## Setup

1. Create an app and an API key at [app.postedapp.com/dashboard/settings](https://app.postedapp.com/dashboard/settings) under **Posted SDK** (see the main README's [Get your app ID and API key](../README.md#get-your-app-id-and-api-key)).
2. Copy `.env.example` to `.env` and fill in the two values:

   | Key              | Where to find it                                          |
   | ---------------- | --------------------------------------------------------- |
   | `POSTED_API_KEY` | Dashboard → Settings → Posted SDK → API keys → Create key |
   | `POSTED_APP_ID`  | Dashboard → Settings → Posted SDK → Apps → Add app        |

3. Run it:

   ```sh
   flutter pub get
   flutter run -d <device-id>
   ```

## What to expect

On the first launch the native SDK posts the install report. Check the native logs: on Android, filter Logcat by the `PostedApiClient` tag; on iOS, filter Console by the `com.postedapp.posted` subsystem. Look for `Install reported`. Later launches send nothing. Uninstall and run again to report a fresh install.
