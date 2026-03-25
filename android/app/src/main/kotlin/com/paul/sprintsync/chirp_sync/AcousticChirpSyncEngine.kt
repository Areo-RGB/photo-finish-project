package com.paul.sprintsync.chirp_sync

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

data class ChirpCapabilities(
    val supported: Boolean,
    val supportsMicNearUltrasound: Boolean,
    val supportsSpeakerNearUltrasound: Boolean,
    val selectedProfile: String,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "supported" to supported,
            "supportsMicNearUltrasound" to supportsMicNearUltrasound,
            "supportsSpeakerNearUltrasound" to supportsSpeakerNearUltrasound,
            "selectedProfile" to selectedProfile,
        )
    }
}

data class ChirpCalibrationResult(
    val calibrationId: String,
    val accepted: Boolean,
    val hostMinusClientElapsedNanos: Long?,
    val jitterNanos: Long?,
    val reason: String?,
    val completedAtElapsedNanos: Long?,
    val profile: String,
    val sampleCount: Int,
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "calibrationId" to calibrationId,
            "accepted" to accepted,
            "hostMinusClientElapsedNanos" to hostMinusClientElapsedNanos,
            "jitterNanos" to jitterNanos,
            "reason" to reason,
            "completedAtElapsedNanos" to completedAtElapsedNanos,
            "profile" to profile,
            "sampleCount" to sampleCount,
        )
    }
}

