// CONTRACT: The native iOS SDK (DetourIOS) discovers this class by name via
// NSClassFromString. The native SDK ships dual-lookup for both DetourFlutterMarker
// and PostedFlutterMarker during the transition window — confirm with the iOS SDK
// team ([POS-11]) before merging. Do NOT rename this class or the sdkHeaderValue
// property without updating the native SDK.

import Foundation

// Native iOS SDK looks up this marker class and reads the final X-SDK value directly.
// We keep the version explicit here because static CocoaPods linking places plugin code
// in the host app bundle, so bundle-based version lookup would read the app version.
@objc(PostedFlutterMarker)
public final class PostedFlutterMarker: NSObject {
    @objc public static let sdkHeaderValue = "flutter/4.0.0"
}
