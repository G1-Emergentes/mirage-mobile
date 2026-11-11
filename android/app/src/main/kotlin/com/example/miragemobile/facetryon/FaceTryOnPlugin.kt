package com.example.miragemobile.facetryon

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * App-level bridge of the glasses try-on: camera permission, saving photos to the
 * gallery and the `mirage/face_try_on_view` platform view.
 */
class FaceTryOnPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val activity: Activity? get() = activityBinding?.activity
    private val pending = mutableMapOf<Int, (Boolean) -> Unit>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        binding.platformViewRegistry.registerViewFactory(VIEW_TYPE, Factory(binding.binaryMessenger))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        pending.values.forEach { it(false) }
        pending.clear()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.error("NO_ACTIVITY", "The app is not in the foreground", null)
            return
        }
        when (call.method) {
            "cameraPermission" -> cameraPermission(current, call.argument<Boolean>("request") == true, result)
            "openSettings" -> {
                current.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", current.packageName, null)),
                )
                result.success(null)
            }
            "saveToGallery" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.error("SAVE_FAILED", "Missing photo", null)
                    return
                }
                val legacy = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
                val storage = Manifest.permission.WRITE_EXTERNAL_STORAGE
                if (legacy && !granted(current, storage)) {
                    request(current, storage, STORAGE_REQUEST) { ok ->
                        if (ok) save(current, bytes, result)
                        else result.error("STORAGE_DENIED", "Storage permission denied", null)
                    }
                } else {
                    save(current, bytes, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun cameraPermission(activity: Activity, ask: Boolean, result: MethodChannel.Result) {
        val camera = Manifest.permission.CAMERA
        if (granted(activity, camera)) {
            result.success("granted")
            return
        }
        if (!ask) {
            result.success("denied")
            return
        }
        request(activity, camera, CAMERA_REQUEST) { ok ->
            result.success(
                when {
                    ok -> "granted"
                    // Denied with "don't ask again": only the system settings can grant it.
                    !ActivityCompat.shouldShowRequestPermissionRationale(activity, camera) -> "permanentlyDenied"
                    else -> "denied"
                },
            )
        }
    }

    private fun granted(context: Context, permission: String) =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    private fun request(activity: Activity, permission: String, code: Int, done: (Boolean) -> Unit) {
        pending.remove(code)?.invoke(false)
        pending[code] = done
        ActivityCompat.requestPermissions(activity, arrayOf(permission), code)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        val done = pending.remove(requestCode) ?: return false
        done(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }

    private fun save(context: Context, jpeg: ByteArray, result: MethodChannel.Result) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "mirage_tryon_${System.currentTimeMillis()}.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Mirage")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("SAVE_FAILED", "Could not create the image", null)
            return
        }
        try {
            resolver.openOutputStream(uri)?.use { it.write(jpeg) }
                ?: throw IllegalStateException("No output stream")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
            }
            result.success(uri.toString())
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            result.error("SAVE_FAILED", e.message, null)
        }
    }

    private inner class Factory(private val messenger: BinaryMessenger) :
        PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val host = activity
            val owner = host as? LifecycleOwner
                ?: throw IllegalStateException("The try-on view needs a lifecycle-aware activity")
            return FaceTryOnView(host, owner, messenger, viewId)
        }
    }

    companion object {
        const val CHANNEL = "mirage/face_try_on"
        const val VIEW_TYPE = "mirage/face_try_on_view"
        private const val CAMERA_REQUEST = 0x4d01
        private const val STORAGE_REQUEST = 0x4d02
    }
}
