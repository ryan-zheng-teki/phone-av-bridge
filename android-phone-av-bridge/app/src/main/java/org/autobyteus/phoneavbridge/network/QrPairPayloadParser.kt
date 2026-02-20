package org.autobyteus.phoneavbridge.network

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

data class QrPairPayload(
  val baseUrl: String,
  val token: String,
)

object QrPairPayloadParser {
  private val json = Json {
    ignoreUnknownKeys = true
  }

  fun parse(rawPayload: String): QrPairPayload? {
    val trimmed = rawPayload.trim()
    if (trimmed.isBlank()) return null

    parseJson(trimmed)?.let { return it }
    return parseUri(trimmed)
  }

  private fun parseJson(trimmed: String): QrPairPayload? {
    val payload = try {
      json.parseToJsonElement(trimmed).jsonObject
    } catch (_: Exception) {
      return null
    }

    val service = payload["service"]?.jsonPrimitive?.contentOrNull?.trim().orEmpty()
    if (service.isNotEmpty() && service != "phone-av-bridge") {
      return null
    }
    val token = payload["token"]?.jsonPrimitive?.contentOrNull?.trim().orEmpty()
    val baseUrl = normalizeHttpBaseUrl(payload["baseUrl"]?.jsonPrimitive?.contentOrNull.orEmpty())
    if (token.isBlank() || baseUrl == null) {
      return null
    }
    return QrPairPayload(baseUrl = baseUrl, token = token)
  }

  private fun parseUri(trimmed: String): QrPairPayload? {
    val uri = try {
      URI(trimmed)
    } catch (_: Exception) {
      return null
    }
    val query = uri.rawQuery ?: return null
    val params = parseQuery(query)
    val token = params["token"].orEmpty().trim()
    val baseUrl = normalizeHttpBaseUrl(params["baseUrl"].orEmpty())
    if (token.isBlank() || baseUrl == null) {
      return null
    }
    return QrPairPayload(baseUrl = baseUrl, token = token)
  }

  private fun parseQuery(query: String): Map<String, String> {
    if (query.isBlank()) return emptyMap()
    return query
      .split('&')
      .mapNotNull { segment ->
        if (segment.isBlank()) return@mapNotNull null
        val idx = segment.indexOf('=')
        val rawKey = if (idx >= 0) segment.substring(0, idx) else segment
        val rawValue = if (idx >= 0) segment.substring(idx + 1) else ""
        val key = urlDecode(rawKey)
        if (key.isBlank()) return@mapNotNull null
        key to urlDecode(rawValue)
      }
      .toMap()
  }

  private fun urlDecode(value: String): String {
    return URLDecoder.decode(value, StandardCharsets.UTF_8)
  }

  private fun normalizeHttpBaseUrl(value: String): String? {
    val normalized = value.trim().removeSuffix("/")
    if (normalized.isBlank()) return null
    val lower = normalized.lowercase()
    return if (lower.startsWith("http://") || lower.startsWith("https://")) normalized else null
  }
}
