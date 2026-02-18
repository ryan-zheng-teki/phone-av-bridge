package org.autobyteus.resourcecompanion.stream

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import android.view.Surface
import androidx.annotation.RequiresApi
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.video.CameraOpenException
import com.pedro.rtspserver.RtspServerCamera2
import com.pedro.rtspserver.RtspServerOnlyAudio
import org.autobyteus.resourcecompanion.model.CameraLens
import org.autobyteus.resourcecompanion.model.CameraOrientationMode
import org.autobyteus.resourcecompanion.network.LanAddressResolver

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class PhoneRtspStreamer(
  context: Context,
  private val port: Int = DEFAULT_RTSP_PORT,
) {
  private data class VideoProfile(
    val width: Int,
    val height: Int,
    val fps: Int,
    val bitrate: Int,
    val iFrameIntervalSeconds: Int,
  )

  private val connectChecker = object : ConnectChecker {
    override fun onConnectionStarted(url: String) = Unit
    override fun onConnectionSuccess() = Unit
    override fun onConnectionFailed(reason: String) = Unit
    override fun onDisconnect() = Unit
    override fun onAuthError() = Unit
    override fun onAuthSuccess() = Unit
    override fun onNewBitrate(bitrate: Long) = Unit
  }

  private val appContext = context.applicationContext
  // Use background OpenGL pipeline to improve camera HAL compatibility.
  private var cameraServer = createCameraServer()
  private val audioOnlyServer = RtspServerOnlyAudio(connectChecker, port)
  private val cameraManager = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
  private val displayManager = appContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
  private var lastPreparedWithMic = false
  private var lastPreparedVideoRotation = -1
  private var activeMode = StreamMode.NONE
  private val preferredVideoProfiles = listOf(
    VideoProfile(width = 1280, height = 720, fps = 30, bitrate = 4_000_000, iFrameIntervalSeconds = 2),
    VideoProfile(width = 960, height = 540, fps = 30, bitrate = 2_500_000, iFrameIntervalSeconds = 2),
    VideoProfile(width = 640, height = 480, fps = 24, bitrate = 1_500_000, iFrameIntervalSeconds = 2),
  )

  fun update(
    cameraEnabled: Boolean,
    microphoneEnabled: Boolean,
    cameraLens: CameraLens,
    cameraOrientationMode: CameraOrientationMode,
  ): String? {
    if (cameraEnabled) {
      return startCameraMode(microphoneEnabled, cameraLens, cameraOrientationMode)
    }

    if (microphoneEnabled) {
      return startAudioOnlyMode()
    }

    stop()
    return null
  }

  fun stop() {
    if (cameraServer.isStreaming) {
      cameraServer.stopStream()
    }
    if (audioOnlyServer.isStreaming) {
      audioOnlyServer.stopStream()
    }
    activeMode = StreamMode.NONE
    lastPreparedWithMic = false
    lastPreparedVideoRotation = -1
  }

  private fun startCameraMode(
    microphoneEnabled: Boolean,
    cameraLens: CameraLens,
    cameraOrientationMode: CameraOrientationMode,
  ): String {
    if (audioOnlyServer.isStreaming) {
      audioOnlyServer.stopStream()
    }
    val targetRotation = resolveTargetVideoRotation(cameraLens, cameraOrientationMode)
    val mustReconfigureAudio = microphoneEnabled != lastPreparedWithMic
    val mustReconfigureVideo = targetRotation != lastPreparedVideoRotation
    val mustPrepare = !cameraServer.isStreaming || mustReconfigureAudio || mustReconfigureVideo || activeMode != StreamMode.CAMERA
    if (mustPrepare) {
      if (cameraServer.isStreaming) {
        cameraServer.stopStream()
      }
      if (!microphoneEnabled) {
        // RootEncoder can retain internal audio state from previous mic-enabled runs.
        // Recreate server for camera-only mode so startStream does not fail with
        // "AudioEncoder not prepared yet" on some devices.
        cameraServer = createCameraServer()
      }
      val videoPrepared = prepareCameraVideoWithFallbackProfiles(targetRotation)
      val audioPrepared = if (microphoneEnabled) {
        cameraServer.prepareAudio(
          AUDIO_BITRATE,
          AUDIO_SAMPLE_RATE,
          AUDIO_IS_STEREO,
          AUDIO_ECHO_CANCELLER,
          AUDIO_NOISE_SUPPRESSOR,
        )
      } else {
        true
      }
      if (!videoPrepared || !audioPrepared) {
        throw IllegalStateException("Unable to prepare phone RTSP camera stream.")
      }
      cameraServer.startStream()
      lastPreparedWithMic = microphoneEnabled
      lastPreparedVideoRotation = targetRotation
      activeMode = StreamMode.CAMERA
    }
    applyCameraLensSelection(cameraLens)
    // Audio encoder state is selected at prepare time. Avoid dynamic enable/disable
    // calls here because some devices throw "AudioEncoder not prepared yet" even
    // after stream start. We always re-prepare on mic mode change above.
    return resolvePublishedEndpoint(cameraServer.streamClient.getEndPointConnection())
  }

  private fun startAudioOnlyMode(): String {
    if (cameraServer.isStreaming) {
      cameraServer.stopStream()
    }
    val mustPrepare = !audioOnlyServer.isStreaming || activeMode != StreamMode.AUDIO_ONLY
    if (mustPrepare) {
      if (
        !audioOnlyServer.prepareAudio(
          AUDIO_BITRATE,
          AUDIO_SAMPLE_RATE,
          AUDIO_IS_STEREO,
          AUDIO_ECHO_CANCELLER,
          AUDIO_NOISE_SUPPRESSOR,
        )
      ) {
        throw IllegalStateException("Unable to prepare phone RTSP audio stream.")
      }
      audioOnlyServer.startStream()
      activeMode = StreamMode.AUDIO_ONLY
      lastPreparedVideoRotation = -1
    }
    return resolvePublishedEndpoint(audioOnlyServer.streamClient.getEndPointConnection())
  }

  private fun resolvePublishedEndpoint(rawEndpoint: String?): String {
    val lanIpv4 = LanAddressResolver.resolveIpv4Address()
    if (!lanIpv4.isNullOrBlank()) {
      return "rtsp://$lanIpv4:$port/"
    }
    val raw = rawEndpoint?.trim()
    if (!raw.isNullOrBlank()) {
      return raw
    }
    throw IllegalStateException("Unable to resolve a reachable RTSP endpoint.")
  }

  companion object {
    const val DEFAULT_RTSP_PORT = 1935
    private const val AUDIO_BITRATE = 96 * 1024
    private const val AUDIO_SAMPLE_RATE = 48_000
    private const val AUDIO_IS_STEREO = false
    private const val AUDIO_ECHO_CANCELLER = false
    private const val AUDIO_NOISE_SUPPRESSOR = true
  }

  private enum class StreamMode {
    NONE,
    CAMERA,
    AUDIO_ONLY,
  }

  private fun prepareCameraVideoWithFallbackProfiles(rotationDegrees: Int): Boolean {
    preferredVideoProfiles.forEach { profile ->
      if (
        cameraServer.prepareVideo(
          profile.width,
          profile.height,
          profile.fps,
          profile.bitrate,
          profile.iFrameIntervalSeconds,
          rotationDegrees,
        )
      ) {
        return true
      }
    }
    return false
  }

  private fun createCameraServer(): RtspServerCamera2 {
    return RtspServerCamera2(appContext, true, connectChecker, port)
  }

  private fun applyCameraLensSelection(lens: CameraLens) {
    val desiredCameraId = resolveCameraId(lens)
      ?: throw IllegalStateException("Selected camera lens is unavailable: ${lens.storageValue}.")
    val currentFacing = detectCurrentCameraFacing()
    if (currentFacing == lens) {
      return
    }
    try {
      cameraServer.switchCamera(desiredCameraId)
    } catch (error: CameraOpenException) {
      throw IllegalStateException("Unable to switch to ${lens.storageValue} camera.", error)
    }
  }

  private fun resolveTargetVideoRotation(lens: CameraLens, mode: CameraOrientationMode): Int {
    val rotationForFormula = when (mode) {
      CameraOrientationMode.AUTO -> currentDeviceRotationDegrees()
      CameraOrientationMode.PORTRAIT_LOCK -> 0
      CameraOrientationMode.LANDSCAPE_LOCK -> 90
    }
    val sensorOrientation = resolveSensorOrientation(lens)
    val computed = if (lens == CameraLens.FRONT) {
      val result = (sensorOrientation + rotationForFormula) % 360
      (360 - result) % 360
    } else {
      (sensorOrientation - rotationForFormula + 360) % 360
    }
    return computed.normalizeToRightAngle()
  }

  private fun currentDeviceRotationDegrees(): Int {
    val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
    return when (display?.rotation ?: Surface.ROTATION_0) {
      Surface.ROTATION_90 -> 90
      Surface.ROTATION_180 -> 180
      Surface.ROTATION_270 -> 270
      else -> 0
    }
  }

  private fun resolveSensorOrientation(lens: CameraLens): Int {
    val cameraId = resolveCameraId(lens) ?: return 90
    val characteristics = cameraManager.getCameraCharacteristics(cameraId)
    return characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
  }

  private fun Int.normalizeToRightAngle(): Int {
    val normalized = ((this % 360) + 360) % 360
    return when {
      normalized < 45 -> 0
      normalized < 135 -> 90
      normalized < 225 -> 180
      normalized < 315 -> 270
      else -> 0
    }
  }

  private fun detectCurrentCameraFacing(): CameraLens? {
    val characteristics = cameraServer.cameraCharacteristics
    val facing = characteristics?.get(CameraCharacteristics.LENS_FACING) ?: return null
    return when (facing) {
      CameraCharacteristics.LENS_FACING_FRONT -> CameraLens.FRONT
      CameraCharacteristics.LENS_FACING_BACK -> CameraLens.BACK
      else -> null
    }
  }

  private fun resolveCameraId(lens: CameraLens): String? {
    val expectedFacing = when (lens) {
      CameraLens.BACK -> CameraCharacteristics.LENS_FACING_BACK
      CameraLens.FRONT -> CameraCharacteristics.LENS_FACING_FRONT
    }
    return cameraManager.cameraIdList.firstOrNull { id ->
      val characteristics = cameraManager.getCameraCharacteristics(id)
      characteristics.get(CameraCharacteristics.LENS_FACING) == expectedFacing
    }
  }
}
