package com.example.miragemobile.facetryon

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.util.concurrent.ExecutorService

/**
 * Front camera with two use cases sharing one ViewPort: the preview shows a crop of the
 * sensor and the analysis frames are cropped to the very same region, so the landmarks
 * MediaPipe returns line up with what the user sees.
 */
class CameraSource(
    private val context: Context,
    private val owner: LifecycleOwner,
    private val previewView: PreviewView,
    private val analysisExecutor: ExecutorService,
    private val onFrame: (Bitmap) -> Unit,
    private val onError: (String) -> Unit,
) {
    private var provider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var analysis: ImageAnalysis? = null
    private var stopped = false

    fun start() {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            if (stopped) return@addListener
            try {
                provider = future.get()
                bind()
            } catch (e: Exception) {
                Log.e(TAG, "Camera unavailable", e)
                onError("CAMERA_UNAVAILABLE")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bind() {
        val cameraProvider = provider ?: return
        val viewPort = previewView.viewPort ?: run {
            // Not laid out yet: try again on the next layout pass.
            previewView.post { if (!stopped) bind() }
            return
        }
        if (!cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
            onError("NO_FRONT_CAMERA")
            return
        }
        val fourThree = AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY
        val newPreview = Preview.Builder()
            .setResolutionSelector(ResolutionSelector.Builder().setAspectRatioStrategy(fourThree).build())
            .build()
        newPreview.setSurfaceProvider(previewView.surfaceProvider)
        val newAnalysis = ImageAnalysis.Builder()
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setAspectRatioStrategy(fourThree)
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            Size(640, 480),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                        ),
                    )
                    .build(),
            )
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
        newAnalysis.setAnalyzer(analysisExecutor) { proxy -> analyze(proxy) }
        val group = UseCaseGroup.Builder()
            .setViewPort(viewPort)
            .addUseCase(newPreview)
            .addUseCase(newAnalysis)
            .build()
        unbind()
        preview = newPreview
        analysis = newAnalysis
        try {
            cameraProvider.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, group)
        } catch (e: Exception) {
            Log.e(TAG, "Could not bind the camera", e)
            onError("CAMERA_UNAVAILABLE")
        }
    }

    private fun analyze(proxy: ImageProxy) {
        try {
            val full = proxy.toBitmap()
            val crop = proxy.cropRect
            val rotate = Matrix().apply { postRotate(proxy.imageInfo.rotationDegrees.toFloat()) }
            val fits = crop.width() > 0 && crop.height() > 0 &&
                crop.right <= full.width && crop.bottom <= full.height
            val upright = if (fits) {
                Bitmap.createBitmap(full, crop.left, crop.top, crop.width(), crop.height(), rotate, true)
            } else {
                Bitmap.createBitmap(full, 0, 0, full.width, full.height, rotate, true)
            }
            onFrame(upright)
        } catch (e: Exception) {
            Log.w(TAG, "Dropped a camera frame", e)
        } finally {
            proxy.close()
        }
    }

    private fun unbind() {
        val cameraProvider = provider ?: return
        analysis?.clearAnalyzer()
        listOfNotNull(preview, analysis).takeIf { it.isNotEmpty() }?.let {
            cameraProvider.unbind(*it.toTypedArray())
        }
        preview = null
        analysis = null
    }

    fun stop() {
        stopped = true
        unbind()
    }

    companion object {
        private const val TAG = "CameraSource"
    }
}
