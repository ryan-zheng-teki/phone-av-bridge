import Foundation
import Combine

@MainActor
public final class PhoneBridgeMainScreenViewModel: ObservableObject {
  @Published public private(set) var state: PhoneBridgeMainScreenState

  private let hostApi: HostApiServing
  private let hostDiscovery: HostDiscoveryServing
  private let bootstrapBaseURL: String?
  private let discoveryTimeoutMs: Int
  private let deviceId: String
  private let cameraStreamURLProvider: @Sendable (PhoneBridgeControlState) -> String?

  public init(
    hostApi: HostApiServing = HostApiClient(),
    hostDiscovery: HostDiscoveryServing = HostDiscoveryClient(),
    bootstrapBaseURL: String? = nil,
    deviceName: String = "iOS Device",
    deviceId: String = "ios-device",
    discoveryTimeoutMs: Int = 2_500,
    cameraStreamURLProvider: @escaping @Sendable (PhoneBridgeControlState) -> String? = { _ in nil }
  ) {
    self.hostApi = hostApi
    self.hostDiscovery = hostDiscovery
    self.bootstrapBaseURL = bootstrapBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.discoveryTimeoutMs = discoveryTimeoutMs
    self.deviceId = deviceId
    self.cameraStreamURLProvider = cameraStreamURLProvider
    self.state = PhoneBridgeMainScreenState(deviceName: deviceName)
  }

  public func onAppear() async {
    await refreshCandidates()
    await refreshHostStatusIfPaired()
  }

  public func refreshCandidates() async {
    let discovery = hostDiscovery
    let timeout = discoveryTimeoutMs

    do {
      let discovered = try await Task.detached(priority: .userInitiated) {
        try discovery.discoverAll(timeoutMs: timeout)
      }.value

      var candidates = discovered
      state.discoveredHostPreview = discovered.first

      if candidates.isEmpty {
        candidates = await fallbackCandidatesWhenDiscoveryEmpty()
      }

      reconcileSelection(candidates: ensureCurrentHostCandidate(candidates))
      state.lastHostError = nil
    } catch {
      let candidates = ensureCurrentHostCandidate([])
      reconcileSelection(candidates: candidates)
      state.lastHostError = error.localizedDescription
    }
  }

  public func refreshHostStatusIfPaired() async {
    guard state.paired else {
      state.lastHostStatus = nil
      state.lastHostError = nil
      state.hostCapabilitiesLoaded = false
      state.hostCapabilities = HostCapabilities(camera: true, microphone: true, speaker: false)
      state.controls = applyCapabilityGating(state.controls)
      return
    }

    let hostBaseURL = state.pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !hostBaseURL.isEmpty else {
      state.lastHostStatus = nil
      state.lastHostError = "missing host url"
      state.hostCapabilitiesLoaded = false
      state.hostCapabilities = HostCapabilities(camera: true, microphone: true, speaker: false)
      state.controls = applyCapabilityGating(state.controls)
      return
    }

    do {
      let snapshot = try await hostApi.fetchStatus(baseURL: hostBaseURL)
      state.lastHostStatus = snapshot
      state.lastHostError = nil
      state.hostCapabilities = snapshot.capabilities
      state.hostCapabilitiesLoaded = true
      state.controls = applyCapabilityGating(state.controls)
    } catch {
      state.lastHostError = error.localizedDescription
    }
  }

  public func selectHost(baseURL: String?) {
    let selected = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
    let explicit = selected != nil
    let selectedNormalized = (selected?.isEmpty == false) ? selected : nil

    state.hostSelection = HostSelectionState.reconcile(
      candidates: state.hostSelection.candidates,
      selectedBaseURL: selectedNormalized,
      explicitSelection: explicit,
      paired: state.paired,
      pairedBaseURL: state.pairedBaseURL
    )
  }

  public func performPrimaryHostAction() async {
    if state.pairingInProgress {
      return
    }

    switch state.hostSelection.action {
    case .pair:
      await beginPairSelectionFlow()
    case .switchHost:
      await beginSwitchHostFlow()
    case .unpair:
      await unpairCurrentHost()
    case .selectRequired:
      state.lastHostError = "Select host from the list first, then tap Pair."
    }
  }

  public func performQrPairing(rawPayload: String) async {
    if state.pairingInProgress {
      return
    }

    if state.paired {
      state.lastHostError = "Unpair current host before scanning a new QR code."
      return
    }

    guard let payload = QrPairPayloadParser.parse(rawPayload) else {
      state.lastHostError = "Invalid QR code. Scan a Phone AV Bridge pairing QR code."
      return
    }

    state.pairingInProgress = true
    do {
      let redeemedHost = try await hostApi.redeemQrToken(baseURL: payload.baseURL, token: payload.token)
      state.discoveredHostPreview = redeemedHost
      state.lastHostError = nil
      reconcileSelection(candidates: ensureCurrentHostCandidate([redeemedHost]))
      state.pairingInProgress = false
      await pairHost(redeemedHost)
    } catch {
      state.pairingInProgress = false
      state.lastHostError = mapPairFailureMessage(error)
    }
  }

