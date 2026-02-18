package org.autobyteus.resourcecompanion.network

import org.autobyteus.resourcecompanion.model.DiscoveredHost
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.NetworkInterface

class HostDiscoveryClient {
  companion object {
    private const val DISCOVERY_MAGIC = "PHONE_RESOURCE_COMPANION_DISCOVER_V1"
    private const val DISCOVERY_PORT = 39888
  }

  fun discover(timeoutMs: Int = 2000): DiscoveredHost? {
    val socket = DatagramSocket()
    socket.broadcast = true
    socket.soTimeout = timeoutMs

    return try {
      val payload = DISCOVERY_MAGIC.toByteArray(Charsets.UTF_8)
      val targets = buildDiscoveryTargets()

      targets.forEach { target ->
        val packet = DatagramPacket(payload, payload.size, target, DISCOVERY_PORT)
        socket.send(packet)
      }

      val receiveBuffer = ByteArray(2048)
      val response = DatagramPacket(receiveBuffer, receiveBuffer.size)
      socket.receive(response)

      val text = String(response.data, 0, response.length, Charsets.UTF_8)
      val json = JSONObject(text)
      if (json.optString("service") != "phone-resource-companion") {
        return null
      }

      val host = json.getString("host")
      val port = json.getInt("port")
      val pairingCode = json.getString("pairingCode")
      val baseUrl = json.optString("baseUrl", "http://$host:$port")
      DiscoveredHost(baseUrl = baseUrl.removeSuffix("/"), pairingCode = pairingCode)
    } catch (_: Exception) {
      null
    } finally {
      socket.close()
    }
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
