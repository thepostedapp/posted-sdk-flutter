import 'src/models.dart';
import 'src/posted_service.dart';
import 'posted_sdk_platform_interface.dart';
import 'posted_sdk_method_channel.dart';

export 'src/models.dart';
export 'src/posted_service.dart';

class PostedSdk {
  Future<void> configure(PostedConfig config) {
    return PostedSdkPlatform.instance.configure(config);
  }

  Future<PostedResult> resolveInitialLink() {
    return PostedSdkPlatform.instance.resolveInitialLink();
  }

  Future<PostedResult> processLink(String url) {
    return PostedSdkPlatform.instance.processLink(url);
  }

  Stream<PostedResult> get linkStream => PostedSdkPlatform.instance.linkStream;

  Future<void> logEvent(
    PostedEventName eventName, {
    Map<String, dynamic>? data,
  }) {
    return PostedSdkPlatform.instance.logEvent(eventName, data: data);
  }

  Future<void> logRetention(String eventName) {
    return PostedSdkPlatform.instance.logRetention(eventName);
  }
}

// Deprecated backward-compat aliases — remove after one minor release cycle (v2.x → v3.0).

@Deprecated('Use PostedSdk instead. Will be removed in v3.0.')
typedef DetourFlutterPlugin = PostedSdk;

@Deprecated('Use PostedConfig instead. Will be removed in v3.0.')
typedef DetourConfig = PostedConfig;

@Deprecated('Use PostedResult instead. Will be removed in v3.0.')
typedef DetourResult = PostedResult;

@Deprecated('Use PostedLink instead. Will be removed in v3.0.')
typedef DetourLink = PostedLink;

@Deprecated('Use PostedEventName instead. Will be removed in v3.0.')
typedef DetourEventName = PostedEventName;

@Deprecated('Use PostedLinkType instead. Will be removed in v3.0.')
typedef LinkType = PostedLinkType;

@Deprecated('Use PostedLinkProcessingMode instead. Will be removed in v3.0.')
typedef LinkProcessingMode = PostedLinkProcessingMode;

@Deprecated('Use PostedService instead. Will be removed in v3.0.')
typedef DetourService = PostedService;

@Deprecated('Use PostedIntent instead. Will be removed in v3.0.')
typedef DetourIntent = PostedIntent;

@Deprecated('Use PostedIntentSource instead. Will be removed in v3.0.')
typedef DetourIntentSource = PostedIntentSource;

@Deprecated('Use PostedSdkPlatform instead. Will be removed in v3.0.')
typedef DetourFlutterPluginPlatform = PostedSdkPlatform;

@Deprecated('Use MethodChannelPostedSdk instead. Will be removed in v3.0.')
typedef MethodChannelDetourFlutterPlugin = MethodChannelPostedSdk;
