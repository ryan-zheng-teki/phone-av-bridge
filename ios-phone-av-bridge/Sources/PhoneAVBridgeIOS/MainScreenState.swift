import Foundation

public enum CameraLensOption: String, CaseIterable, Sendable {
  case back
  case front
}

public enum CameraOrientationOption: String, CaseIterable, Sendable {
  case auto
  case portrait
  case landscape
}

public struct PhoneBridgeControlState: Sendable, Equatable {
  public var cameraEnabled: Bool
  public var microphoneEnabled: Bool
  public var speakerEnabled: Bool
  public var cameraLens: CameraLensOption
  public var cameraOrientation: CameraOrientationOption

  public init(
    cameraEnabled: Bool = false,
    microphoneEnabled: Bool = false,
    speakerEnabled: Bool = false,
    cameraLens: CameraLensOption = .back,
    cameraOrientation: CameraOrientationOption = .auto
  ) {
    self.cameraEnabled = cameraEnabled
    self.microphoneEnabled = microphoneEnabled
    self.speakerEnabled = speakerEnabled
    self.cameraLens = cameraLens
    self.cameraOrientation = cameraOrientation
  }
}

public struct PhoneBridgeMainScreenState: Sendable {
  public var pairingInProgress: Bool
  public var paired: Bool
  public var pairedBaseURL: String
  public var savedPairCode: String
  public var hostSelection: HostSelectionSnapshot
  public var discoveredHostPreview: DiscoveredHost?
  public var lastHostStatus: HostStatusSnapshot?
  public var lastHostError: String?
  public var hostCapabilities: HostCapabilities
  public var hostCapabilitiesLoaded: Bool
  public var controls: PhoneBridgeControlState
  public var deviceName: String

  public init(
    pairingInProgress: Bool = false,
    paired: Bool = false,
    pairedBaseURL: String = "",
    savedPairCode: String = "",
    hostSelection: HostSelectionSnapshot = HostSelectionSnapshot(
      candidates: [],
      selectedBaseURL: nil,
      explicitSelection: false,
      action: .selectRequired
    ),
    discoveredHostPreview: DiscoveredHost? = nil,
    lastHostStatus: HostStatusSnapshot? = nil,
    lastHostError: String? = nil,
    hostCapabilities: HostCapabilities = HostCapabilities(camera: true, microphone: true, speaker: false),
    hostCapabilitiesLoaded: Bool = false,
    controls: PhoneBridgeControlState = PhoneBridgeControlState(),
    deviceName: String = "iOS Device"
  ) {
    self.pairingInProgress = pairingInProgress
    self.paired = paired
    self.pairedBaseURL = pairedBaseURL
    self.savedPairCode = savedPairCode
    self.hostSelection = hostSelection
    self.discoveredHostPreview = discoveredHostPreview
    self.lastHostStatus = lastHostStatus
    self.lastHostError = lastHostError
    self.hostCapabilities = hostCapabilities
    self.hostCapabilitiesLoaded = hostCapabilitiesLoaded
    self.controls = controls
    self.deviceName = deviceName
  }

  public var primaryHostActionLabel: String {
    switch hostSelection.action {
    case .pair, .selectRequired:
      return "Pair"
    case .switchHost:
      return "Switch"
    case .unpair:
      return "Unpair"
    }
  }

  public var statusTitle: String {
    if pairingInProgress {
      return "Status: Pairing in progress…"
    }
    if !paired {
      return "Status: Not paired"
    }
    if isDegraded {
      return "Status: Paired (host sync issue)"
    }
    return "Status: Paired and ready"
  }

  public var statusDetail: String {
    if pairingInProgress {
      return "Looking for host and validating pairing code."
    }
    if !paired {
      if hostSelection.action == .selectRequired {
        return "Multiple hosts detected. Select one below, then tap Pair."
      }
      if hasKnownHostCandidate {
        return "Host detected. Select and tap Pair to connect."
      }
      return "Select a host and tap Pair, or use Scan QR."
    }
    if isDegraded {
      return "Host is paired but currently unreachable or has route issues."
    }
    if hostSelection.action == .switchHost {
      return "Different host selected. Tap Switch to move connection."
    }
    if hostSelection.action == .selectRequired {
      return "Multiple hosts detected. Select one below, then tap Pair."
    }
    return "Host connected. You can now enable any resource below."
  }

