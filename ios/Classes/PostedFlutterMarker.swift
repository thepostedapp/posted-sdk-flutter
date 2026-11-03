// CONTRACT: the native iOS SDK (PostedSDK) discovers this class by name via NSClassFromString
// and reads `sdkHeaderValue` as the X-SDK header, so installs are attributed to the Flutter
// SDK. Do NOT rename this class or the property without updating the native SDK.

import Foundation

// The version is explicit because static CocoaPods linking places plugin code in the host app
// bundle, so a bundle-based lookup would read the app version. Kept in sync with pubspec.yaml by
// scripts/check_ios_marker_version.sh.
@objc(PostedFlutterMarker)
public final class PostedFlutterMarker: NSObject {
    @objc public static let sdkHeaderValue = "flutter/1.0.0"
}
