package org.autobyteus.phoneavbridge.pairing

import org.autobyteus.phoneavbridge.model.DiscoveredHost
import org.autobyteus.phoneavbridge.network.HostApiClient
import org.autobyteus.phoneavbridge.network.HostDiscoveryClient
import org.autobyteus.phoneavbridge.network.QrPairPayload
import org.autobyteus.phoneavbridge.network.QrPairPayloadParser

class PairingCoordinator(
  private val hostApiClient: HostApiClient,
  private val hostDiscoveryClient: HostDiscoveryClient,
) {
  data class PairHostResult(
    val host: DiscoveredHost,
    val snapshot: HostApiClient.HostStatusSnapshot,
  )

  fun parseQrPayload(rawPayload: String): QrPairPayload? {
    return QrPairPayloadParser.parse(rawPayload)
  }

  fun redeemQrPayload(payload: QrPairPayload): DiscoveredHost {
    return hostApiClient.redeemQrToken(payload.baseUrl, payload.token)
  }

  fun discoverHostsForPair(
    savedBaseUrl: String,
    savedPairCode: String,
    isLikelyEmulator: Boolean,
    isLoopbackBaseUrl: (String) -> Boolean,
  ): List<DiscoveredHost> {
    hostDiscoveryClient.discoverAll(timeoutMs = 2500).takeIf { it.isNotEmpty() }?.let { return it }
    hostDiscoveryClient.discoverAll(timeoutMs = 4000).takeIf { it.isNotEmpty() }?.let { return it }

    if (savedBaseUrl.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      try {
        return listOf(hostApiClient.fetchBootstrap(savedBaseUrl))
      } catch (_: Exception) {
      }
    }
    if (savedBaseUrl.isNotBlank() && savedPairCode.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      return listOf(DiscoveredHost(savedBaseUrl, savedPairCode))
    }

    val bootstrapCandidates = if (isLikelyEmulator) {
      listOf("http://10.0.2.2:8787", "http://127.0.0.1:8787")
    } else {
      emptyList()
    }
    bootstrapCandidates.forEach { candidate ->
      try {
        return listOf(hostApiClient.fetchBootstrap(candidate))
      } catch (_: Exception) {
      }
    }
    return emptyList()
  }

  fun pairHost(
    host: DiscoveredHost,
    deviceName: String,
    deviceId: String,
  ): PairHostResult {
    hostApiClient.pair(
      baseUrl = host.baseUrl,
      pairCode = host.pairingCode,
      deviceName = deviceName,
      deviceId = deviceId,
    )
    val snapshot = hostApiClient.fetchStatus(host.baseUrl)
    return PairHostResult(host = host, snapshot = snapshot)
  }

  fun switchHost(
    currentBaseUrl: String,
    targetHost: DiscoveredHost,
    deviceName: String,
    deviceId: String,
  ): PairHostResult {
    val current = currentBaseUrl.trim()
    if (current.isNotBlank() && current != targetHost.baseUrl) {
      try {
        unpairHost(current)
      } catch (_: Exception) {
        // Best effort old-host cleanup before pairing target host.
      }
    }
    return pairHost(targetHost, deviceName, deviceId)
  }

  fun unpairHost(hostBaseUrl: String) {
    if (hostBaseUrl.isBlank()) return
    hostApiClient.unpair(hostBaseUrl)
  }
}
