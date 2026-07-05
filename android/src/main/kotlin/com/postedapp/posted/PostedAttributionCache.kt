package com.postedapp.posted

import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Persistence for the fire-once attribution result cached after the first
 * successful `resolveAppLaunch`.
 *
 * Two defensive invariants (mirrors the iOS SDK hardening in POS-140):
 *
 *  1. **Atomic write.** The blob, schema version and resolved flag are written
 *     in a single [SharedPreferences.Editor.apply] batch, so the flag is never
 *     persisted without its blob (no flag-without-blob window).
 *  2. **Versioned.** Each cached blob is stamped with [VERSION]. On read the
 *     cache is only honored when the stored version matches the current one; a
 *     legacy (unversioned) or incompatible blob is dropped and re-resolved
 *     rather than decoded into stale/garbage data.
 */
object PostedAttributionCache {
    /** Bump whenever the stored key layout changes incompatibly. */
    const val VERSION = 1

    const val KEY_RESOLVED = "attributionResolved"
    const val KEY_VERSION = "attributionCacheVersion"
    const val KEY_HAS_LINK = "attributionHasLink"
    const val KEY_URL = "attributionLinkUrl"
    const val KEY_ROUTE = "attributionLinkRoute"
    const val KEY_PATHNAME = "attributionLinkPathname"
    const val KEY_TYPE = "attributionLinkType"
    const val KEY_PARAMS = "attributionLinkParams"

    /**
     * `true` only when a resolved result with a matching schema version is
     * cached. A set flag without a matching version (legacy/incompatible
     * cache) reports `false` so the caller re-resolves.
     */
    fun hasValidResolvedCache(prefs: SharedPreferences): Boolean {
        if (!prefs.getBoolean(KEY_RESOLVED, false)) return false
        return prefs.getInt(KEY_VERSION, -1) == VERSION
    }

    /**
     * Persists the resolved result atomically. The resolved flag, schema
     * version and blob are committed together in one [apply] batch.
     */
    fun save(prefs: SharedPreferences, map: Map<String, Any?>) {
        val editor = prefs.edit()
        val link = map["link"] as? Map<*, *>
        if (link != null) {
            editor.putBoolean(KEY_HAS_LINK, true)
            editor.putString(KEY_URL, link["url"] as? String ?: "")
            editor.putString(KEY_ROUTE, link["route"] as? String ?: "")
            editor.putString(KEY_PATHNAME, link["pathname"] as? String ?: "")
            editor.putString(KEY_TYPE, link["type"] as? String ?: "")
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
            editor.putString(KEY_PARAMS, paramsJson)
        } else {
            editor.putBoolean(KEY_HAS_LINK, false)
            editor.remove(KEY_PARAMS)
        }
        editor.putInt(KEY_VERSION, VERSION)
        editor.putBoolean(KEY_RESOLVED, true)
        // Single atomic commit: flag, version and blob are persisted together.
        editor.apply()
    }

    /**
     * Reads a previously-persisted result. Callers must gate on
     * [hasValidResolvedCache] first.
     */
    fun load(prefs: SharedPreferences): Map<String, Any?> {
        val hasLink = prefs.getBoolean(KEY_HAS_LINK, false)
        return if (hasLink) {
            val paramsStr = prefs.getString(KEY_PARAMS, "{}") ?: "{}"
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
                    "url" to (prefs.getString(KEY_URL, "") ?: ""),
                    "route" to (prefs.getString(KEY_ROUTE, "") ?: ""),
                    "pathname" to (prefs.getString(KEY_PATHNAME, "") ?: ""),
                    "type" to (prefs.getString(KEY_TYPE, "deferred") ?: "deferred"),
                    "params" to paramsMap,
                ),
            )
        } else {
            mapOf("processed" to true, "link" to null)
        }
    }

    /** Drops every cached attribution key (used on reset and on version drop). */
    fun clear(prefs: SharedPreferences) {
        prefs.edit()
            .remove(KEY_RESOLVED)
            .remove(KEY_VERSION)
            .remove(KEY_HAS_LINK)
            .remove(KEY_URL)
            .remove(KEY_ROUTE)
            .remove(KEY_PATHNAME)
            .remove(KEY_TYPE)
            .remove(KEY_PARAMS)
            .apply()
    }
}
