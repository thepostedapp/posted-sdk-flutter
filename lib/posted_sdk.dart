/// Reports app installs to Posted, so the backend can match each install to
/// the ad click that led to it and report it back to the ad network as a
/// conversion.
///
/// The SDK has one function, [Posted.reportInstall]. Call it on every app
/// launch. It sends the report once per install.
library;

import 'package:flutter/foundation.dart';

import 'posted_sdk_platform_interface.dart';
import 'src/models.dart';

export 'src/models.dart';

class Posted {
  Posted._();

  /// Reports this install for ad attribution.
  ///
  /// Safe to call on every launch: the install is sent once, and retried on
  /// later launches until the backend accepts it. Never throws, and does not
  /// block app startup; you don't need to `await` it. On platforms other than
  /// Android and iOS it does nothing.
  ///
  /// The report is sent by the native Posted SDK for the platform. Android
  /// installs include the Play install referrer `click_id` when present.
  static Future<void> reportInstall(PostedConfig config) async {
    try {
      await PostedSdkPlatform.instance.reportInstall(config);
    } catch (error) {
      debugPrint('[Posted:INSTALL_ERROR] Error reporting install: $error');
    }
  }
}
