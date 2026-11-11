package com.example.miragemobile.facetryon

import android.opengl.Matrix
import android.view.Choreographer
import android.view.Surface
import android.view.TextureView
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.EntityManager
import com.google.android.filament.Filament
import com.google.android.filament.IndirectLight
import com.google.android.filament.LightManager
import com.google.android.filament.Renderer
import com.google.android.filament.Scene
import com.google.android.filament.SwapChain
import com.google.android.filament.Texture
import com.google.android.filament.View
import com.google.android.filament.Viewport
import com.google.android.filament.android.UiHelper
import com.google.android.filament.gltfio.AssetLoader
import com.google.android.filament.gltfio.FilamentAsset
import com.google.android.filament.gltfio.Gltfio
import com.google.android.filament.gltfio.ResourceLoader
import com.google.android.filament.gltfio.UbershaderProvider
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.sqrt

/**
 * How a glasses model sits on the face. The GLB contract (virtual-try-on-service) puts
 * the origin on the nose bridge, front plane, in metres; this adds a per-model nudge.
 */
data class GlassesFit(
    val offsetXm: Float = 0f,
    val offsetYm: Float = 0.003f,
    val offsetZm: Float = 0.006f,
    val scale: Float = 1f,
    val pitchDeg: Float = 0f,
) {
    companion object {
        fun from(map: Map<*, *>?): GlassesFit {
            if (map == null) return GlassesFit()
            val offset = (map["offset_m"] as? List<*>)?.map { (it as Number).toFloat() }
            val defaults = GlassesFit()
            return GlassesFit(
                offsetXm = offset?.getOrNull(0) ?: defaults.offsetXm,
                offsetYm = offset?.getOrNull(1) ?: defaults.offsetYm,
                offsetZm = offset?.getOrNull(2) ?: defaults.offsetZm,
                scale = (map["scale"] as? Number)?.toFloat() ?: defaults.scale,
                pitchDeg = (map["pitch_deg"] as? Number)?.toFloat() ?: defaults.pitchDeg,
            )
        }
    }
}

/**
 * Filament scene on a transparent TextureView drawn over the camera preview.
 *
 * World units are centimetres, the camera sits at the origin looking down -Z with
 * MediaPipe's vertical field of view: MediaPipe's facial transformation matrix can be
 * used as the model matrix without any conversion.
 */
class GlassesRenderer(private val textureView: TextureView) : Choreographer.FrameCallback {
    private val engine: Engine
    private val renderer: Renderer
    private val scene: Scene
    private val view: View
    private val camera: Camera
    private val cameraEntity: Int
    private val sun: Int
    private val reflections: Texture
    private val indirectLight: IndirectLight
    private val uiHelper = UiHelper(UiHelper.ContextErrorPolicy.DONT_CHECK)
    private val materialProvider: UbershaderProvider
    private val assetLoader: AssetLoader
    private val resourceLoader: ResourceLoader
    private var swapChain: SwapChain? = null

    private var asset: FilamentAsset? = null
    private var assetInScene = false
    private var fit = GlassesFit()
    private var pose: FloatArray? = null
    private var running = false
    private var destroyed = false

    init {
        Filament.init()
        Gltfio.init()
        engine = Engine.create()
        renderer = engine.createRenderer()
        scene = engine.createScene()
        view = engine.createView()
        cameraEntity = EntityManager.get().create()
        camera = engine.createCamera(cameraEntity)
        // Same exposure as Filament's defaults, written out so lighting below is readable.
        camera.setExposure(16f, 1f / 125f, 100f)
        view.camera = camera
        view.scene = scene
        view.blendMode = View.BlendMode.TRANSLUCENT
        view.antiAliasing = View.AntiAliasing.FXAA
        view.multiSampleAntiAliasingOptions = View.MultiSampleAntiAliasingOptions().apply {
            enabled = true
            sampleCount = 4
        }
        renderer.clearOptions = Renderer.ClearOptions().apply {
            clear = true
            clearColor = doubleArrayOf(0.0, 0.0, 0.0, 0.0)
        }

        reflections = studioCubemap(engine)
        indirectLight = IndirectLight.Builder()
            .reflections(reflections)
            .irradiance(1, floatArrayOf(0.75f, 0.75f, 0.78f))
            .intensity(28_000f)
            .build(engine)
        scene.indirectLight = indirectLight
        sun = EntityManager.get().create()
        LightManager.Builder(LightManager.Type.DIRECTIONAL)
            .color(1f, 0.97f, 0.92f)
            .intensity(60_000f)
            .direction(0.25f, -0.6f, -1f)
            .castShadows(false)
            .build(engine, sun)
        scene.addEntity(sun)

        materialProvider = UbershaderProvider(engine)
        assetLoader = AssetLoader(engine, materialProvider, EntityManager.get())
        resourceLoader = ResourceLoader(engine)

        uiHelper.isOpaque = false
        uiHelper.renderCallback = object : UiHelper.RendererCallback {
            override fun onNativeWindowChanged(surface: Surface) {
                swapChain?.let { engine.destroySwapChain(it) }
                swapChain = engine.createSwapChain(surface, uiHelper.swapChainFlags)
            }

            override fun onDetachedFromSurface() {
                swapChain?.let {
                    engine.destroySwapChain(it)
                    engine.flushAndWait()
                }
                swapChain = null
            }

            override fun onResized(width: Int, height: Int) {
                view.viewport = Viewport(0, 0, width, height)
                camera.setProjection(
                    VERTICAL_FOV_DEG, width.toDouble() / max(height, 1),
                    NEAR_CM, FAR_CM, Camera.Fov.VERTICAL,
                )
            }
        }
        uiHelper.attachTo(textureView)
    }

    fun start() {
        if (running || destroyed) return
        running = true
        Choreographer.getInstance().postFrameCallback(this)
    }

