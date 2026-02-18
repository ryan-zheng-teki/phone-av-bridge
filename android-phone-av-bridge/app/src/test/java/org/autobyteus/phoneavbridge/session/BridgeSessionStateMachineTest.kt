package org.autobyteus.phoneavbridge.session

import org.junit.Assert.assertEquals
import org.junit.Test

class BridgeSessionStateMachineTest {
  @Test
  fun transitionsFromPairToConnected() {
    val sm = BridgeSessionStateMachine()
    sm.onPairStart()
    assertEquals(SessionState.PAIRING, sm.state)
    sm.onPairSuccess()
    assertEquals(SessionState.CONNECTED, sm.state)
  }

  @Test
  fun reconnectFailuresEventuallyRequireRepair() {
    val sm = BridgeSessionStateMachine(maxReconnectFailures = 2)
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
    val sm = BridgeSessionStateMachine()
    sm.onPairStart()
    sm.onPairSuccess()
    sm.onHeartbeatTimeout()
    sm.onReconnectSuccess()
    assertEquals(SessionState.CONNECTED, sm.state)
  }
}