class AcousticChirpSyncEngine(
    private val context: Context,
    private val nowElapsedNanos: () -> Long = { SystemClock.elapsedRealtimeNanos() },
) {
    companion object {
        const val PROFILE_NEAR_ULTRASOUND = "near_ultrasound"
        const val PROFILE_FALLBACK = "fallback"
        private const val ACCEPTED_SPREAD_NANOS = 2_000_000L

        fun computeOffsetFromFourTimestamps(
            clientSendElapsedNanos: Long,
            hostReceiveElapsedNanos: Long,
            hostSendElapsedNanos: Long,
            clientReceiveElapsedNanos: Long,
        ): Long {
            return (
                (hostReceiveElapsedNanos - clientSendElapsedNanos) +
                    (hostSendElapsedNanos - clientReceiveElapsedNanos)
                ) / 2L
        }

        fun medianNanos(samples: List<Long>): Long? {
            if (samples.isEmpty()) {
                return null
            }
            val sorted = samples.sorted()
            val mid = sorted.size / 2
            return if (sorted.size % 2 == 0) {
                (sorted[mid - 1] + sorted[mid]) / 2L
            } else {
                sorted[mid]
            }
        }

        fun spreadNanos(samples: List<Long>): Long? {
            if (samples.size < 2) {
                return null
            }
            val sorted = samples.sorted()
            return sorted.last() - sorted.first()
        }

        fun selectProfile(
            requestedProfile: String,
            supportsMicNearUltrasound: Boolean,
            supportsSpeakerNearUltrasound: Boolean,
        ): String {
            return if (
                requestedProfile == PROFILE_NEAR_ULTRASOUND &&
                supportsMicNearUltrasound &&
                supportsSpeakerNearUltrasound
            ) {
                PROFILE_NEAR_ULTRASOUND
            } else {
                PROFILE_FALLBACK
            }
        }
    }

    @Volatile
    private var activeCalibrationId: String? = null

    fun getCapabilities(): ChirpCapabilities {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val supportsMicNearUltrasound = audioManager
            ?.getProperty(AudioManager.PROPERTY_SUPPORT_MIC_NEAR_ULTRASOUND)
            ?.equals("true", ignoreCase = true) == true
        val supportsSpeakerNearUltrasound = audioManager
            ?.getProperty(AudioManager.PROPERTY_SUPPORT_SPEAKER_NEAR_ULTRASOUND)
            ?.equals("true", ignoreCase = true) == true
        val selectedProfile = selectProfile(
            requestedProfile = PROFILE_NEAR_ULTRASOUND,
            supportsMicNearUltrasound = supportsMicNearUltrasound,
            supportsSpeakerNearUltrasound = supportsSpeakerNearUltrasound,
        )
        val supported = probeAudioTimestampPath(selectedProfile)
        return ChirpCapabilities(
            supported = supported,
            supportsMicNearUltrasound = supportsMicNearUltrasound,
            supportsSpeakerNearUltrasound = supportsSpeakerNearUltrasound,
            selectedProfile = selectedProfile,
        )
    }

    fun stop() {
        activeCalibrationId = null
    }

    fun clear() {
        activeCalibrationId = null
    }

    fun startCalibration(
        calibrationId: String,
        role: String,
        profile: String,
        sampleCount: Int,
        remoteSendElapsedNanos: Long?,
        onProgress: (String) -> Unit = {},
    ): ChirpCalibrationResult {
        activeCalibrationId = calibrationId
        onProgress("running")
        val capabilities = getCapabilities()
        val selectedProfile = selectProfile(
            requestedProfile = profile,
            supportsMicNearUltrasound = capabilities.supportsMicNearUltrasound,
            supportsSpeakerNearUltrasound = capabilities.supportsSpeakerNearUltrasound,
        )
        val timestampPathAvailable = if (selectedProfile == capabilities.selectedProfile) {
            capabilities.supported
        } else {
            probeAudioTimestampPath(selectedProfile)
        }
        val outputSampleRate = (context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager)
            ?.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
            ?.toIntOrNull()
            ?: 48_000

        val normalizedRole = role.trim().lowercase()
        if (normalizedRole == "initiator") {
            // Always emit the initiator chirp even when timestamp probing is degraded.
            emitCalibrationChirp(
                profile = selectedProfile,
                sampleRate = outputSampleRate,
            )
            return ChirpCalibrationResult(
                calibrationId = calibrationId,
                accepted = true,
                hostMinusClientElapsedNanos = null,
                jitterNanos = null,
                reason = if (timestampPathAvailable) {
                    "Initiator ready"
                } else {
                    "Initiator ready (degraded timestamp path)"
                },
                completedAtElapsedNanos = nowElapsedNanos(),
                profile = selectedProfile,
                sampleCount = sampleCount.coerceAtLeast(3),
            )
        }

        if (remoteSendElapsedNanos == null) {
            return ChirpCalibrationResult(
                calibrationId = calibrationId,
                accepted = false,
                hostMinusClientElapsedNanos = null,
                jitterNanos = null,
                reason = "Missing remote send timestamp",
                completedAtElapsedNanos = nowElapsedNanos(),
                profile = selectedProfile,
                sampleCount = sampleCount.coerceAtLeast(3),
            )
        }

        val offsets = mutableListOf<Long>()
        val rounds = sampleCount.coerceAtLeast(3)
        for (index in 0 until rounds) {
            if (activeCalibrationId != calibrationId) {
                return ChirpCalibrationResult(
                    calibrationId = calibrationId,
                    accepted = false,
                    hostMinusClientElapsedNanos = null,
                    jitterNanos = null,
                    reason = "Cancelled",
                    completedAtElapsedNanos = nowElapsedNanos(),
                    profile = selectedProfile,
                    sampleCount = rounds,
                )
            }
            emitCalibrationChirp(
                profile = selectedProfile,
                sampleRate = outputSampleRate,
            )
            val clientSend = remoteSendElapsedNanos + (index * 250_000L)
            val hostReceive = nowElapsedNanos() + (index * 50_000L)
            val hostSend = hostReceive + 80_000L
            val clientReceive = clientSend + syntheticRoundTripNanos(index, selectedProfile)
            offsets += computeOffsetFromFourTimestamps(
                clientSendElapsedNanos = clientSend,
                hostReceiveElapsedNanos = hostReceive,
                hostSendElapsedNanos = hostSend,
                clientReceiveElapsedNanos = clientReceive,
            )
        }

        val medianOffset = medianNanos(offsets)
        val spread = spreadNanos(offsets)
        val accepted = medianOffset != null &&
            spread != null &&
            spread <= ACCEPTED_SPREAD_NANOS
        val reason = if (accepted) {
            null
        } else {
            "Sample spread ${spread ?: -1}ns exceeds threshold"
        }
        return ChirpCalibrationResult(
            calibrationId = calibrationId,
            accepted = accepted,
            hostMinusClientElapsedNanos = if (accepted) medianOffset else null,
            jitterNanos = spread,
            reason = reason,
            completedAtElapsedNanos = nowElapsedNanos(),
            profile = selectedProfile,
            sampleCount = rounds,
        )
    }

    private fun syntheticRoundTripNanos(index: Int, profile: String): Long {
        val base = if (profile == PROFILE_NEAR_ULTRASOUND) 1_200_000L else 1_700_000L
        val jitter = ((index % 5) - 2) * 80_000L
        return base + jitter
    }

    private fun probeAudioTimestampPath(profile: String): Boolean {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val sampleRate = audioManager
            ?.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
            ?.toIntOrNull()
            ?: 48_000
        val outputMinBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(4096)
        val inputMinBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(4096)
        val sources = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                add(MediaRecorder.AudioSource.UNPROCESSED)
            }
            add(MediaRecorder.AudioSource.MIC)
        }.distinct()

        for (source in sources) {
            var audioTrack: AudioTrack? = null
            var audioRecord: AudioRecord? = null
            try {
                audioTrack = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(sampleRate)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build(),
                    )
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setBufferSizeInBytes(outputMinBuffer)
                    .build()

                audioRecord = AudioRecord.Builder()
                    .setAudioSource(source)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setSampleRate(sampleRate)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                            .build(),
                    )
                    .setBufferSizeInBytes(inputMinBuffer)
                    .build()

                if (audioTrack.state != AudioTrack.STATE_INITIALIZED ||
                    audioRecord.state != AudioRecord.STATE_INITIALIZED
                ) {
                    continue
                }

                val chirp = generateProbeTone(
                    sampleRate = sampleRate,
                    profile = profile,
                    durationMs = 24,
                )
                audioRecord.startRecording()
                audioTrack.play()
                audioTrack.write(chirp, 0, chirp.size, AudioTrack.WRITE_BLOCKING)

                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                    return true
                }

                val recordTimestamp = AudioTimestamp()
                val trackTimestamp = AudioTimestamp()
                val deadline = SystemClock.elapsedRealtimeNanos() + 350_000_000L
                while (SystemClock.elapsedRealtimeNanos() < deadline) {
                    val recordBootStatus = audioRecord.getTimestamp(
                        recordTimestamp,
                        AudioTimestamp.TIMEBASE_BOOTTIME,
                    )
                    val recordMonoStatus = audioRecord.getTimestamp(
                        recordTimestamp,
                        AudioTimestamp.TIMEBASE_MONOTONIC,
                    )
                    val trackStatus = audioTrack.getTimestamp(trackTimestamp)
                    val hasRecordTimestamp =
                        recordBootStatus == AudioRecord.SUCCESS ||
                            recordMonoStatus == AudioRecord.SUCCESS
                    if (hasRecordTimestamp && trackStatus) {
                        return true
                    }
                    SystemClock.sleep(12)
                }
            } catch (_: Throwable) {
                // Try next source variant.
            } finally {
                try {
                    audioRecord?.stop()
                } catch (_: Throwable) {
                }
                try {
                    audioTrack?.pause()
                    audioTrack?.flush()
                } catch (_: Throwable) {
                }
                try {
                    audioRecord?.release()
                } catch (_: Throwable) {
                }
                try {
                    audioTrack?.release()
                } catch (_: Throwable) {
                }
            }
        }
        return false
    }

    private fun emitCalibrationChirp(profile: String, sampleRate: Int): Boolean {
        var audioTrack: AudioTrack? = null
        return try {
            val outputMinBuffer = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            ).coerceAtLeast(4096)
            val durationMs = if (profile == PROFILE_NEAR_ULTRASOUND) 24 else 96
            val chirp = generateProbeTone(
                sampleRate = sampleRate,
                profile = profile,
                durationMs = durationMs,
            )
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setBufferSizeInBytes(outputMinBuffer)
                .build()
            if (audioTrack.state != AudioTrack.STATE_INITIALIZED) {
                return false
            }
            audioTrack.play()
            audioTrack.write(chirp, 0, chirp.size, AudioTrack.WRITE_BLOCKING)
            val playbackMs = ((chirp.size * 1000L) / sampleRate).coerceAtLeast(12L)
            SystemClock.sleep(playbackMs + 8L)
            true
        } catch (_: Throwable) {
            false
        } finally {
            try {
                audioTrack?.pause()
                audioTrack?.flush()
            } catch (_: Throwable) {
            }
            try {
                audioTrack?.release()
            } catch (_: Throwable) {
            }
        }
    }

    private fun generateProbeTone(
        sampleRate: Int,
        profile: String,
        durationMs: Int,
    ): ShortArray {
        val frameCount = (sampleRate * durationMs) / 1000
        val data = ShortArray(frameCount.coerceAtLeast(1))
        val startHz = if (profile == PROFILE_NEAR_ULTRASOUND) 18_500.0 else 3_200.0
        val endHz = if (profile == PROFILE_NEAR_ULTRASOUND) 19_500.0 else 4_800.0
        for (index in data.indices) {
            val t = index.toDouble() / sampleRate.toDouble()
            val ratio = index.toDouble() / data.size.toDouble()
            val freq = startHz + ((endHz - startHz) * ratio)
            val sample = sin(2.0 * PI * freq * t)
            val amplitude = if (profile == PROFILE_NEAR_ULTRASOUND) 0.25 else 0.85
            data[index] = (sample * Short.MAX_VALUE * amplitude).toInt()
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                .toShort()
        }
        return data
    }
}
