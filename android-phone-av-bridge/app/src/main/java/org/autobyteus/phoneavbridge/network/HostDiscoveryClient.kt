package org.autobyteus.phoneavbridge.network

import org.autobyteus.phoneavbridge.model.DiscoveredHost
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketTimeoutException
import java.util.Locale

class HostDiscoveryClient {
  companion object {
    private const val DISCOVERY_MAGIC = "PHONE_AV_BRIDGE_DISCOVER_V1"
    private const val DISCOVERY_PORT = 39888
  }

  fun discover(timeoutMs: Int = 2000): DiscoveredHost? {
    return discoverAll(timeoutMs).firstOrNull()
  }

  fun discoverAll(timeoutMs: Int = 2000): List<DiscoveredHost> {
    val safeTimeoutMs = timeoutMs.coerceAtLeast(200)
    val socket = DatagramSocket()
    socket.broadcast = true

    return try {
      val payload = DISCOVERY_MAGIC.toByteArray(Charsets.UTF_8)
      val targets = buildDiscoveryTargets()

      targets.forEach { target ->
        val packet = DatagramPacket(payload, payload.size, target, DISCOVERY_PORT)
        socket.send(packet)
      }

      val deadline = System.currentTimeMillis() + safeTimeoutMs
      val receiveBuffer = ByteArray(2048)
      val discovered = linkedMapOf<String, DiscoveredHost>()

      while (System.currentTimeMillis() < deadline) {
        val remaining = (deadline - System.currentTimeMillis()).coerceAtLeast(50L).toInt()
        socket.soTimeout = remaining
        val response = DatagramPacket(receiveBuffer, receiveBuffer.size)

        try {
          socket.receive(response)
        } catch (_: SocketTimeoutException) {
          break
        }

        val host = parseResponse(response) ?: continue
        discovered[host.baseUrl] = host
      }

      discovered.values
        .sortedWith(
          compareBy(
            { it.displayName?.lowercase(Locale.ROOT).orEmpty() },
            { it.baseUrl.lowercase(Locale.ROOT) },
          ),
        )
    } catch (_: Exception) {
      emptyList()
    } finally {
      socket.close()
    }
  }

  private fun parseResponse(response: DatagramPacket): DiscoveredHost? {
    val text = String(response.data, 0, response.length, Charsets.UTF_8)
    val json = JSONObject(text)
    if (json.optString("service") != "phone-av-bridge") {
      return null
    }

    val host = json.optString("host").trim()
    val port = json.optInt("port", 0)
    val pairingCode = json.optString("pairingCode").trim()
    if (host.isBlank() || port <= 0 || pairingCode.isBlank()) {
      return null
    }

    val resolvedBaseUrl = json.optString("baseUrl", "http://$host:$port").trim().removeSuffix("/")
    if (resolvedBaseUrl.isBlank()) {
      return null
    }

    return DiscoveredHost(
      baseUrl = resolvedBaseUrl,
      pairingCode = pairingCode,
      hostId = json.optString("hostId").takeIf { it.isNotBlank() },
      displayName = json.optString("displayName").takeIf { it.isNotBlank() },
      platform = json.optString("platform").takeIf { it.isNotBlank() },
    )
  }

  private fun buildDiscoveryTargets(): List<InetAddress> {
    val targets = linkedSetOf<InetAddress>()
    targets.add(InetAddress.getByName("255.255.255.255"))
    targets.add(InetAddress.getByName("10.0.2.2"))

    try {
      val interfaces = NetworkInterface.getNetworkInterfaces() ?: return targets.toList()
      for (iface in interfaces) {
        if (!iface.isUp || iface.isLoopback) continue
        val addresses = iface.interfaceAddresses ?: continue
        for (address in addresses) {
          val broadcast = address.broadcast ?: continue
          targets.add(broadcast)
        }
      }
    } catch (_: Exception) {
      // Keep discovery robust even if interface inspection fails.
    }
    return targets.toList()
  }
}
