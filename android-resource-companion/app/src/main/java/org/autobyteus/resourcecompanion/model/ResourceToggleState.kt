package org.autobyteus.resourcecompanion.model

data class ResourceToggleState(
  val cameraEnabled: Boolean = false,
  val microphoneEnabled: Boolean = false,
  val speakerEnabled: Boolean = false,
  val cameraLens: CameraLens = CameraLens.BACK,
  val cameraOrientationMode: CameraOrientationMode = CameraOrientationMode.AUTO,
  val cameraStreamUrl: String? = null,
) {
  fun anyEnabled(): Boolean = cameraEnabled || microphoneEnabled || speakerEnabled

  fun enabledLabels(): String {
    val parts = mutableListOf<String>()
    if (cameraEnabled) parts += "camera"
    if (microphoneEnabled) parts += "microphone"
    if (speakerEnabled) parts += "speaker"
    return if (parts.isEmpty()) "none" else parts.joinToString(", ")
  }
}
