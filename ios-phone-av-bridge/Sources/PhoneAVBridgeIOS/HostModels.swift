import Foundation

public struct DiscoveredHost: Codable, Hashable, Sendable {
  public let baseURL: String
  public let pairingCode: String
  public let hostId: String?
  public let displayName: String?
  public let platform: String?

  public init(
    baseURL: String,
    pairingCode: String,
    hostId: String? = nil,
    displayName: String? = nil,
    platform: String? = nil
  ) {
    self.baseURL = baseURL
    self.pairingCode = pairingCode
    self.hostId = hostId
    self.displayName = displayName
    self.platform = platform
  }
}

public struct HostTogglePayload: Sendable {
  public let camera: Bool
  public let microphone: Bool
  public let speaker: Bool
  public let cameraLens: String
  public let cameraOrientationMode: String
  public let cameraStreamURL: String?
  public let deviceName: String?
  public let deviceId: String?

  public init(
    camera: Bool,
    microphone: Bool,
    speaker: Bool,
    cameraLens: String = "back",
    cameraOrientationMode: String = "auto",
    cameraStreamURL: String? = nil,
    deviceName: String? = nil,
    deviceId: String? = nil
  ) {
    self.camera = camera
    self.microphone = microphone
    self.speaker = speaker
    self.cameraLens = cameraLens
    self.cameraOrientationMode = cameraOrientationMode
    self.cameraStreamURL = cameraStreamURL
    self.deviceName = deviceName
    self.deviceId = deviceId
  }

  func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [
      "camera": camera,
      "microphone": microphone,
      "speaker": speaker,
      "cameraLens": cameraLens,
      "cameraOrientationMode": cameraOrientationMode,
    ]
    if let cameraStreamURL, !cameraStreamURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      dict["cameraStreamUrl"] = cameraStreamURL
    }
    if let deviceName, !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      dict["deviceName"] = deviceName
    }
    if let deviceId, !deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      dict["deviceId"] = deviceId
    }
    return dict
  }
}

public struct HostStatusIssue: Decodable, Sendable, Equatable {
  public let resource: String
  public let message: String

  public init(resource: String, message: String) {
    self.resource = resource
    self.message = message
  }
}

public struct HostCapabilities: Decodable, Sendable, Equatable {
  public let camera: Bool
  public let microphone: Bool
  public let speaker: Bool

  public init(camera: Bool = true, microphone: Bool = true, speaker: Bool = false) {
    self.camera = camera
    self.microphone = microphone
    self.speaker = speaker
  }
}

public struct HostResources: Decodable, Sendable, Equatable {
  public let camera: Bool
  public let microphone: Bool
  public let speaker: Bool

  public init(camera: Bool, microphone: Bool, speaker: Bool) {
    self.camera = camera
    self.microphone = microphone
    self.speaker = speaker
  }
}

public struct HostPhoneIdentity: Decodable, Sendable, Equatable {
  public let deviceName: String?
  public let deviceId: String?

  public init(deviceName: String? = nil, deviceId: String? = nil) {
    self.deviceName = deviceName
    self.deviceId = deviceId
  }
}

public struct HostPhoneCamera: Decodable, Sendable, Equatable {
  public let lens: String?
  public let orientationMode: String?

  public init(lens: String? = nil, orientationMode: String? = nil) {
    self.lens = lens
    self.orientationMode = orientationMode
  }
}

public struct HostStatusSnapshot: Decodable, Sendable, Equatable {
  public let paired: Bool
  public let hostStatus: String
  public let issues: [HostStatusIssue]
  public let capabilities: HostCapabilities
  public let resources: HostResources
  public let phone: HostPhoneIdentity?
  public let phoneCamera: HostPhoneCamera?
  public let cameraStreamURL: String?

  enum CodingKeys: String, CodingKey {
    case paired
    case hostStatus
    case issues
    case capabilities
    case resources
    case phone
    case phoneCamera
    case cameraStreamURL = "cameraStreamUrl"
  }

  public init(
    paired: Bool,
    hostStatus: String,
    issues: [HostStatusIssue],
    capabilities: HostCapabilities,
    resources: HostResources,
    phone: HostPhoneIdentity? = nil,
    phoneCamera: HostPhoneCamera? = nil,
    cameraStreamURL: String? = nil
  ) {
    self.paired = paired
    self.hostStatus = hostStatus
    self.issues = issues
    self.capabilities = capabilities
    self.resources = resources
    self.phone = phone
    self.phoneCamera = phoneCamera
    self.cameraStreamURL = cameraStreamURL
  }
}

public struct SpeakerPcmMetadata: Sendable, Equatable {
  public let encoding: String
  public let sampleRate: Int
  public let channels: Int

  public init(encoding: String, sampleRate: Int, channels: Int) {
    self.encoding = encoding
    self.sampleRate = sampleRate
    self.channels = channels
  }
}

struct BootstrapEnvelope: Decodable {
  let bootstrap: BootstrapPayload
}

struct BootstrapPayload: Decodable {
  let baseURL: String
  let pairingCode: String
  let hostId: String?
  let displayName: String?
  let platform: String?

  enum CodingKeys: String, CodingKey {
    case baseURL = "baseUrl"
    case pairingCode
    case hostId
    case displayName
    case platform
  }
}

struct StatusEnvelope: Decodable {
  let status: HostStatusSnapshot
}

struct GenericStatusEnvelope: Decodable {
  let status: GenericStatus?
}

struct GenericStatus: Decodable {
  let paired: Bool?
}
