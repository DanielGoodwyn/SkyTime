import SwiftUI

public struct SkyGradientKeyframe {
    public let hour: Double
    public let colors: [Color]
}

public final class SkyGradient {
    public static let shared = SkyGradient()
    
    // Exact 17 keyframes from SPEC.md and index.html
    public let keyframes: [(hour: Double, stops: [(r: Double, g: Double, b: Double)])] = [
        (0.0,  [(2,3,10),    (5,8,28),    (10,18,48),  (16,29,72)]),
        (4.0,  [(4,6,20),    (8,16,40),   (16,30,70),  (24,45,102)]),
        (5.0,  [(8,20,54),   (16,36,88),  (30,63,128), (59,104,168)]),
        (5.5,  [(14,31,77),  (34,56,117), (92,60,122), (168,80,112)]),
        (6.0,  [(24,54,122), (72,80,152), (184,80,120),(242,140,64)]),
        (6.5,  [(36,82,166), (86,132,200),(216,152,108),(250,224,140)]),
        (7.0,  [(50,116,200),(110,168,224),(203,224,236),(255,248,214)]),
        (9.5,  [(28,100,196),(78,150,222),(158,208,242),(238,248,252)]),
        (12.0, [(10,76,180), (42,126,216),(120,188,240),(230,245,255)]),
        (15.0, [(20,86,184), (56,130,212),(130,188,232),(216,238,251)]),
        (17.0, [(12,52,132), (34,88,164), (82,140,200), (140,194,230)]),
        (17.5, [(12,42,114), (38,72,146), (112,100,164),(212,124,84)]),
        (18.0, [(18,36,100), (56,60,136), (152,56,104), (235,84,40)]),
        (18.5, [(10,22,68),  (30,36,100), (100,40,104), (200,60,36)]),
        (19.2, [(6,13,44),   (16,24,68),  (46,26,84),  (74,36,80)]),
        (20.5, [(3,6,20),    (7,12,38),   (14,22,58),  (21,34,84)]),
        (24.0, [(2,3,10),    (5,8,28),    (10,18,48),  (16,29,72)])
    ]
    
    public func stops(for hour24: Double, gain: Double = 1.0, lift: Double = 0.0) -> [Color] {
        let h = (hour24.truncatingRemainder(dividingBy: 24.0) + 24.0).truncatingRemainder(dividingBy: 24.0)
        
        var lo = keyframes[0]
        var hi = keyframes[keyframes.count - 1]
        
        for i in 0..<(keyframes.count - 1) {
            if h >= keyframes[i].hour && h < keyframes[i + 1].hour {
                lo = keyframes[i]
                hi = keyframes[i + 1]
                break
            }
        }
        
        let span = hi.hour - lo.hour
        let t = span > 0 ? (h - lo.hour) / span : 0.0
        
        return (0..<4).map { idx in
            let c1 = lo.stops[idx]
            let c2 = hi.stops[idx]
            
            let rVal = min(255.0, max(0.0, (c1.r * (1.0 - t) + c2.r * t) * gain + lift)) / 255.0
            let gVal = min(255.0, max(0.0, (c1.g * (1.0 - t) + c2.g * t) * gain + lift)) / 255.0
            let bVal = min(255.0, max(0.0, (c1.b * (1.0 - t) + c2.b * t) * gain + lift)) / 255.0
            
            return Color(red: rVal, green: gVal, blue: bVal)
        }
    }
    
    public func verticalGradient(for hour24: Double) -> LinearGradient {
        LinearGradient(
            colors: stops(for: hour24),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    public func horizontalGradient(for hour24: Double, isDay: Bool) -> LinearGradient {
        let colors = isDay
            ? stops(for: hour24, gain: 0.55, lift: 95.0)
            : stops(for: hour24, gain: 0.35, lift: 0.0)
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    public func fillGradient(for hour24: Double) -> LinearGradient {
        LinearGradient(
            colors: stops(for: hour24, gain: 1.25, lift: 18.0),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
