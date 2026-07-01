package com.postedapp.posted

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import org.json.JSONObject
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import com.swmansion.detour.Detour
import com.swmansion.detour.DetourConfig
import com.swmansion.detour.analytics.DetourAnalytics
import com.swmansion.detour.analytics.DetourEventNames
import com.swmansion.detour.models.LinkProcessingMode
import com.swmansion.detour.models.LinkResult

class PostedFlutterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler,
    PluginRegistry.NewIntentListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var isConfigured = false

    private val scope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "posted_sdk")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "posted_sdk/links")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activity = null
        activityBinding = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        if (!isConfigured) return false
        val sink = eventSink ?: return false

        scope.launch {
            when (val nativeResult = Detour.processLink(intent)) {
                is LinkResult.Error -> {
                    sink.error("NATIVE_ERROR", nativeResult.exception.message, null)
                }
                else -> sink.success(toFlutterMap(nativeResult))
            }
        }
        return true
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configure" -> {
                val args = call.arguments as? Map<*, *>
                val apiKey = args?.get("apiKey") as? String
                val appID = args?.get("appID") as? String
                if (apiKey.isNullOrBlank() || appID.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "apiKey and appID are required", null)
                    return
                }

                val modeRaw = (args["linkProcessingMode"] as? String) ?: "all"
                val mode = when (modeRaw) {
                    "web-only" -> LinkProcessingMode.WEB_ONLY
                    "deferred-only" -> LinkProcessingMode.DEFERRED_ONLY
                    else -> LinkProcessingMode.ALL
                }

                val appContext = activity?.applicationContext
                if (appContext == null) {
                    result.error("NO_ACTIVITY", "Plugin requires an attached Activity to configure", null)
                    return
                }

                val config = DetourConfig(
                    apiKey = apiKey,
                    appId = appID,
                    linkProcessingMode = mode,
                    storage = null,
                )

                Detour.initialize(appContext, config)
                isConfigured = true
                result.success(null)
            }

            "resolveInitialLink" -> {
                if (!isConfigured) {
                    result.error("NOT_CONFIGURED", "Call configure() first", null)
                    return
                }

                val initialIntent = activity?.intent ?: Intent()
                scope.launch {
                    when (val nativeResult = Detour.processLink(initialIntent)) {
                        is LinkResult.Error -> {
                            result.error("NATIVE_ERROR", nativeResult.exception.message, null)
                        }
                        else -> result.success(toFlutterMap(nativeResult))
                    }
                }
            }

            "processLink" -> {
                if (!isConfigured) {
                    result.error("NOT_CONFIGURED", "Call configure() first", null)
                    return
                }

                val args = call.arguments as? Map<*, *>
                val rawUrl = args?.get("url") as? String
                if (rawUrl.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "url is required", null)
                    return
                }

                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(rawUrl))
                scope.launch {
                    when (val nativeResult = Detour.processLink(intent)) {
                        is LinkResult.Error -> {
                            result.error("NATIVE_ERROR", nativeResult.exception.message, null)
                        }
                        else -> result.success(toFlutterMap(nativeResult))
                    }
                }
            }

            "logEvent" -> {
                if (!isConfigured) {
                    result.error("NOT_CONFIGURED", "Call configure() first", null)
                    return
                }

                val args = call.arguments as? Map<*, *>
                val eventName = args?.get("eventName") as? String
                if (eventName.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "eventName is required", null)
                    return
                }

                val enumValue = DetourEventNames.entries.firstOrNull { it.eventName == eventName }
                if (enumValue == null) {
                    result.error(
                        "UNSUPPORTED_EVENT",
                        "Android SDK supports predefined DetourEventNames only. Received: $eventName",
                        null,
                    )
                    return
                }

                val data = args["data"]
                DetourAnalytics.logEvent(enumValue, data)
                result.success(null)
            }

            "logRetention" -> {
                if (!isConfigured) {
                    result.error("NOT_CONFIGURED", "Call configure() first", null)
                    return
                }

                val args = call.arguments as? Map<*, *>
                val eventName = args?.get("eventName") as? String
                if (eventName.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "eventName is required", null)
                    return
                }

                DetourAnalytics.logRetention(eventName)
                result.success(null)
            }

            "resolveAppLaunch" -> {
                val args = call.arguments as? Map<*, *>
                val apiKey = args?.get("apiKey") as? String
                val appID = args?.get("appID") as? String
                if (apiKey.isNullOrBlank() || appID.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "apiKey and appID are required", null)
                    return
                }

                val appContext = activity?.applicationContext
                if (appContext == null) {
                    result.error("NO_ACTIVITY", "Plugin requires an attached Activity", null)
                    return
                }

                val prefs = appContext.getSharedPreferences("posted_sdk", Context.MODE_PRIVATE)
                if (prefs.getBoolean("attributionResolved", false)) {
                    result.success(loadCachedResult(prefs))
                    return
                }

                if (!isConfigured) {
                    val modeRaw = (args["linkProcessingMode"] as? String) ?: "all"
                    val mode = when (modeRaw) {
                        "web-only" -> LinkProcessingMode.WEB_ONLY
                        "deferred-only" -> LinkProcessingMode.DEFERRED_ONLY
                        else -> LinkProcessingMode.ALL
                    }
                    val config = DetourConfig(
                        apiKey = apiKey,
                        appId = appID,
                        linkProcessingMode = mode,
                        storage = null,
                    )
                    Detour.initialize(appContext, config)
                    isConfigured = true
                }

                val initialIntent = activity?.intent ?: Intent()
                scope.launch {
                    when (val nativeResult = Detour.processLink(initialIntent)) {
                        is LinkResult.Error -> {
                            result.error("NATIVE_ERROR", nativeResult.exception.message, null)
                        }
                        else -> {
                            val flutterMap = toFlutterMap(nativeResult)
                            saveCachedResult(prefs, flutterMap)
                            result.success(flutterMap)
                        }
                    }
                }
            }

            "resetSession" -> {
                val appContext = activity?.applicationContext
                appContext?.getSharedPreferences("posted_sdk", Context.MODE_PRIVATE)
                    ?.edit()
                    ?.remove("attributionResolved")
                    ?.remove("attributionHasLink")
                    ?.remove("attributionLinkUrl")
                    ?.remove("attributionLinkRoute")
                    ?.remove("attributionLinkPathname")
                    ?.remove("attributionLinkType")
                    ?.remove("attributionLinkParams")
                    ?.apply()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun saveCachedResult(prefs: android.content.SharedPreferences, map: Map<String, Any?>) {
        val editor = prefs.edit()
        editor.putBoolean("attributionResolved", true)
        val link = map["link"] as? Map<*, *>
        if (link != null) {
            editor.putBoolean("attributionHasLink", true)
            editor.putString("attributionLinkUrl", link["url"] as? String ?: "")
            editor.putString("attributionLinkRoute", link["route"] as? String ?: "")
            editor.putString("attributionLinkPathname", link["pathname"] as? String ?: "")
            editor.putString("attributionLinkType", link["type"] as? String ?: "")
            val params = link["params"]
            val paramsJson = if (params is Map<*, *>) {
                try {
                    val jsonObj = JSONObject()
                    params.forEach { (k, v) -> jsonObj.put(k.toString(), v ?: JSONObject.NULL) }
                    jsonObj.toString()
                } catch (e: Exception) {
                    "{}"
                }
            } else {
                "{}"
            }
            editor.putString("attributionLinkParams", paramsJson)
        } else {
            editor.putBoolean("attributionHasLink", false)
        }
        editor.apply()
    }

    private fun loadCachedResult(prefs: android.content.SharedPreferences): Map<String, Any?> {
        val hasLink = prefs.getBoolean("attributionHasLink", false)
        return if (hasLink) {
            val paramsStr = prefs.getString("attributionLinkParams", "{}") ?: "{}"
            val paramsMap: Map<String, Any> = try {
                val json = JSONObject(paramsStr)
                json.keys().asSequence().associate { k ->
                    val v = json.get(k)
                    k to (if (v == JSONObject.NULL) "" else v)
                }
            } catch (e: Exception) {
                emptyMap()
            }
            mapOf(
                "processed" to true,
                "link" to mapOf(
                    "url" to (prefs.getString("attributionLinkUrl", "") ?: ""),
                    "route" to (prefs.getString("attributionLinkRoute", "") ?: ""),
                    "pathname" to (prefs.getString("attributionLinkPathname", "") ?: ""),
                    "type" to (prefs.getString("attributionLinkType", "deferred") ?: "deferred"),
                    "params" to paramsMap,
                ),
            )
        } else {
            mapOf("processed" to true, "link" to null)
        }
    }

    private fun toFlutterMap(nativeResult: LinkResult): Map<String, Any?> {
        return when (nativeResult) {
            is LinkResult.Success -> {
                mapOf(
                    "processed" to true,
                    "link" to mapOf(
                        "url" to nativeResult.url,
                        "route" to nativeResult.route,
                        "pathname" to nativeResult.pathname,
                        "params" to nativeResult.params,
                        "type" to when (nativeResult.type) {
                            com.swmansion.detour.models.LinkType.DEFERRED -> "deferred"
                            com.swmansion.detour.models.LinkType.VERIFIED -> "verified"
                            com.swmansion.detour.models.LinkType.SCHEME -> "scheme"
                        },
                    ),
                )
            }
            is LinkResult.NoLink,
            is LinkResult.NotFirstLaunch,
            is LinkResult.Error -> {
                mapOf(
                    "processed" to true,
                    "link" to null,
                )
            }
        }
    }
}
