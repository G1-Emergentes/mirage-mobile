package com.example.miragemobile.facetryon

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Camera preview + face tracking + glasses rendering, embedded in Flutter.
 *
 * Layers (bottom to top): CameraX preview (mirrored by CameraX for the front camera),
 * Filament on a transparent TextureView (mirrored here, because MediaPipe receives the
 * un-mirrored image), and an optional debug overlay with the anchor landmarks.
 *
 * Channels: `mirage/face_try_on/view_<id>` for commands, `mirage/face_try_on/events_<id>`
 * for tracking updates.
 */
class FaceTryOnView(
    context: Context,
    owner: LifecycleOwner,
    messenger: BinaryMessenger,
    id: Int,
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private val root = FrameLayout(context)
    private val previewView = PreviewView(context).apply {
        // TextureView-backed: required inside Flutter and for capturing the frame.
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }
    private val glView = TextureView(context).apply { scaleX = -1f }
    private val overlay = DebugOverlay(context)
    private val renderer: GlassesRenderer
    private val smoother = PoseSmoother()
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val tracker: FaceTracker
    private val camera: CameraSource
    private val methods = MethodChannel(messenger, "mirage/face_try_on/view_$id")
    private val events = EventChannel(messenger, "mirage/face_try_on/events_$id")
    private var sink: EventChannel.EventSink? = null

    private var faceVisible = false
    private var lastFaceAt = 0L
    private var framesThisSecond = 0
    private var secondStartedAt = SystemClock.uptimeMillis()
    private var fps = 0.0
    private var disposed = false

    init {
        val match = FrameLayout.LayoutParams.MATCH_PARENT
        root.setBackgroundColor(Color.BLACK)
        root.addView(previewView, FrameLayout.LayoutParams(match, match))
        root.addView(glView, FrameLayout.LayoutParams(match, match))
        root.addView(overlay, FrameLayout.LayoutParams(match, match))
        renderer = GlassesRenderer(glView)
        renderer.start()
        tracker = FaceTracker(
            context,
            onResult = { frame -> main.post { onFace(frame) } },
            onError = { code -> main.post { emit(mapOf("type" to "error", "code" to code)) } },
        )
        camera = CameraSource(
            context, owner, previewView, analysisExecutor,
            onFrame = { bitmap -> tracker.process(bitmap) },
            onError = { code -> main.post { emit(mapOf("type" to "error", "code" to code)) } },
        )
        camera.start()
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun getView(): View = root

    private fun onFace(frame: FaceFrame?) {
        if (disposed) return
        val now = SystemClock.uptimeMillis()
        framesThisSecond++
        if (now - secondStartedAt >= 1000) {
            fps = framesThisSecond * 1000.0 / (now - secondStartedAt)
            framesThisSecond = 0
            secondStartedAt = now
            emitTracking()
        }
        if (frame != null) {
            lastFaceAt = now
            renderer.setPose(smoother.smooth(frame.pose, System.nanoTime()))
            overlay.points = frame.landmarks
            if (!faceVisible) {
                faceVisible = true
                emitTracking()
            }
        } else if (faceVisible && now - lastFaceAt > FACE_LOST_AFTER_MS) {
            faceVisible = false
            renderer.setPose(null)
            smoother.reset()
            overlay.points = null
            emitTracking()
        }
    }

    private fun emitTracking() =
        emit(mapOf("type" to "tracking", "face" to faceVisible, "fps" to fps))

    private fun emit(event: Map<String, Any?>) {
        if (!disposed) sink?.success(event)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("INVALID_MODEL", "Missing model bytes", null)
                    return
                }
                try {
                    renderer.loadModel(bytes, GlassesFit.from(call.argument<Map<*, *>>("fit")))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("INVALID_MODEL", e.message, null)
                }
            }
            "updateFit" -> {
                renderer.updateFit(GlassesFit.from(call.argument<Map<*, *>>("fit")))
                result.success(null)
            }
            "clearModel" -> {
                renderer.clearModel()
                result.success(null)
            }
            "setDebug" -> {
                overlay.visibility = if (call.argument<Boolean>("enabled") == true) View.VISIBLE else View.GONE
                result.success(null)
            }
            "capture" -> capture(result)
            else -> result.notImplemented()
        }
    }

    /** What the user sees: mirrored camera frame + mirrored glasses, as JPEG. */
    private fun capture(result: MethodChannel.Result) {
        val width = root.width
        val height = root.height
        val cameraFrame = previewView.bitmap
        val glasses = glView.bitmap
        if (width == 0 || height == 0 || cameraFrame == null) {
            result.error("CAPTURE_FAILED", "The camera is not ready", null)
            return
        }
        Thread {
            try {
                val photo = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(photo)
                canvas.drawBitmap(cameraFrame, null, Rect(0, 0, width, height), null)
                if (glasses != null) {
                    canvas.save()
                    canvas.scale(-1f, 1f, width / 2f, 0f)
                    canvas.drawBitmap(glasses, null, Rect(0, 0, width, height), null)
                    canvas.restore()
                }
                val jpeg = ByteArrayOutputStream()
                photo.compress(Bitmap.CompressFormat.JPEG, 92, jpeg)
                main.post { result.success(jpeg.toByteArray()) }
            } catch (e: Exception) {
                main.post { result.error("CAPTURE_FAILED", e.message, null) }
            }
        }.start()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        emitTracking()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
        camera.stop()
        analysisExecutor.execute { tracker.close() }
        analysisExecutor.shutdown()
        renderer.destroy()
    }

    /** Draws the anchor landmarks (mirrored like the preview) to calibrate the fit. */
    private class DebugOverlay(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.GREEN }

        var points: FloatArray? = null
            set(value) {
                field = value
                if (visibility == VISIBLE) invalidate()
            }

        init {
            visibility = GONE
        }

        override fun onDraw(canvas: Canvas) {
            val p = points ?: return
            for (i in p.indices step 2) {
                canvas.drawCircle((1f - p[i]) * width, p[i + 1] * height, 8f, paint)
            }
        }
    }

    companion object {
        private const val FACE_LOST_AFTER_MS = 250L
    }
}
