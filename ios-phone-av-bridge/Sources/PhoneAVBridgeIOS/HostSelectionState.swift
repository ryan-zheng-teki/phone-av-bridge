import Foundation

public enum HostSelectionAction: String, Sendable {
  case pair
  case switchHost
  case unpair
  case selectRequired
}

public struct HostSelectionSnapshot: Sendable, Equatable {
  public let candidates: [DiscoveredHost]
  public let selectedBaseURL: String?
  public let explicitSelection: Bool
  public let action: HostSelectionAction

  public init(
    candidates: [DiscoveredHost],
    selectedBaseURL: String?,
    explicitSelection: Bool,
    action: HostSelectionAction
  ) {
    self.candidates = candidates
    self.selectedBaseURL = selectedBaseURL
    self.explicitSelection = explicitSelection
    self.action = action
  }
}

public enum HostSelectionState {
  public static func reconcile(
    candidates: [DiscoveredHost],
    selectedBaseURL: String?,
    explicitSelection: Bool,
    paired: Bool,
    pairedBaseURL: String?
  ) -> HostSelectionSnapshot {
    let normalized = dedupeByBaseURL(candidates)
    if normalized.isEmpty {
      return HostSelectionSnapshot(
        candidates: [],
        selectedBaseURL: nil,
        explicitSelection: false,
        action: paired ? .unpair : .selectRequired
      )
    }

    let hasSelected = selectedBaseURL != nil && normalized.contains(where: { $0.baseURL == selectedBaseURL })
    let currentPairedBaseURL = (pairedBaseURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    var effectiveSelected = hasSelected ? selectedBaseURL : nil
    var effectiveExplicit = explicitSelection && hasSelected

    if normalized.count > 1 && !effectiveExplicit {
      if paired {
        effectiveSelected = normalized.first(where: { $0.baseURL == currentPairedBaseURL })?.baseURL
      } else {
        effectiveSelected = nil
      }
    } else if effectiveSelected == nil && normalized.count == 1 {
      effectiveSelected = normalized[0].baseURL
      effectiveExplicit = false
    }

    let action: HostSelectionAction
    if !paired {
      action = (effectiveSelected == nil) ? .selectRequired : .pair
    } else {
      if currentPairedBaseURL.isEmpty, effectiveSelected != nil {
        action = .pair
      } else if currentPairedBaseURL.isEmpty || effectiveSelected == nil {
        action = .selectRequired
      } else if effectiveSelected == currentPairedBaseURL {
        action = .unpair
      } else {
        action = .switchHost
      }
    }

    return HostSelectionSnapshot(
      candidates: normalized,
      selectedBaseURL: effectiveSelected,
      explicitSelection: effectiveExplicit,
      action: action
    )
  }

  static func dedupeByBaseURL(_ candidates: [DiscoveredHost]) -> [DiscoveredHost] {
    var deduped: [String: DiscoveredHost] = [:]
    var order: [String] = []
    for candidate in candidates {
      if deduped[candidate.baseURL] == nil {
        order.append(candidate.baseURL)
      }
      deduped[candidate.baseURL] = candidate
    }
    return order.compactMap { deduped[$0] }
  }
}
