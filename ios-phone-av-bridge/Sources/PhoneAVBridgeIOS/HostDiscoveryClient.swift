import Foundation
import Darwin

public final class HostDiscoveryClient: HostDiscoveryServing, Sendable {
  private static let discoveryMagic = "PHONE_AV_BRIDGE_DISCOVER_V1"
  private static let discoveryPort: UInt16 = 39888

  public init() {}

  public func discoverAll(timeoutMs: Int = 2000) throws -> [DiscoveredHost] {
    let socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard socketFd >= 0 else {
      return []
    }
    defer { close(socketFd) }

    var yes: Int32 = 1
    _ = setsockopt(socketFd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

    var recvTimeout = timeval(
      tv_sec: Int(timeoutMs / 1000),
      tv_usec: Int32((timeoutMs % 1000) * 1000)
    )
    _ = setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &recvTimeout, socklen_t(MemoryLayout<timeval>.size))

    try sendProbe(socketFd: socketFd, target: "255.255.255.255")
    try sendProbe(socketFd: socketFd, target: "10.0.2.2")

    var hostsByBaseURL: [String: DiscoveredHost] = [:]
    let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)

    while Date() < deadline {
      var buffer = [UInt8](repeating: 0, count: 2048)
      var sourceAddr = sockaddr_in()
      var sourceLen = socklen_t(MemoryLayout<sockaddr_in>.size)
      let received = withUnsafeMutablePointer(to: &sourceAddr) { ptr -> ssize_t in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
          recvfrom(socketFd, &buffer, buffer.count, 0, sockaddrPtr, &sourceLen)
        }
      }

      if received <= 0 {
        break
      }

      let data = Data(buffer.prefix(Int(received)))
      if let host = Self.parseHostResponse(data: data) {
        hostsByBaseURL[host.baseURL] = host
      }
    }

    return Self.dedupeAndSort(Array(hostsByBaseURL.values))
  }

  private func sendProbe(socketFd: Int32, target: String) throws {
    guard var addr = makeSockAddr(target: target, port: Self.discoveryPort) else {
      return
    }
    let payload = Array(Self.discoveryMagic.utf8)
    let sent = withUnsafePointer(to: &addr) { ptr -> ssize_t in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        sendto(socketFd, payload, payload.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    if sent < 0 {
      throw POSIXError(.EIO)
    }
  }

  private func makeSockAddr(target: String, port: UInt16) -> sockaddr_in? {
    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian

    let conversion = target.withCString { cString in
      inet_pton(AF_INET, cString, &addr.sin_addr)
    }
    return conversion == 1 ? addr : nil
  }

  static func parseHostResponse(data: Data) -> DiscoveredHost? {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let service = object["service"] as? String,
      service == "phone-av-bridge"
    else {
      return nil
    }

    let host = (object["host"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let port = object["port"] as? Int ?? 0
    let pairingCode = (object["pairingCode"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if host.isEmpty || port <= 0 || pairingCode.isEmpty {
      return nil
    }

    let rawBaseURL = (object["baseUrl"] as? String ?? "http://\(host):\(port)")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    if rawBaseURL.isEmpty {
      return nil
    }

    let hostId = (object["hostId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName = (object["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let platform = (object["platform"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

    return DiscoveredHost(
      baseURL: rawBaseURL,
      pairingCode: pairingCode,
      hostId: hostId?.isEmpty == true ? nil : hostId,
      displayName: displayName?.isEmpty == true ? nil : displayName,
      platform: platform?.isEmpty == true ? nil : platform
    )
  }

  static func dedupeAndSort(_ hosts: [DiscoveredHost]) -> [DiscoveredHost] {
    hosts.sorted {
      let lhsName = ($0.displayName ?? "").lowercased()
      let rhsName = ($1.displayName ?? "").lowercased()
      if lhsName == rhsName {
        return $0.baseURL.lowercased() < $1.baseURL.lowercased()
      }
      return lhsName < rhsName
    }
  }
}
