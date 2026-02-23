import XCTest
@testable import PhoneAVBridgeIOS

@MainActor
final class MainScreenViewModelTests: XCTestCase {
  func testOnAppearWithMultipleHostsRequiresSelection() async {
    let api = FakeHostApi()
    let discovery = FakeHostDiscovery(hosts: [
      DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
      DiscoveredHost(baseURL: "http://host-2:8787", pairingCode: "PAIR-2"),
    ])
    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery, deviceName: "iPhone Sim")

    await viewModel.onAppear()

    let state = viewModel.state
    XCTAssertEqual(state.hostSelection.action, .selectRequired)
    XCTAssertEqual(state.primaryHostActionLabel, "Pair")
    XCTAssertEqual(state.statusTitle, "Status: Not paired")
    XCTAssertEqual(state.statusDetail, "Multiple hosts detected. Select one below, then tap Pair.")
    XCTAssertEqual(state.hostCandidatesHint, "Tap a host row to select it, then tap Pair.")
  }

  func testPairFlowUpdatesPairedStateAndPublishesToggles() async {
    let api = FakeHostApi()
    api.statusSnapshot = HostStatusSnapshot(
      paired: true,
      hostStatus: "Ready",
      issues: [],
      capabilities: HostCapabilities(camera: true, microphone: true, speaker: true),
      resources: HostResources(camera: false, microphone: false, speaker: false),
      phone: HostPhoneIdentity(deviceName: "iPhone Sim", deviceId: "sim-1")
    )

    let discovery = FakeHostDiscovery(hosts: [
      DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
    ])

    let viewModel = PhoneBridgeMainScreenViewModel(
      hostApi: api,
      hostDiscovery: discovery,
      deviceName: "iPhone Sim",
      deviceId: "sim-1",
      cameraStreamURLProvider: { controls in
        controls.cameraEnabled || controls.microphoneEnabled ? "rtsp://127.0.0.1:8554/live" : nil
      }
    )

    await viewModel.onAppear()
    await viewModel.performPrimaryHostAction()

    XCTAssertTrue(viewModel.state.paired)
    XCTAssertEqual(viewModel.state.pairedBaseURL, "http://host-1:8787")
    XCTAssertEqual(api.pairCalls.count, 1)
    XCTAssertEqual(api.presenceCalls.count, 1)

    await viewModel.setCameraEnabled(true)

    XCTAssertEqual(api.publishToggleCalls.count, 2)
    let lastPayload = api.publishToggleCalls.last
    XCTAssertEqual(lastPayload?.camera, true)
    XCTAssertEqual(lastPayload?.cameraStreamURL, "rtsp://127.0.0.1:8554/live")
  }

  func testSwitchActionUnpairsCurrentHostAndPairsNewHost() async {
    let api = FakeHostApi()
    api.statusSnapshot = HostStatusSnapshot(
      paired: true,
      hostStatus: "Ready",
      issues: [],
      capabilities: HostCapabilities(camera: true, microphone: true, speaker: true),
      resources: HostResources(camera: false, microphone: false, speaker: false)
    )

    let discovery = FakeHostDiscovery(hosts: [
      DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
      DiscoveredHost(baseURL: "http://host-2:8787", pairingCode: "PAIR-2"),
    ])

    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery)

    await viewModel.onAppear()
    viewModel.selectHost(baseURL: "http://host-1:8787")
    await viewModel.performPrimaryHostAction()

    await viewModel.refreshCandidates()
    viewModel.selectHost(baseURL: "http://host-2:8787")

    XCTAssertEqual(viewModel.state.hostSelection.action, .switchHost)

    await viewModel.performPrimaryHostAction()

    XCTAssertTrue(viewModel.state.paired)
    XCTAssertEqual(viewModel.state.pairedBaseURL, "http://host-2:8787")
    XCTAssertTrue(api.unpairCalls.contains("http://host-1:8787"))
    XCTAssertEqual(api.pairCalls.last?.baseURL, "http://host-2:8787")
  }

  func testCapabilityGatingForcesUnsupportedControlsOff() async {
    let api = FakeHostApi()
    api.statusSnapshot = HostStatusSnapshot(
      paired: true,
      hostStatus: "Ready",
      issues: [],
      capabilities: HostCapabilities(camera: false, microphone: true, speaker: false),
      resources: HostResources(camera: false, microphone: false, speaker: false)
    )

    let discovery = FakeHostDiscovery(hosts: [
      DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
    ])

    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery)

    await viewModel.onAppear()
    await viewModel.performPrimaryHostAction()
    await viewModel.setCameraEnabled(true)
    await viewModel.setSpeakerEnabled(true)
    await viewModel.setMicrophoneEnabled(true)

    XCTAssertFalse(viewModel.state.controls.cameraEnabled)
    XCTAssertFalse(viewModel.state.controls.speakerEnabled)
    XCTAssertTrue(viewModel.state.controls.microphoneEnabled)

    let lastPayload = api.publishToggleCalls.last
    XCTAssertEqual(lastPayload?.camera, false)
    XCTAssertEqual(lastPayload?.speaker, false)
    XCTAssertEqual(lastPayload?.microphone, true)
  }

  func testStatusBecomesDegradedWhenRefreshFailsWhilePaired() async {
    let api = FakeHostApi()
    api.statusSnapshot = HostStatusSnapshot(
      paired: true,
      hostStatus: "Ready",
      issues: [],
      capabilities: HostCapabilities(camera: true, microphone: true, speaker: true),
      resources: HostResources(camera: false, microphone: false, speaker: false)
    )

    let discovery = FakeHostDiscovery(hosts: [
      DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
    ])

    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery)

    await viewModel.onAppear()
    await viewModel.performPrimaryHostAction()

    api.statusError = NSError(domain: "test", code: 1001, userInfo: [NSLocalizedDescriptionKey: "host unreachable"])
    await viewModel.refreshHostStatusIfPaired()

    XCTAssertEqual(viewModel.state.statusTitle, "Status: Paired (host sync issue)")
    XCTAssertEqual(viewModel.state.statusDetail, "Host is paired but currently unreachable or has route issues.")
    XCTAssertEqual(viewModel.state.issuesText, "Issues: host unreachable")
  }

  func testPairStaysSuccessfulWhenPresencePublishFails() async {
    let api = FakeHostApi()
    api.statusSnapshot = HostStatusSnapshot(
      paired: true,
      hostStatus: "Ready",
      issues: [],
      capabilities: HostCapabilities(camera: true, microphone: true, speaker: true),
      resources: HostResources(camera: false, microphone: false, speaker: false)
    )
    api.presenceError = NSError(domain: "test", code: 4001, userInfo: [NSLocalizedDescriptionKey: "presence failed"])

    let discovery = FakeHostDiscovery(hosts: [
      DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
    ])

    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery)

    await viewModel.onAppear()
    await viewModel.performPrimaryHostAction()

    XCTAssertTrue(viewModel.state.paired)
    XCTAssertEqual(viewModel.state.pairedBaseURL, "http://host-1:8787")
    XCTAssertEqual(api.pairCalls.count, 1)
    XCTAssertEqual(api.presenceCalls.count, 1)
  }

  func testQrPairingFlowRedeemsTokenThenPairsHost() async {
    let api = FakeHostApi()
    api.redeemedHost = DiscoveredHost(baseURL: "http://qr-host:8787", pairingCode: "PAIR-QR")
    api.statusSnapshot = HostStatusSnapshot(
      paired: true,
      hostStatus: "Ready",
      issues: [],
      capabilities: HostCapabilities(camera: true, microphone: true, speaker: true),
      resources: HostResources(camera: false, microphone: false, speaker: false)
    )
    let discovery = FakeHostDiscovery(hosts: [])
    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery)

    await viewModel.performQrPairing(rawPayload: #"{"service":"phone-av-bridge","token":"token-123","baseUrl":"http://qr-host:8787"}"#)

    XCTAssertEqual(api.redeemCalls.count, 1)
    XCTAssertEqual(api.redeemCalls.first?.baseURL, "http://qr-host:8787")
    XCTAssertEqual(api.redeemCalls.first?.token, "token-123")
    XCTAssertEqual(api.pairCalls.count, 1)
    XCTAssertTrue(viewModel.state.paired)
    XCTAssertEqual(viewModel.state.pairedBaseURL, "http://qr-host:8787")
  }

  func testQrPairingInvalidPayloadSetsErrorAndSkipsApiCalls() async {
    let api = FakeHostApi()
    let discovery = FakeHostDiscovery(hosts: [])
    let viewModel = PhoneBridgeMainScreenViewModel(hostApi: api, hostDiscovery: discovery)

    await viewModel.performQrPairing(rawPayload: "not-a-valid-qr-payload")

    XCTAssertEqual(api.redeemCalls.count, 0)
    XCTAssertEqual(api.pairCalls.count, 0)
    XCTAssertEqual(viewModel.state.lastHostError, "Invalid QR code. Scan a Phone AV Bridge pairing QR code.")
  }
}

