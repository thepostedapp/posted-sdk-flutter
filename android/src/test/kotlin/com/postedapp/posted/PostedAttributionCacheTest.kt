package com.postedapp.posted

import android.content.SharedPreferences
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Unit tests for [PostedAttributionCache] fire-once persistence:
 * atomic write, version stamping, and drop-on-mismatch (POS-163).
 *
 * Uses a hand-rolled in-memory [SharedPreferences] so the logic runs on a
 * plain JVM without Robolectric or a device. The params-JSON encode/decode
 * path routes through `org.json.JSONObject`, which is a throwing stub under
 * plain JVM unit tests, so these tests exercise the `link == null` path; the
 * params-JSON round trip is covered by the iOS `PostedAttributionCacheTests`
 * suite (via `JSONSerialization`).
 */
internal class PostedAttributionCacheTest {

    private fun noLinkResult(): Map<String, Any?> =
        mapOf("processed" to true, "link" to null)

    @Test
    fun save_stampsVersion_andMarksResolved() {
        val prefs = FakeSharedPreferences()
        PostedAttributionCache.save(prefs, noLinkResult())

        assertTrue(PostedAttributionCache.hasValidResolvedCache(prefs))
        assertEquals(PostedAttributionCache.VERSION, prefs.getInt(PostedAttributionCache.KEY_VERSION, -1))
    }

    @Test
    fun save_writesFlagAndBlobAtomically() {
        // All writes go through a single apply() batch, so the resolved flag is
        // never committed without its blob (no flag-without-blob window).
        val prefs = FakeSharedPreferences()
        PostedAttributionCache.save(prefs, noLinkResult())

        assertEquals(1, prefs.applyCount, "expected exactly one atomic commit")
        assertTrue(prefs.getBoolean(PostedAttributionCache.KEY_RESOLVED, false))
    }

    @Test
    fun load_returnsNullLinkWhenNoLinkCached() {
        val prefs = FakeSharedPreferences()
        PostedAttributionCache.save(prefs, noLinkResult())

        assertTrue(PostedAttributionCache.hasValidResolvedCache(prefs))
        assertNull(PostedAttributionCache.load(prefs)["link"])
    }

    @Test
    fun hasValidResolvedCache_falseWhenVersionMismatch() {
        val prefs = FakeSharedPreferences()
        PostedAttributionCache.save(prefs, noLinkResult())
        // Simulate a blob written by an incompatible future/older layout.
        prefs.edit().putInt(PostedAttributionCache.KEY_VERSION, PostedAttributionCache.VERSION + 1).apply()

        assertFalse(PostedAttributionCache.hasValidResolvedCache(prefs))
    }

    @Test
    fun hasValidResolvedCache_falseForLegacyFlagWithoutVersion() {
        // Legacy cache from before versioning: flag set, no version key.
        val prefs = FakeSharedPreferences()
        prefs.edit()
            .putBoolean(PostedAttributionCache.KEY_RESOLVED, true)
            .putBoolean(PostedAttributionCache.KEY_HAS_LINK, false)
            .apply()

        assertFalse(PostedAttributionCache.hasValidResolvedCache(prefs))
    }

    @Test
    fun hasValidResolvedCache_falseForPartialWriteWithoutFlag() {
        // Interrupted write: version present but the resolved flag (written
        // last) never landed. Cache must read as unresolved.
        val prefs = FakeSharedPreferences()
        prefs.edit()
            .putInt(PostedAttributionCache.KEY_VERSION, PostedAttributionCache.VERSION)
            .putBoolean(PostedAttributionCache.KEY_HAS_LINK, false)
            .apply()

        assertFalse(PostedAttributionCache.hasValidResolvedCache(prefs))
    }

    @Test
    fun clear_dropsEveryKey() {
        val prefs = FakeSharedPreferences()
        PostedAttributionCache.save(prefs, noLinkResult())
        PostedAttributionCache.clear(prefs)

        assertFalse(PostedAttributionCache.hasValidResolvedCache(prefs))
        assertFalse(prefs.contains(PostedAttributionCache.KEY_RESOLVED))
        assertFalse(prefs.contains(PostedAttributionCache.KEY_VERSION))
        assertFalse(prefs.contains(PostedAttributionCache.KEY_HAS_LINK))
    }
}

/** Minimal in-memory [SharedPreferences] for unit tests. */
private class FakeSharedPreferences : SharedPreferences {
    private val store = HashMap<String, Any?>()
    var applyCount = 0
        private set

    override fun getAll(): MutableMap<String, *> = HashMap(store)

    override fun getString(key: String?, defValue: String?): String? =
        (store[key] as? String) ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        (store[key] as? MutableSet<String>) ?: defValues

    override fun getInt(key: String?, defValue: Int): Int = (store[key] as? Int) ?: defValue

    override fun getLong(key: String?, defValue: Long): Long = (store[key] as? Long) ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float = (store[key] as? Float) ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        (store[key] as? Boolean) ?: defValue

    override fun contains(key: String?): Boolean = store.containsKey(key)

    override fun edit(): SharedPreferences.Editor = FakeEditor()

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    private inner class FakeEditor : SharedPreferences.Editor {
        // Staged mutations flush to the backing store only on apply()/commit(),
        // so a partially-built edit is never observable — this models the
        // all-or-nothing atomicity of a real SharedPreferences commit.
        private val staged = LinkedHashMap<String, Any?>()
        private val removed = LinkedHashSet<String>()
        private var clearAll = false

        override fun putString(key: String?, value: String?) = chain { staged[key!!] = value }
        override fun putStringSet(key: String?, values: MutableSet<String>?) =
            chain { staged[key!!] = values }
        override fun putInt(key: String?, value: Int) = chain { staged[key!!] = value }
        override fun putLong(key: String?, value: Long) = chain { staged[key!!] = value }
        override fun putFloat(key: String?, value: Float) = chain { staged[key!!] = value }
        override fun putBoolean(key: String?, value: Boolean) = chain { staged[key!!] = value }
        override fun remove(key: String?) = chain { removed.add(key!!) }
        override fun clear() = chain { clearAll = true }

        override fun commit(): Boolean {
            flush()
            return true
        }

        override fun apply() {
            flush()
        }

        private fun flush() {
            if (clearAll) store.clear()
            removed.forEach { store.remove(it) }
            store.putAll(staged)
            applyCount++
        }

        private fun chain(block: () -> Unit): SharedPreferences.Editor {
            block()
            return this
        }
    }
}
