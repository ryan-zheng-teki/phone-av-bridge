package org.autobyteus.resourcecompanion.model

data class HostCapabilities(
  val camera: Boolean = true,
  val microphone: Boolean = true,
  val speaker: Boolean = false,
)
