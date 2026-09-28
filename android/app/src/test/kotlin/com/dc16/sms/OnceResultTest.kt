package com.dc16.sms

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 记录 [MethodChannel.Result] 收到的回调，验证 [OnceResult] 只发出一次。 */
private class RecordingResult : MethodChannel.Result {
  val successes = mutableListOf<Any?>()
  val errors = mutableListOf<Triple<String, String?, Any?>>()
  var notImplementedCount = 0

  override fun success(result: Any?) {
    successes.add(result)
  }

  override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
    errors.add(Triple(errorCode, errorMessage, errorDetails))
  }

  override fun notImplemented() {
    notImplementedCount++
  }

  val totalCalls: Int get() = successes.size + errors.size + notImplementedCount
}

class OnceResultTest {

  @Test
  fun `success only forwards once`() {
    val raw = RecordingResult()
    val once = OnceResult(raw)
    once.success("a")
    once.success("b")
    once.error("error", "x", null)
    once.notImplemented()
    assertEquals(listOf<Any?>("a"), raw.successes)
    assertEquals(0, raw.errors.size)
    assertEquals(0, raw.notImplementedCount)
    assertEquals(1, raw.totalCalls)
  }

  @Test
  fun `error only forwards once`() {
    val raw = RecordingResult()
    val once = OnceResult(raw)
    once.error("lifecycle", "cancelled", null)
    once.error("error", "boom", null)
    once.success(true)
    assertEquals(0, raw.successes.size)
    assertEquals(1, raw.errors.size)
    assertEquals("lifecycle", raw.errors[0].first)
    assertEquals(1, raw.totalCalls)
  }

  @Test
  fun `notImplemented only forwards once`() {
    val raw = RecordingResult()
    val once = OnceResult(raw)
    once.notImplemented()
    once.success(1)
    once.error("error", null, null)
    assertEquals(0, raw.successes.size)
    assertEquals(0, raw.errors.size)
    assertEquals(1, raw.notImplementedCount)
  }

  @Test
  fun `null success is a completion`() {
    val raw = RecordingResult()
    val once = OnceResult(raw)
    once.success(null)
    once.success("later")
    assertEquals(1, raw.successes.size)
    assertNull(raw.successes[0])
  }

  @Test
  fun `raw throwing does not allow a second completion`() {
    var calls = 0
    val raw = object : MethodChannel.Result {
      override fun success(result: Any?) {
        calls++
        throw IllegalStateException("already replied")
      }

      override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        calls++
      }

      override fun notImplemented() {
        calls++
      }
    }
    val once = OnceResult(raw)
    once.success("a")
    once.success("b")
    once.error("error", null, null)
    assertEquals(1, calls)
  }
}
