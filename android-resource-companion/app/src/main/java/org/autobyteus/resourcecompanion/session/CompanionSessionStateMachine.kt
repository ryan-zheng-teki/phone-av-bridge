package org.autobyteus.resourcecompanion.session

enum class SessionState {
  DISCONNECTED,
  PAIRING,
  CONNECTED,
  RECONNECTING,
  REQUIRES_REPAIR,
}

class CompanionSessionStateMachine(
  private val maxReconnectFailures: Int = 3,
) {
  private var reconnectFailures: Int = 0
  var state: SessionState = SessionState.DISCONNECTED
    private set

  fun onPairStart() {
    state = SessionState.PAIRING
  }

  fun onPairSuccess() {
    reconnectFailures = 0
    state = SessionState.CONNECTED
  }

  fun onUnpair() {
    reconnectFailures = 0
    state = SessionState.DISCONNECTED
  }

  fun onHeartbeatTimeout() {
    if (state == SessionState.CONNECTED || state == SessionState.RECONNECTING) {
      state = SessionState.RECONNECTING
    }
  }

  fun onReconnectSuccess() {
    reconnectFailures = 0
    state = SessionState.CONNECTED
  }

  fun onReconnectFailure() {
    reconnectFailures += 1
    state = if (reconnectFailures >= maxReconnectFailures) {
      SessionState.REQUIRES_REPAIR
    } else {
      SessionState.RECONNECTING
    }
  }
}
