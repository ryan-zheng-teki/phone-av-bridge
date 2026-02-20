package org.autobyteus.phoneavbridge

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
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.google.android.material.materialswitch.MaterialSwitch
import org.autobyteus.phoneavbridge.device.DeviceIdentityResolver
import org.autobyteus.phoneavbridge.model.CameraLens
import org.autobyteus.phoneavbridge.model.CameraOrientationMode
import org.autobyteus.phoneavbridge.model.DiscoveredHost
import org.autobyteus.phoneavbridge.model.HostCapabilities
import org.autobyteus.phoneavbridge.model.ResourceToggleState
import org.autobyteus.phoneavbridge.network.HostApiClient
import org.autobyteus.phoneavbridge.network.HostDiscoveryClient
import org.autobyteus.phoneavbridge.network.LanAddressResolver
import org.autobyteus.phoneavbridge.pairing.PairingCoordinator
import org.autobyteus.phoneavbridge.publish.ResourcePublishCoordinator
import org.autobyteus.phoneavbridge.service.ResourceService
import org.autobyteus.phoneavbridge.sync.HostStateRefresher
import org.autobyteus.phoneavbridge.session.BridgeSessionStateMachine
import org.autobyteus.phoneavbridge.session.SessionState
import org.autobyteus.phoneavbridge.store.AppPrefs
import org.autobyteus.phoneavbridge.stream.PhoneRtspStreamer
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {
  private val logTag = "PhoneAvBridgeMain"
  private lateinit var statusText: TextView
  private lateinit var statusDetailText: TextView
  private lateinit var hostText: TextView
  private lateinit var issuesText: TextView
  private lateinit var pairButton: Button
  private lateinit var scanQrButton: Button
  private lateinit var cameraSwitch: MaterialSwitch
  private lateinit var micSwitch: MaterialSwitch
  private lateinit var speakerSwitch: MaterialSwitch
  private lateinit var cameraLensGroup: RadioGroup
  private lateinit var cameraOrientationGroup: RadioGroup

  private val sessionStateMachine = BridgeSessionStateMachine()
  private val hostApiClient = HostApiClient()
  private val hostDiscoveryClient = HostDiscoveryClient()
  private val pairingCoordinator = PairingCoordinator(hostApiClient, hostDiscoveryClient)
  private val hostStateRefresher = HostStateRefresher(hostApiClient, hostDiscoveryClient)
  private val ioExecutor = Executors.newSingleThreadScheduledExecutor()
  private lateinit var resourcePublishCoordinator: ResourcePublishCoordinator
  private var pendingPermissionToggle: (() -> Unit)? = null
  private var isUpdatingUi = false
  private var pairingInProgress = false
  private var hostCapabilities = HostCapabilities()
  private var hostCapabilitiesLoaded = false
  private var hostStatusTicker: ScheduledFuture<*>? = null
  @Volatile private var lastHostStatus: HostApiClient.HostStatusSnapshot? = null
  @Volatile private var lastHostStatusError: String? = null
  @Volatile private var discoveredHostPreview: DiscoveredHost? = null
  @Volatile private var discoveredHostCandidates: List<DiscoveredHost> = emptyList()
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

  private val qrScanLauncher =
    registerForActivityResult(ScanContract()) { result ->
      val contents = result.contents?.trim().orEmpty()
      if (contents.isBlank()) {
        Log.i(logTag, "QR scan result empty/cancelled")
        return@registerForActivityResult
      }
      Log.i(logTag, "QR scan captured payloadLength=${contents.length}")
      beginQrPairingFlow(contents)
    }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)

    statusText = findViewById(R.id.statusText)
    statusDetailText = findViewById(R.id.statusDetailText)
    hostText = findViewById(R.id.hostText)
    issuesText = findViewById(R.id.issuesText)
    pairButton = findViewById(R.id.pairButton)
    scanQrButton = findViewById(R.id.scanQrButton)
    cameraSwitch = findViewById(R.id.cameraSwitch)
    micSwitch = findViewById(R.id.micSwitch)
    speakerSwitch = findViewById(R.id.speakerSwitch)
    cameraLensGroup = findViewById(R.id.cameraLensGroup)
    cameraOrientationGroup = findViewById(R.id.cameraOrientationGroup)
    resourcePublishCoordinator = ResourcePublishCoordinator(
      hostApiClient = hostApiClient,
      ioExecutor = ioExecutor,
      localDeviceName = localDeviceName,
      localDeviceId = localDeviceId,
      logTag = logTag,
    )

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
        beginPairSelectionFlow()
      }
    }

    scanQrButton.setOnClickListener {
      if (pairingInProgress) return@setOnClickListener
      if (AppPrefs.isPaired(this)) {
        Toast.makeText(this, getString(R.string.scan_qr_requires_unpair), Toast.LENGTH_SHORT).show()
        return@setOnClickListener
      }
      launchQrScan()
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

  private fun launchQrScan() {
    if (!hasPermission(Manifest.permission.CAMERA)) {
      pendingPermissionToggle = { launchQrScan() }
      permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA))
      return
    }
    val options = ScanOptions()
      .setDesiredBarcodeFormats(ScanOptions.QR_CODE)
      .setPrompt(getString(R.string.scan_qr_prompt))
      .setBeepEnabled(true)
      .setBarcodeImageEnabled(false)
      .setOrientationLocked(false)
    qrScanLauncher.launch(options)
  }

  private fun beginQrPairingFlow(rawPayload: String) {
    val payload = pairingCoordinator.parseQrPayload(rawPayload)
    if (payload == null) {
      val preview = rawPayload.take(120).replace("\n", " ")
      Log.w(logTag, "QR parse failed. payloadPreview=$preview")
      Toast.makeText(this, getString(R.string.scan_qr_invalid), Toast.LENGTH_LONG).show()
      return
    }

    Log.i(logTag, "QR parse success baseUrl=${payload.baseUrl}")

    pairingInProgress = true
    updateUiFromPrefs()

    ioExecutor.execute {
      try {
        val host = pairingCoordinator.redeemQrPayload(payload)
        Log.i(logTag, "QR redeem success baseUrl=${host.baseUrl}")
        discoveredHostPreview = host
        discoveredHostCandidates = listOf(host)
        runOnUiThread {
          pairingInProgress = false
          updateUiFromPrefs()
          pairHost(host)
        }
      } catch (error: Exception) {
        lastHostStatusError = error.message ?: "pair failed"
        Log.w(logTag, "QR redeem/pair failed: ${error.message}", error)
        runOnUiThread {
          pairingInProgress = false
          updateUiFromPrefs()
          val resolved = resolvePairFailureMessageRes(error)
          if (resolved == R.string.pair_failed_unknown) {
            Toast.makeText(this, getString(R.string.pair_failed, error.message ?: "unknown"), Toast.LENGTH_LONG).show()
          } else {
            Toast.makeText(this, getString(resolved), Toast.LENGTH_LONG).show()
          }
        }
      }
    }
  }

  private fun beginPairSelectionFlow() {
    pairingInProgress = true
    updateUiFromPrefs()
    pairButton.isEnabled = false

    ioExecutor.execute {
      try {
        val hosts = pairingCoordinator.discoverHostsForPair(
          savedBaseUrl = AppPrefs.getHostBaseUrl(this),
          savedPairCode = AppPrefs.getHostPairCode(this),
          isLikelyEmulator = isLikelyEmulator(),
          isLoopbackBaseUrl = ::isLoopbackBaseUrl,
        )
        discoveredHostCandidates = hosts
        runOnUiThread {
          pairingInProgress = false
          updateUiFromPrefs()
          pairButton.isEnabled = true
          when {
            hosts.isEmpty() -> {
              Toast.makeText(this, getString(R.string.pair_failed_discovery), Toast.LENGTH_LONG).show()
            }
            hosts.size == 1 -> {
              pairHost(hosts[0])
            }
            else -> {
              showHostSelectionDialog(hosts)
            }
          }
        }
      } catch (error: Exception) {
        lastHostStatusError = error.message ?: "pair failed"
        runOnUiThread {
          pairingInProgress = false
          updateUiFromPrefs()
          pairButton.isEnabled = true
          Toast.makeText(this, getString(resolvePairFailureMessageRes(error)), Toast.LENGTH_LONG).show()
        }
      }
    }
  }

  private fun showHostSelectionDialog(hosts: List<DiscoveredHost>) {
    val labels = hosts.map { formatHostLabel(it) }.toTypedArray()
    var selectedIndex = hosts.indexOfFirst { it.baseUrl == discoveredHostPreview?.baseUrl }
    if (selectedIndex < 0) {
      selectedIndex = 0
    }

    AlertDialog.Builder(this)
      .setTitle(R.string.select_host_title)
      .setSingleChoiceItems(labels, selectedIndex) { _, which ->
        selectedIndex = which
      }
      .setPositiveButton(R.string.select_host_confirm_button) { _, _ ->
        pairHost(hosts[selectedIndex])
      }
      .setNegativeButton(android.R.string.cancel, null)
      .show()
  }

  private fun formatHostLabel(host: DiscoveredHost): String {
    val name = host.displayName?.trim().orEmpty().ifBlank { host.baseUrl }
    val platform = host.platform?.trim().orEmpty().ifBlank { "host" }
    return "$name ($platform)\n${host.baseUrl}"
  }

  private fun pairHost(host: DiscoveredHost) {
    pairingInProgress = true
    updateUiFromPrefs()
    pairButton.isEnabled = false

    ioExecutor.execute {
      try {
        sessionStateMachine.onPairStart()
        val pairResult = pairingCoordinator.pairHost(
          host = host,
          deviceName = localDeviceName,
          deviceId = localDeviceId,
        )
        discoveredHostPreview = pairResult.host

        AppPrefs.setHostBaseUrl(this, pairResult.host.baseUrl)
        AppPrefs.setHostPairCode(this, pairResult.host.pairingCode)
        AppPrefs.setPaired(this, true)
        sessionStateMachine.onPairSuccess()
        lastHostStatusError = null
        lastHostStatus = pairResult.snapshot.also {
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
        try {
          pairingCoordinator.unpairHost(AppPrefs.getHostBaseUrl(this))
        } catch (_: Exception) {
          // Keep local unpair robust even when host is unreachable.
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

  private fun updateUiFromPrefs() {
    val paired = AppPrefs.isPaired(this)
    pairButton.text = if (paired) getString(R.string.unpair_button) else getString(R.string.pair_button)
    pairButton.isEnabled = !pairingInProgress
    scanQrButton.isEnabled = !pairingInProgress && !paired
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
      resourcePublishCoordinator.publishWithRetry(
        hostBaseUrl = hostBaseUrl,
        state = state,
        onSuccess = {
          runOnUiThread {
            lastHostStatusError = null
            updateUiFromPrefs()
          }
        },
        onFailure = { message ->
          runOnUiThread {
            lastHostStatusError = message
            updateUiFromPrefs()
          }
        },
      )
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
      val refreshResult = hostStateRefresher.refreshPairedHost(
        HostStateRefresher.RefreshRequest(
          hostBaseUrl = hostBaseUrl,
          desiredCameraEnabled = AppPrefs.isCameraEnabled(this),
          desiredMicrophoneEnabled = AppPrefs.isMicEnabled(this),
          desiredSpeakerEnabled = AppPrefs.isSpeakerEnabled(this),
          desiredLens = AppPrefs.getCameraLens(this),
          desiredOrientationMode = AppPrefs.getCameraOrientationMode(this),
        ),
      )

      hostCapabilitiesLoaded = refreshResult.capabilitiesLoaded
      hostCapabilities = refreshResult.capabilities
      lastHostStatus = refreshResult.snapshot
      lastHostStatusError = refreshResult.errorMessage

      if (refreshResult.forceUnpair) {
        AppPrefs.setPaired(this, false)
        AppPrefs.clearResourceToggles(this)
      }

      runOnUiThread {
        if (refreshResult.forceUnpair) {
          val intent = ResourceService.buildIntent(this, ResourceToggleState())
          stopService(intent)
        }
        if (refreshResult.resourceDriftDetected) {
          lastHostStatusError = "Host sync drift detected. Retrying resource sync."
        }
        updateUiFromPrefs()
        if (refreshResult.resourceDriftDetected) {
          applyForegroundServiceState()
          return@runOnUiThread
        }
        if (!applyServiceState) return@runOnUiThread
        if (refreshResult.snapshot != null && refreshResult.hostConfirmsPaired) {
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
    hostStatusTicker = hostStateRefresher.startTicker(ioExecutor) {
        refreshHostStatusIfPaired(applyServiceState = false)
        refreshHostPreviewIfUnpaired()
      }
  }

  private fun refreshHostPreviewIfUnpaired() {
    if (AppPrefs.isPaired(this) || pairingInProgress) {
      return
    }
    val preview = discoverHostPreview()
    discoveredHostPreview = preview
    discoveredHostCandidates = preview?.let { listOf(it) } ?: emptyList()
    if (preview != null) {
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
    return hostStateRefresher.discoverHostPreview(
      savedBaseUrl = AppPrefs.getHostBaseUrl(this),
      savedPairCode = AppPrefs.getHostPairCode(this),
      isLikelyEmulator = isLikelyEmulator(),
      isLoopbackBaseUrl = ::isLoopbackBaseUrl,
    )
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
      message.contains("qr token") || message.contains("request failed (404)") -> R.string.pair_failed_qr_token
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
