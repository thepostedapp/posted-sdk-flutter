package com.postedapp.posted

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class PostedFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private val scope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "posted_sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "reportInstall" -> {
                val args = call.arguments as? Map<*, *>
                val apiKey = args?.get("apiKey") as? String
                val appID = args?.get("appID") as? String
                if (apiKey.isNullOrBlank() || appID.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "apiKey and appID are required", null)
                    return
                }
                val context = applicationContext
                if (context == null) {
                    result.error("NOT_ATTACHED", "Plugin is not attached to a Flutter engine", null)
                    return
                }
                val config = PostedConfig(apiKey = apiKey, appId = appID)
                scope.launch {
                    // Never throws; the native SDK logs failures and retries on the next launch.
                    Posted.reportInstallAndAwait(context, config)
                    result.success(null)
                }
            }

            else -> result.notImplemented()
        }
    }
}