    fun stop() {
        running = false
        Choreographer.getInstance().removeFrameCallback(this)
    }

    /** Replaces the current model. Throws if the bytes are not a valid glTF binary. */
    fun loadModel(glb: ByteArray, newFit: GlassesFit) {
        val buffer = ByteBuffer.allocateDirect(glb.size).order(ByteOrder.nativeOrder())
        buffer.put(glb).flip()
        val loaded = assetLoader.createAsset(buffer) ?: throw IllegalArgumentException("INVALID_MODEL")
        resourceLoader.loadResources(loaded)
        loaded.releaseSourceData()
        clearModel()
        asset = loaded
        fit = newFit
    }

    fun updateFit(newFit: GlassesFit) {
        fit = newFit
    }

    fun clearModel() {
        asset?.let {
            if (assetInScene) scene.removeEntities(it.entities)
            assetLoader.destroyAsset(it)
        }
        asset = null
        assetInScene = false
    }

    /** Latest smoothed face pose, or null when no face is visible. */
    fun setPose(matrix: FloatArray?) {
        pose = matrix
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (!running) return
        Choreographer.getInstance().postFrameCallback(this)
        updateModelTransform()
        val chain = swapChain ?: return
        if (uiHelper.isReadyToRender && renderer.beginFrame(chain, frameTimeNanos)) {
            renderer.render(view)
            renderer.endFrame()
        }
    }

    private fun updateModelTransform() {
        val model = asset ?: return
        val face = pose
        if (face == null) {
            if (assetInScene) {
                scene.removeEntities(model.entities)
                assetInScene = false
            }
            return
        }
        // model = facePose * T(noseBridge + offset) * Rx(pitch) * S(metres -> cm)
        val local = FloatArray(16)
        Matrix.setIdentityM(local, 0)
        Matrix.translateM(
            local, 0,
            NOSE_BRIDGE_CM[0] + fit.offsetXm * 100f,
            NOSE_BRIDGE_CM[1] + fit.offsetYm * 100f,
            NOSE_BRIDGE_CM[2] + fit.offsetZm * 100f,
        )
        if (fit.pitchDeg != 0f) Matrix.rotateM(local, 0, fit.pitchDeg, 1f, 0f, 0f)
        val s = 100f * fit.scale
        Matrix.scaleM(local, 0, s, s, s)
        val world = FloatArray(16)
        Matrix.multiplyMM(world, 0, face, 0, local, 0)
        val tm = engine.transformManager
        tm.setTransform(tm.getInstance(model.root), world)
        if (!assetInScene) {
            scene.addEntities(model.entities)
            assetInScene = true
        }
    }

    fun destroy() {
        if (destroyed) return
        stop()
        destroyed = true
        clearModel()
        uiHelper.detach()
        swapChain?.let { engine.destroySwapChain(it) }
        swapChain = null
        resourceLoader.destroy()
        assetLoader.destroy()
        materialProvider.destroyMaterials()
        materialProvider.destroy()
        engine.destroyIndirectLight(indirectLight)
        engine.destroyTexture(reflections)
        engine.destroyEntity(sun)
        EntityManager.get().destroy(sun)
        engine.destroyRenderer(renderer)
        engine.destroyView(view)
        engine.destroyScene(scene)
        engine.destroyCameraComponent(cameraEntity)
        EntityManager.get().destroy(cameraEntity)
        engine.destroy()
    }

    companion object {
        /** MediaPipe face geometry: perspective camera used to build the metric pose. */
        const val VERTICAL_FOV_DEG = 63.0
        const val NEAR_CM = 1.0
        const val FAR_CM = 2000.0

        /** Landmark 168 (between the eyes) in MediaPipe's canonical face model, in cm. */
        val NOSE_BRIDGE_CM = floatArrayOf(0f, 3.271027f, 5.236015f)

        /**
         * A soft "photo studio" environment generated in code: bright top, neutral
         * horizon, dark floor. Gives metal frames something to reflect without shipping
         * an HDR file.
         */
        private fun studioCubemap(engine: Engine): Texture {
            val size = 32
            val texture = Texture.Builder()
                .width(size)
                .height(size)
                .levels(1)
                .sampler(Texture.Sampler.SAMPLER_CUBEMAP)
                .format(Texture.InternalFormat.RGBA8)
                .build(engine)
            val data = ByteBuffer.allocateDirect(size * size * 4 * 6)
            for (face in 0 until 6) {
                for (py in 0 until size) {
                    for (px in 0 until size) {
                        val u = 2f * (px + 0.5f) / size - 1f
                        val v = 2f * (py + 0.5f) / size - 1f
                        // Cubemap face directions (+X, -X, +Y, -Y, +Z, -Z).
                        val (x, y, z) = when (face) {
                            0 -> Triple(1f, -v, -u)
                            1 -> Triple(-1f, -v, u)
                            2 -> Triple(u, 1f, v)
                            3 -> Triple(u, -1f, -v)
                            4 -> Triple(u, -v, 1f)
                            else -> Triple(-u, -v, -1f)
                        }
                        val up = y / sqrt(x * x + y * y + z * z)
                        val level = when {
                            up > 0.55f -> 1f
                            up > -0.1f -> 0.55f + 0.45f * ((up + 0.1f) / 0.65f)
                            else -> 0.18f
                        }
                        val c = (level * 255f).toInt().coerceIn(0, 255).toByte()
                        data.put(c).put(c).put(c).put(255.toByte())
                    }
                }
            }
            data.flip()
            texture.setImage(
                engine, 0, 0, 0, 0, size, size, 6,
                Texture.PixelBufferDescriptor(data, Texture.Format.RGBA, Texture.Type.UBYTE),
            )
            return texture
        }
    }
}
