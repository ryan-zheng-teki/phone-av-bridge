import XCTest
@testable import PhoneAVBridgeIOS

final class HostSelectionStateTests: XCTestCase {
  func testReconcileSelectRequiredWhenNoCandidatesAndUnpaired() {
    let snapshot = HostSelectionState.reconcile(
      candidates: [],
      selectedBaseURL: nil,
      explicitSelection: false,
      paired: false,
      pairedBaseURL: nil
    )

    XCTAssertEqual(snapshot.action, .selectRequired)
    XCTAssertNil(snapshot.selectedBaseURL)
    XCTAssertTrue(snapshot.candidates.isEmpty)
  }

  func testReconcileAutoSelectSingleCandidateForPairAction() {
    let candidate = DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1")

    let snapshot = HostSelectionState.reconcile(
      candidates: [candidate],
      selectedBaseURL: nil,
      explicitSelection: false,
      paired: false,
      pairedBaseURL: nil
    )

    XCTAssertEqual(snapshot.action, .pair)
    XCTAssertEqual(snapshot.selectedBaseURL, candidate.baseURL)
    XCTAssertFalse(snapshot.explicitSelection)
  }

  func testReconcileRequiresExplicitSelectionWhenMultipleCandidatesUnpaired() {
    let snapshot = HostSelectionState.reconcile(
      candidates: [
        DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
        DiscoveredHost(baseURL: "http://host-2:8787", pairingCode: "PAIR-2"),
      ],
      selectedBaseURL: nil,
      explicitSelection: false,
      paired: false,
      pairedBaseURL: nil
    )

    XCTAssertEqual(snapshot.action, .selectRequired)
    XCTAssertNil(snapshot.selectedBaseURL)
  }

  func testReconcileKeepsCurrentHostWhenPairedAndNoExplicitSelection() {
    let snapshot = HostSelectionState.reconcile(
      candidates: [
        DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
        DiscoveredHost(baseURL: "http://host-2:8787", pairingCode: "PAIR-2"),
      ],
      selectedBaseURL: nil,
      explicitSelection: false,
      paired: true,
      pairedBaseURL: "http://host-2:8787"
    )

    XCTAssertEqual(snapshot.selectedBaseURL, "http://host-2:8787")
    XCTAssertEqual(snapshot.action, .unpair)
  }

  func testReconcileSwitchActionWhenPairedAndExplicitSelectionDifferentFromCurrent() {
    let snapshot = HostSelectionState.reconcile(
      candidates: [
        DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-1"),
        DiscoveredHost(baseURL: "http://host-2:8787", pairingCode: "PAIR-2"),
      ],
      selectedBaseURL: "http://host-1:8787",
      explicitSelection: true,
      paired: true,
      pairedBaseURL: "http://host-2:8787"
    )

    XCTAssertEqual(snapshot.action, .switchHost)
    XCTAssertEqual(snapshot.selectedBaseURL, "http://host-1:8787")
    XCTAssertTrue(snapshot.explicitSelection)
  }

  func testReconcileDedupesByBaseURLWithLastValue() {
    let snapshot = HostSelectionState.reconcile(
      candidates: [
        DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-OLD", displayName: "Old"),
        DiscoveredHost(baseURL: "http://host-1:8787", pairingCode: "PAIR-NEW", displayName: "New"),
      ],
      selectedBaseURL: "http://host-1:8787",
      explicitSelection: true,
      paired: false,
      pairedBaseURL: nil
    )

    XCTAssertEqual(snapshot.candidates.count, 1)
    XCTAssertEqual(snapshot.candidates.first?.pairingCode, "PAIR-NEW")
  }
}
