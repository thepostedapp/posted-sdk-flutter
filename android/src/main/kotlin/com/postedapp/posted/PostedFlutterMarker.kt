// CONTRACT: The native Android SDK (posted-sdk-android) discovers this class by name
// via reflection in FlutterSdkHeaderResolver.kt. The native SDK ships dual-lookup
// for PostedFlutterMarker
// — confirm with the Android SDK team ([POS-10]) before merging. Do NOT rename
// this class or the SDK_HEADER_VALUE field without updating the native SDK.

package com.postedapp.posted

// Native SDK detects this marker via reflection to tag requests as Flutter-originated.
object PostedFlutterMarker {
    @JvmField
    val SDK_HEADER_VALUE: String = BuildConfig.FLUTTER_SDK_HEADER_VALUE
}
