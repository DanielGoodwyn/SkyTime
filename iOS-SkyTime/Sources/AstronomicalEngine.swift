import Foundation

public struct SunEvent {
    public let time: Date?
    public let polar: String? // "day", "night", or nil
}

public struct SkyTimeResult {
    public let h: Int
    public let m: Int
    public let s: Int
    public let ap: String
    public let skyHours: Double
    public let isDay: Bool
    public let dayProg: Double
}

public struct ClockTimeResult {
    public let h: Int
    public let m: Int
    public let s: Int
    public let ap: String
    public let fracHour: Double
    public let year: Int
    public let month: Int
    public let day: Int
    public let isoDate: String
    public let isoTime: String
    public let tzOffsetHours: Double
}

public final class AstronomicalEngine {
    public static let shared = AstronomicalEngine()
    
    public init() {}
    
    // MARK: - Sunrise Equation Algorithm
    public func calcSunEvent(year y: Int, month m: Int, day d: Int, lat latD: Double, lng lngD: Double, isRise: Bool) -> SunEvent {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let targetComponents = DateComponents(year: y, month: m, day: d)
        let yearStartComponents = DateComponents(year: y, month: 1, day: 0)
        
        guard let targetDate = cal.date(from: targetComponents),
              let yearStartDate = cal.date(from: yearStartComponents) else {
            return SunEvent(time: nil, polar: nil)
        }
        
        let N = floor(targetDate.timeIntervalSince(yearStartDate) / 86400.0)
        let lngH = lngD / 15.0
        let t = N + ((isRise ? 6.0 : 18.0) - lngH) / 24.0
        let M = (0.9856 * t) - 3.289
        let Mr = M * .pi / 180.0
        
        var L = ((M + 1.916 * sin(Mr) + 0.020 * sin(2.0 * Mr) + 282.634).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let Lr = L * .pi / 180.0
        
        var RA = ((atan(0.91764 * tan(Lr)) * 180.0 / .pi).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        RA = (RA + (floor(L / 90.0) * 90.0 - floor(RA / 90.0) * 90.0)) / 15.0
        
        let sinDec = 0.39782 * sin(Lr)
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(90.833 * .pi / 180.0) - sinDec * sin(latD * .pi / 180.0)) / (cosDec * cos(latD * .pi / 180.0))
        
        if cosH > 1.0 {
            return SunEvent(time: nil, polar: "night")
        }
        if cosH < -1.0 {
            return SunEvent(time: nil, polar: "day")
        }
        
        let H: Double
        if isRise {
            H = (360.0 - acos(cosH) * 180.0 / .pi) / 15.0
        } else {
            H = (acos(cosH) * 180.0 / .pi) / 15.0
        }
        
        var T = ((H + RA - 0.06571 * t - 6.622).truncatingRemainder(dividingBy: 24.0) + 24.0).truncatingRemainder(dividingBy: 24.0)
        if isRise && T > 12.0 { T -= 24.0 }
        if !isRise && T < 12.0 { T += 24.0 }
        
        let eventDate = targetDate.addingTimeInterval((T - lngH) * 3600.0)
        return SunEvent(time: eventDate, polar: nil)
    }
    
    // MARK: - SkyTime Planetary Hours
    public func getSkyTime(date: Date, lat latD: Double, lng lngD: Double) -> SkyTimeResult {
        let lngH = lngD / 15.0
        let solarDate = date.addingTimeInterval(lngH * 3600.0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let comps = cal.dateComponents([.year, .month, .day], from: solarDate)
        let Y = comps.year ?? 2026
        let M = comps.month ?? 10
        let D = comps.day ?? 16
        
        struct DayEv {
            let rise: SunEvent
            let set: SunEvent
            let midDate: Date
        }
        
        func dayEvents(offset: Int) -> DayEv {
            var c = cal
            c.timeZone = TimeZone(secondsFromGMT: 0)!
            let dt = c.date(byAdding: .day, value: offset, to: cal.date(from: DateComponents(year: Y, month: M, day: D))!)!
            let y = c.component(.year, from: dt)
            let m = c.component(.month, from: dt)
            let d = c.component(.day, from: dt)
            let rise = calcSunEvent(year: y, month: m, day: d, lat: latD, lng: lngD, isRise: true)
            let set = calcSunEvent(year: y, month: m, day: d, lat: latD, lng: lngD, isRise: false)
            let mid = dt.addingTimeInterval(-lngH * 3600.0)
            return DayEv(rise: rise, set: set, midDate: mid)
        }
        
        let prev = dayEvents(offset: -1)
        let curr = dayEvents(offset: 0)
        let next = dayEvents(offset: 1)
        
        var isDay = false
        var prog = 0.0
        let nowMs = date.timeIntervalSince1970
        
        if curr.rise.polar == "day" || curr.rise.polar == "night" {
            isDay = (curr.rise.polar == "day")
            let midMs = curr.midDate.timeIntervalSince1970
            prog = max(0.0, min(1.0, (nowMs - midMs) / 86400.0))
        } else {
            let rPrev = prev.rise.time?.timeIntervalSince1970 ?? (curr.midDate.timeIntervalSince1970 - 64800.0)
            let sPrev = prev.set.time?.timeIntervalSince1970 ?? (curr.midDate.timeIntervalSince1970 - 21600.0)
            let rCurr = curr.rise.time?.timeIntervalSince1970 ?? (curr.midDate.timeIntervalSince1970 + 21600.0)
            let sCurr = curr.set.time?.timeIntervalSince1970 ?? (curr.midDate.timeIntervalSince1970 + 64800.0)
            let rNext = next.rise.time?.timeIntervalSince1970 ?? (curr.midDate.timeIntervalSince1970 + 108000.0)
            let sNext = next.set.time?.timeIntervalSince1970 ?? (curr.midDate.timeIntervalSince1970 + 151200.0)
            
            var start = 0.0
            var end = 0.0
            
            if nowMs >= rNext {
                isDay = true; start = rNext; end = sNext
            } else if nowMs >= sCurr {
                isDay = false; start = sCurr; end = rNext
            } else if nowMs >= rCurr {
                isDay = true; start = rCurr; end = sCurr
            } else if nowMs >= sPrev {
                isDay = false; start = sPrev; end = rCurr
            } else {
                isDay = true; start = rPrev; end = sPrev
            }
            
            if end > start {
                prog = max(0.0, min(1.0, (nowMs - start) / (end - start)))
            }
        }
        
        let skyHours = isDay ? (6.0 + prog * 12.0) : (18.0 + prog * 12.0)
        let h24 = (skyHours.truncatingRemainder(dividingBy: 24.0) + 24.0).truncatingRemainder(dividingBy: 24.0)
        let H = Int(floor(h24))
        let fracM = (h24 - Double(H)) * 60.0
        let Min = Int(floor(fracM))
        let Sec = Int(floor((fracM - Double(Min)) * 60.0))
        let h12 = (H % 12 == 0) ? 12 : (H % 12)
        let ap = (H < 12) ? "am" : "pm"
        let dayProg = isDay ? (prog * 0.5) : (0.5 + prog * 0.5)
        
        return SkyTimeResult(h: h12, m: Min, s: Sec, ap: ap, skyHours: h24, isDay: isDay, dayProg: dayProg)
    }
    
    // MARK: - Timezone & Daylight Saving Time
    public func isDstInRegion(date: Date, lat latD: Double, lng lngD: Double) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let m = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let hour = cal.component(.hour, from: date)
        let year = cal.component(.year, from: date)
        
        // North America (lat 24..72, lng -168..-52)
        if latD >= 24 && latD <= 72 && lngD >= -168 && lngD <= -52 {
            if latD >= 31.3 && latD <= 37.0 && lngD >= -114.8 && lngD <= -109.0 { return false } // Arizona
            if latD <= 23 && lngD >= -162 && lngD <= -154 { return false } // Hawaii
            if m > 3 && m < 11 { return true }
            if m == 3 {
                // 2nd Sunday of March (between March 8 and 14)
                let firstDay = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: 3, day: 1))!) - 1
                let secondSun = 1 + (7 - firstDay) % 7 + 7
                return day > secondSun || (day == secondSun && hour >= 10)
            }
            if m == 11 {
                // 1st Sunday of Nov
                let firstDay = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: 11, day: 1))!) - 1
                let firstSun = 1 + (7 - firstDay) % 7
                return day < firstSun || (day == firstSun && hour < 10)
            }
            return false
        }
        
        // Europe (lat 35..72, lng -15..40)
        if latD >= 35 && latD <= 72 && lngD >= -15 && lngD <= 40 {
            if latD >= 63 && lngD <= -13 { return false } // Iceland
            if lngD > 28 && latD >= 50 { return false } // Russia/Belarus
            if m > 3 && m < 10 { return true }
            if m == 3 {
                let lastDay = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: 3, day: 31))!) - 1
                let lastSun = 31 - lastDay
                return day > lastSun || (day == lastSun && hour >= 1)
            }
            if m == 10 {
                let lastDay = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: 10, day: 31))!) - 1
                let lastSun = 31 - lastDay
                return day < lastSun || (day == lastSun && hour < 1)
            }
            return false
        }
        
        // Australia SE
        if latD <= -28 && latD >= -44 && lngD >= 135 && lngD <= 155 {
            if m >= 11 || m < 4 { return true }
            if m == 10 {
                let firstDay = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: 10, day: 1))!) - 1
                let firstSun = 1 + (7 - firstDay) % 7
                return day >= firstSun
            }
            if m == 4 {
                let firstDay = cal.component(.weekday, from: cal.date(from: DateComponents(year: year, month: 4, day: 1))!) - 1
                let firstSun = 1 + (7 - firstDay) % 7
                return day < firstSun
            }
            return false
        }
        
        return false
    }
    
    public func getTimezoneOffsetHours(date: Date, lat latD: Double, lng lngD: Double, isGPS: Bool) -> Double {
        if isGPS {
            return Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        }
        
        // Check if matching device standard zone
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let y = cal.component(.year, from: date)
        if let jan15 = cal.date(from: DateComponents(year: y, month: 1, day: 15)) {
            let localStdOffset = Double(TimeZone.current.secondsFromGMT(for: jan15)) / 3600.0
            let targetStdOffset = round(lngD / 15.0)
            if abs(targetStdOffset - localStdOffset) < 0.1 && abs(lngD - (-localStdOffset * 15.0)) < 16.0 {
                return Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
            }
        }
        
        // Western / Central Europe civil base
        if latD >= 36 && latD <= 60 && lngD >= -11 && lngD <= 30 {
            let isGmt = (latD >= 50 && latD <= 60 && lngD >= -11 && lngD <= 1.8) ||
                        (latD >= 36 && latD <= 42.5 && lngD >= -9.6 && lngD <= -6.1)
            let base: Double = isGmt ? 0.0 : 1.0
            return base + (isDstInRegion(date: date, lat: latD, lng: lngD) ? 1.0 : 0.0)
        }
        
        // Half hour / regional overrides
        if latD >= 7 && latD <= 36 && lngD >= 68 && lngD <= 90 { return 5.5 } // India
        if latD >= 25 && latD <= 40 && lngD >= 44 && lngD <= 63 { return 3.5 } // Iran
        if latD >= 26 && latD <= 31 && lngD >= 80 && lngD <= 88 { return 5.75 } // Nepal
        if latD <= -10 && lngD >= 129 && lngD <= 141 {
            let isDst = latD <= -26 && isDstInRegion(date: date, lat: latD, lng: lngD)
            return 9.5 + (isDst ? 1.0 : 0.0)
        }
        if latD >= 46 && latD <= 52 && lngD >= -59 && lngD <= -52 {
            return -3.5 + (isDstInRegion(date: date, lat: latD, lng: lngD) ? 1.0 : 0.0)
        }
        if latD >= 18 && latD <= 54 && lngD >= 73 && lngD <= 135 { return 8.0 } // China
        
        var base = round(lngD / 15.0)
        if isDstInRegion(date: date, lat: latD, lng: lngD) {
            base += 1.0
        }
        return base
    }
    
    // MARK: - Clock Time
    public func getClockTime(date: Date, lat latD: Double, lng lngD: Double, isGPS: Bool) -> ClockTimeResult {
        let tzOff = getTimezoneOffsetHours(date: date, lat: latD, lng: lngD, isGPS: isGPS)
        let solar = date.addingTimeInterval(tzOff * 3600.0)
        
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: solar)
        let Y = comps.year ?? 2026
        let Mo = comps.month ?? 10
        let D = comps.day ?? 16
        let H = comps.hour ?? 0
        let M = comps.minute ?? 0
        let S = comps.second ?? 0
        let ms = Double(comps.nanosecond ?? 0) / 1_000_000.0
        
        let h12 = (H % 12 == 0) ? 12 : (H % 12)
        let ap = (H < 12) ? "am" : "pm"
        let fracHour = Double(H) + Double(M) / 60.0 + (Double(S) + ms / 1000.0) / 3600.0
        
        let isoDate = String(format: "%04d-%02d-%02d", Y, Mo, D)
        let isoTime = String(format: "%02d:%02d:%02d", H, M, S)
        
        return ClockTimeResult(
            h: h12,
            m: M,
            s: S,
            ap: ap,
            fracHour: fracHour,
            year: Y,
            month: Mo,
            day: D,
            isoDate: isoDate,
            isoTime: isoTime,
            tzOffsetHours: tzOff
        )
    }
    
    // MARK: - Moon Phase & Solstice
    public func moonPhase(date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let ref = cal.date(from: DateComponents(year: 2000, month: 1, day: 6, hour: 18, minute: 14)) else {
            return 0.0
        }
        let synodic = 29.53058867
        let diff = date.timeIntervalSince(ref) / 86400.0
        let rem = (diff.truncatingRemainder(dividingBy: synodic) + synodic).truncatingRemainder(dividingBy: synodic)
        return rem / synodic
    }
    
    public func solsticeProgress(date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let y = cal.component(.year, from: date)
        
        guard let wPrev = cal.date(from: DateComponents(year: y - 1, month: 12, day: 21, hour: 12)),
              let sCurr = cal.date(from: DateComponents(year: y, month: 6, day: 21, hour: 12)),
              let wCurr = cal.date(from: DateComponents(year: y, month: 12, day: 21, hour: 12)),
              let sNext = cal.date(from: DateComponents(year: y + 1, month: 6, day: 21, hour: 12)) else {
            return 0.0
        }
        
        let t = date.timeIntervalSince1970
        let wp = wPrev.timeIntervalSince1970
        let sc = sCurr.timeIntervalSince1970
        let wc = wCurr.timeIntervalSince1970
        let sn = sNext.timeIntervalSince1970
        
        if t < sc {
            return 0.5 * (t - wp) / (sc - wp)
        } else if t < wc {
            return 0.5 + 0.5 * (t - sc) / (wc - sc)
        } else {
            return 0.5 * (t - wc) / (sn - wc)
        }
    }
}
