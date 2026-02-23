import Foundation

struct AppConfig {
  let hostBaseURL: String
  let deviceName: String
  let deviceId: String
  let defaultCameraStreamURL: String

  static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfig {
    let hostBaseURL = value(environment["HOST_BASE_URL"], fallback: "http://127.0.0.1:8787")
    let deviceName = value(environment["IOS_DEVICE_NAME"], fallback: "iOS Simulator")
    let deviceId = value(environment["IOS_DEVICE_ID"], fallback: "ios-sim-app")
    let defaultCameraStreamURL = value(environment["IOS_CAMERA_STREAM_URL"], fallback: "rtsp://127.0.0.1:8554/live")

    return AppConfig(
      hostBaseURL: hostBaseURL,
      deviceName: deviceName,
      deviceId: deviceId,
      defaultCameraStreamURL: defaultCameraStreamURL
    )
  }

  private static func value(_ raw: String?, fallback: String) -> String {
    let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? fallback : trimmed
  }
}
