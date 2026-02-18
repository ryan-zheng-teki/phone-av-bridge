package org.autobyteus.resourcecompanion.device

import android.content.Context
import android.os.Build
import android.provider.Settings
import java.util.Locale

object DeviceIdentityResolver {
  fun resolveDeviceName(context: Context): String {
    val configured = Settings.Global.getString(context.contentResolver, "device_name")?.trim().orEmpty()
    if (configured.isNotBlank()) return configured.take(48)

    val manufacturer = Build.MANUFACTURER?.trim().orEmpty()
    val model = Build.MODEL?.trim().orEmpty()
    val fallback = listOf(manufacturer, model).filter { it.isNotBlank() }.joinToString(" ").trim()
    return (if (fallback.isBlank()) "Android Phone" else fallback).take(48)
  }

  fun resolveDeviceId(context: Context): String {
    val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
      ?.trim()
      .orEmpty()
    if (androidId.isNotBlank()) {
      return "android-$androidId".lowercase(Locale.ROOT).take(72)
    }

    val fallback = "${Build.BRAND}-${Build.MODEL}-${Build.DEVICE}".lowercase(Locale.ROOT)
    val compact = fallback.replace(Regex("[^a-z0-9_-]"), "")
    return "android-${compact.ifBlank { "unknown" }}".take(72)
  }
}
