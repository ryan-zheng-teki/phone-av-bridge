package org.autobyteus.resourcecompanion.speaker

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.max

class HostSpeakerStreamPlayer {
  @Volatile private var running = false
  @Volatile private var targetUrl = ""
  @Volatile private var activeConnection: HttpURLConnection? = null
  @Volatile private var activeStream: InputStream? = null
  @Volatile private var activeTrack: AudioTrack? = null
  private var worker: Thread? = null

  @Synchronized
  fun start(baseUrl: String) {
    val normalized = baseUrl.trim().removeSuffix("/")
    if (normalized.isBlank()) {
      stopLocked()
      return
    }
    val nextUrl = "$normalized/api/speaker/stream"
    if (running && targetUrl == nextUrl) {
      return
    }

    stopLocked()
    running = true
    targetUrl = nextUrl
    worker = Thread(
      {
        runLoop(nextUrl)
      },
      "host-speaker-stream-player",
    ).apply {
      isDaemon = true
      start()
    }
  }

  @Synchronized
  fun stop() {
    stopLocked()
  }

  private fun runLoop(streamUrl: String) {
    while (running) {
      try {
        streamOnce(streamUrl)
      } catch (_: InterruptedException) {
        break
      } catch (_: Exception) {
      }
      if (!running) break
      try {
        Thread.sleep(1000)
      } catch (_: InterruptedException) {
        break
      }
    }
  }

  private fun streamOnce(streamUrl: String) {
    val connection = URL(streamUrl).openConnection() as HttpURLConnection
    connection.requestMethod = "GET"
    connection.connectTimeout = 4000
    connection.readTimeout = 0
    connection.setRequestProperty("Accept", "application/octet-stream")
    connection.connect()

    if (connection.responseCode !in 200..299) {
      throw IllegalStateException("Speaker stream unavailable: HTTP ${connection.responseCode}")
    }

    val encoding = connection.getHeaderField("X-PCM-ENCODING")?.trim()?.lowercase() ?: "s16le"
    if (encoding != "s16le") {
      throw IllegalStateException("Unsupported PCM encoding from host: $encoding")
    }

    val sampleRate = (connection.getHeaderField("X-PCM-SAMPLE-RATE")?.toIntOrNull() ?: 48000)
      .coerceIn(8000, 96000)
    val channels = (connection.getHeaderField("X-PCM-CHANNELS")?.toIntOrNull() ?: 1)
      .coerceIn(1, 2)
    val channelMask = if (channels <= 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
    val minBuffer = AudioTrack.getMinBufferSize(sampleRate, channelMask, AudioFormat.ENCODING_PCM_16BIT)
    val bufferSize = max(16 * 1024, if (minBuffer > 0) minBuffer * 4 else sampleRate * channels * 2)
    val audioTrack = AudioTrack(
      AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build(),
      AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(sampleRate)
        .setChannelMask(channelMask)
        .build(),
      bufferSize,
      AudioTrack.MODE_STREAM,
      AudioManager.AUDIO_SESSION_ID_GENERATE,
    )
    audioTrack.play()

    val input = connection.inputStream
    synchronized(this) {
      if (!running) {
        releaseTrack(audioTrack)
        input.close()
        connection.disconnect()
        return
      }
      activeConnection = connection
      activeStream = input
      activeTrack = audioTrack
    }

    val buffer = ByteArray(16 * 1024)
    val frameBytes = channels.coerceAtLeast(1) * 2 // PCM16
    val carry = ByteArray(frameBytes)
    var carryLen = 0
    while (running) {
      val read = input.read(buffer)
      if (read < 0) break
      if (read == 0) continue

      var offset = 0
      if (carryLen > 0) {
        val needed = frameBytes - carryLen
        val take = minOf(needed, read)
        System.arraycopy(buffer, 0, carry, carryLen, take)
        carryLen += take
        offset += take
        if (carryLen == frameBytes) {
          audioTrack.write(carry, 0, frameBytes, AudioTrack.WRITE_BLOCKING)
          carryLen = 0
        }
      }

      val remaining = read - offset
      if (remaining > 0) {
        val aligned = remaining - (remaining % frameBytes)
        if (aligned > 0) {
          audioTrack.write(buffer, offset, aligned, AudioTrack.WRITE_BLOCKING)
          offset += aligned
        }
      }

      val tail = read - offset
      if (tail > 0) {
        System.arraycopy(buffer, offset, carry, 0, tail)
        carryLen = tail
      }
    }

    synchronized(this) {
      if (activeStream === input) activeStream = null
      if (activeConnection === connection) activeConnection = null
      if (activeTrack === audioTrack) activeTrack = null
    }
    input.close()
    connection.disconnect()
    releaseTrack(audioTrack)
  }

  @Synchronized
  private fun stopLocked() {
    running = false
    worker?.interrupt()
    worker = null
    try {
      activeStream?.close()
    } catch (_: Exception) {
    }
    try {
      activeConnection?.disconnect()
    } catch (_: Exception) {
    }
    releaseTrack(activeTrack)
    activeStream = null
    activeConnection = null
    activeTrack = null
    targetUrl = ""
  }

  private fun releaseTrack(track: AudioTrack?) {
    if (track == null) return
    try {
      track.pause()
    } catch (_: Exception) {
    }
    try {
      track.flush()
    } catch (_: Exception) {
    }
    try {
      track.stop()
    } catch (_: Exception) {
    }
    try {
      track.release()
    } catch (_: Exception) {
    }
  }
}