private final class FakeHostApi: HostApiServing, @unchecked Sendable {
  var bootstrapHost = DiscoveredHost(baseURL: "http://127.0.0.1:8787", pairingCode: "PAIR-DEFAULT")
  var redeemedHost = DiscoveredHost(baseURL: "http://127.0.0.1:8787", pairingCode: "PAIR-QR")
  var statusSnapshot = HostStatusSnapshot(
    paired: true,
    hostStatus: "Ready",
    issues: [],
    capabilities: HostCapabilities(camera: true, microphone: true, speaker: true),
    resources: HostResources(camera: false, microphone: false, speaker: false)
  )
  var statusError: Error?
  var presenceError: Error?

  var pairCalls: [(baseURL: String, pairCode: String, deviceName: String?, deviceId: String?)] = []
  var redeemCalls: [(baseURL: String, token: String)] = []
  var unpairCalls: [String] = []
  var publishToggleCalls: [HostTogglePayload] = []
  var presenceCalls: [(baseURL: String, deviceName: String?, deviceId: String?)] = []

  func fetchBootstrap(baseURL: String) async throws -> DiscoveredHost {
    bootstrapHost
  }

  func redeemQrToken(baseURL: String, token: String) async throws -> DiscoveredHost {
    redeemCalls.append((baseURL, token))
    return redeemedHost
  }

  func pair(baseURL: String, pairCode: String, deviceName: String?, deviceId: String?) async throws {
    pairCalls.append((baseURL, pairCode, deviceName, deviceId))
  }

  func unpair(baseURL: String) async throws {
    unpairCalls.append(baseURL)
  }

  func fetchStatus(baseURL: String) async throws -> HostStatusSnapshot {
    if let statusError {
      throw statusError
    }
    return statusSnapshot
  }

  func publishToggles(baseURL: String, payload: HostTogglePayload) async throws {
    publishToggleCalls.append(payload)
  }

  func publishPresence(baseURL: String, deviceName: String?, deviceId: String?) async throws {
    presenceCalls.append((baseURL, deviceName, deviceId))
    if let presenceError {
      throw presenceError
    }
  }

  func health(baseURL: String) async -> Bool {
    true
  }
}

private final class FakeHostDiscovery: HostDiscoveryServing, @unchecked Sendable {
  var hosts: [DiscoveredHost]
  var error: Error? = nil

  init(hosts: [DiscoveredHost], error: Error? = nil) {
    self.hosts = hosts
    self.error = error
  }

  func discoverAll(timeoutMs: Int) throws -> [DiscoveredHost] {
    if let error {
      throw error
    }
    return hosts
  }
}
