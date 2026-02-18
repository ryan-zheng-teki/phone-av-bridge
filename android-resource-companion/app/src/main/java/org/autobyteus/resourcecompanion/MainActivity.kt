package org.autobyteus.resourcecompanion

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.util.Log
import android.widget.Button
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.materialswitch.MaterialSwitch
import org.autobyteus.resourcecompanion.device.DeviceIdentityResolver
import org.autobyteus.resourcecompanion.model.CameraLens
import org.autobyteus.resourcecompanion.model.CameraOrientationMode
import org.autobyteus.resourcecompanion.model.DiscoveredHost
import org.autobyteus.resourcecompanion.model.HostCapabilities
import org.autobyteus.resourcecompanion.model.ResourceToggleState
import org.autobyteus.resourcecompanion.network.HostApiClient
import org.autobyteus.resourcecompanion.network.HostDiscoveryClient
import org.autobyteus.resourcecompanion.network.LanAddressResolver
import org.autobyteus.resourcecompanion.service.ResourceService
import org.autobyteus.resourcecompanion.session.CompanionSessionStateMachine
import org.autobyteus.resourcecompanion.session.SessionState
import org.autobyteus.resourcecompanion.store.AppPrefs
import org.autobyteus.resourcecompanion.stream.PhoneRtspStreamer
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {
  private val logTag = "ResourceCompanionMain"
  private lateinit var statusText: TextView
  private lateinit var statusDetailText: TextView
  private lateinit var hostText: TextView
  private lateinit var issuesText: TextView
  private lateinit var pairButton: Button
  private lateinit var cameraSwitch: MaterialSwitch
  private lateinit var micSwitch: MaterialSwitch
  private lateinit var speakerSwitch: MaterialSwitch
  private lateinit var cameraLensGroup: RadioGroup
  private lateinit var cameraOrientationGroup: RadioGroup

  private val sessionStateMachine = CompanionSessionStateMachine()
  private val hostApiClient = HostApiClient()
  private val hostDiscoveryClient = HostDiscoveryClient()
  private val ioExecutor = Executors.newSingleThreadScheduledExecutor()
  private var pendingPermissionToggle: (() -> Unit)? = null
  private var isUpdatingUi = false
  private var pairingInProgress = false
  private var hostCapabilities = HostCapabilities()
  private var hostCapabilitiesLoaded = false
  private var hostStatusTicker: ScheduledFuture<*>? = null
  @Volatile private var lastHostStatus: HostApiClient.HostStatusSnapshot? = null
  @Volatile private var lastHostStatusError: String? = null
  @Volatile private var discoveredHostPreview: DiscoveredHost? = null
  @Volatile private var publishGeneration = 0
  private val localDeviceName by lazy { DeviceIdentityResolver.resolveDeviceName(this) }
  private val localDeviceId by lazy { DeviceIdentityResolver.resolveDeviceId(this) }

  private val permissionLauncher =
    registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
      val granted = result.values.all { it }
      if (granted) {
        pendingPermissionToggle?.invoke()
      } else {
        updateUiFromPrefs()
        Toast.makeText(this, getString(R.string.permission_denied_generic), Toast.LENGTH_SHORT).show()
      }
      pendingPermissionToggle = null
    }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)

    statusText = findViewById(R.id.statusText)
    statusDetailText = findViewById(R.id.statusDetailText)
    hostText = findViewById(R.id.hostText)
    issuesText = findViewById(R.id.issuesText)
    pairButton = findViewById(R.id.pairButton)
    cameraSwitch = findViewById(R.id.cameraSwitch)
    micSwitch = findViewById(R.id.micSwitch)
    speakerSwitch = findViewById(R.id.speakerSwitch)
    cameraLensGroup = findViewById(R.id.cameraLensGroup)
    cameraOrientationGroup = findViewById(R.id.cameraOrientationGroup)

    setupListeners()
    updateUiFromPrefs()
    refreshHostStatusIfPaired(applyServiceState = true)
    ioExecutor.execute { refreshHostPreviewIfUnpaired() }
    ensureHostStatusTicker()
  }

  override fun onDestroy() {
    hostStatusTicker?.cancel(true)
    hostStatusTicker = null
    ioExecutor.shutdown()
    ioExecutor.awaitTermination(500, TimeUnit.MILLISECONDS)
    super.onDestroy()
  }

  override fun onResume() {
    super.onResume()
    refreshHostStatusIfPaired(applyServiceState = true)
    ioExecutor.execute { refreshHostPreviewIfUnpaired() }
  }

  private fun setupListeners() {
    pairButton.setOnClickListener {
      if (pairingInProgress) return@setOnClickListener
      if (AppPrefs.isPaired(this)) {
        unpairHost()
      } else {
        pairHost()
      }
    }

    cameraSwitch.setOnCheckedChangeListener { _, enabled ->
      if (isUpdatingUi) return@setOnCheckedChangeListener
      if (!AppPrefs.isPaired(this)) {
        cameraSwitch.isChecked = false
        Toast.makeText(this, getString(R.string.must_pair_first), Toast.LENGTH_SHORT).show()
        return@setOnCheckedChangeListener
      }
      if (enabled && !hasPermission(Manifest.permission.CAMERA)) {
        pendingPermissionToggle = {
          AppPrefs.setCameraEnabled(this, true)
          updateUiFromPrefs()
          applyForegroundServiceState()
        }
        cameraSwitch.isChecked = false
        permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA))
        return@setOnCheckedChangeListener
      }
      AppPrefs.setCameraEnabled(this, enabled)
      applyForegroundServiceState()
    }

    micSwitch.setOnCheckedChangeListener { _, enabled ->
      if (isUpdatingUi) return@setOnCheckedChangeListener
      if (!AppPrefs.isPaired(this)) {
        micSwitch.isChecked = false
        Toast.makeText(this, getString(R.string.must_pair_first), Toast.LENGTH_SHORT).show()
        return@setOnCheckedChangeListener
      }
      if (enabled && !hasPermission(Manifest.permission.RECORD_AUDIO)) {
        pendingPermissionToggle = {
          AppPrefs.setMicEnabled(this, true)
          updateUiFromPrefs()
          applyForegroundServiceState()
        }
        micSwitch.isChecked = false
        permissionLauncher.launch(arrayOf(Manifest.permission.RECORD_AUDIO))
        return@setOnCheckedChangeListener
      }
      AppPrefs.setMicEnabled(this, enabled)
      applyForegroundServiceState()
    }

    speakerSwitch.setOnCheckedChangeListener { _, enabled ->
      if (isUpdatingUi) return@setOnCheckedChangeListener
      if (!AppPrefs.isPaired(this)) {
        speakerSwitch.isChecked = false
        Toast.makeText(this, getString(R.string.must_pair_first), Toast.LENGTH_SHORT).show()
        return@setOnCheckedChangeListener
      }
      AppPrefs.setSpeakerEnabled(this, enabled)
      applyForegroundServiceState()
    }

    cameraLensGroup.setOnCheckedChangeListener { _, checkedId ->
      if (isUpdatingUi) return@setOnCheckedChangeListener
      if (!AppPrefs.isPaired(this)) {
        updateUiFromPrefs()
        Toast.makeText(this, getString(R.string.must_pair_first), Toast.LENGTH_SHORT).show()
        return@setOnCheckedChangeListener
      }
      val selectedLens = if (checkedId == R.id.cameraLensFront) CameraLens.FRONT else CameraLens.BACK
      AppPrefs.setCameraLens(this, selectedLens)
      applyForegroundServiceState()
    }

    cameraOrientationGroup.setOnCheckedChangeListener { _, checkedId ->
      if (isUpdatingUi) return@setOnCheckedChangeListener
      if (!AppPrefs.isPaired(this)) {
        updateUiFromPrefs()
        Toast.makeText(this, getString(R.string.must_pair_first), Toast.LENGTH_SHORT).show()
        return@setOnCheckedChangeListener
      }
      val selectedMode = when (checkedId) {
        R.id.cameraOrientationPortrait -> CameraOrientationMode.PORTRAIT_LOCK
        R.id.cameraOrientationLandscape -> CameraOrientationMode.LANDSCAPE_LOCK
        else -> CameraOrientationMode.AUTO
      }
      AppPrefs.setCameraOrientationMode(this, selectedMode)
      applyForegroundServiceState()
    }
  }

  private fun pairHost() {
    pairingInProgress = true
    updateUiFromPrefs()
    pairButton.isEnabled = false

    ioExecutor.execute {
      try {
        sessionStateMachine.onPairStart()
        val host = discoverHostOrThrow()
        discoveredHostPreview = host
        hostApiClient.pair(
          baseUrl = host.baseUrl,
          pairCode = host.pairingCode,
          deviceName = localDeviceName,
          deviceId = localDeviceId,
        )

        AppPrefs.setHostBaseUrl(this, host.baseUrl)
        AppPrefs.setHostPairCode(this, host.pairingCode)
        AppPrefs.setPaired(this, true)
        sessionStateMachine.onPairSuccess()
        lastHostStatusError = null
        lastHostStatus = hostApiClient.fetchStatus(host.baseUrl).also {
          hostCapabilities = it.capabilities
          hostCapabilitiesLoaded = true
        }

        runOnUiThread {
          updateUiFromPrefs()
          applyForegroundServiceState()
          Toast.makeText(this, getString(R.string.pair_success), Toast.LENGTH_SHORT).show()
        }
      } catch (error: Exception) {
        AppPrefs.setPaired(this, false)
        sessionStateMachine.onUnpair()
        hostCapabilities = HostCapabilities()
        hostCapabilitiesLoaded = false
        lastHostStatus = null
        lastHostStatusError = error.message ?: "pair failed"
        runOnUiThread {
          updateUiFromPrefs()
          Toast.makeText(this, getString(resolvePairFailureMessageRes(error)), Toast.LENGTH_LONG).show()
        }
      } finally {
        runOnUiThread {
          pairingInProgress = false
          updateUiFromPrefs()
          pairButton.isEnabled = true
        }
      }
    }
  }

  private fun unpairHost() {
    pairingInProgress = true
    pairButton.isEnabled = false

    ioExecutor.execute {
      try {
        val hostBaseUrl = AppPrefs.getHostBaseUrl(this)
        if (hostBaseUrl.isNotBlank()) {
          try {
            hostApiClient.unpair(hostBaseUrl)
          } catch (_: Exception) {
            // Keep local unpair robust even when host is unreachable.
          }
        }
        AppPrefs.setPaired(this, false)
        AppPrefs.clearResourceToggles(this)
        sessionStateMachine.onUnpair()
        hostCapabilities = HostCapabilities()
        hostCapabilitiesLoaded = false
        lastHostStatus = null
        lastHostStatusError = null

        runOnUiThread {
          updateUiFromPrefs()
          applyForegroundServiceState()
          ioExecutor.execute { refreshHostPreviewIfUnpaired() }
        }
      } finally {
        runOnUiThread {
          pairingInProgress = false
          updateUiFromPrefs()
          pairButton.isEnabled = true
        }
      }
    }
  }

  private fun discoverHostOrThrow(): DiscoveredHost {
    hostDiscoveryClient.discover(timeoutMs = 2500)?.let { return it }
    hostDiscoveryClient.discover(timeoutMs = 4000)?.let { return it }

    val savedBaseUrl = AppPrefs.getHostBaseUrl(this)
    val savedPairCode = AppPrefs.getHostPairCode(this)
    if (savedBaseUrl.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      try {
        return hostApiClient.fetchBootstrap(savedBaseUrl)
      } catch (_: Exception) {
      }
    }
    if (savedBaseUrl.isNotBlank() && savedPairCode.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      return DiscoveredHost(savedBaseUrl, savedPairCode)
    }

    val bootstrapCandidates = if (isLikelyEmulator()) {
      listOf(
        "http://10.0.2.2:8787",
        "http://127.0.0.1:8787",
      )
    } else {
      emptyList()
    }
    bootstrapCandidates.forEach { candidate ->
      try {
        return hostApiClient.fetchBootstrap(candidate)
      } catch (_: Exception) {
      }
    }

    throw IllegalStateException("Host auto-discovery failed. Ensure host app is running on the same network.")
  }

  private fun updateUiFromPrefs() {
    val paired = AppPrefs.isPaired(this)
    pairButton.text = if (paired) getString(R.string.unpair_button) else getString(R.string.pair_button)
    if (!paired && sessionStateMachine.state != SessionState.DISCONNECTED) {
      sessionStateMachine.onUnpair()
    }

    val snapshot = lastHostStatus
    val degraded = paired && (
      lastHostStatusError != null ||
        snapshot == null ||
        !snapshot.paired ||
        snapshot.hostStatus.equals("Needs Attention", ignoreCase = true) ||
        snapshot.issues.isNotEmpty()
      )
    statusText.text = when {
      pairingInProgress -> getString(R.string.status_pairing)
      !paired -> getString(R.string.status_disconnected)
      degraded -> getString(R.string.status_connected_degraded)
      else -> getString(R.string.status_connected)
    }
    statusDetailText.text = when {
      pairingInProgress -> getString(R.string.status_detail_pairing)
      !paired -> getString(R.string.status_detail_disconnected)
      degraded -> getString(R.string.status_detail_degraded)
      else -> getString(R.string.status_detail_paired)
    }

    if (!paired) {
      hostText.text = resolveUnpairedHostSummary()
      issuesText.text = getString(R.string.issues_none)
      if (!pairingInProgress && hasKnownHostCandidate()) {
        statusDetailText.text = getString(R.string.status_detail_discovered_host)
      }
    } else {
      val hostBaseUrl = AppPrefs.getHostBaseUrl(this).ifBlank { "unknown host" }
      val phoneName = snapshot?.deviceName ?: localDeviceName
      hostText.text = getString(R.string.host_summary, hostBaseUrl, phoneName)
      val issueMessage = snapshot?.issues?.takeIf { it.isNotEmpty() }?.joinToString(" | ")
        ?: lastHostStatusError
      issuesText.text = if (issueMessage.isNullOrBlank()) {
        getString(R.string.issues_none)
      } else {
        getString(R.string.issues_prefix, issueMessage)
      }
    }

    isUpdatingUi = true
    cameraSwitch.isChecked = paired && AppPrefs.isCameraEnabled(this)
    micSwitch.isChecked = paired && AppPrefs.isMicEnabled(this)
    speakerSwitch.isChecked = paired && AppPrefs.isSpeakerEnabled(this)
    cameraSwitch.isEnabled = paired && (!hostCapabilitiesLoaded || hostCapabilities.camera)
    micSwitch.isEnabled = paired && (!hostCapabilitiesLoaded || hostCapabilities.microphone)
    speakerSwitch.isEnabled = paired && (!hostCapabilitiesLoaded || hostCapabilities.speaker)
    val selectedLens = AppPrefs.getCameraLens(this)
    val lensCheckId = if (selectedLens == CameraLens.FRONT) R.id.cameraLensFront else R.id.cameraLensBack
    cameraLensGroup.check(lensCheckId)
    cameraLensGroup.isEnabled = paired && (!hostCapabilitiesLoaded || hostCapabilities.camera)
    for (index in 0 until cameraLensGroup.childCount) {
      cameraLensGroup.getChildAt(index).isEnabled = cameraLensGroup.isEnabled
    }
    val orientationMode = AppPrefs.getCameraOrientationMode(this)
    val orientationCheckId = when (orientationMode) {
      CameraOrientationMode.PORTRAIT_LOCK -> R.id.cameraOrientationPortrait
      CameraOrientationMode.LANDSCAPE_LOCK -> R.id.cameraOrientationLandscape
      CameraOrientationMode.AUTO -> R.id.cameraOrientationAuto
    }
    cameraOrientationGroup.check(orientationCheckId)
    cameraOrientationGroup.isEnabled = paired && (!hostCapabilitiesLoaded || hostCapabilities.camera)
    for (index in 0 until cameraOrientationGroup.childCount) {
      cameraOrientationGroup.getChildAt(index).isEnabled = cameraOrientationGroup.isEnabled
    }
    isUpdatingUi = false
  }

  private fun applyForegroundServiceState() {
    val paired = AppPrefs.isPaired(this)
    if (!paired) {
      val intent = ResourceService.buildIntent(this, ResourceToggleState())
      stopService(intent)
      return
    }

    var cameraEnabled = AppPrefs.isCameraEnabled(this)
    var micEnabled = AppPrefs.isMicEnabled(this)
    val speakerEnabled = AppPrefs.isSpeakerEnabled(this)

    var prefsAdjusted = false
    if (hostCapabilitiesLoaded && cameraEnabled && !hostCapabilities.camera) {
      cameraEnabled = false
      AppPrefs.setCameraEnabled(this, false)
      prefsAdjusted = true
    }
    if (hostCapabilitiesLoaded && micEnabled && !hostCapabilities.microphone) {
      micEnabled = false
      AppPrefs.setMicEnabled(this, false)
      prefsAdjusted = true
    }
    var effectiveSpeakerEnabled = speakerEnabled
    if (hostCapabilitiesLoaded && effectiveSpeakerEnabled && !hostCapabilities.speaker) {
      effectiveSpeakerEnabled = false
      AppPrefs.setSpeakerEnabled(this, false)
      prefsAdjusted = true
    }
    if (cameraEnabled && !hasPermission(Manifest.permission.CAMERA)) {
      cameraEnabled = false
      AppPrefs.setCameraEnabled(this, false)
      prefsAdjusted = true
    }
    if (micEnabled && !hasPermission(Manifest.permission.RECORD_AUDIO)) {
      micEnabled = false
      AppPrefs.setMicEnabled(this, false)
      prefsAdjusted = true
    }
    if (prefsAdjusted) {
      updateUiFromPrefs()
    }

    val state = ResourceToggleState(
      cameraEnabled = cameraEnabled,
      microphoneEnabled = micEnabled,
      speakerEnabled = effectiveSpeakerEnabled,
      cameraLens = AppPrefs.getCameraLens(this),
      cameraOrientationMode = AppPrefs.getCameraOrientationMode(this),
      cameraStreamUrl = resolveCameraStreamUrl(cameraEnabled, micEnabled),
    )
    val intent = ResourceService.buildIntent(this, state)
    if (state.anyEnabled()) {
      ContextCompat.startForegroundService(this, intent)
    } else {
      stopService(intent)
    }

    val hostBaseUrl = AppPrefs.getHostBaseUrl(this)
    if (hostBaseUrl.isNotBlank()) {
      publishGeneration += 1
      publishTogglesWithRetry(
        hostBaseUrl = hostBaseUrl,
        state = state,
        generation = publishGeneration,
      )
    }
  }

  private fun publishTogglesWithRetry(
    hostBaseUrl: String,
    state: ResourceToggleState,
    generation: Int,
    attempt: Int = 0,
  ) {
    ioExecutor.execute {
      if (generation != publishGeneration) return@execute

      try {
        hostApiClient.publishToggles(
          baseUrl = hostBaseUrl,
          state = state,
          deviceName = localDeviceName,
          deviceId = localDeviceId,
        )
        runOnUiThread {
          if (generation == publishGeneration) {
            lastHostStatusError = null
            updateUiFromPrefs()
          }
        }
      } catch (error: Exception) {
        Log.w(logTag, "Toggle publish failed (attempt=$attempt, generation=$generation): ${error.message}")
        runOnUiThread {
          if (generation == publishGeneration) {
            lastHostStatusError = error.message ?: "publish failed"
            updateUiFromPrefs()
          }
        }
        if (attempt >= 3) return@execute
        ioExecutor.schedule(
          {
            publishTogglesWithRetry(
              hostBaseUrl = hostBaseUrl,
              state = state,
              generation = generation,
              attempt = attempt + 1,
            )
          },
          2,
          TimeUnit.SECONDS,
        )
      }
    }
  }

  private fun hasPermission(permission: String): Boolean {
    return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
  }

  private fun resolveCameraStreamUrl(cameraEnabled: Boolean, microphoneEnabled: Boolean): String? {
    if (!cameraEnabled && !microphoneEnabled) return null

    val cached = AppPrefs.getCameraStreamUrl(this).trim()
    if (cached.isNotBlank()) {
      return cached
    }

    val ip = LanAddressResolver.resolveIpv4Address() ?: return null
    return "rtsp://$ip:${PhoneRtspStreamer.DEFAULT_RTSP_PORT}/"
  }

  private fun refreshHostStatusIfPaired(applyServiceState: Boolean = false) {
    if (!AppPrefs.isPaired(this)) {
      hostCapabilities = HostCapabilities()
      hostCapabilitiesLoaded = false
      lastHostStatus = null
      lastHostStatusError = null
      if (applyServiceState) {
        val intent = ResourceService.buildIntent(this, ResourceToggleState())
        stopService(intent)
      }
      return
    }
    val hostBaseUrl = AppPrefs.getHostBaseUrl(this)
    if (hostBaseUrl.isBlank()) {
      hostCapabilities = HostCapabilities()
      hostCapabilitiesLoaded = false
      lastHostStatus = null
      lastHostStatusError = "missing host url"
      return
    }

    ioExecutor.execute {
      var hostConfirmsPaired = false
      var forceStopService = false
      var resourceDriftDetected = false
      val refreshed = try {
        val snapshot = hostApiClient.fetchStatus(hostBaseUrl)
        hostCapabilitiesLoaded = true
        hostCapabilities = snapshot.capabilities
        lastHostStatus = snapshot
        lastHostStatusError = null
        hostConfirmsPaired = snapshot.paired
        if (!snapshot.paired) {
          AppPrefs.setPaired(this, false)
          AppPrefs.clearResourceToggles(this)
          forceStopService = true
        } else {
          val desiredCamera = AppPrefs.isCameraEnabled(this)
          val desiredMic = AppPrefs.isMicEnabled(this)
          val desiredSpeaker = AppPrefs.isSpeakerEnabled(this)
          val desiredLens = AppPrefs.getCameraLens(this)
          val desiredOrientationMode = AppPrefs.getCameraOrientationMode(this)
          val cameraMetadataDrift = snapshot.hasCameraMetadata && (
            desiredLens != snapshot.cameraLens ||
              desiredOrientationMode != snapshot.cameraOrientationMode
            )
          resourceDriftDetected = desiredCamera != snapshot.cameraEnabled ||
            desiredMic != snapshot.microphoneEnabled ||
            desiredSpeaker != snapshot.speakerEnabled ||
            cameraMetadataDrift
        }
        true
      } catch (error: Exception) {
        hostCapabilitiesLoaded = false
        lastHostStatus = null
        lastHostStatusError = error.message ?: "status check failed"
        false
      }
      runOnUiThread {
        if (forceStopService) {
          val intent = ResourceService.buildIntent(this, ResourceToggleState())
          stopService(intent)
        }
        if (resourceDriftDetected) {
          lastHostStatusError = "Host sync drift detected. Retrying resource sync."
        }
        updateUiFromPrefs()
        if (resourceDriftDetected) {
          applyForegroundServiceState()
          return@runOnUiThread
        }
        if (!applyServiceState) return@runOnUiThread
        if (refreshed && hostConfirmsPaired) {
          applyForegroundServiceState()
        } else if (!AppPrefs.isPaired(this)) {
          val intent = ResourceService.buildIntent(this, ResourceToggleState())
          stopService(intent)
        }
      }
    }
  }

  private fun ensureHostStatusTicker() {
    if (hostStatusTicker != null && !hostStatusTicker!!.isCancelled) {
      return
    }
    hostStatusTicker = ioExecutor.scheduleAtFixedRate(
      {
        refreshHostStatusIfPaired(applyServiceState = false)
        refreshHostPreviewIfUnpaired()
      },
      3,
      5,
      TimeUnit.SECONDS,
    )
  }

  private fun refreshHostPreviewIfUnpaired() {
    if (AppPrefs.isPaired(this) || pairingInProgress) {
      return
    }
    val preview = discoverHostPreview()
    discoveredHostPreview = preview
    if (preview != null) {
      AppPrefs.setHostBaseUrl(this, preview.baseUrl)
      AppPrefs.setHostPairCode(this, preview.pairingCode)
      try {
        hostApiClient.publishPresence(
          baseUrl = preview.baseUrl,
          deviceName = localDeviceName,
          deviceId = localDeviceId,
        )
      } catch (error: Exception) {
        Log.w(logTag, "Presence publish failed: ${error.message}")
      }
    }
    runOnUiThread { updateUiFromPrefs() }
  }

  private fun discoverHostPreview(): DiscoveredHost? {
    hostDiscoveryClient.discover(timeoutMs = 1200)?.let { return it }

    val savedBaseUrl = AppPrefs.getHostBaseUrl(this)
    val savedPairCode = AppPrefs.getHostPairCode(this)
    if (savedBaseUrl.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      try {
        return hostApiClient.fetchBootstrap(savedBaseUrl)
      } catch (_: Exception) {
      }
    }
    if (savedBaseUrl.isNotBlank() && savedPairCode.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      return DiscoveredHost(savedBaseUrl, savedPairCode)
    }

    if (isLikelyEmulator()) {
      listOf("http://10.0.2.2:8787", "http://127.0.0.1:8787").forEach { candidate ->
        try {
          return hostApiClient.fetchBootstrap(candidate)
        } catch (_: Exception) {
        }
      }
    }
    return null
  }

  private fun hasKnownHostCandidate(): Boolean {
    if (discoveredHostPreview != null) return true
    val savedBaseUrl = AppPrefs.getHostBaseUrl(this).trim()
    return savedBaseUrl.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)
  }

  private fun resolveUnpairedHostSummary(): String {
    discoveredHostPreview?.let { host ->
      return getString(R.string.host_summary_discovered, host.baseUrl)
    }
    val savedBaseUrl = AppPrefs.getHostBaseUrl(this).trim()
    if (savedBaseUrl.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      return getString(R.string.host_summary_saved, savedBaseUrl)
    }
    return getString(R.string.host_summary_searching)
  }

  private fun resolvePairFailureMessageRes(error: Exception): Int {
    val message = (error.message ?: "").lowercase()
    return when {
      message.contains("auto-discovery failed") || message.contains("discover") -> R.string.pair_failed_discovery
      message.contains("refused") || message.contains("timed out") || message.contains("unreachable") -> R.string.pair_failed_unreachable
      message.contains("invalid pair code") || message.contains("request failed (400)") -> R.string.pair_failed_rejected
      else -> R.string.pair_failed_unknown
    }
  }

  private fun isLoopbackBaseUrl(baseUrl: String): Boolean {
    val normalized = baseUrl.trim().lowercase()
    return normalized.startsWith("http://127.0.0.1") ||
      normalized.startsWith("https://127.0.0.1") ||
      normalized.startsWith("http://localhost") ||
      normalized.startsWith("https://localhost")
  }

  private fun isLikelyEmulator(): Boolean {
    val fingerprint = Build.FINGERPRINT.lowercase()
    val model = Build.MODEL.lowercase()
    val product = Build.PRODUCT.lowercase()
    val manufacturer = Build.MANUFACTURER.lowercase()
    val brand = Build.BRAND.lowercase()
    val device = Build.DEVICE.lowercase()

    return fingerprint.contains("generic") ||
      fingerprint.contains("emulator") ||
      model.contains("sdk") ||
      model.contains("emulator") ||
      product.contains("sdk") ||
      manufacturer.contains("genymotion") ||
      (brand.startsWith("generic") && device.startsWith("generic"))
  }
}