  public var hostSummary: String {
    if !paired {
      if let selected = selectedHost {
        return "Selected host: \(selected.baseURL)"
      }
      if !hostSelection.candidates.isEmpty {
        return "Hosts discovered: \(hostSelection.candidates.count)"
      }
      if !pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "Last host: \(pairedBaseURL)"
      }
      return "Host: searching on local network…"
    }

    let hostBaseURL = pairedBaseURL.isEmpty ? "unknown host" : pairedBaseURL
    let phoneName = lastHostStatus?.phone?.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let effectivePhoneName = (phoneName?.isEmpty == false) ? phoneName! : deviceName
    return "\(hostBaseURL)\nPhone name on host: \(effectivePhoneName)"
  }

  public var issuesText: String {
    if !paired {
      return "Issues: none"
    }
    let issueMessage = lastHostStatus?.issues
      .map(\.message)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: " | ")

    let merged = (issueMessage?.isEmpty == false ? issueMessage : nil) ?? lastHostError
    guard let merged, !merged.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return "Issues: none"
    }
    return "Issues: \(merged)"
  }

  public var hostCandidatesHint: String {
    if hostSelection.candidates.isEmpty {
      return "No hosts found yet. Keep host app running and connected to the same network."
    }
    if pairingInProgress {
      return "Looking for host and validating pairing code."
    }
    if hostSelection.action == .selectRequired {
      return "Tap a host row to select it, then tap Pair."
    }
    if paired && hostSelection.action == .switchHost {
      return "Selected host differs from connected host. Tap Switch."
    }
    return "Selected host is ready."
  }

  public var cameraControlEnabled: Bool {
    paired && (!hostCapabilitiesLoaded || hostCapabilities.camera)
  }

  public var microphoneControlEnabled: Bool {
    paired && (!hostCapabilitiesLoaded || hostCapabilities.microphone)
  }

  public var speakerControlEnabled: Bool {
    paired && (!hostCapabilitiesLoaded || hostCapabilities.speaker)
  }

  public var cameraLensEnabled: Bool {
    cameraControlEnabled
  }

  public var cameraOrientationEnabled: Bool {
    cameraControlEnabled
  }

  public var selectedHost: DiscoveredHost? {
    guard let selectedBaseURL = hostSelection.selectedBaseURL else {
      return nil
    }
    return hostSelection.candidates.first(where: { $0.baseURL == selectedBaseURL })
  }

  public var hasKnownHostCandidate: Bool {
    if !hostSelection.candidates.isEmpty {
      return true
    }
    if discoveredHostPreview != nil {
      return true
    }
    return !pairedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public var canTapPrimaryAction: Bool {
    !pairingInProgress
  }

  public var canTapScanQr: Bool {
    !pairingInProgress && !paired
  }

  public func hostCandidateLabel(_ host: DiscoveredHost) -> String {
    let name = host.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName = (name?.isEmpty == false) ? name! : host.baseURL
    let platformRaw = host.platform?.trimmingCharacters(in: .whitespacesAndNewlines)
    let platform = (platformRaw?.isEmpty == false) ? platformRaw! : "host"
    let currentTag = paired && host.baseURL == pairedBaseURL ? " • Connected" : ""
    return "\(displayName) (\(platform))\(currentTag)\n\(host.baseURL)"
  }

  public var isDegraded: Bool {
    if !paired {
      return false
    }
    if lastHostError != nil {
      return true
    }
    guard let snapshot = lastHostStatus else {
      return true
    }
    if !snapshot.paired {
      return true
    }
    if snapshot.hostStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "needs attention" {
      return true
    }
    return !snapshot.issues.isEmpty
  }
}
