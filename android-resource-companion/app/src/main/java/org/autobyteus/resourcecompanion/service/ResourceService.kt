package org.autobyteus.resourcecompanion.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.autobyteus.resourcecompanion.R
import org.autobyteus.resourcecompanion.device.DeviceIdentityResolver
import org.autobyteus.resourcecompanion.model.CameraLens
import org.autobyteus.resourcecompanion.model.CameraOrientationMode
import org.autobyteus.resourcecompanion.model.ResourceToggleState
import org.autobyteus.resourcecompanion.network.HostApiClient
import org.autobyteus.resourcecompanion.speaker.HostSpeakerStreamPlayer
import org.autobyteus.resourcecompanion.store.AppPrefs
import org.autobyteus.resourcecompanion.stream.PhoneRtspStreamer
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class ResourceService : Service() {
  private val logTag = "ResourceCompanionSvc"
  private var phoneRtspStreamer: PhoneRtspStreamer? = null
  private var hostSpeakerStreamPlayer: HostSpeakerStreamPlayer? = null
  private val hostApiClient = HostApiClient()
  private val ioExecutor = Executors.newSingleThreadScheduledExecutor()
  private var publishTicker: ScheduledFuture<*>? = null
  @Volatile private var currentState = ResourceToggleState()
  private val localDeviceName by lazy { DeviceIdentityResolver.resolveDeviceName(this) }
  private val localDeviceId by lazy { DeviceIdentityResolver.resolveDeviceId(this) }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val requestedState = ResourceToggleState(
      cameraEnabled = intent?.getBooleanExtra(EXTRA_CAMERA_ENABLED, false) ?: false,
      microphoneEnabled = intent?.getBooleanExtra(EXTRA_MIC_ENABLED, false) ?: false,
      speakerEnabled = intent?.getBooleanExtra(EXTRA_SPEAKER_ENABLED, false) ?: false,
      cameraLens = CameraLens.fromStorage(intent?.getStringExtra(EXTRA_CAMERA_LENS)),
      cameraOrientationMode = CameraOrientationMode.fromStorage(intent?.getStringExtra(EXTRA_CAMERA_ORIENTATION_MODE)),
    )

    if (!requestedState.anyEnabled()) {
      currentState = ResourceToggleState()
      publishStateToHost(currentState)
      phoneRtspStreamer?.stop()
      hostSpeakerStreamPlayer?.stop()
      stopPublishTicker()
      AppPrefs.clearCameraStreamUrl(this)
      stopForeground(STOP_FOREGROUND_REMOVE)
      stopSelf()
      return START_NOT_STICKY
    }

    val synchronizedState = syncPhoneMediaRoutes(requestedState)
    currentState = synchronizedState
    ensureChannel()
    ServiceCompat.startForeground(
      this,
      NOTIFICATION_ID,
      buildNotification(synchronizedState),
      serviceTypeMask(synchronizedState),
    )
    publishStateToHost(synchronizedState)
    ensurePublishTicker()
    return START_STICKY
  }

  override fun onDestroy() {
    stopPublishTicker()
    ioExecutor.shutdownNow()
    phoneRtspStreamer?.stop()
    hostSpeakerStreamPlayer?.stop()
    super.onDestroy()
  }

  private fun buildNotification(state: ResourceToggleState): Notification {
    val text = getString(R.string.notification_text_active, state.enabledLabels())
    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(android.R.drawable.stat_notify_sync)
      .setContentTitle(getString(R.string.notification_title))
      .setContentText(text)
      .setOngoing(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
  }

  private fun ensureChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val channel = NotificationChannel(
      CHANNEL_ID,
      getString(R.string.notification_channel_name),
      NotificationManager.IMPORTANCE_LOW,
    )
    manager.createNotificationChannel(channel)
  }

  companion object {
    const val EXTRA_CAMERA_ENABLED = "extra_camera_enabled"
    const val EXTRA_MIC_ENABLED = "extra_mic_enabled"
    const val EXTRA_SPEAKER_ENABLED = "extra_speaker_enabled"
    const val EXTRA_CAMERA_LENS = "extra_camera_lens"
    const val EXTRA_CAMERA_ORIENTATION_MODE = "extra_camera_orientation_mode"

    private const val CHANNEL_ID = "resource_companion_channel"
    private const val NOTIFICATION_ID = 1001

    private fun serviceTypeMask(state: ResourceToggleState): Int {
      var mask = 0
      if (state.cameraEnabled) {
        mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
      }
      if (state.microphoneEnabled) {
        mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
      }
      if (state.speakerEnabled) {
        mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
      }
      return if (mask == 0) ServiceInfo.FOREGROUND_SERVICE_TYPE_MANIFEST else mask
    }

    fun buildIntent(
      context: Context,
      state: ResourceToggleState,
    ): Intent {
      return Intent(context, ResourceService::class.java)
        .putExtra(EXTRA_CAMERA_ENABLED, state.cameraEnabled)
        .putExtra(EXTRA_MIC_ENABLED, state.microphoneEnabled)
        .putExtra(EXTRA_SPEAKER_ENABLED, state.speakerEnabled)
        .putExtra(EXTRA_CAMERA_LENS, state.cameraLens.storageValue)
        .putExtra(EXTRA_CAMERA_ORIENTATION_MODE, state.cameraOrientationMode.storageValue)
    }
  }

  private fun syncPhoneMediaRoutes(state: ResourceToggleState): ResourceToggleState {
    var streamUrl: String? = null
    try {
      val streamer = phoneRtspStreamer ?: PhoneRtspStreamer(applicationContext).also { phoneRtspStreamer = it }
      streamUrl = streamer.update(
        cameraEnabled = state.cameraEnabled,
        microphoneEnabled = state.microphoneEnabled,
        cameraLens = state.cameraLens,
        cameraOrientationMode = state.cameraOrientationMode,
      )
      if (streamUrl.isNullOrBlank()) {
        AppPrefs.clearCameraStreamUrl(this)
      } else {
        AppPrefs.setCameraStreamUrl(this, streamUrl)
      }
    } catch (error: Exception) {
      Log.w(logTag, "RTSP sync failed: ${error.message}")
      AppPrefs.clearCameraStreamUrl(this)
      streamUrl = null
    }

    val speakerPlayer = hostSpeakerStreamPlayer ?: HostSpeakerStreamPlayer().also { hostSpeakerStreamPlayer = it }
    if (!state.speakerEnabled) {
      speakerPlayer.stop()
      return state.copy(cameraStreamUrl = streamUrl)
    }

    val hostBaseUrl = AppPrefs.getHostBaseUrl(this).trim()
    if (hostBaseUrl.isBlank()) {
      speakerPlayer.stop()
      return state.copy(cameraStreamUrl = streamUrl)
    }
    speakerPlayer.start(hostBaseUrl)
    return state.copy(cameraStreamUrl = streamUrl)
  }

  private fun publishStateToHost(state: ResourceToggleState) {
    val hostBaseUrl = AppPrefs.getHostBaseUrl(this).trim()
    if (hostBaseUrl.isBlank()) {
      return
    }

    ioExecutor.execute {
      try {
        hostApiClient.publishToggles(
          baseUrl = hostBaseUrl,
          state = state,
          deviceName = localDeviceName,
          deviceId = localDeviceId,
        )
      } catch (error: Exception) {
        Log.w(logTag, "Service publish failed: ${error.message}")
      }
    }
  }

  private fun ensurePublishTicker() {
    if (publishTicker != null && !publishTicker!!.isCancelled) {
      return
    }
    publishTicker = ioExecutor.scheduleAtFixedRate(
      { publishStateToHost(currentState) },
      3,
      3,
      TimeUnit.SECONDS,
    )
  }

  private fun stopPublishTicker() {
    publishTicker?.cancel(true)
    publishTicker = null
  }
}
