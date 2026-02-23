import XCTest
@testable import PhoneAVBridgeIOS

final class HostApiClientTests: XCTestCase {
  override func setUp() {
    super.setUp()
    MockURLProtocol.requestHandler = nil
  }

  func testFetchBootstrapParsesHostPayload() async throws {
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.url?.path, "/api/bootstrap")
      let payload = """
      {
        "bootstrap": {
          "baseUrl": "http://192.168.1.20:8787",
          "pairingCode": "PAIR-123456",
          "hostId": "host-abc12345",
          "displayName": "My Host",
          "platform": "darwin"
        }
      }
      """
      return MockURLProtocol.makeHTTPResponse(statusCode: 200, body: payload)
    }

    let client = HostApiClient(session: makeMockedSession())
    let host = try await client.fetchBootstrap(baseURL: "http://127.0.0.1:8787")
    XCTAssertEqual(host.baseURL, "http://192.168.1.20:8787")
    XCTAssertEqual(host.pairingCode, "PAIR-123456")
    XCTAssertEqual(host.hostId, "host-abc12345")
    XCTAssertEqual(host.displayName, "My Host")
    XCTAssertEqual(host.platform, "darwin")
  }

  func testPublishTogglesSendsCameraStreamURL() async throws {
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/api/toggles")
      return MockURLProtocol.makeHTTPResponse(statusCode: 200, body: "{\"status\":{}}")
    }

    let client = HostApiClient(session: makeMockedSession())
    let payload = HostTogglePayload(
      camera: true,
      microphone: true,
      speaker: false,
      cameraStreamURL: "rtsp://192.168.1.10:1935/"
    )

    let dictionary = payload.toDictionary()
    XCTAssertEqual(dictionary["camera"] as? Bool, true)
    XCTAssertEqual(dictionary["microphone"] as? Bool, true)
    XCTAssertEqual(dictionary["speaker"] as? Bool, false)
    XCTAssertEqual(dictionary["cameraStreamUrl"] as? String, "rtsp://192.168.1.10:1935/")

    try await client.publishToggles(baseURL: "http://127.0.0.1:8787", payload: payload)
  }

  func testRedeemQrTokenParsesBootstrapPayload() async throws {
    MockURLProtocol.requestHandler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/api/bootstrap/qr-redeem")

      let payload = """
      {
        "bootstrap": {
          "baseUrl": "http://192.168.1.30:8787",
          "pairingCode": "PAIR-654321",
          "hostId": "host-qr",
          "displayName": "QR Host",
          "platform": "darwin"
        }
      }
      """
      return MockURLProtocol.makeHTTPResponse(statusCode: 200, body: payload)
    }

    let client = HostApiClient(session: makeMockedSession())
    let host = try await client.redeemQrToken(baseURL: "http://127.0.0.1:8787", token: "token-123")
    XCTAssertEqual(host.baseURL, "http://192.168.1.30:8787")
    XCTAssertEqual(host.pairingCode, "PAIR-654321")
    XCTAssertEqual(host.hostId, "host-qr")
  }

  func testRequestFailureMapsStatusCode() async {
    MockURLProtocol.requestHandler = { _ in
      MockURLProtocol.makeHTTPResponse(statusCode: 400, body: "bad request")
    }

    let client = HostApiClient(session: makeMockedSession())
    do {
      _ = try await client.fetchBootstrap(baseURL: "http://127.0.0.1:8787")
      XCTFail("expected failure")
    } catch let error as HostApiClient.Error {
      XCTAssertEqual(error, .requestFailed(statusCode: 400, body: "bad request"))
    } catch {
      XCTFail("unexpected error \(error)")
    }
  }

  private func makeMockedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
  }
}

private final class MockURLProtocol: URLProtocol {
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  static func makeHTTPResponse(statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
    let url = URL(string: "http://unit.test")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8) ?? Data())
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: 1))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
