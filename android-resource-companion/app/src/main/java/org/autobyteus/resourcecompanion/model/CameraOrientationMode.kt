package org.autobyteus.resourcecompanion.model

enum class CameraOrientationMode(val storageValue: String) {
  AUTO("auto"),
  PORTRAIT_LOCK("portrait_lock"),
  LANDSCAPE_LOCK("landscape_lock");

  companion object {
    fun fromStorage(value: String?): CameraOrientationMode {
      return when (value?.trim()?.lowercase()) {
        PORTRAIT_LOCK.storageValue -> PORTRAIT_LOCK
        LANDSCAPE_LOCK.storageValue -> LANDSCAPE_LOCK
        else -> AUTO
      }
    }
  }
}
