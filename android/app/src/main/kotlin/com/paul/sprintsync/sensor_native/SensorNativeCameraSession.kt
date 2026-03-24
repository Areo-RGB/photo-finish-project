package com.paul.sprintsync.sensor_native

import android.hardware.camera2.CaptureRequest
import android.os.Handler
import android.os.SystemClock
import android.util.Range
import androidx.camera.camera2.interop.Camera2CameraControl
import androidx.camera.camera2.interop.CaptureRequestOptions
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import java.util.concurrent.ExecutorService

internal class SensorNativeCameraSession(
    private val activity: FlutterActivity,
    private val mainHandler: Handler,
    private val analyzerExecutor: ExecutorService,
    private val analyzer: ImageAnalysis.Analyzer,
    private val emitError: (String) -> Unit,
    private val emitDiagnostic: (String) -> Unit,
) {
    private var camera: Camera? = null
    private var bindGeneration = 0L
    private var pendingAeAwbLockRunnable: Runnable? = null
    private var previewUseCase: Preview? = null
    private var hsFallbackDiagnosticEmitted = false
    @Volatile
    private var activeFpsMode: NativeCameraFpsMode = NativeCameraFpsMode.NORMAL
    @Volatile
    private var activeTargetFpsUpper = 0

    fun stop(provider: ProcessCameraProvider?) {
        cancelPendingAeAwbLock()
        provider?.unbindAll()
        camera = null
        previewUseCase = null
        hsFallbackDiagnosticEmitted = false
        activeFpsMode = NativeCameraFpsMode.NORMAL
        activeTargetFpsUpper = 0
    }

    fun bindAndConfigure(
        provider: ProcessCameraProvider,
        previewView: PreviewView?,
        includePreview: Boolean,
        preferredFacing: NativeCameraFacing,
        preferredFpsMode: NativeCameraFpsMode,
    ) {
        val binding = bindCameraUseCases(
            provider = provider,
            previewView = previewView,
            includePreview = includePreview,
            preferredFacing = preferredFacing,
        )
        applyUnlockedPolicy(binding, preferredFpsMode)
    }

    fun currentCameraFpsMode(): NativeCameraFpsMode = activeFpsMode

    fun currentTargetFpsUpper(): Int = activeTargetFpsUpper

    private fun bindCameraUseCases(
        provider: ProcessCameraProvider,
        previewView: PreviewView?,
        includePreview: Boolean,
        preferredFacing: NativeCameraFacing,
    ): CameraBinding {
        cancelPendingAeAwbLock()
        provider.unbindAll()

        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
            .build()
        imageAnalysis.setAnalyzer(analyzerExecutor, analyzer)

        val facingSelection = SensorNativeCameraPolicy.selectCameraFacing(
            preferred = preferredFacing,
            hasRear = provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA),
            hasFront = provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA),
        ) ?: throw IllegalStateException("No camera available for native monitoring.")
        if (facingSelection.fallbackUsed) {
            emitError(
                "Requested ${preferredFacing.wireName} camera unavailable; using ${facingSelection.selected.wireName}.",
            )
        }
        val selector = when (facingSelection.selected) {
            NativeCameraFacing.REAR -> CameraSelector.DEFAULT_BACK_CAMERA
            NativeCameraFacing.FRONT -> CameraSelector.DEFAULT_FRONT_CAMERA
        }

        val localPreviewView = if (includePreview) previewView else null
        val preview = localPreviewView?.let { view ->
            Preview.Builder().build().also { useCase ->
                useCase.setSurfaceProvider(view.surfaceProvider)
            }
        }
        previewUseCase = preview

        val boundCamera = if (preview == null) {
            provider.bindToLifecycle(activity, selector, imageAnalysis)
        } else {
            provider.bindToLifecycle(activity, selector, preview, imageAnalysis)
        }
        camera = boundCamera
        bindGeneration += 1
        return CameraBinding(
            camera = boundCamera,
            previewBound = preview != null,
            generation = bindGeneration,
        )
    }

    private fun applyUnlockedPolicy(
        binding: CameraBinding,
        preferredFpsMode: NativeCameraFpsMode,
    ) {
        val fpsSelection = SensorNativeCameraPolicy.selectFrameRateSelection(
            binding.camera.cameraInfo.supportedFrameRateRanges,
            preferredFpsMode,
        )
        if (fpsSelection == null) {
            emitError("No supported FPS range reported; continuing with camera defaults.")
            return
        }
        if (fpsSelection.fallbackActivated) {
            emitHsFallbackDiagnosticOnce(
                "HS120 unavailable; using normal ${fpsSelection.primaryRange.lower}-${fpsSelection.primaryRange.upper} fps.",
            )
        }

        applyCamera2Options(
            binding = binding,
            fpsRange = fpsSelection.primaryRange,
            lockAeAwb = false,
        ) { success, error ->
            if (!success) {
                val fallbackRange = fpsSelection.fallbackRange
                if (fallbackRange == null) {
                    handleUnlockedPolicyFailure(error ?: "unknown")
                    return@applyCamera2Options
                }
                emitHsFallbackDiagnosticOnce(
                    "HS120 apply failed; falling back to normal ${fallbackRange.lower}-${fallbackRange.upper} fps.",
                )
                applyCamera2Options(
                    binding = binding,
                    fpsRange = fallbackRange,
                    lockAeAwb = false,
                ) { fallbackSuccess, fallbackError ->
                    if (!fallbackSuccess) {
                        handleUnlockedPolicyFailure(
                            "primary=${error ?: "unknown"}, fallback=${fallbackError ?: "unknown"}",
                        )
                        return@applyCamera2Options
                    }
                    updateActiveFps(
                        mode = NativeCameraFpsMode.NORMAL,
                        range = fallbackRange,
                    )
                    scheduleAeAwbLock(binding, fallbackRange)
                }
                return@applyCamera2Options
            }
            updateActiveFps(
                mode = fpsSelection.primaryMode,
                range = fpsSelection.primaryRange,
            )
            scheduleAeAwbLock(binding, fpsSelection.primaryRange)
        }
    }

    private fun updateActiveFps(
        mode: NativeCameraFpsMode,
        range: Range<Int>,
    ) {
        activeFpsMode = mode
        activeTargetFpsUpper = range.upper
    }

    private fun emitHsFallbackDiagnosticOnce(message: String) {
        if (hsFallbackDiagnosticEmitted) {
            return
        }
        hsFallbackDiagnosticEmitted = true
        emitDiagnostic(message)
    }

    private fun handleUnlockedPolicyFailure(reason: String) {
        emitError("Failed to apply max FPS controls; keeping preview with camera defaults: $reason")
    }

    private fun scheduleAeAwbLock(
        binding: CameraBinding,
        fpsRange: Range<Int>,
    ) {
        cancelPendingAeAwbLock()
        val warmupStartMs = SystemClock.elapsedRealtime()
        val lockRunnable = Runnable {
            if (!isCurrentBinding(binding)) {
                return@Runnable
            }
            val elapsedMs = SystemClock.elapsedRealtime() - warmupStartMs
            if (!SensorNativeCameraPolicy.shouldLockAeAwb(elapsedMs)) {
                return@Runnable
            }
            applyCamera2Options(
                binding = binding,
                fpsRange = fpsRange,
                lockAeAwb = true,
            ) { success, error ->
                if (!success) {
                    emitError("Failed to lock AE/AWB; continuing unlocked: ${error ?: "unknown"}")
                }
            }
        }
        pendingAeAwbLockRunnable = lockRunnable
        mainHandler.postDelayed(lockRunnable, SensorNativeCameraPolicy.AE_AWB_WARMUP_MS)
    }

    private fun applyCamera2Options(
        binding: CameraBinding,
        fpsRange: Range<Int>,
        lockAeAwb: Boolean,
        onComplete: (Boolean, String?) -> Unit,
    ) {
        val requestOptions = CaptureRequestOptions.Builder()
            .setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fpsRange)
            .setCaptureRequestOption(CaptureRequest.CONTROL_AE_LOCK, lockAeAwb)
            .setCaptureRequestOption(CaptureRequest.CONTROL_AWB_LOCK, lockAeAwb)
            .build()
        val control = Camera2CameraControl.from(binding.camera.cameraControl)
        val future = control.setCaptureRequestOptions(requestOptions)
        future.addListener(
            {
                if (!isCurrentBinding(binding)) {
                    return@addListener
                }
                try {
                    future.get()
                    onComplete(true, null)
                } catch (error: Exception) {
                    if (error is InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                    onComplete(false, error.localizedMessage ?: "unknown")
                }
            },
            ContextCompat.getMainExecutor(activity),
        )
    }

    private fun cancelPendingAeAwbLock() {
        pendingAeAwbLockRunnable?.let(mainHandler::removeCallbacks)
        pendingAeAwbLockRunnable = null
    }

    private fun isCurrentBinding(binding: CameraBinding): Boolean {
        return binding.generation == bindGeneration && camera === binding.camera
    }

    private data class CameraBinding(
        val camera: Camera,
        val previewBound: Boolean,
        val generation: Long,
    )
}

