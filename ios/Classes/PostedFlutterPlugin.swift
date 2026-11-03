import Flutter
import PostedSDK

public class PostedFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "posted_sdk", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(PostedFlutterPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "reportInstall":
            guard let args = call.arguments as? [String: Any],
                  let apiKey = args["apiKey"] as? String,
                  let appID = args["appID"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing apiKey or appID", details: nil))
                return
            }
            let config = PostedConfig(apiKey: apiKey, appID: appID)
            Task { @MainActor in
                // Never throws; the native SDK logs failures and retries on the next launch.
                await Posted.shared.reportInstall(config: config)
                result(nil)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
