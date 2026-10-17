import SwiftUI
import UIKit

public struct SingleProgressBar: View {
    public let label: String
    public let valueText: String?
    public let centerText: String?
    public let progress: Double // 0.0 to 1.0
    public let trackGradient: LinearGradient
    public let fillGradient: LinearGradient
    public var onDrag: ((Double) -> Void)? = nil
    public var onTap: (() -> Void)? = nil
    
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    public init(
        label: String,
        valueText: String? = nil,
        centerText: String? = nil,
        progress: Double,
        trackGradient: LinearGradient,
        fillGradient: LinearGradient,
        onDrag: ((Double) -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.label = label
        self.valueText = valueText
        self.centerText = centerText
        self.progress = max(0.0, min(1.0, progress))
        self.trackGradient = trackGradient
        self.fillGradient = fillGradient
        self.onDrag = onDrag
        self.onTap = onTap
    }
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let p = max(0.0, min(1.0, progress))
            
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(trackGradient)
                
                // Fill
                Rectangle()
                    .fill(fillGradient)
                    .frame(width: w * p)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 1),
                        alignment: .trailing
                    )
                
                // Content Layer
                HStack(spacing: 0) {
                    Text(label)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                        .padding(.leading, 6)
                    
                    if let center = centerText {
                        Spacer()
                        Text(center)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                        Spacer()
                    } else {
                        Spacer()
                    }
                    
                    if let val = valueText {
                        Text(val)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            .padding(.trailing, 6)
                    }
                }
            }
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let dragHandler = onDrag {
                            let frac = max(0.0, min(1.0, value.location.x / w))
                            dragHandler(frac)
                            haptic.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        onTap?()
                    }
            )
        }
        .frame(height: 10)
    }
}

public struct TopProgressBarGroup: View {
    public let dayProg: Double
    public let monthProg: Double
    public let yearProg: Double
    public let dayStr: String
    public let monthStr: String
    public let yearStr: String
    public let trackGrad: LinearGradient
    public let fillGrad: LinearGradient
    public var onOpenModal: () -> Void
    
    public init(dayProg: Double, monthProg: Double, yearProg: Double, dayStr: String, monthStr: String, yearStr: String, trackGrad: LinearGradient, fillGrad: LinearGradient, onOpenModal: @escaping () -> Void) {
        self.dayProg = dayProg
        self.monthProg = monthProg
        self.yearProg = yearProg
        self.dayStr = dayStr
        self.monthStr = monthStr
        self.yearStr = yearStr
        self.trackGrad = trackGrad
        self.fillGrad = fillGrad
        self.onOpenModal = onOpenModal
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            SingleProgressBar(label: "day", valueText: dayStr, progress: dayProg, trackGradient: trackGrad, fillGradient: fillGrad, onTap: onOpenModal)
            SingleProgressBar(label: "month", valueText: monthStr, progress: monthProg, trackGradient: trackGrad, fillGradient: fillGrad, onTap: onOpenModal)
            SingleProgressBar(label: "year", valueText: yearStr, progress: yearProg, trackGradient: trackGrad, fillGradient: fillGrad, onTap: onOpenModal)
        }
        .frame(height: 30)
    }
}

public struct BottomProgressBarGroup: View {
    @Binding public var longitude: Double
    @Binding public var latitude: Double
    public let gpsState: GPSState
    public let trackGrad: LinearGradient
    public let fillGrad: LinearGradient
    public var onToggleGPS: () -> Void
    public var onOpenModal: () -> Void
    
    public init(longitude: Binding<Double>, latitude: Binding<Double>, gpsState: GPSState, trackGrad: LinearGradient, fillGrad: LinearGradient, onToggleGPS: @escaping () -> Void, onOpenModal: @escaping () -> Void) {
        self._longitude = longitude
        self._latitude = latitude
        self.gpsState = gpsState
        self.trackGrad = trackGrad
        self.fillGrad = fillGrad
        self.onToggleGPS = onToggleGPS
        self.onOpenModal = onOpenModal
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Longitude (-180 to 180)
            SingleProgressBar(
                label: "long",
                valueText: String(format: "%.2f", longitude),
                progress: (longitude + 180.0) / 360.0,
                trackGradient: trackGrad,
                fillGradient: fillGrad,
                onDrag: { frac in
                    longitude = -180.0 + frac * 360.0
                },
                onTap: onOpenModal
            )
            
            // Latitude (-90 to 90)
            SingleProgressBar(
                label: "lat",
                valueText: String(format: "%.2f", latitude),
                progress: (latitude + 90.0) / 180.0,
                trackGradient: trackGrad,
                fillGradient: fillGrad,
                onDrag: { frac in
                    latitude = -90.0 + frac * 180.0
                },
                onTap: onOpenModal
            )
            
            // GPS row
            let gpsVal: Double = (gpsState == .on) ? 1.0 : (gpsState == .locating ? 0.5 : 0.0)
            let centerText = (gpsState == .on) ? "gps: on" : (gpsState == .locating ? "gps: locating..." : (gpsState == .denied ? "gps: off (denied)" : "gps: off"))
            let rightText = (gpsState == .on) ? "on" : (gpsState == .locating ? "locating..." : (gpsState == .denied ? "off (denied)" : "off"))
            
            SingleProgressBar(
                label: "gps",
                valueText: rightText,
                centerText: centerText,
                progress: gpsVal,
                trackGradient: trackGrad,
                fillGradient: fillGrad,
                onTap: onToggleGPS
            )
        }
        .frame(height: 30)
    }
}
