package org.autobyteus.phoneavbridge.sync

import org.autobyteus.phoneavbridge.model.CameraLens
import org.autobyteus.phoneavbridge.model.CameraOrientationMode
import org.autobyteus.phoneavbridge.model.DiscoveredHost
import org.autobyteus.phoneavbridge.model.HostCapabilities
import org.autobyteus.phoneavbridge.network.HostApiClient
import org.autobyteus.phoneavbridge.network.HostDiscoveryClient
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class HostStateRefresher(
  private val hostApiClient: HostApiClient,
  private val hostDiscoveryClient: HostDiscoveryClient,
) {
  data class RefreshRequest(
    val hostBaseUrl: String,
    val desiredCameraEnabled: Boolean,
    val desiredMicrophoneEnabled: Boolean,
    val desiredSpeakerEnabled: Boolean,
    val desiredLens: CameraLens,
    val desiredOrientationMode: CameraOrientationMode,
  )

  data class RefreshResult(
    val capabilitiesLoaded: Boolean,
    val capabilities: HostCapabilities,
    val snapshot: HostApiClient.HostStatusSnapshot?,
    val errorMessage: String?,
    val hostConfirmsPaired: Boolean,
    val forceUnpair: Boolean,
    val resourceDriftDetected: Boolean,
  )

  fun refreshPairedHost(request: RefreshRequest): RefreshResult {
    return try {
      val snapshot = hostApiClient.fetchStatus(request.hostBaseUrl)
      val cameraMetadataDrift = snapshot.hasCameraMetadata && (
        request.desiredLens != snapshot.cameraLens ||
          request.desiredOrientationMode != snapshot.cameraOrientationMode
        )
      val resourceDriftDetected =
        request.desiredCameraEnabled != snapshot.cameraEnabled ||
          request.desiredMicrophoneEnabled != snapshot.microphoneEnabled ||
          request.desiredSpeakerEnabled != snapshot.speakerEnabled ||
          cameraMetadataDrift

      RefreshResult(
        capabilitiesLoaded = true,
        capabilities = snapshot.capabilities,
        snapshot = snapshot,
        errorMessage = null,
        hostConfirmsPaired = snapshot.paired,
        forceUnpair = !snapshot.paired,
        resourceDriftDetected = resourceDriftDetected,
      )
    } catch (error: Exception) {
      RefreshResult(
        capabilitiesLoaded = false,
        capabilities = HostCapabilities(),
        snapshot = null,
        errorMessage = error.message ?: "status check failed",
        hostConfirmsPaired = false,
        forceUnpair = false,
        resourceDriftDetected = false,
      )
    }
  }

  fun discoverHostPreview(
    savedBaseUrl: String,
    savedPairCode: String,
    isLikelyEmulator: Boolean,
    isLoopbackBaseUrl: (String) -> Boolean,
  ): DiscoveredHost? {
    hostDiscoveryClient.discoverAll(timeoutMs = 1200).firstOrNull()?.let { return it }

    if (savedBaseUrl.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      try {
        return hostApiClient.fetchBootstrap(savedBaseUrl)
      } catch (_: Exception) {
      }
    }
    if (savedBaseUrl.isNotBlank() && savedPairCode.isNotBlank() && !isLoopbackBaseUrl(savedBaseUrl)) {
      return DiscoveredHost(savedBaseUrl, savedPairCode)
    }

    if (isLikelyEmulator) {
      listOf("http://10.0.2.2:8787", "http://127.0.0.1:8787").forEach { candidate ->
        try {
          return hostApiClient.fetchBootstrap(candidate)
        } catch (_: Exception) {
        }
      }
    }
    return null
  }

  fun startTicker(ioExecutor: ScheduledExecutorService, task: () -> Unit): ScheduledFuture<*> {
    return ioExecutor.scheduleAtFixedRate(
      {
        task()
      },
      3,
      5,
      TimeUnit.SECONDS,
    )
  }
}
