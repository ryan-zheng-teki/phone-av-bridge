import Foundation

public final class HostApiClient: HostApiServing, @unchecked Sendable {
  public enum Error: Swift.Error, LocalizedError, Equatable {
    case invalidURL(String)
    case invalidResponse
    case requestFailed(statusCode: Int, body: String)
    case invalidJsonBody
    case decodeFailure(String)

    public var errorDescription: String? {
      switch self {
      case .invalidURL(let value):
        return "Invalid URL: \(value)"
      case .invalidResponse:
        return "Host API response was not an HTTP response."
      case .requestFailed(let statusCode, let body):
        return "Host API request failed (\(statusCode)): \(body)"
      case .invalidJsonBody:
        return "Failed to encode JSON body."
      case .decodeFailure(let detail):
        return "Failed to decode host payload: \(detail)"
      }
    }
  }

  private let session: URLSession
  private let decoder: JSONDecoder

  public init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
    self.session = session
    self.decoder = decoder
  }

  public func fetchBootstrap(baseURL: String) async throws -> DiscoveredHost {
    let normalized = normalizeBaseURL(baseURL)
    let url = try urlFor(baseURL: normalized, path: "/api/bootstrap")
    let data = try await requestData(method: "GET", url: url, body: nil)
    do {
      let envelope = try decoder.decode(BootstrapEnvelope.self, from: data)
      return DiscoveredHost(
        baseURL: normalizeBaseURL(envelope.bootstrap.baseURL),
        pairingCode: envelope.bootstrap.pairingCode,
        hostId: envelope.bootstrap.hostId,
        displayName: envelope.bootstrap.displayName,
        platform: envelope.bootstrap.platform
      )
    } catch {
      throw Error.decodeFailure(String(describing: error))
    }
  }

  public func redeemQrToken(baseURL: String, token: String) async throws -> DiscoveredHost {
    let normalized = normalizeBaseURL(baseURL)
    let url = try urlFor(baseURL: normalized, path: "/api/bootstrap/qr-redeem")
    let data = try await requestData(method: "POST", url: url, body: ["token": token])
    do {
      let envelope = try decoder.decode(BootstrapEnvelope.self, from: data)
      let resolvedBaseURL = normalizeBaseURL(envelope.bootstrap.baseURL)
      return DiscoveredHost(
        baseURL: resolvedBaseURL.isEmpty ? normalized : resolvedBaseURL,
        pairingCode: envelope.bootstrap.pairingCode,
        hostId: envelope.bootstrap.hostId,
        displayName: envelope.bootstrap.displayName,
        platform: envelope.bootstrap.platform
      )
    } catch {
      throw Error.decodeFailure(String(describing: error))
    }
  }

  public func pair(baseURL: String, pairCode: String, deviceName: String? = nil, deviceId: String? = nil) async throws {
    let url = try urlFor(baseURL: normalizeBaseURL(baseURL), path: "/api/pair")
    var body: [String: Any] = ["pairCode": pairCode]
    if let deviceName = sanitized(deviceName) {
      body["deviceName"] = deviceName
    }
    if let deviceId = sanitized(deviceId) {
      body["deviceId"] = deviceId
    }
    _ = try await requestData(method: "POST", url: url, body: body)
  }

  public func unpair(baseURL: String) async throws {
    let url = try urlFor(baseURL: normalizeBaseURL(baseURL), path: "/api/unpair")
    _ = try await requestData(method: "POST", url: url, body: [:])
  }

  public func fetchStatus(baseURL: String) async throws -> HostStatusSnapshot {
    let url = try urlFor(baseURL: normalizeBaseURL(baseURL), path: "/api/status")
    let data = try await requestData(method: "GET", url: url, body: nil)
    do {
      let envelope = try decoder.decode(StatusEnvelope.self, from: data)
      return envelope.status
    } catch {
      throw Error.decodeFailure(String(describing: error))
    }
  }

  public func publishToggles(baseURL: String, payload: HostTogglePayload) async throws {
    let url = try urlFor(baseURL: normalizeBaseURL(baseURL), path: "/api/toggles")
    _ = try await requestData(method: "POST", url: url, body: payload.toDictionary())
  }

  public func publishPresence(baseURL: String, deviceName: String? = nil, deviceId: String? = nil) async throws {
    let url = try urlFor(baseURL: normalizeBaseURL(baseURL), path: "/api/presence")
    var body: [String: Any] = [:]
    if let deviceName = sanitized(deviceName) {
      body["deviceName"] = deviceName
    }
    if let deviceId = sanitized(deviceId) {
      body["deviceId"] = deviceId
    }
    _ = try await requestData(method: "POST", url: url, body: body)
  }

  public func health(baseURL: String) async -> Bool {
    do {
      let url = try urlFor(baseURL: normalizeBaseURL(baseURL), path: "/health")
      _ = try await requestData(method: "GET", url: url, body: nil)
      return true
    } catch {
      return false
    }
  }

  func normalizeBaseURL(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
  }

  private func sanitized(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func urlFor(baseURL: String, path: String) throws -> URL {
    guard let base = URL(string: baseURL) else {
      throw Error.invalidURL(baseURL)
    }
    return base.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
  }

  private func requestData(method: String, url: URL, body: [String: Any]?) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      guard JSONSerialization.isValidJSONObject(body) else {
        throw Error.invalidJsonBody
      }
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }
    guard (200...299).contains(http.statusCode) else {
      let bodyText = String(data: data, encoding: .utf8) ?? ""
      throw Error.requestFailed(statusCode: http.statusCode, body: bodyText)
    }
    return data
  }
}
