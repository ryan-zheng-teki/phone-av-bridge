import Foundation

public struct QrPairPayload: Sendable, Equatable {
  public let baseURL: String
  public let token: String

  public init(baseURL: String, token: String) {
    self.baseURL = baseURL
    self.token = token
  }
}

public enum QrPairPayloadParser {
  public static func parse(_ rawPayload: String) -> QrPairPayload? {
    let trimmed = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return nil
    }

    if let parsed = parseJson(trimmed) {
      return parsed
    }
    return parseUri(trimmed)
  }

  private static func parseJson(_ raw: String) -> QrPairPayload? {
    guard let data = raw.data(using: .utf8) else {
      return nil
    }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }

    let service = (object["service"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !service.isEmpty && service != "phone-av-bridge" {
      return nil
    }

    let token = (object["token"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      return nil
    }

    let baseURL = normalizeHttpBaseURL(object["baseUrl"] as? String)
    guard let baseURL else {
      return nil
    }

    return QrPairPayload(baseURL: baseURL, token: token)
  }

  private static func parseUri(_ raw: String) -> QrPairPayload? {
    guard let components = URLComponents(string: raw) else {
      return nil
    }

    var values: [String: String] = [:]
    for item in components.queryItems ?? [] {
      let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
      if key.isEmpty {
        continue
      }
      values[key] = (item.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let token = (values["token"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      return nil
    }

    let baseURL = normalizeHttpBaseURL(values["baseUrl"])
    guard let baseURL else {
      return nil
    }

    return QrPairPayload(baseURL: baseURL, token: token)
  }

  private static func normalizeHttpBaseURL(_ raw: String?) -> String? {
    let normalized = (raw ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)

    if normalized.isEmpty {
      return nil
    }

    let lower = normalized.lowercased()
    if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
      return nil
    }

    return normalized
  }
}
