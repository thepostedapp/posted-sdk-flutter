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
