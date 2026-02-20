package org.autobyteus.phoneavbridge.network

import org.autobyteus.phoneavbridge.model.DiscoveredHost
import org.autobyteus.phoneavbridge.model.HostCapabilities
import org.autobyteus.phoneavbridge.model.CameraLens
import org.autobyteus.phoneavbridge.model.CameraOrientationMode
import org.autobyteus.phoneavbridge.model.ResourceToggleState
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class HostApiClient {
  data class HostStatusSnapshot(
    val paired: Boolean,
    val hostStatus: String,
    val issues: List<String>,
    val capabilities: HostCapabilities,
    val deviceName: String?,
    val deviceId: String?,
    val cameraEnabled: Boolean,
    val microphoneEnabled: Boolean,
    val speakerEnabled: Boolean,
    val cameraLens: CameraLens,
    val cameraOrientationMode: CameraOrientationMode,
    val hasCameraMetadata: Boolean,
  )

  companion object {
    private const val CONNECT_TIMEOUT_MS = 6000
    private const val READ_TIMEOUT_MS = 20000
  }

  fun fetchBootstrap(baseUrl: String): DiscoveredHost {
    val normalized = normalizeBaseUrl(baseUrl)
    val payload = request("GET", "$normalized/api/bootstrap", null)
    val bootstrap = payload.getJSONObject("bootstrap")
    val pairingCode = bootstrap.getString("pairingCode")
    val resolvedBaseUrl = bootstrap.optString("baseUrl", normalized)
    return DiscoveredHost(
      baseUrl = normalizeBaseUrl(resolvedBaseUrl),
      pairingCode = pairingCode,
      hostId = bootstrap.optString("hostId").takeIf { it.isNotBlank() },
      displayName = bootstrap.optString("displayName").takeIf { it.isNotBlank() },
      platform = bootstrap.optString("platform").takeIf { it.isNotBlank() },
    )
  }

  fun redeemQrToken(baseUrl: String, token: String): DiscoveredHost {
    val payload = request(
      "POST",
      "${normalizeBaseUrl(baseUrl)}/api/bootstrap/qr-redeem",
      JSONObject().put("token", token.trim()),
    )
    val bootstrap = payload.getJSONObject("bootstrap")
    val pairingCode = bootstrap.getString("pairingCode")
    val resolvedBaseUrl = bootstrap.optString("baseUrl", normalizeBaseUrl(baseUrl))
    return DiscoveredHost(
      baseUrl = normalizeBaseUrl(resolvedBaseUrl),
      pairingCode = pairingCode,
      hostId = bootstrap.optString("hostId").takeIf { it.isNotBlank() },
      displayName = bootstrap.optString("displayName").takeIf { it.isNotBlank() },
      platform = bootstrap.optString("platform").takeIf { it.isNotBlank() },
    )
  }

  fun pair(baseUrl: String, pairCode: String, deviceName: String? = null, deviceId: String? = null) {
    val body = JSONObject()
      .put("pairCode", pairCode)
    deviceName?.takeIf { it.isNotBlank() }?.let { body.put("deviceName", it) }
    deviceId?.takeIf { it.isNotBlank() }?.let { body.put("deviceId", it) }
    request("POST", "${normalizeBaseUrl(baseUrl)}/api/pair", body)
  }

  fun unpair(baseUrl: String) {
    request("POST", "${normalizeBaseUrl(baseUrl)}/api/unpair", JSONObject())
  }

  fun publishPresence(baseUrl: String, deviceName: String? = null, deviceId: String? = null) {
    val body = JSONObject()
    deviceName?.takeIf { it.isNotBlank() }?.let { body.put("deviceName", it) }
    deviceId?.takeIf { it.isNotBlank() }?.let { body.put("deviceId", it) }
    request("POST", "${normalizeBaseUrl(baseUrl)}/api/presence", body)
  }

  fun fetchCapabilities(baseUrl: String): HostCapabilities {
    val payload = request("GET", "${normalizeBaseUrl(baseUrl)}/api/status", null)
    return parseCapabilities(payload.optJSONObject("status"))
  }

  fun fetchStatus(baseUrl: String): HostStatusSnapshot {
    val payload = request("GET", "${normalizeBaseUrl(baseUrl)}/api/status", null)
    val status = payload.optJSONObject("status") ?: JSONObject()
    val issues = status.optJSONArray("issues").toJsonObjects().map { issueObj ->
      val resource = issueObj.optString("resource", "resource")
      val message = issueObj.optString("message", "unknown issue")
      "$resource: $message"
    }
    val phone = status.optJSONObject("phone")
    val phoneCamera = status.optJSONObject("phoneCamera")
    return HostStatusSnapshot(
      paired = status.optBoolean("paired", false),
      hostStatus = status.optString("hostStatus", "Unknown"),
      issues = issues,
      capabilities = parseCapabilities(status),
      deviceName = phone?.optString("deviceName")?.takeIf { it.isNotBlank() },
      deviceId = phone?.optString("deviceId")?.takeIf { it.isNotBlank() },
      cameraEnabled = status.optJSONObject("resources")?.optBoolean("camera", false) ?: false,
      microphoneEnabled = status.optJSONObject("resources")?.optBoolean("microphone", false) ?: false,
      speakerEnabled = status.optJSONObject("resources")?.optBoolean("speaker", false) ?: false,
      cameraLens = CameraLens.fromStorage(phoneCamera?.optString("lens")),
      cameraOrientationMode = CameraOrientationMode.fromStorage(phoneCamera?.optString("orientationMode")),
      hasCameraMetadata = phoneCamera != null,
    )
  }

  fun publishToggles(
    baseUrl: String,
    state: ResourceToggleState,
    deviceName: String? = null,
    deviceId: String? = null,
  ) {
    val body = JSONObject()
      .put("camera", state.cameraEnabled)
      .put("microphone", state.microphoneEnabled)
      .put("speaker", state.speakerEnabled)
      .put("cameraLens", state.cameraLens.storageValue)
      .put("cameraOrientationMode", state.cameraOrientationMode.storageValue)
    state.cameraStreamUrl?.takeIf { it.isNotBlank() }?.let {
      body.put("cameraStreamUrl", it)
    }
    deviceName?.takeIf { it.isNotBlank() }?.let { body.put("deviceName", it) }
    deviceId?.takeIf { it.isNotBlank() }?.let { body.put("deviceId", it) }
    request("POST", "${normalizeBaseUrl(baseUrl)}/api/toggles", body)
  }

  private fun request(method: String, targetUrl: String, body: JSONObject?): JSONObject {
    val connection = (URL(targetUrl).openConnection() as HttpURLConnection).apply {
      requestMethod = method
      connectTimeout = CONNECT_TIMEOUT_MS
      readTimeout = READ_TIMEOUT_MS
      setRequestProperty("Accept", "application/json")
      if (body != null) {
        doOutput = true
        setRequestProperty("Content-Type", "application/json")
      }
    }

    try {
      if (body != null) {
        OutputStreamWriter(connection.outputStream).use { writer ->
          writer.write(body.toString())
        }
      }

      val statusCode = connection.responseCode
      val responseText = if (statusCode in 200..299) {
        connection.inputStream.bufferedReader().use { it.readText() }
      } else {
        val errorText = connection.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
        throw IllegalStateException("Host API request failed ($statusCode): $errorText")
      }

      return if (responseText.isBlank()) JSONObject() else JSONObject(responseText)
    } finally {
      connection.disconnect()
    }
  }

  private fun normalizeBaseUrl(value: String): String {
    return value.trim().removeSuffix("/")
  }

  private fun parseCapabilities(status: JSONObject?): HostCapabilities {
    val capabilities = status?.optJSONObject("capabilities")
    return HostCapabilities(
      camera = capabilities?.optBoolean("camera", true) ?: true,
      microphone = capabilities?.optBoolean("microphone", true) ?: true,
      speaker = capabilities?.optBoolean("speaker", false) ?: false,
    )
  }

  private fun org.json.JSONArray?.toJsonObjects(): List<JSONObject> {
    if (this == null) return emptyList()
    return buildList {
      for (index in 0 until length()) {
        optJSONObject(index)?.let { add(it) }
      }
    }
  }
}
