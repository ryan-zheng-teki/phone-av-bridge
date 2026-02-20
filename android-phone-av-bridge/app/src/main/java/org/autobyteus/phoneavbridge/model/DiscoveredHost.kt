package org.autobyteus.phoneavbridge.model

data class DiscoveredHost(
  val baseUrl: String,
  val pairingCode: String,
  val hostId: String? = null,
  val displayName: String? = null,
  val platform: String? = null,
)