internal object SensorNativeCameraPolicy {
    const val AE_AWB_WARMUP_MS = 400L
    private const val NORMAL_MODE_MAX_UPPER_FPS = 60

    data class FrameRateSelection(
        val primaryRange: Range<Int>,
        val primaryMode: NativeCameraFpsMode,
        val fallbackRange: Range<Int>?,
        val fallbackActivated: Boolean,
    )

    data class FrameRateSelectionBounds(
        val primaryBounds: Pair<Int, Int>,
        val primaryMode: NativeCameraFpsMode,
        val fallbackBounds: Pair<Int, Int>?,
        val fallbackActivated: Boolean,
    )

    data class CameraFacingSelection(
        val selected: NativeCameraFacing,
        val fallbackUsed: Boolean,
    )

    fun shouldLockAeAwb(elapsedMs: Long): Boolean {
        return elapsedMs >= AE_AWB_WARMUP_MS
    }

    fun selectFrameRateSelection(
        ranges: Set<Range<Int>>?,
        preferredMode: NativeCameraFpsMode,
    ): FrameRateSelection? {
        val bounds = ranges?.map { it.lower to it.upper }
        val selected = selectFrameRateSelectionBounds(bounds, preferredMode) ?: return null
        return FrameRateSelection(
            primaryRange = Range(selected.primaryBounds.first, selected.primaryBounds.second),
            primaryMode = selected.primaryMode,
            fallbackRange = selected.fallbackBounds?.let { Range(it.first, it.second) },
            fallbackActivated = selected.fallbackActivated,
        )
    }

