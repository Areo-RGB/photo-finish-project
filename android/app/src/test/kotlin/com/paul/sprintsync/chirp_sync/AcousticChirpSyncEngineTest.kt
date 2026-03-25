package com.paul.sprintsync.chirp_sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AcousticChirpSyncEngineTest {
    @Test
    fun `four timestamp offset math computes host minus client`() {
        val offset = AcousticChirpSyncEngine.computeOffsetFromFourTimestamps(
            clientSendElapsedNanos = 1_000_000_000L,
            hostReceiveElapsedNanos = 1_250_000_000L,
            hostSendElapsedNanos = 1_250_100_000L,
            clientReceiveElapsedNanos = 1_300_000_000L,
        )

        assertEquals(100_050_000L, offset)
    }

    @Test
    fun `median and spread summarize calibration stability`() {
        val samples = listOf(100L, 120L, 110L, 130L, 115L)

        assertEquals(115L, AcousticChirpSyncEngine.medianNanos(samples))
        assertEquals(30L, AcousticChirpSyncEngine.spreadNanos(samples))
        assertNull(AcousticChirpSyncEngine.spreadNanos(listOf(42L)))
    }

    @Test
    fun `profile selection uses near ultrasound only when both paths support it`() {
        val nearProfile = AcousticChirpSyncEngine.selectProfile(
            requestedProfile = AcousticChirpSyncEngine.PROFILE_NEAR_ULTRASOUND,
            supportsMicNearUltrasound = true,
            supportsSpeakerNearUltrasound = true,
        )
        assertEquals(AcousticChirpSyncEngine.PROFILE_NEAR_ULTRASOUND, nearProfile)

        val fallbackProfile = AcousticChirpSyncEngine.selectProfile(
            requestedProfile = AcousticChirpSyncEngine.PROFILE_NEAR_ULTRASOUND,
            supportsMicNearUltrasound = true,
            supportsSpeakerNearUltrasound = false,
        )
        assertEquals(AcousticChirpSyncEngine.PROFILE_FALLBACK, fallbackProfile)
    }
}

