package com.danielgoodwyn.skytime

import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import kotlin.math.*

data class SunEvent(
    val time: Long?,
    val polar: String? // "day", "night", or null
)

data class SkyTimeResult(
    val h: Int,
    val m: Int,
    val s: Int,
    val ap: String,
    val skyHours: Double,
    val isDay: Bool,
    val dayProg: Double
)

data class ClockTimeResult(
    val h: Int,
    val m: Int,
    val s: Int,
    val ap: String,
    val fracHour: Double,
    val year: Int,
    val month: Int,
    val day: Int,
    val isoDate: String,
    val isoTime: String,
    val tzOffsetHours: Double
)

typealias Bool = Boolean

object AstronomicalEngine {

    fun calcSunEvent(y: Int, m: Int, d: Int, latD: Double, lngD: Double, isRise: Boolean): SunEvent {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(y, m - 1, d, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val targetMs = cal.timeInMillis

        val calYearStart = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(y, 0, 0, 0, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val yearStartMs = calYearStart.timeInMillis

        val N = floor((targetMs - yearStartMs) / 86400000.0)
        val lngH = lngD / 15.0
        val t = N + ((if (isRise) 6.0 else 18.0) - lngH) / 24.0
        val M = (0.9856 * t) - 3.289
        val Mr = Math.toRadians(M)

        var L = ((M + 1.916 * sin(Mr) + 0.020 * sin(2.0 * Mr) + 282.634) % 360.0 + 360.0) % 360.0
        val Lr = Math.toRadians(L)

        var RA = ((Math.toDegrees(atan(0.91764 * tan(Lr)))) % 360.0 + 360.0) % 360.0
        RA = (RA + (floor(L / 90.0) * 90.0 - floor(RA / 90.0) * 90.0)) / 15.0

        val sinDec = 0.39782 * sin(Lr)
        val cosDec = cos(asin(sinDec))
        val cosH = (cos(Math.toRadians(90.833)) - sinDec * sin(Math.toRadians(latD))) / (cosDec * cos(Math.toRadians(latD)))

        if (cosH > 1.0) return SunEvent(null, "night")
        if (cosH < -1.0) return SunEvent(null, "day")

        val H = if (isRise) {
            (360.0 - Math.toDegrees(acos(cosH))) / 15.0
        } else {
            Math.toDegrees(acos(cosH)) / 15.0
        }

        var T = ((H + RA - 0.06571 * t - 6.622) % 24.0 + 24.0) % 24.0
        if (isRise && T > 12.0) T -= 24.0
        if (!isRise && T < 12.0) T += 24.0

        val eventMs = (targetMs + (T - lngH) * 3600000.0).toLong()
        return SunEvent(eventMs, null)
    }

    fun getSkyTime(nowMs: Long, latD: Double, lngD: Double): SkyTimeResult {
        val lngH = lngD / 15.0
        val solarMs = (nowMs + lngH * 3600000.0).toLong()
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = solarMs }

        val Y = cal.get(Calendar.YEAR)
        val M = cal.get(Calendar.MONTH) + 1
        val D = cal.get(Calendar.DAY_OF_MONTH)

        data class DayEv(val rise: SunEvent, val set: SunEvent, val midMs: Long)

        fun dayEvents(off: Int): DayEv {
            val c = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
                set(Y, M - 1, D, 0, 0, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_MONTH, off)
            }
            val y = c.get(Calendar.YEAR)
            val m = c.get(Calendar.MONTH) + 1
            val d = c.get(Calendar.DAY_OF_MONTH)
            val rise = calcSunEvent(y, m, d, latD, lngD, true)
            val set = calcSunEvent(y, m, d, latD, lngD, false)
            val mid = (c.timeInMillis - lngH * 3600000.0).toLong()
            return DayEv(rise, set, mid)
        }

        val prev = dayEvents(-1)
        val curr = dayEvents(0)
        val next = dayEvents(1)

        var isDay = false
        var prog = 0.0

        if (curr.rise.polar == "day" || curr.rise.polar == "night") {
            isDay = curr.rise.polar == "day"
            prog = max(0.0, min(1.0, (nowMs - curr.midMs) / 86400000.0))
        } else {
            val rPrev = prev.rise.time ?: (curr.midMs - 64800000L)
            val sPrev = prev.set.time ?: (curr.midMs - 21600000L)
            val rCurr = curr.rise.time ?: (curr.midMs + 21600000L)
            val sCurr = curr.set.time ?: (curr.midMs + 64800000L)
            val rNext = next.rise.time ?: (curr.midMs + 108000000L)
            val sNext = next.set.time ?: (curr.midMs + 151200000L)

            val start: Long
            val end: Long

            if (nowMs >= rNext) {
                isDay = true; start = rNext; end = sNext
            } else if (nowMs >= sCurr) {
                isDay = false; start = sCurr; end = rNext
            } else if (nowMs >= rCurr) {
                isDay = true; start = rCurr; end = sCurr
            } else if (nowMs >= sPrev) {
                isDay = false; start = sPrev; end = rCurr
            } else {
                isDay = true; start = rPrev; end = sPrev
            }

            if (end > start) {
                prog = max(0.0, min(1.0, (nowMs - start).toDouble() / (end - start).toDouble()))
            }
        }

        val skyHours = if (isDay) (6.0 + prog * 12.0) else (18.0 + prog * 12.0)
        val h24 = (skyHours % 24.0 + 24.0) % 24.0
        val H = floor(h24).toInt()
        val fracM = (h24 - H) * 60.0
        val Min = floor(fracM).toInt()
        val Sec = floor((fracM - Min) * 60.0).toInt()
        val h12 = if (H % 12 == 0) 12 else (H % 12)
        val ap = if (H < 12) "am" else "pm"
        val dayProg = if (isDay) (prog * 0.5) else (0.5 + prog * 0.5)

        return SkyTimeResult(h12, Min, Sec, ap, h24, isDay, dayProg)
    }

