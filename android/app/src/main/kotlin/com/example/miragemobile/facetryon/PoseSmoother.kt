package com.example.miragemobile.facetryon

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * One Euro filter (Casiez et al. 2012): strong smoothing when the head is still (no
 * jitter) and little smoothing when it moves fast (no lag).
 */
private class OneEuro(val minCutoff: Float, val beta: Float, val dCutoff: Float = 1f) {
    private var x = 0f
    private var dx = 0f
    private var ready = false

    private fun alpha(cutoff: Float, dt: Float): Float {
        val tau = 1f / (2f * PI.toFloat() * cutoff)
        return 1f / (1f + tau / dt)
    }

    fun filter(value: Float, dt: Float): Float {
        if (!ready) {
            x = value; dx = 0f; ready = true
            return value
        }
        val rawDx = (value - x) / dt
        dx += alpha(dCutoff, dt) * (rawDx - dx)
        val cutoff = minCutoff + beta * abs(dx)
        x += alpha(cutoff, dt) * (value - x)
        return x
    }

    fun reset() {
        ready = false
    }
}

/**
 * Smooths MediaPipe's face pose. Translation (cm), scale and rotation are filtered
 * separately; rotation is interpolated as a quaternion so it never shears.
 */
class PoseSmoother {
    private val translation = Array(3) { OneEuro(minCutoff = 1.2f, beta = 0.05f) }
    private val scale = OneEuro(minCutoff = 0.8f, beta = 0.0f)
    private var rotation: FloatArray? = null
    private var lastNanos = 0L

    fun reset() {
        translation.forEach { it.reset() }
        scale.reset()
        rotation = null
        lastNanos = 0L
    }

    /** Returns a new column-major matrix. */
    fun smooth(pose: FloatArray, timeNanos: Long): FloatArray {
        val dt = if (lastNanos == 0L) 1f / 30f
        else ((timeNanos - lastNanos) / 1e9f).coerceIn(1f / 240f, 0.5f)
        lastNanos = timeNanos

        val sx = length(pose[0], pose[1], pose[2])
        val sy = length(pose[4], pose[5], pose[6])
        val sz = length(pose[8], pose[9], pose[10])
        val s = (sx + sy + sz) / 3f
        val q = quaternionFromMatrix(pose, sx, sy, sz)

        val previous = rotation
        val smoothedQ = if (previous == null) q else {
            if (dot(previous, q) < 0f) for (i in 0..3) q[i] = -q[i]
            val angle = 2f * acos(dot(previous, q).coerceIn(-1f, 1f))
            // Rotational One Euro: the cutoff grows with the angular speed (rad/s).
            val cutoff = 1.0f + 0.6f * (angle / dt)
            val tau = 1f / (2f * PI.toFloat() * cutoff)
            slerp(previous, q, 1f / (1f + tau / dt))
        }
        rotation = smoothedQ

        val out = matrixFromQuaternion(smoothedQ)
        val fs = scale.filter(s, dt)
        for (c in 0..2) for (r in 0..2) out[c * 4 + r] *= fs
        out[12] = translation[0].filter(pose[12], dt)
        out[13] = translation[1].filter(pose[13], dt)
        out[14] = translation[2].filter(pose[14], dt)
        return out
    }

    private fun length(x: Float, y: Float, z: Float) = sqrt(x * x + y * y + z * z)

    private fun dot(a: FloatArray, b: FloatArray) =
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]

    /** (x, y, z, w) from the rotation part of a column-major matrix. */
    private fun quaternionFromMatrix(m: FloatArray, sx: Float, sy: Float, sz: Float): FloatArray {
        val m00 = m[0] / sx; val m10 = m[1] / sx; val m20 = m[2] / sx
        val m01 = m[4] / sy; val m11 = m[5] / sy; val m21 = m[6] / sy
        val m02 = m[8] / sz; val m12 = m[9] / sz; val m22 = m[10] / sz
        val trace = m00 + m11 + m22
        val q = FloatArray(4)
        if (trace > 0f) {
            val s = sqrt(trace + 1f) * 2f
            q[3] = 0.25f * s
            q[0] = (m21 - m12) / s
            q[1] = (m02 - m20) / s
            q[2] = (m10 - m01) / s
        } else if (m00 > m11 && m00 > m22) {
            val s = sqrt(1f + m00 - m11 - m22) * 2f
            q[3] = (m21 - m12) / s
            q[0] = 0.25f * s
            q[1] = (m01 + m10) / s
            q[2] = (m02 + m20) / s
        } else if (m11 > m22) {
            val s = sqrt(1f + m11 - m00 - m22) * 2f
            q[3] = (m02 - m20) / s
            q[0] = (m01 + m10) / s
            q[1] = 0.25f * s
            q[2] = (m12 + m21) / s
        } else {
            val s = sqrt(1f + m22 - m00 - m11) * 2f
            q[3] = (m10 - m01) / s
            q[0] = (m02 + m20) / s
            q[1] = (m12 + m21) / s
            q[2] = 0.25f * s
        }
        return normalize(q)
    }

    private fun matrixFromQuaternion(q: FloatArray): FloatArray {
        val (x, y, z, w) = q
        return floatArrayOf(
            1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0f,
            2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0f,
            2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0f,
            0f, 0f, 0f, 1f,
        )
    }

    private fun normalize(q: FloatArray): FloatArray {
        val n = sqrt(dot(q, q))
        for (i in 0..3) q[i] /= n
        return q
    }

    private fun slerp(a: FloatArray, b: FloatArray, t: Float): FloatArray {
        val cos = dot(a, b).coerceIn(-1f, 1f)
        if (cos > 0.9995f) {
            return normalize(FloatArray(4) { a[it] + t * (b[it] - a[it]) })
        }
        val theta = acos(cos)
        val sinTheta = sin(theta)
        val wa = sin((1 - t) * theta) / sinTheta
        val wb = sin(t * theta) / sinTheta
        return FloatArray(4) { wa * a[it] + wb * b[it] }
    }
}
