import XCTest
@testable import PhoneAVBridgeIOS

final class QrPairPayloadParserTests: XCTestCase {
  func testParseJsonPayload() {
    let raw = #"{"service":"phone-av-bridge","version":1,"token":"abc123","baseUrl":"http://127.0.0.1:8787/"}"#
    let payload = QrPairPayloadParser.parse(raw)

    XCTAssertEqual(payload?.token, "abc123")
    XCTAssertEqual(payload?.baseURL, "http://127.0.0.1:8787")
  }

  func testParseUriPayload() {
    let raw = "phone-av-bridge://pair?token=abc123&baseUrl=http%3A%2F%2F192.168.1.20%3A8787"
    let payload = QrPairPayloadParser.parse(raw)

    XCTAssertEqual(payload?.token, "abc123")
    XCTAssertEqual(payload?.baseURL, "http://192.168.1.20:8787")
  }

  func testRejectsInvalidService() {
    let raw = #"{"service":"other-app","token":"abc123","baseUrl":"http://127.0.0.1:8787"}"#
    XCTAssertNil(QrPairPayloadParser.parse(raw))
  }

  func testRejectsMissingToken() {
    let raw = #"{"service":"phone-av-bridge","baseUrl":"http://127.0.0.1:8787"}"#
    XCTAssertNil(QrPairPayloadParser.parse(raw))
  }

  func testRejectsNonHttpBaseURL() {
    let raw = #"{"service":"phone-av-bridge","token":"abc123","baseUrl":"ftp://127.0.0.1:8787"}"#
    XCTAssertNil(QrPairPayloadParser.parse(raw))
  }
}
