package com.danielgoodwyn.skytime

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

object SkyGradient {

    private data class RGB(val r: Double, val g: Double, val b: Double)
    private data class Keyframe(val hour: Double, val stops: List<RGB>)

    private val keyframes = listOf(
        Keyframe(0.0, listOf(RGB(2.0,3.0,10.0), RGB(5.0,8.0,28.0), RGB(10.0,18.0,48.0), RGB(16.0,29.0,72.0))),
        Keyframe(4.0, listOf(RGB(4.0,6.0,20.0), RGB(8.0,16.0,40.0), RGB(16.0,30.0,70.0), RGB(24.0,45.0,102.0))),
        Keyframe(5.0, listOf(RGB(8.0,20.0,54.0), RGB(16.0,36.0,88.0), RGB(30.0,63.0,128.0), RGB(59.0,104.0,168.0))),
        Keyframe(5.5, listOf(RGB(14.0,31.0,77.0), RGB(34.0,56.0,117.0), RGB(92.0,60.0,122.0), RGB(168.0,80.0,112.0))),
        Keyframe(6.0, listOf(RGB(24.0,54.0,122.0), RGB(72.0,80.0,152.0), RGB(184.0,80.0,120.0), RGB(242.0,140.0,64.0))),
        Keyframe(6.5, listOf(RGB(36.0,82.0,166.0), RGB(86.0,132.0,200.0), RGB(216.0,152.0,108.0), RGB(250.0,224.0,140.0))),
        Keyframe(7.0, listOf(RGB(50.0,116.0,200.0), RGB(110.0,168.0,224.0), RGB(203.0,224.0,236.0), RGB(255.0,248.0,214.0))),
        Keyframe(9.5, listOf(RGB(28.0,100.0,196.0), RGB(78.0,150.0,222.0), RGB(158.0,208.0,242.0), RGB(238.0,248.0,252.0))),
        Keyframe(12.0, listOf(RGB(10.0,76.0,180.0), RGB(42.0,126.0,216.0), RGB(120.0,188.0,240.0), RGB(230.0,245.0,255.0))),
        Keyframe(15.0, listOf(RGB(20.0,86.0,184.0), RGB(56.0,130.0,212.0), RGB(130.0,188.0,232.0), RGB(216.0,238.0,251.0))),
        Keyframe(17.0, listOf(RGB(12.0,52.0,132.0), RGB(34.0,88.0,164.0), RGB(82.0,140.0,200.0), RGB(140.0,194.0,230.0))),
        Keyframe(17.5, listOf(RGB(12.0,42.0,114.0), RGB(38.0,72.0,146.0), RGB(112.0,100.0,164.0), RGB(212.0,124.0,84.0))),
        Keyframe(18.0, listOf(RGB(18.0,36.0,100.0), RGB(56.0,60.0,136.0), RGB(152.0,56.0,104.0), RGB(235.0,84.0,40.0))),
        Keyframe(18.5, listOf(RGB(10.0,22.0,68.0), RGB(30.0,36.0,100.0), RGB(100.0,40.0,104.0), RGB(200.0,60.0,36.0))),
        Keyframe(19.2, listOf(RGB(6.0,13.0,44.0), RGB(16.0,24.0,68.0), RGB(46.0,26.0,84.0), RGB(74.0,36.0,80.0))),
        Keyframe(20.5, listOf(RGB(3.0,6.0,20.0), RGB(7.0,12.0,38.0), RGB(14.0,22.0,58.0), RGB(21.0,34.0,84.0))),
        Keyframe(24.0, listOf(RGB(2.0,3.0,10.0), RGB(5.0,8.0,28.0), RGB(10.0,18.0,48.0), RGB(16.0,29.0,72.0)))
    )

    fun stops(hour24: Double, gain: Double = 1.0, lift: Double = 0.0): List<Color> {
        val h = (hour24 % 24.0 + 24.0) % 24.0
        var lo = keyframes[0]
        var hi = keyframes[keyframes.size - 1]

        for (i in 0 until keyframes.size - 1) {
            if (h >= keyframes[i].hour && h < keyframes[i + 1].hour) {
                lo = keyframes[i]
                hi = keyframes[i + 1]
                break
            }
        }

        val span = hi.hour - lo.hour
        val t = if (span > 0) (h - lo.hour) / span else 0.0

        return (0..3).map { idx ->
            val c1 = lo.stops[idx]
            val c2 = hi.stops[idx]

            val r = min(255.0, max(0.0, (c1.r * (1.0 - t) + c2.r * t) * gain + lift)).roundToInt()
            val g = min(255.0, max(0.0, (c1.g * (1.0 - t) + c2.g * t) * gain + lift)).roundToInt()
            val b = min(255.0, max(0.0, (c1.b * (1.0 - t) + c2.b * t) * gain + lift)).roundToInt()

            Color(r, g, b)
        }
    }

    fun verticalBrush(hour24: Double): Brush {
        return Brush.verticalGradient(stops(hour24))
    }

    fun trackBrush(hour24: Double, isDay: Boolean): Brush {
        val colors = if (isDay) stops(hour24, gain = 0.55, lift = 95.0) else stops(hour24, gain = 0.35, lift = 0.0)
        return Brush.horizontalGradient(colors)
    }

    fun fillBrush(hour24: Double): Brush {
        return Brush.horizontalGradient(stops(hour24, gain = 1.25, lift = 18.0))
    }
}
