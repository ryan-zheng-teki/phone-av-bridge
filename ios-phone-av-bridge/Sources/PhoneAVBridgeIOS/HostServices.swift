import Foundation

public protocol HostApiServing: Sendable {
  func fetchBootstrap(baseURL: String) async throws -> DiscoveredHost
  func redeemQrToken(baseURL: String, token: String) async throws -> DiscoveredHost
  func pair(baseURL: String, pairCode: String, deviceName: String?, deviceId: String?) async throws
  func unpair(baseURL: String) async throws
  func fetchStatus(baseURL: String) async throws -> HostStatusSnapshot
  func publishToggles(baseURL: String, payload: HostTogglePayload) async throws
  func publishPresence(baseURL: String, deviceName: String?, deviceId: String?) async throws
  func health(baseURL: String) async -> Bool
}

public protocol HostDiscoveryServing: Sendable {
  func discoverAll(timeoutMs: Int) throws -> [DiscoveredHost]
}