    fun isDstInRegion(nowMs: Long, latD: Double, lngD: Double): Boolean {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = nowMs }
        val m = cal.get(Calendar.MONTH) + 1
        val date = cal.get(Calendar.DAY_OF_MONTH)
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val year = cal.get(Calendar.YEAR)

        if (latD in 24.0..72.0 && lngD in -168.0..-52.0) {
            if (latD in 31.3..37.0 && lngD in -114.8..-109.0) return false // Arizona
            if (latD <= 23.0 && lngD in -162.0..-154.0) return false // Hawaii
            if (m in 4..10) return true
            if (m == 3) {
                val cMar1 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(year, 2, 1) }
                val firstDay = cMar1.get(Calendar.DAY_OF_WEEK) - 1
                val secondSun = 1 + (7 - firstDay) % 7 + 7
                return date > secondSun || (date == secondSun && hour >= 10)
            }
            if (m == 11) {
                val cNov1 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(year, 10, 1) }
                val firstDay = cNov1.get(Calendar.DAY_OF_WEEK) - 1
                val firstSun = 1 + (7 - firstDay) % 7
                return date < firstSun || (date == firstSun && hour < 10)
            }
            return false
        }

        if (latD in 35.0..72.0 && lngD in -15.0..40.0) {
            if (latD >= 63.0 && lngD <= -13.0) return false // Iceland
            if (lngD > 28.0 && latD >= 50.0) return false // Russia/Belarus
            if (m in 4..9) return true
            if (m == 3) {
                val cMar31 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(year, 2, 31) }
                val lastDay = cMar31.get(Calendar.DAY_OF_WEEK) - 1
                val lastSun = 31 - lastDay
                return date > lastSun || (date == lastSun && hour >= 1)
            }
            if (m == 10) {
                val cOct31 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(year, 9, 31) }
                val lastDay = cOct31.get(Calendar.DAY_OF_WEEK) - 1
                val lastSun = 31 - lastDay
                return date < lastSun || (date == lastSun && hour < 1)
            }
            return false
        }

        if (latD in -44.0..-28.0 && lngD in 135.0..155.0) {
            if (m >= 11 || m < 4) return true
            if (m == 10) {
                val cOct1 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(year, 9, 1) }
                val firstDay = cOct1.get(Calendar.DAY_OF_WEEK) - 1
                val firstSun = 1 + (7 - firstDay) % 7
                return date >= firstSun
            }
            if (m == 4) {
                val cApr1 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(year, 3, 1) }
                val firstDay = cApr1.get(Calendar.DAY_OF_WEEK) - 1
                val firstSun = 1 + (7 - firstDay) % 7
                return date < firstSun
            }
            return false
        }

        return false
    }

    fun getTimezoneOffsetHours(nowMs: Long, latD: Double, lngD: Double, isGPS: Boolean): Double {
        if (isGPS) {
            return TimeZone.getDefault().getOffset(nowMs).toDouble() / 3600000.0
        }

        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = nowMs }
        val y = cal.get(Calendar.YEAR)
        val cJan15 = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(y, 0, 15) }
        val localStdOffset = TimeZone.getDefault().getOffset(cJan15.timeInMillis).toDouble() / 3600000.0
        val targetStdOffset = round(lngD / 15.0)

        if (abs(targetStdOffset - localStdOffset) < 0.1 && abs(lngD - (-localStdOffset * 15.0)) < 16.0) {
            return TimeZone.getDefault().getOffset(nowMs).toDouble() / 3600000.0
        }

        if (latD in 36.0..60.0 && lngD in -11.0..30.0) {
            val isGmt = (latD in 50.0..60.0 && lngD in -11.0..1.8) ||
                        (latD in 36.0..42.5 && lngD in -9.6..-6.1)
            val base = if (isGmt) 0.0 else 1.0
            return base + (if (isDstInRegion(nowMs, latD, lngD)) 1.0 else 0.0)
        }

        if (latD in 7.0..36.0 && lngD in 68.0..90.0) return 5.5
        if (latD in 25.0..40.0 && lngD in 44.0..63.0) return 3.5
        if (latD in 26.0..31.0 && lngD in 80.0..88.0) return 5.75
        if (latD <= -10.0 && lngD in 129.0..141.0) {
            val isDst = latD <= -26.0 && isDstInRegion(nowMs, latD, lngD)
            return 9.5 + (if (isDst) 1.0 else 0.0)
        }
        if (latD in 46.0..52.0 && lngD in -59.0..-52.0) {
            return -3.5 + (if (isDstInRegion(nowMs, latD, lngD)) 1.0 else 0.0)
        }
        if (latD in 18.0..54.0 && lngD in 73.0..135.0) return 8.0

        var base = round(lngD / 15.0)
        if (isDstInRegion(nowMs, latD, lngD)) base += 1.0
        return base
    }

    fun getClockTime(nowMs: Long, latD: Double, lngD: Double, isGPS: Boolean): ClockTimeResult {
        val tzOffH = getTimezoneOffsetHours(nowMs, latD, lngD, isGPS)
        val solarMs = (nowMs + tzOffH * 3600000.0).toLong()

        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = solarMs }
        val Y = cal.get(Calendar.YEAR)
        val Mo = cal.get(Calendar.MONTH) + 1
        val D = cal.get(Calendar.DAY_OF_MONTH)
        val H = cal.get(Calendar.HOUR_OF_DAY)
        val M = cal.get(Calendar.MINUTE)
        val S = cal.get(Calendar.SECOND)
        val ms = cal.get(Calendar.MILLISECOND)

        val h12 = if (H % 12 == 0) 12 else (H % 12)
        val ap = if (H < 12) "am" else "pm"
        val fracHour = H.toDouble() + M.toDouble() / 60.0 + (S.toDouble() + ms.toDouble() / 1000.0) / 3600.0

        val isoDate = "%04d-%02d-%02d".format(Y, Mo, D)
        val isoTime = "%02d:%02d:%02d".format(H, M, S)

        return ClockTimeResult(h12, M, S, ap, fracHour, Y, Mo, D, isoDate, isoTime, tzOffH)
    }

    fun moonPhase(nowMs: Long): Double {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(2000, 0, 6, 18, 14, 0) }
        val synodic = 29.53058867
        val diff = (nowMs - cal.timeInMillis) / 86400000.0
        val rem = ((diff % synodic) + synodic) % synodic
        return rem / synodic
    }

    fun solsticeProgress(nowMs: Long): Double {
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = nowMs }
        val y = cal.get(Calendar.YEAR)

        val wPrev = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(y - 1, 11, 21, 12, 0, 0) }.timeInMillis
        val sCurr = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(y, 5, 21, 12, 0, 0) }.timeInMillis
        val wCurr = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(y, 11, 21, 12, 0, 0) }.timeInMillis
        val sNext = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { set(y + 1, 5, 21, 12, 0, 0) }.timeInMillis

        return when {
            nowMs < sCurr -> 0.5 * (nowMs - wPrev).toDouble() / (sCurr - wPrev).toDouble()
            nowMs < wCurr -> 0.5 + 0.5 * (nowMs - sCurr).toDouble() / (wCurr - sCurr).toDouble()
            else -> 0.5 * (nowMs - wCurr).toDouble() / (sNext - wCurr).toDouble()
        }
    }
}
