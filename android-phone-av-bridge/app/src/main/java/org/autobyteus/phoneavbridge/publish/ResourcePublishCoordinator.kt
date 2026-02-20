package org.autobyteus.phoneavbridge.publish

import android.util.Log
import org.autobyteus.phoneavbridge.model.ResourceToggleState
import org.autobyteus.phoneavbridge.network.HostApiClient
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class ResourcePublishCoordinator(
  private val hostApiClient: HostApiClient,
  private val ioExecutor: ScheduledExecutorService,
  private val localDeviceName: String,
  private val localDeviceId: String,
  private val logTag: String,
) {
  @Volatile private var publishGeneration = 0

  fun publishWithRetry(
    hostBaseUrl: String,
    state: ResourceToggleState,
    onSuccess: () -> Unit,
    onFailure: (String) -> Unit,
  ) {
    publishGeneration += 1
    publishAttempt(hostBaseUrl, state, publishGeneration, 0, onSuccess, onFailure)
  }

  private fun publishAttempt(
    hostBaseUrl: String,
    state: ResourceToggleState,
    generation: Int,
    attempt: Int,
    onSuccess: () -> Unit,
    onFailure: (String) -> Unit,
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
        if (generation == publishGeneration) {
          onSuccess()
        }
      } catch (error: Exception) {
        val message = error.message ?: "publish failed"
        Log.w(logTag, "Toggle publish failed (attempt=$attempt, generation=$generation): $message")
        if (generation == publishGeneration) {
          onFailure(message)
        }
        if (attempt >= 3) return@execute
        ioExecutor.schedule(
          {
            publishAttempt(
              hostBaseUrl = hostBaseUrl,
              state = state,
              generation = generation,
              attempt = attempt + 1,
              onSuccess = onSuccess,
              onFailure = onFailure,
            )
          },
          2,
          TimeUnit.SECONDS,
        )
      }
    }
  }
}
