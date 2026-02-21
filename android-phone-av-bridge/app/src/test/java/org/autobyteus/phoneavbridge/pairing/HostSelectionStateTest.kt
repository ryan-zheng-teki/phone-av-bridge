package org.autobyteus.phoneavbridge.pairing

import org.autobyteus.phoneavbridge.model.DiscoveredHost
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HostSelectionStateTest {
  private val mac = DiscoveredHost(baseUrl = "http://192.168.2.158:8787", pairingCode = "PAIR-111111")
  private val linux = DiscoveredHost(baseUrl = "http://192.168.2.124:8787", pairingCode = "PAIR-222222")

  @Test
  fun unpairedMultipleHostsRequiresExplicitSelection() {
    val snapshot = HostSelectionState.reconcile(
      candidates = listOf(mac, linux),
      selectedBaseUrl = null,
      explicitSelection = false,
      paired = false,
      pairedBaseUrl = null,
    )

    assertEquals(HostSelectionAction.SELECT_REQUIRED, snapshot.action)
    assertNull(snapshot.selectedBaseUrl)
  }

  @Test
  fun pairedMultipleHostsDefaultsToCurrentHostSelection() {
    val snapshot = HostSelectionState.reconcile(
      candidates = listOf(mac, linux),
      selectedBaseUrl = null,
      explicitSelection = false,
      paired = true,
      pairedBaseUrl = mac.baseUrl,
    )

    assertEquals(HostSelectionAction.UNPAIR, snapshot.action)
    assertEquals(mac.baseUrl, snapshot.selectedBaseUrl)
  }

  @Test
  fun pairedExplicitAlternateSelectionEnablesSwitch() {
    val snapshot = HostSelectionState.reconcile(
      candidates = listOf(mac, linux),
      selectedBaseUrl = linux.baseUrl,
      explicitSelection = true,
      paired = true,
      pairedBaseUrl = mac.baseUrl,
    )

    assertEquals(HostSelectionAction.SWITCH, snapshot.action)
    assertEquals(linux.baseUrl, snapshot.selectedBaseUrl)
  }
}
