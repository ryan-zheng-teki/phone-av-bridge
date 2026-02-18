package org.autobyteus.phoneavbridge.store

import android.content.Context
import org.autobyteus.phoneavbridge.model.CameraLens
import org.autobyteus.phoneavbridge.model.CameraOrientationMode

object AppPrefs {
  private const val PREF_NAME = "phone_av_bridge_prefs"
  private const val KEY_PAIRED = "paired"
  private const val KEY_CAMERA = "camera_enabled"
  private const val KEY_MIC = "mic_enabled"
  private const val KEY_SPEAKER = "speaker_enabled"
  private const val KEY_HOST_BASE_URL = "host_base_url"
  private const val KEY_HOST_PAIR_CODE = "host_pair_code"
  private const val KEY_CAMERA_STREAM_URL = "camera_stream_url"
  private const val KEY_CAMERA_LENS = "camera_lens"
  private const val KEY_CAMERA_ORIENTATION_MODE = "camera_orientation_mode"

  fun getPrefs(context: Context) =
    context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

  fun isPaired(context: Context): Boolean = getPrefs(context).getBoolean(KEY_PAIRED, false)
  fun setPaired(context: Context, value: Boolean) = getPrefs(context).edit().putBoolean(KEY_PAIRED, value).apply()

  fun isCameraEnabled(context: Context): Boolean = getPrefs(context).getBoolean(KEY_CAMERA, false)
  fun setCameraEnabled(context: Context, value: Boolean) = getPrefs(context).edit().putBoolean(KEY_CAMERA, value).apply()

  fun isMicEnabled(context: Context): Boolean = getPrefs(context).getBoolean(KEY_MIC, false)
  fun setMicEnabled(context: Context, value: Boolean) = getPrefs(context).edit().putBoolean(KEY_MIC, value).apply()

  fun isSpeakerEnabled(context: Context): Boolean = getPrefs(context).getBoolean(KEY_SPEAKER, false)
  fun setSpeakerEnabled(context: Context, value: Boolean) = getPrefs(context).edit().putBoolean(KEY_SPEAKER, value).apply()

  fun clearResourceToggles(context: Context) {
    getPrefs(context).edit()
      .putBoolean(KEY_CAMERA, false)
      .putBoolean(KEY_MIC, false)
      .putBoolean(KEY_SPEAKER, false)
      .remove(KEY_CAMERA_STREAM_URL)
      .apply()
  }

  fun clearAll(context: Context) {
    getPrefs(context).edit().clear().apply()
  }

  fun getHostBaseUrl(context: Context): String = getPrefs(context).getString(KEY_HOST_BASE_URL, "") ?: ""
  fun setHostBaseUrl(context: Context, value: String) = getPrefs(context).edit().putString(KEY_HOST_BASE_URL, value).apply()

  fun getHostPairCode(context: Context): String = getPrefs(context).getString(KEY_HOST_PAIR_CODE, "") ?: ""
  fun setHostPairCode(context: Context, value: String) = getPrefs(context).edit().putString(KEY_HOST_PAIR_CODE, value).apply()

  fun getCameraStreamUrl(context: Context): String = getPrefs(context).getString(KEY_CAMERA_STREAM_URL, "") ?: ""
  fun setCameraStreamUrl(context: Context, value: String) = getPrefs(context).edit().putString(KEY_CAMERA_STREAM_URL, value).apply()
  fun clearCameraStreamUrl(context: Context) = getPrefs(context).edit().remove(KEY_CAMERA_STREAM_URL).apply()

  fun getCameraLens(context: Context): CameraLens =
    CameraLens.fromStorage(getPrefs(context).getString(KEY_CAMERA_LENS, CameraLens.BACK.storageValue))

  fun setCameraLens(context: Context, value: CameraLens) =
    getPrefs(context).edit().putString(KEY_CAMERA_LENS, value.storageValue).apply()

  fun getCameraOrientationMode(context: Context): CameraOrientationMode =
    CameraOrientationMode.fromStorage(
      getPrefs(context).getString(KEY_CAMERA_ORIENTATION_MODE, CameraOrientationMode.AUTO.storageValue),
    )

  fun setCameraOrientationMode(context: Context, value: CameraOrientationMode) =
    getPrefs(context).edit().putString(KEY_CAMERA_ORIENTATION_MODE, value.storageValue).apply()

  fun clearHost(context: Context) {
    getPrefs(context).edit()
      .remove(KEY_HOST_BASE_URL)
      .remove(KEY_HOST_PAIR_CODE)
      .apply()
  }
}
