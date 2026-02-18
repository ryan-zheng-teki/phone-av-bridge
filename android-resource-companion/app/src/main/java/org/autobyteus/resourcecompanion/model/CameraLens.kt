package org.autobyteus.resourcecompanion.model

enum class CameraLens(val storageValue: String) {
  BACK("back"),
  FRONT("front");

  companion object {
    fun fromStorage(value: String?): CameraLens {
      return when (value?.trim()?.lowercase()) {
        FRONT.storageValue -> FRONT
        else -> BACK
      }
    }
  }
}