    fun selectFrameRateSelectionBounds(
        bounds: Iterable<Pair<Int, Int>>?,
        preferredMode: NativeCameraFpsMode,
    ): FrameRateSelectionBounds? {
        if (bounds == null) {
            return null
        }
        val boundsList = bounds.toList()
        if (boundsList.isEmpty()) {
            return null
        }
        val normalBounds = selectHighestNormalFrameRateBounds(boundsList)
        val fixed120Bounds = boundsList.firstOrNull { it.first == 120 && it.second == 120 }
        return when (preferredMode) {
            NativeCameraFpsMode.HS120 -> {
                if (fixed120Bounds != null) {
                    val fallback = normalBounds?.takeIf { it != fixed120Bounds }
                    FrameRateSelectionBounds(
                        primaryBounds = fixed120Bounds,
                        primaryMode = NativeCameraFpsMode.HS120,
                        fallbackBounds = fallback,
                        fallbackActivated = false,
                    )
                } else {
                    val fallback = normalBounds ?: selectHighestFrameRateBounds(boundsList)
                    if (fallback == null) {
                        null
                    } else {
                        FrameRateSelectionBounds(
                            primaryBounds = fallback,
                            primaryMode = NativeCameraFpsMode.NORMAL,
                            fallbackBounds = null,
                            fallbackActivated = true,
                        )
                    }
                }
            }

            NativeCameraFpsMode.NORMAL -> {
                val selected = normalBounds ?: selectHighestFrameRateBounds(boundsList) ?: return null
                FrameRateSelectionBounds(
                    primaryBounds = selected,
                    primaryMode = NativeCameraFpsMode.NORMAL,
                    fallbackBounds = null,
                    fallbackActivated = false,
                )
            }
        }
    }

    fun selectHighestFrameRateRange(ranges: Set<Range<Int>>?): Range<Int>? {
        val selectedBounds = selectHighestFrameRateBounds(ranges?.map { it.lower to it.upper })
        if (selectedBounds == null) {
            return null
        }
        return Range(selectedBounds.first, selectedBounds.second)
    }

    fun selectHighestFrameRateBounds(
        bounds: Iterable<Pair<Int, Int>>?,
    ): Pair<Int, Int>? {
        if (bounds == null) {
            return null
        }
        return bounds.maxWithOrNull(compareBy<Pair<Int, Int>>({ it.second }, { it.first }))
    }

    fun selectHighestNormalFrameRateBounds(
        bounds: Iterable<Pair<Int, Int>>?,
    ): Pair<Int, Int>? {
        if (bounds == null) {
            return null
        }
        val normalBounds = bounds.filter { it.second <= NORMAL_MODE_MAX_UPPER_FPS }
        if (normalBounds.isEmpty()) {
            return null
        }
        return normalBounds.maxWithOrNull(compareBy<Pair<Int, Int>>({ it.second }, { it.first }))
    }

    fun selectCameraFacing(
        preferred: NativeCameraFacing,
        hasRear: Boolean,
        hasFront: Boolean,
    ): CameraFacingSelection? {
        if (!hasRear && !hasFront) {
            return null
        }
        return when (preferred) {
            NativeCameraFacing.REAR -> {
                if (hasRear) {
                    CameraFacingSelection(selected = NativeCameraFacing.REAR, fallbackUsed = false)
                } else {
                    CameraFacingSelection(selected = NativeCameraFacing.FRONT, fallbackUsed = true)
                }
            }

            NativeCameraFacing.FRONT -> {
                if (hasFront) {
                    CameraFacingSelection(selected = NativeCameraFacing.FRONT, fallbackUsed = false)
                } else {
                    CameraFacingSelection(selected = NativeCameraFacing.REAR, fallbackUsed = true)
                }
            }
        }
    }
}
