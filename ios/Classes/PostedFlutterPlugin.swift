import Flutter
import UIKit
import PostedSDK

public class PostedFlutterPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate, FlutterSceneLifeCycleDelegate {
    private var config: PostedConfig?
    private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    private var eventSink: FlutterEventSink?
    private var pendingRuntimeURLs: [URL] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "posted_sdk",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "posted_sdk/links",
            binaryMessenger: registrar.messenger()
        )
        let instance = PostedFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        registrar.addApplicationDelegate(instance)
        // Register for scene lifecycle callbacks when available (iOS 13+).
        // Use selector-based invocation for backwards compatibility with older Flutter SDKs.
        if let registrarObject = registrar as? NSObject {
            let selector = NSSelectorFromString("addSceneDelegate:")
            if registrarObject.responds(to: selector) {
                _ = registrarObject.perform(selector, with: instance)
            }
        }
    }

    // MARK: - FlutterApplicationLifeCycleDelegate

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any] = [:]
    ) -> Bool {
        self.launchOptions = launchOptions
        return true
    }

    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard shouldHandleSchemeRuntimeLink(url) else { return false }
        emitOrQueueRuntimeURL(url)
        return true
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return false }
        guard let url = userActivity.webpageURL else { return false }
        guard shouldHandleWebRuntimeLink(url) else { return false }

        emitOrQueueRuntimeURL(url)
        return true
    }

    // MARK: - FlutterSceneLifeCycleDelegate

    @available(iOS 13.0, *)
    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        guard let connectionOptions else { return false }

        var handled = false

        for urlContext in connectionOptions.urlContexts {
            if handleRuntimeURLCandidate(urlContext.url) {
                handled = true
            }
        }

        for userActivity in connectionOptions.userActivities {
            guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
                  let url = userActivity.webpageURL,
                  shouldHandleWebRuntimeLink(url) else {
                continue
            }
            emitOrQueueRuntimeURL(url)
            handled = true
        }

        return handled
    }

    @available(iOS 13.0, *)
    public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        var handled = false

        for urlContext in URLContexts {
            if handleRuntimeURLCandidate(urlContext.url) {
                handled = true
            }
        }

        return handled
    }

    @available(iOS 13.0, *)
    public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return false }
        guard let url = userActivity.webpageURL else { return false }
        guard shouldHandleWebRuntimeLink(url) else { return false }

        emitOrQueueRuntimeURL(url)
        return true
    }

    // MARK: - FlutterMethodCallHandler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":
            guard let args = call.arguments as? [String: Any],
                  let config = configFromArgs(args) else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing apiKey or appID", details: nil))
                return
            }
            self.config = config
            flushPendingRuntimeURLsIfPossible()
            result(nil)

        case "resolveInitialLink":
            guard let config = self.config else {
                result(FlutterError(code: "NOT_CONFIGURED", message: "Call configure() first", details: nil))
                return
            }
            let launchOpts = self.launchOptions
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let r = await Posted.shared.resolveAppLaunch(config: config, launchContext: .launchOptions(launchOpts))
                result(self.postedResultToMap(r))
            }

        case "processLink":
            guard let config = self.config else {
                result(FlutterError(code: "NOT_CONFIGURED", message: "Call configure() first", details: nil))
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "url is required", details: nil))
                return
            }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let r = await Posted.shared.processLink(url, config: config)
                result(self.postedResultToMap(r))
            }

        case "logEvent":
            guard let args = call.arguments as? [String: Any],
                  let eventName = args["eventName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "eventName is required", details: nil))
                return
            }
            let data = args["data"] as? [String: Any]
            guard let typedEventName = PostedEventName(rawValue: eventName) else {
                result(FlutterError(code: "UNSUPPORTED_EVENT", message: "Only predefined PostedEventName values are supported", details: nil))
                return
            }
            Task { @MainActor in
                PostedAnalytics.logEvent(typedEventName, data: data)
            }
            result(nil)

        case "logRetention":
            guard let args = call.arguments as? [String: Any],
                  let eventName = args["eventName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "eventName is required", details: nil))
                return
            }
            Task { @MainActor in
                PostedAnalytics.logRetention(eventName)
            }
            result(nil)

        case "resolveAppLaunch":
            guard let args = call.arguments as? [String: Any],
                  let config = configFromArgs(args) else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing apiKey or appID", details: nil))
                return
            }
            self.config = config

            let defaults = UserDefaults.standard
            if PostedAttributionCache.hasValidResolvedCache(defaults) {
                result(PostedAttributionCache.load(from: defaults))
                return
            }
            // A set flag without a matching schema version means a partial
            // write or a legacy/incompatible cache. Drop it and re-resolve
            // rather than short-circuit to stale/empty data.
            PostedAttributionCache.clear(defaults)

            let launchOpts = self.launchOptions
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let r = await Posted.shared.resolveAppLaunch(config: config, launchContext: .launchOptions(launchOpts))
                // A genuine network/transport failure must not arm the plugin's fire-once
                // cache (POS-460/POS-531) — only persist on success or a legitimate
                // no-match. Mirrors the Android glue's `LinkResult.Error` branch, which
                // already returns before `save()`.
                guard !r.resolutionFailed else {
                    result(FlutterError(code: "NATIVE_ERROR", message: "Attribution resolution failed", details: nil))
                    return
                }
                let map = self.postedResultToMap(r)
                PostedAttributionCache.save(map, to: UserDefaults.standard)
                result(map)
            }

        case "resetSession":
            PostedAttributionCache.clear(UserDefaults.standard)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helpers

    private func postedResultToMap(_ r: PostedResult) -> [String: Any?] {
        var map: [String: Any?] = ["processed": r.processed]
        if let link = r.link {
            map["link"] = [
                "url": link.url,
                "route": link.route,
                "pathname": link.pathname,
                "params": link.params,
                "type": link.type.rawValue,
            ] as [String: Any]
        } else {
            map["link"] = nil
        }
        return map
    }

    private func configFromArgs(_ args: [String: Any]) -> PostedConfig? {
        guard let apiKey = args["apiKey"] as? String,
              let appID = args["appID"] as? String else { return nil }
        let shouldUseClipboard = args["shouldUseClipboard"] as? Bool ?? true
        let modeStr = args["linkProcessingMode"] as? String ?? "all"
        let mode: LinkProcessingMode
        switch modeStr {
        case "web-only": mode = .webOnly
        case "deferred-only": mode = .deferredOnly
        default: mode = .all
        }
        return PostedConfig(
            apiKey: apiKey,
            appID: appID,
            shouldUseClipboard: shouldUseClipboard,
            linkProcessingMode: mode
        )
    }

    private func shouldHandleSchemeRuntimeLink(_ url: URL) -> Bool {
        guard !isWebURL(url) else { return false }
        guard !isInfrastructureURL(url) else { return false }
        guard config?.linkProcessingMode != .webOnly else { return false }
        guard config?.linkProcessingMode != .deferredOnly else { return false }
        return true
    }

    private func shouldHandleWebRuntimeLink(_ url: URL) -> Bool {
        guard isWebURL(url) else { return false }
        guard !isInfrastructureURL(url) else { return false }
        guard config?.linkProcessingMode != .deferredOnly else { return false }
        return true
    }

    private func handleRuntimeURLCandidate(_ url: URL) -> Bool {
        if shouldHandleWebRuntimeLink(url) || shouldHandleSchemeRuntimeLink(url) {
            emitOrQueueRuntimeURL(url)
            return true
        }
        return false
    }

    private func canProcessRuntimeURL(_ url: URL, with config: PostedConfig) -> Bool {
        if isInfrastructureURL(url) {
            return false
        }

        switch config.linkProcessingMode {
        case .all:
            return true
        case .webOnly:
            return isWebURL(url)
        case .deferredOnly:
            return false
        }
    }

    private func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func isInfrastructureURL(_ url: URL) -> Bool {
        let raw = url.absoluteString
        return raw.isEmpty || raw == "about:blank"
    }

    private func emitOrQueueRuntimeURL(_ url: URL) {
        guard let config = self.config, let sink = self.eventSink else {
            pendingRuntimeURLs.append(url)
            return
        }

        guard canProcessRuntimeURL(url, with: config) else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let result = await Posted.shared.processLink(url, config: config)
            sink(self.postedResultToMap(result))
        }
    }

    private func flushPendingRuntimeURLsIfPossible() {
        guard let config = self.config, let sink = self.eventSink else { return }
        guard !pendingRuntimeURLs.isEmpty else { return }

        let queued = pendingRuntimeURLs
        pendingRuntimeURLs.removeAll()

        for url in queued {
            guard canProcessRuntimeURL(url, with: config) else { continue }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let result = await Posted.shared.processLink(url, config: config)
                sink(self.postedResultToMap(result))
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension PostedFlutterPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        flushPendingRuntimeURLsIfPossible()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
