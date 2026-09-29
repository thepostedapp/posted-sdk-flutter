package com.postedapp.posted

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Executes the real native resolver (POS-274): [PostedFlutterMarker.SDK_HEADER_VALUE] is a
 * `BuildConfig` field generated and compiled by the Android Gradle plugin, not source text — this
 * runs the actual compiled value the native SDK's reflection lookup would see, closing the gap
 * left by the source-parse guards in `test/sdk_marker_test.dart` (POS-92).
 */
internal class PostedFlutterMarkerTest {

    @Test
    fun sdkHeaderValue_matchesPubspecVersion() {
        assertEquals("flutter/${pubspecVersion()}", PostedFlutterMarker.SDK_HEADER_VALUE)
    }

    private fun pubspecVersion(): String {
        val pubspec = repoRoot().resolve("pubspec.yaml")
        val versionLine =
            pubspec.readLines().firstOrNull { it.startsWith("version:") }
                ?: error("Failed to find version: line in $pubspec")
        return versionLine.removePrefix("version:").trim()
    }

    private fun repoRoot(): File {
        var dir = File(".").absoluteFile
        while (!File(dir, "pubspec.yaml").exists()) {
            dir = dir.parentFile ?: error("Failed to locate repo root containing pubspec.yaml")
        }
        return dir
    }
}
