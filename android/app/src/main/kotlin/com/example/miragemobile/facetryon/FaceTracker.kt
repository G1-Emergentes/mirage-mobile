package com.example.miragemobile.facetryon

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import java.util.concurrent.atomic.AtomicInteger

/**
 * One tracked face in a frame.
 *
 * [pose] is MediaPipe's facial transformation matrix (column-major, 4x4): it moves the
 * canonical face model (centimetres) into the metric camera space, where the camera sits
 * at the origin looking down -Z. [landmarks] holds the few normalised points the debug
 * overlay draws: x/y pairs in the order of [DEBUG_LANDMARKS].
 */
class FaceFrame(
    val pose: FloatArray,
    val landmarks: FloatArray,
    val imageWidth: Int,
    val imageHeight: Int,
)

/**
 * MediaPipe Face Landmarker in LIVE_STREAM mode. All calls must come from the same
 * (analysis) thread; results arrive asynchronously on a MediaPipe thread.
 */
class FaceTracker(
    private val context: Context,
    private val onResult: (FaceFrame?) -> Unit,
    private val onError: (String) -> Unit,
) {
    private var landmarker: FaceLandmarker? = null
    private var delegate = Delegate.GPU
    private var lastTimestamp = 0L
    private var failed = false

    /**
     * Some GPUs (and the emulator) build the GPU graph fine and then fail on the first
     * frames. Set from MediaPipe's thread; the analysis thread then rebuilds on CPU.
     */
    @Volatile
    private var gpuBroken = false

    /**
     * Frames sent since the last result. MediaPipe answers every frame (with or without
     * a face); a GPU graph that fails internally only logs and never answers, so many
     * unanswered frames mean the GPU path is broken.
     */
    private val unanswered = AtomicInteger(0)

    private fun create(delegate: Delegate): FaceLandmarker {
        val base = BaseOptions.builder()
            .setModelAssetPath(MODEL_ASSET)
            .setDelegate(delegate)
            .build()
        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumFaces(1)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setOutputFaceBlendshapes(false)
            .setOutputFacialTransformationMatrixes(true)
            .setResultListener { result: FaceLandmarkerResult, image ->
                unanswered.set(0)
                onResult(toFrame(result, image.width, image.height))
            }
            .setErrorListener { error ->
                if (delegate == Delegate.GPU) {
                    Log.w(TAG, "GPU inference failed, switching to CPU", error)
                    gpuBroken = true
                } else {
                    Log.e(TAG, "Face tracking failed", error)
                    onError("FACE_TRACKER_UNAVAILABLE")
                }
            }
            .build()
        return FaceLandmarker.createFromOptions(context, options)
    }

    private fun ensure(): FaceLandmarker? {
        if (delegate == Delegate.GPU && unanswered.get() > MAX_UNANSWERED_FRAMES) {
            Log.w(TAG, "GPU delegate returns no results, switching to CPU")
            gpuBroken = true
        }
        if (gpuBroken && delegate == Delegate.GPU) {
            unanswered.set(0)
            closeQuietly()
            landmarker = null
            delegate = Delegate.CPU
        }
        if (landmarker != null || failed) return landmarker
        landmarker = try {
            create(delegate)
        } catch (e: Throwable) {
            if (delegate == Delegate.GPU) {
                Log.w(TAG, "GPU delegate unavailable, falling back to CPU", e)
                delegate = Delegate.CPU
                try {
                    create(Delegate.CPU)
                } catch (e2: Throwable) {
                    Log.e(TAG, "Face tracker unavailable", e2)
                    null
                }
            } else {
                Log.e(TAG, "Face tracker unavailable", e)
                null
            }
        }
        if (landmarker == null) {
            failed = true
            onError("FACE_TRACKER_UNAVAILABLE")
        }
        return landmarker
    }

    /** [bitmap] must be upright and cropped to exactly what the preview shows. */
    fun process(bitmap: Bitmap) {
        val tracker = ensure() ?: return
        // LIVE_STREAM requires strictly increasing timestamps.
        val now = SystemClock.uptimeMillis().coerceAtLeast(lastTimestamp + 1)
        lastTimestamp = now
        try {
            unanswered.incrementAndGet()
            tracker.detectAsync(BitmapImageBuilder(bitmap).build(), now)
        } catch (e: Exception) {
            // A broken GPU graph rejects new packets; the next frame rebuilds on CPU.
            if (delegate == Delegate.GPU) gpuBroken = true
            else Log.w(TAG, "Dropped a frame", e)
        }
    }

    fun close() {
        closeQuietly()
        landmarker = null
    }

    /** Closing a graph that already failed rethrows its error: nothing left to do. */
    private fun closeQuietly() {
        try {
            landmarker?.close()
        } catch (e: Exception) {
            Log.d(TAG, "Closed a failed face tracker", e)
        }
    }

    private fun toFrame(result: FaceLandmarkerResult, width: Int, height: Int): FaceFrame? {
        val faces = result.faceLandmarks()
        val matrices = result.facialTransformationMatrixes().orElse(null)
        if (faces.isEmpty() || matrices.isNullOrEmpty()) return null
        val face = faces[0]
        val points = FloatArray(DEBUG_LANDMARKS.size * 2)
        DEBUG_LANDMARKS.forEachIndexed { i, index ->
            points[i * 2] = face[index].x()
            points[i * 2 + 1] = face[index].y()
        }
        return FaceFrame(matrices[0].copyOf(), points, width, height)
    }

    companion object {
        private const val TAG = "FaceTracker"
        private const val MAX_UNANSWERED_FRAMES = 15
        const val MODEL_ASSET = "face_landmarker.task"

        /**
         * Nose bridge (the anchor, landmark 6), outer corners of the eyes and upper eyelids:
         * with the debug overlay on, the lens centres should sit between the eyelid points.
         */
        val DEBUG_LANDMARKS = intArrayOf(6, 33, 263, 159, 386)
    }
}