  public func setCameraEnabled(_ enabled: Bool) async {
    if !state.paired {
      state.controls.cameraEnabled = false
      return
    }
    state.controls.cameraEnabled = enabled
    state.controls = applyCapabilityGating(state.controls)
    await publishControlsIfPaired()
  }

  public func setMicrophoneEnabled(_ enabled: Bool) async {
    if !state.paired {
      state.controls.microphoneEnabled = false
      return
    }
    state.controls.microphoneEnabled = enabled
    state.controls = applyCapabilityGating(state.controls)
    await publishControlsIfPaired()
  }

  public func setSpeakerEnabled(_ enabled: Bool) async {
    if !state.paired {
      state.controls.speakerEnabled = false
      return
    }
    state.controls.speakerEnabled = enabled
    state.controls = applyCapabilityGating(state.controls)
    await publishControlsIfPaired()
  }

  public func setCameraLens(_ lens: CameraLensOption) async {
    state.controls.cameraLens = lens
    if state.paired {
      await publishControlsIfPaired()
    }
  }

  public func setCameraOrientation(_ orientation: CameraOrientationOption) async {
    state.controls.cameraOrientation = orientation
    if state.paired {
      await publishControlsIfPaired()
    }
  }

  private func beginPairSelectionFlow() async {
    if let selected = state.selectedHost {
      await pairHost(selected)
      return
    }

    state.pairingInProgress = true
    await refreshCandidates()
    state.pairingInProgress = false

    guard let selected = state.selectedHost else {
      state.lastHostError = "Pair failed: host not found. Ensure Phone AV Bridge Host is open and on the same network."
      return
    }
    await pairHost(selected)
  }

  private func beginSwitchHostFlow() async {
    guard let selected = state.selectedHost else {
      state.lastHostError = "Switch failed. Select host and retry."
      return
    }

    let currentBaseURL = state.pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if selected.baseURL == currentBaseURL {
      await unpairCurrentHost()
      return
    }

    state.pairingInProgress = true

    if !currentBaseURL.isEmpty {
      do {
        try await hostApi.unpair(baseURL: currentBaseURL)
      } catch {
        // Keep switch robust even if old host cannot be reached.
      }
    }

    await pairHost(selected)
  }

  private func pairHost(_ host: DiscoveredHost) async {
    state.pairingInProgress = true
    do {
      try await hostApi.pair(
        baseURL: host.baseURL,
        pairCode: host.pairingCode,
        deviceName: state.deviceName,
        deviceId: deviceId
      )
      state.paired = true
      state.pairedBaseURL = host.baseURL
      state.savedPairCode = host.pairingCode
      state.lastHostError = nil
      state.discoveredHostPreview = host

      do {
        try await hostApi.publishPresence(baseURL: host.baseURL, deviceName: state.deviceName, deviceId: deviceId)
      } catch {
        // Presence publish is best effort; pairing should remain successful if this call fails.
        state.lastHostError = error.localizedDescription
      }
      await refreshHostStatusIfPaired()
      await publishControlsIfPaired()
      reconcileSelection(candidates: ensureCurrentHostCandidate(state.hostSelection.candidates))
    } catch {
      state.paired = false
      state.lastHostStatus = nil
      state.hostCapabilitiesLoaded = false
      state.hostCapabilities = HostCapabilities(camera: true, microphone: true, speaker: false)
      state.controls = applyCapabilityGating(state.controls)
      state.lastHostError = mapPairFailureMessage(error)
      reconcileSelection(candidates: ensureCurrentHostCandidate(state.hostSelection.candidates))
    }
    state.pairingInProgress = false
  }

  private func unpairCurrentHost() async {
    state.pairingInProgress = true

    let currentBaseURL = state.pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if !currentBaseURL.isEmpty {
      do {
        try await hostApi.unpair(baseURL: currentBaseURL)
      } catch {
        // Keep local unpair robust even when host is unreachable.
      }
    }

    state.paired = false
    state.controls = PhoneBridgeControlState(
      cameraEnabled: false,
      microphoneEnabled: false,
      speakerEnabled: false,
      cameraLens: state.controls.cameraLens,
      cameraOrientation: state.controls.cameraOrientation
    )
    state.hostCapabilities = HostCapabilities(camera: true, microphone: true, speaker: false)
    state.hostCapabilitiesLoaded = false
    state.lastHostStatus = nil
    state.lastHostError = nil
    reconcileSelection(candidates: ensureCurrentHostCandidate(state.hostSelection.candidates))

    state.pairingInProgress = false
    await refreshCandidates()
  }

