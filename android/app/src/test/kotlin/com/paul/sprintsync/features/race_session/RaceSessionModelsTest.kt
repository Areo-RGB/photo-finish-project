package com.paul.sprintsync.features.race_session

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class RaceSessionModelsTest {
    @Test
    fun `snapshot round-trips host GPS fields`() {
        val original = SessionSnapshotMessage(
            stage = SessionStage.MONITORING,
            monitoringActive = true,
            devices = listOf(
                SessionDevice(
                    id = "local-device",
                    name = "This Device",
                    role = SessionDeviceRole.START,
                    isLocal = true,
                ),
            ),
            hostStartSensorNanos = 1_000L,
            hostStopSensorNanos = 2_000L,
            runId = "run-1",
            hostSensorMinusElapsedNanos = 120L,
            hostGpsUtcOffsetNanos = 8_000L,
            hostGpsFixAgeNanos = 600_000_000L,
            selfDeviceId = "peer-1",
        )

        val parsed = SessionSnapshotMessage.tryParse(original.toJsonString())

        assertNotNull(parsed)
        assertEquals(8_000L, parsed?.hostGpsUtcOffsetNanos)
        assertEquals(600_000_000L, parsed?.hostGpsFixAgeNanos)
    }

    @Test
    fun `timeline snapshot round-trips with optional fields`() {
        val original = SessionTimelineSnapshotMessage(
            hostStartSensorNanos = 1_000L,
            hostStopSensorNanos = 2_500L,
            sentElapsedNanos = 90_000L,
        )

        val parsed = SessionTimelineSnapshotMessage.tryParse(original.toJsonString())

        assertNotNull(parsed)
        assertEquals(1_000L, parsed?.hostStartSensorNanos)
        assertEquals(2_500L, parsed?.hostStopSensorNanos)
        assertEquals(90_000L, parsed?.sentElapsedNanos)
    }

    @Test
    fun `trigger message parse rejects invalid payload`() {
        val invalid = """
            {"type":"session_trigger","triggerType":"","triggerSensorNanos":0}
        """.trimIndent()

        val parsed = SessionTriggerMessage.tryParse(invalid)

        assertNull(parsed)
    }

    @Test
    fun `clock sync request and response round-trip`() {
        val request = SessionClockSyncRequestMessage(clientSendElapsedNanos = 100L)
        val response = SessionClockSyncResponseMessage(
            clientSendElapsedNanos = 100L,
            hostReceiveElapsedNanos = 220L,
            hostSendElapsedNanos = 260L,
        )

        val parsedRequest = SessionClockSyncRequestMessage.tryParse(request.toJsonString())
        val parsedResponse = SessionClockSyncResponseMessage.tryParse(response.toJsonString())

        assertNotNull(parsedRequest)
        assertEquals(100L, parsedRequest?.clientSendElapsedNanos)
        assertNotNull(parsedResponse)
        assertEquals(220L, parsedResponse?.hostReceiveElapsedNanos)
        assertEquals(260L, parsedResponse?.hostSendElapsedNanos)
    }

    @Test
    fun `trigger refinement parser rejects missing run id`() {
        val invalid = """
            {"type":"trigger_refinement","runId":"","role":"start","provisionalHostSensorNanos":1,"refinedHostSensorNanos":2}
        """.trimIndent()

        val parsed = SessionTriggerRefinementMessage.tryParse(invalid)

        assertNull(parsed)
    }

    @Test
    fun `device identity message round-trips`() {
        val original = SessionDeviceIdentityMessage(
            stableDeviceId = "stable-device-1",
            deviceName = "Pixel 8 Pro",
        )

        val parsed = SessionDeviceIdentityMessage.tryParse(original.toJsonString())

        assertNotNull(parsed)
        assertEquals("stable-device-1", parsed?.stableDeviceId)
        assertEquals("Pixel 8 Pro", parsed?.deviceName)
    }
}
