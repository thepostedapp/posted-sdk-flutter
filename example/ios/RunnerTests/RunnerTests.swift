import Flutter
import XCTest

@testable import posted_sdk

class RunnerTests: XCTestCase {
  func testReportInstallWithoutRequiredArgsReturnsInvalidArgs() {
    let plugin = PostedFlutterPlugin()
    let call = FlutterMethodCall(methodName: "reportInstall", arguments: [:])

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

  func testUnknownMethodReturnsNotImplemented() {
    let plugin = PostedFlutterPlugin()
    let call = FlutterMethodCall(methodName: "unknown", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called")

    plugin.handle(call) { result in
      XCTAssertTrue((result as AnyObject) === FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }
}

// MARK: - PostedFlutterMarker

// Executes the real native resolver instead of parsing source: resolves the marker class by name
// the same way the native SDK does (NSClassFromString) and reads the compiled sdkHeaderValue.
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
