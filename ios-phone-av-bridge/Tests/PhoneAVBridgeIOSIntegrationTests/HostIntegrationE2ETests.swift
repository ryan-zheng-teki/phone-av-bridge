import XCTest
@testable import PhoneAVBridgeIOS

final class HostIntegrationE2ETests: XCTestCase {
  func testPairToggleSpeakerFlow() async throws {
    let env = ProcessInfo.processInfo.environment
    let hostBaseURL = env["HOST_BASE_URL"] ?? "http://127.0.0.1:8787"
    let deviceName = env["IOS_TEST_DEVICE_NAME"] ?? "iOS Simulator"
    let deviceId = env["IOS_TEST_DEVICE_ID"] ?? "ios-sim-01"

    let api = HostApiClient()
    guard await api.health(baseURL: hostBaseURL) else {
      throw XCTSkip("integration host unavailable at \(hostBaseURL)")
    }
    let bootstrap = try await api.fetchBootstrap(baseURL: hostBaseURL)

    try await api.pair(baseURL: hostBaseURL, pairCode: bootstrap.pairingCode, deviceName: deviceName, deviceId: deviceId)
    defer {
      Task {
        try? await api.unpair(baseURL: hostBaseURL)
      }
    }

    let togglePayload = HostTogglePayload(
      camera: false,
      microphone: false,
      speaker: true,
      cameraStreamURL: "rtsp://127.0.0.1:8554/live",
      deviceName: deviceName,
      deviceId: deviceId
    )
    try await api.publishToggles(baseURL: hostBaseURL, payload: togglePayload)

    let status = try await api.fetchStatus(baseURL: hostBaseURL)
    XCTAssertTrue(status.paired)
    XCTAssertTrue(status.resources.speaker)

    let speakerClient = SpeakerStreamClient()
    let metadata = try await speakerClient.open(baseURL: hostBaseURL, maxBytes: 4096) { _ in }

    XCTAssertEqual(metadata.encoding, "s16le")
    XCTAssertTrue((8_000...96_000).contains(metadata.sampleRate))
    XCTAssertTrue((1...2).contains(metadata.channels))
  }
}
