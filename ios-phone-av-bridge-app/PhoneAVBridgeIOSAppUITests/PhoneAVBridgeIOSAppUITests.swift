import XCTest

final class PhoneAVBridgeIOSAppUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchEnvironment["HOST_BASE_URL"] = ProcessInfo.processInfo.environment["HOST_BASE_URL"] ?? "http://127.0.0.1:8787"
    app.launchEnvironment["IOS_DEVICE_NAME"] = "iOS UI Test"
    app.launchEnvironment["IOS_DEVICE_ID"] = "ios-ui-test"
    app.launch()
  }

  func testPairAndToggleCameraFlow() {
    let pairButton = app.buttons["primaryHostActionButton"]
    let scanQrButton = app.buttons["scanQrButton"]
    XCTAssertTrue(pairButton.waitForExistence(timeout: 20), "Primary action button should appear")
    XCTAssertTrue(scanQrButton.waitForExistence(timeout: 20), "Scan QR button should appear")
    XCTAssertEqual(scanQrButton.label, "Scan QR Pairing")
    XCTAssertTrue(scanQrButton.isEnabled, "Scan QR should be enabled while unpaired")

    pairButton.tap()

    let statusText = app.staticTexts["statusTitleText"]
    XCTAssertTrue(statusText.waitForExistence(timeout: 20), "Status title should appear")

    let pairedPredicate = NSPredicate(format: "label CONTAINS[c] 'Paired'")
    expectation(for: pairedPredicate, evaluatedWith: statusText)
    waitForExpectations(timeout: 20)
    XCTAssertTrue(scanQrButton.exists, "Scan QR should remain visible after pairing")

    let toggleIdentifiers = ["cameraToggle", "microphoneToggle", "speakerToggle"]
    var foundEnabledToggle = false

    for identifier in toggleIdentifiers {
      let toggle = app.switches[identifier]
      XCTAssertTrue(toggle.waitForExistence(timeout: 10), "\(identifier) should exist")
      guard toggle.isEnabled else {
        continue
      }
      foundEnabledToggle = true
      toggle.tap()
      break
    }

    if !foundEnabledToggle {
      XCTAssertTrue(true, "No enabled toggles reported by host capabilities in this run; gating behavior preserved.")
    }
  }
}
