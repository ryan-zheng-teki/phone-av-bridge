package org.autobyteus.phoneavbridge.network

import java.net.Inet4Address
import java.net.NetworkInterface

object LanAddressResolver {
  fun resolveIpv4Address(): String? {
    val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
    for (iface in interfaces) {
      if (!iface.isUp || iface.isLoopback) continue
      val addresses = iface.inetAddresses
      for (address in addresses) {
        if (address is Inet4Address && !address.isLoopbackAddress) {
          return address.hostAddress
        }
      }
    }
    return null
  }
}
