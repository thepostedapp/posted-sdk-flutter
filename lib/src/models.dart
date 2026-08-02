enum PostedLinkType { deferred, verified, scheme }

enum PostedLinkProcessingMode {
  all,
  webOnly,
  deferredOnly;

  String get value {
    switch (this) {
      case PostedLinkProcessingMode.all:
        return 'all';
      case PostedLinkProcessingMode.webOnly:
        return 'web-only';
      case PostedLinkProcessingMode.deferredOnly:
        return 'deferred-only';
    }
  }
}

enum PostedEventName {
  login,
  search,
  share,
  signUp,
  tutorialBegin,
  tutorialComplete,
  reEngage,
  invite,
  openedFromPushNotification,
  addPaymentInfo,
  addShippingInfo,
  addToCart,
  removeFromCart,
  refund,
  viewItem,
  beginCheckout,
  purchase,
  adImpression;

  String get rawValue {
    switch (this) {
      case PostedEventName.login:
        return 'login';
      case PostedEventName.search:
        return 'search';
      case PostedEventName.share:
        return 'share';
      case PostedEventName.signUp:
        return 'sign_up';
      case PostedEventName.tutorialBegin:
        return 'tutorial_begin';
      case PostedEventName.tutorialComplete:
        return 'tutorial_complete';
      case PostedEventName.reEngage:
        return 're_engage';
      case PostedEventName.invite:
        return 'invite';
      case PostedEventName.openedFromPushNotification:
        return 'opened_from_push_notification';
      case PostedEventName.addPaymentInfo:
        return 'add_payment_info';
      case PostedEventName.addShippingInfo:
        return 'add_shipping_info';
      case PostedEventName.addToCart:
        return 'add_to_cart';
      case PostedEventName.removeFromCart:
        return 'remove_from_cart';
      case PostedEventName.refund:
        return 'refund';
      case PostedEventName.viewItem:
        return 'view_item';
      case PostedEventName.beginCheckout:
        return 'begin_checkout';
      case PostedEventName.purchase:
        return 'purchase';
      case PostedEventName.adImpression:
        return 'ad_impression';
    }
  }
}

class PostedConfig {
  final String apiKey;
  final String appID;
  final bool shouldUseClipboard;
  final PostedLinkProcessingMode linkProcessingMode;

  const PostedConfig({
    required this.apiKey,
    required this.appID,
    this.shouldUseClipboard = true,
    this.linkProcessingMode = PostedLinkProcessingMode.all,
  });
}

class PostedLink {
  final String url;
  final String route;
  final String pathname;
  final Map<String, String> params;
  final PostedLinkType type;

  const PostedLink({
    required this.url,
    required this.route,
    required this.pathname,
    required this.params,
    required this.type,
  });

  factory PostedLink.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'verified';
    final PostedLinkType type;
    switch (typeStr) {
      case 'deferred':
        type = PostedLinkType.deferred;
        break;
      case 'scheme':
        type = PostedLinkType.scheme;
        break;
      default:
        type = PostedLinkType.verified;
    }
    final paramsRaw = map['params'] as Map? ?? {};
    final params = paramsRaw.map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    return PostedLink(
      url: map['url'] as String? ?? '',
      route: map['route'] as String? ?? '',
      pathname: map['pathname'] as String? ?? '',
      params: params,
      type: type,
    );
  }
}

/// The canonical continuous-event payload emitted by [PostedSdk.linkStream].
///
/// [link] — when non-null — always carries the fully parsed [PostedLink]
/// (`url`/`route`/`pathname`/`params`/`type`); it is null only when the event
/// has nothing attributable (e.g. a plain app open).
class PostedResult {
  final bool processed;
  final PostedLink? link;

  const PostedResult({required this.processed, this.link});

  factory PostedResult.fromMap(Map<dynamic, dynamic> map) {
    final linkMap = map['link'] as Map?;
    return PostedResult(
      processed: map['processed'] as bool? ?? false,
      link: linkMap != null ? PostedLink.fromMap(linkMap) : null,
    );
  }
}
