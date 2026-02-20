package org.autobyteus.phoneavbridge.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QrPairPayloadParserTest {
  @Test
  fun parse_acceptsHostJsonPayload() {
    val raw = """
      {"service":"phone-av-bridge","version":1,"token":"tok-123","baseUrl":"http://192.168.1.2:8787"}
    """.trimIndent()

    val parsed = QrPairPayloadParser.parse(raw)

    assertEquals("tok-123", parsed?.token)
    assertEquals("http://192.168.1.2:8787", parsed?.baseUrl)
  }

  @Test
  fun parse_rejectsUnexpectedServiceJsonPayload() {
    val raw = """
      {"service":"other-service","token":"tok-123","baseUrl":"http://192.168.1.2:8787"}
    """.trimIndent()

    val parsed = QrPairPayloadParser.parse(raw)

    assertNull(parsed)
  }

  @Test
  fun parse_acceptsUriQueryPayload() {
    val raw = "phoneavbridge://pair?token=tok-abc&baseUrl=http%3A%2F%2F10.0.0.5%3A8787"

    val parsed = QrPairPayloadParser.parse(raw)

    assertEquals("tok-abc", parsed?.token)
    assertEquals("http://10.0.0.5:8787", parsed?.baseUrl)
  }

  @Test
  fun parse_returnsNullForInvalidPayload() {
    val parsed = QrPairPayloadParser.parse("hello world")

    assertNull(parsed)
  }
}
