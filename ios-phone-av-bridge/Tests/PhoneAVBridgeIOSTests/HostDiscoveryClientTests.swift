import XCTest
@testable import PhoneAVBridgeIOS

final class HostDiscoveryClientTests: XCTestCase {
  func testParseHostResponseAcceptsValidPayload() throws {
    let payload = """
    {
      "service":"phone-av-bridge",
      "host":"192.168.1.11",
      "port":8787,
      "pairingCode":"PAIR-777777",
      "baseUrl":"http://192.168.1.11:8787",
      "hostId":"host-abcde123",
      "displayName":"Desk Host",
      "platform":"darwin"
    }
    """

    let data = try XCTUnwrap(payload.data(using: .utf8))
    let host = try XCTUnwrap(HostDiscoveryClient.parseHostResponse(data: data))
    XCTAssertEqual(host.baseURL, "http://192.168.1.11:8787")
    XCTAssertEqual(host.pairingCode, "PAIR-777777")
    XCTAssertEqual(host.hostId, "host-abcde123")
    XCTAssertEqual(host.displayName, "Desk Host")
    XCTAssertEqual(host.platform, "darwin")
  }

  func testDedupeAndSortOrdersByDisplayNameThenBaseURL() {
    let hosts = [
      DiscoveredHost(baseURL: "http://z.local:8787", pairingCode: "PAIR-1", displayName: "Beta"),
      DiscoveredHost(baseURL: "http://a.local:8787", pairingCode: "PAIR-2", displayName: "Alpha"),
      DiscoveredHost(baseURL: "http://b.local:8787", pairingCode: "PAIR-3", displayName: "Alpha"),
    ]

    let sorted = HostDiscoveryClient.dedupeAndSort(hosts)
    XCTAssertEqual(sorted.map(\.baseURL), ["http://a.local:8787", "http://b.local:8787", "http://z.local:8787"])
  }
}
