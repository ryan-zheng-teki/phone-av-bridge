package org.autobyteus.resourcecompanion.session

import org.junit.Assert.assertEquals
import org.junit.Test

class CompanionSessionStateMachineTest {
  @Test
  fun transitionsFromPairToConnected() {
    val sm = CompanionSessionStateMachine()
    sm.onPairStart()
    assertEquals(SessionState.PAIRING, sm.state)
    sm.onPairSuccess()
    assertEquals(SessionState.CONNECTED, sm.state)
  }

  @Test
  fun reconnectFailuresEventuallyRequireRepair() {
    val sm = CompanionSessionStateMachine(maxReconnectFailures = 2)
    sm.onPairStart()
    sm.onPairSuccess()
    sm.onHeartbeatTimeout()
    assertEquals(SessionState.RECONNECTING, sm.state)
    sm.onReconnectFailure()
    assertEquals(SessionState.RECONNECTING, sm.state)
    sm.onReconnectFailure()
    assertEquals(SessionState.REQUIRES_REPAIR, sm.state)
  }

  @Test
  fun reconnectSuccessReturnsToConnected() {
    val sm = CompanionSessionStateMachine()
    sm.onPairStart()
    sm.onPairSuccess()
    sm.onHeartbeatTimeout()
    sm.onReconnectSuccess()
    assertEquals(SessionState.CONNECTED, sm.state)
  }
}