  private func publishControlsIfPaired() async {
    guard state.paired else {
      return
    }
    let hostBaseURL = state.pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !hostBaseURL.isEmpty else {
      return
    }

    let controls = applyCapabilityGating(state.controls)
    state.controls = controls

    let cameraStreamURL: String?
    if controls.cameraEnabled || controls.microphoneEnabled {
      cameraStreamURL = cameraStreamURLProvider(controls)
    } else {
      cameraStreamURL = nil
    }

    let payload = HostTogglePayload(
      camera: controls.cameraEnabled,
      microphone: controls.microphoneEnabled,
      speaker: controls.speakerEnabled,
      cameraLens: controls.cameraLens.rawValue,
      cameraOrientationMode: controls.cameraOrientation.rawValue,
      cameraStreamURL: cameraStreamURL,
      deviceName: state.deviceName,
      deviceId: deviceId
    )

    do {
      try await hostApi.publishToggles(baseURL: hostBaseURL, payload: payload)
      state.lastHostError = nil
    } catch {
      state.lastHostError = error.localizedDescription
    }
  }

  private func applyCapabilityGating(_ controls: PhoneBridgeControlState) -> PhoneBridgeControlState {
    var output = controls

    if !state.paired {
      output.cameraEnabled = false
      output.microphoneEnabled = false
      output.speakerEnabled = false
      return output
    }

    if state.hostCapabilitiesLoaded {
      if output.cameraEnabled && !state.hostCapabilities.camera {
        output.cameraEnabled = false
      }
      if output.microphoneEnabled && !state.hostCapabilities.microphone {
        output.microphoneEnabled = false
      }
      if output.speakerEnabled && !state.hostCapabilities.speaker {
        output.speakerEnabled = false
      }
    }

    return output
  }

  private func fallbackCandidatesWhenDiscoveryEmpty() async -> [DiscoveredHost] {
    var candidates: [DiscoveredHost] = []

    let savedBaseURL = state.pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let savedPairCode = state.savedPairCode.trimmingCharacters(in: .whitespacesAndNewlines)
    if !savedBaseURL.isEmpty && !savedPairCode.isEmpty {
      candidates.append(
        DiscoveredHost(
          baseURL: savedBaseURL,
          pairingCode: savedPairCode,
          displayName: "Current Host",
          platform: "connected"
        )
      )
    }

    if candidates.isEmpty, let bootstrapBaseURL, !bootstrapBaseURL.isEmpty {
      do {
        let bootstrapHost = try await hostApi.fetchBootstrap(baseURL: bootstrapBaseURL)
        candidates.append(bootstrapHost)
      } catch {
        // Keep fallback best-effort only.
      }
    }

    return candidates
  }

  private func ensureCurrentHostCandidate(_ candidates: [DiscoveredHost]) -> [DiscoveredHost] {
    let pairedBaseURL = state.pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if pairedBaseURL.isEmpty {
      return candidates
    }
    if candidates.contains(where: { $0.baseURL == pairedBaseURL }) {
      return candidates
    }

    let pairedPairCode = state.savedPairCode.trimmingCharacters(in: .whitespacesAndNewlines)
    if pairedPairCode.isEmpty {
      return candidates
    }

    return [
      DiscoveredHost(
        baseURL: pairedBaseURL,
        pairingCode: pairedPairCode,
        displayName: "Current Host",
        platform: "connected"
      ),
    ] + candidates
  }

  private func reconcileSelection(candidates: [DiscoveredHost]) {
    state.hostSelection = HostSelectionState.reconcile(
      candidates: candidates,
      selectedBaseURL: state.hostSelection.selectedBaseURL,
      explicitSelection: state.hostSelection.explicitSelection,
      paired: state.paired,
      pairedBaseURL: state.pairedBaseURL
    )
  }

  private func mapPairFailureMessage(_ error: Error) -> String {
    let message = error.localizedDescription.lowercased()
    if message.contains("auto-discovery failed") || message.contains("discover") {
      return "Pair failed: host not found. Ensure Phone AV Bridge Host is open and on the same network."
    }
    if message.contains("refused") || message.contains("timed out") || message.contains("unreachable") {
      return "Pair failed: host discovered but not reachable. Check network/firewall."
    }
    if message.contains("qr token") || message.contains("request failed (404)") {
      return "Pair failed: QR token expired or already used. Generate a fresh QR code and retry."
    }
    if message.contains("invalid pair code") || message.contains("request failed (400)") {
      return "Pair failed: host rejected pair code. Restart host app and retry."
    }
    return "Pair failed: unexpected host error. Retry once after reopening host app."
  }
}
