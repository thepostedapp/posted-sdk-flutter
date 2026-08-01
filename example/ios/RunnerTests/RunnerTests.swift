import Flutter
import XCTest

@testable import posted_sdk

class RunnerTests: XCTestCase {
  func testConfigureWithoutRequiredArgsReturnsInvalidArgs() {
    let plugin = PostedFlutterPlugin()
    let call = FlutterMethodCall(methodName: "configure", arguments: [:])

    let resultExpectation = expectation(description: "result block must be called")

    plugin.handle(call) { result in
      guard let error = result as? FlutterError else {
        XCTFail("Expected FlutterError")
        resultExpectation.fulfill()
        return
      }

      XCTAssertEqual(error.code, "INVALID_ARGS")
      resultExpectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }
}

// MARK: - PostedFlutterMarker (POS-274)

// Executes the real native resolver instead of parsing source: resolves the marker class
// by name the same way the native SDK does (NSClassFromString) and reads the compiled
// sdkHeaderValue, closing the gap left by the source-parse guards in
// test/sdk_marker_test.dart (POS-92).
class PostedFlutterMarkerTests: XCTestCase {
  func testSdkHeaderValueMatchesPubspecVersion() throws {
    guard let markerClass = NSClassFromString("PostedFlutterMarker") as? PostedFlutterMarker.Type else {
      XCTFail("Native SDK could not resolve PostedFlutterMarker via NSClassFromString")
      return
    }

    let expected = "flutter/\(try Self.pubspecVersion())"
    XCTAssertEqual(markerClass.sdkHeaderValue, expected)
  }

  private static func pubspecVersion() throws -> String {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let fileManager = FileManager.default
    while !fileManager.fileExists(atPath: dir.appendingPathComponent("pubspec.yaml").path) {
      let parent = dir.deletingLastPathComponent()
      guard parent.path != dir.path else {
        throw NSError(domain: "PostedFlutterMarkerTests", code: 1, userInfo: [
          NSLocalizedDescriptionKey: "Failed to locate repo root containing pubspec.yaml",
        ])
      }
      dir = parent
    }

    let pubspec = try String(contentsOf: dir.appendingPathComponent("pubspec.yaml"), encoding: .utf8)
    guard let line = pubspec.split(separator: "\n").first(where: { $0.hasPrefix("version:") }) else {
      throw NSError(domain: "PostedFlutterMarkerTests", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Failed to find version: line in pubspec.yaml",
      ])
    }
    return line.dropFirst("version:".count).trimmingCharacters(in: .whitespaces)
  }
}

// MARK: - PostedAttributionCache (POS-163)

class PostedAttributionCacheTests: XCTestCase {
  private var defaults: UserDefaults!
  private let suiteName = "PostedAttributionCacheTests"

  override func setUp() {
    super.setUp()
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  private func linkResult() -> [String: Any?] {
    return [
      "processed": true,
      "link": [
        "url": "https://ex.co/a",
        "route": "/a",
        "pathname": "a",
        "type": "deferred",
        "params": ["k": "v"],
      ] as [String: Any],
    ]
  }

  func testSaveStampsVersionAndRoundTrips() {
    PostedAttributionCache.save(linkResult(), to: defaults)

    XCTAssertTrue(PostedAttributionCache.hasValidResolvedCache(defaults))
    XCTAssertEqual(defaults.integer(forKey: PostedAttributionCache.keyVersion), PostedAttributionCache.version)

    let loaded = PostedAttributionCache.load(from: defaults)
    let link = loaded["link"] as? [String: Any]
    XCTAssertEqual(link?["url"] as? String, "https://ex.co/a")
    XCTAssertEqual((link?["params"] as? [String: Any])?["k"] as? String, "v")
  }

  func testFlagWrittenLast_partialWriteIsInvalid() {
    // Simulate an interrupted write: blob + version present, but the resolved
    // flag (written last) never landed. Cache must read as unresolved.
    defaults.set(true, forKey: PostedAttributionCache.keyHasLink)
    defaults.set(PostedAttributionCache.version, forKey: PostedAttributionCache.keyVersion)
    XCTAssertFalse(PostedAttributionCache.hasValidResolvedCache(defaults))
  }

  func testVersionMismatchIsInvalid() {
    PostedAttributionCache.save(linkResult(), to: defaults)
    defaults.set(PostedAttributionCache.version + 1, forKey: PostedAttributionCache.keyVersion)
    XCTAssertFalse(PostedAttributionCache.hasValidResolvedCache(defaults))
  }

  func testLegacyFlagWithoutVersionIsInvalid() {
    // Legacy cache written before versioning: flag set, no version key.
    defaults.set(true, forKey: PostedAttributionCache.keyResolved)
    defaults.set(false, forKey: PostedAttributionCache.keyHasLink)
    XCTAssertFalse(PostedAttributionCache.hasValidResolvedCache(defaults))
  }

  func testClearDropsEveryKey() {
    PostedAttributionCache.save(linkResult(), to: defaults)
    PostedAttributionCache.clear(defaults)

    XCTAssertFalse(PostedAttributionCache.hasValidResolvedCache(defaults))
    for key in PostedAttributionCache.allKeys {
      XCTAssertNil(defaults.object(forKey: key), "expected \(key) to be cleared")
    }
  }

  func testNoLinkRoundTrips() {
    PostedAttributionCache.save(["processed": true, "link": nil], to: defaults)

    XCTAssertTrue(PostedAttributionCache.hasValidResolvedCache(defaults))
    let loaded = PostedAttributionCache.load(from: defaults)
    XCTAssertNil(loaded["link"] ?? nil)
  }

  // NOTE: a genuine params-encode failure (e.g. NaN, Date, or another value
  // JSONSerialization can't represent) is not exercised here. On this
  // Foundation, JSONSerialization.data(withJSONObject:) raises an *uncaught*
  // NSException for such values instead of returning a catchable Swift
  // error, so `try?` never actually observes the failure — it would crash
  // the process (verified locally; see POS-272 discovery comment). The
  // fallback branch below the `try?` is therefore effectively unreachable in
  // practice; the reachable, safely-testable side of the encode-failure
  // contract is covered on Android instead, where org.json genuinely throws
  // a catchable exception.
}
