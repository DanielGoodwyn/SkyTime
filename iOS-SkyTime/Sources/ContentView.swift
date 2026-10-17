import SwiftUI

public struct ContentView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var authManager = AuthManager.shared
    
    @State private var latitude: Double = 37.7749
    @State private var longitude: Double = -122.4194
    
    @State private var customTimeMode: Bool = false
    @State private var customTargetDate: Date? = nil
    @State private var customAnchorDate: Date? = nil
    @State private var customFrozen: Bool = false
    
    @State private var showLocationSheet: Bool = false
    @State private var showAuthSheet: Bool = false
    
    @State private var currentDate: Date = Date()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private let engine = AstronomicalEngine.shared
    private let skyGradient = SkyGradient.shared
    private let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
    
    public init() {}
    
    private var activeDate: Date {
        if !customTimeMode || customTargetDate == nil {
            return currentDate
        }
        if customFrozen {
            return customTargetDate!
        }
        let elapsed = currentDate.timeIntervalSince(customAnchorDate ?? currentDate)
        return customTargetDate!.addingTimeInterval(elapsed)
    }
    
    public var body: some View {
        let now = activeDate
        let isGPSOn = (locationManager.gpsState == .on)
        let lat = isGPSOn ? locationManager.latitude : latitude
        let lng = isGPSOn ? locationManager.longitude : longitude
        
        let sky = engine.getSkyTime(date: now, lat: lat, lng: lng)
        let clk = engine.getClockTime(date: now, lat: lat, lng: lng, isGPS: isGPSOn)
        
        let monthName = (clk.month >= 1 && clk.month <= 12) ? months[clk.month - 1] : "oct"
        let dayString = String(format: "%02d", clk.day)
        let yearString = String(format: "%d", clk.year)
        
        let trackGrad = skyGradient.horizontalGradient(for: clk.fracHour, isDay: sky.isDay)
        let fillGrad = skyGradient.fillGradient(for: clk.fracHour)
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP PROGRESS BARS (30px)
                TopProgressBarGroup(
                    dayProg: sky.dayProg,
                    monthProg: engine.moonPhase(date: now),
                    yearProg: engine.solsticeProgress(date: now),
                    dayStr: dayString,
                    monthStr: monthName,
                    yearStr: yearString,
                    trackGrad: trackGrad,
                    fillGrad: fillGrad,
                    onOpenModal: { showLocationSheet = true }
                )
                
                // CENTER SPLIT SCREEN (50% / 50%)
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    ZStack {
                        HStack(spacing: 0) {
                            // Left: SkyTime
                            ZStack {
                                skyGradient.verticalGradient(for: sky.skyHours)
                                ClockDisplayView(
                                    title: "SkyTime",
                                    hours: sky.h,
                                    minutes: sky.m,
                                    seconds: sky.s,
                                    ampm: sky.ap
                                )
                            }
                            .frame(width: w / 2, height: h)
                            
                            // Center subtle divider
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 1, height: h)
                            
                            // Right: Clock Time
                            ZStack {
                                skyGradient.verticalGradient(for: clk.fracHour)
                                ClockDisplayView(
                                    title: "Clock Time",
                                    hours: clk.h,
                                    minutes: clk.m,
                                    seconds: clk.s,
                                    ampm: clk.ap
                                )
                            }
                            .frame(width: w / 2 - 1, height: h)
                        }
                        
                        // Floating HUD Pill
                        VStack {
                            Spacer()
                            HUDPillView(
                                gpsState: locationManager.gpsState,
                                latitude: lat,
                                longitude: lng,
                                datetimeString: customTimeMode
                                    ? "\(clk.isoDate) \(clk.isoTime)\(customFrozen ? " (frozen)" : " (custom)")"
                                    : "\(clk.isoDate) (live)",
                                user: authManager.currentUser,
                                isFrozen: customFrozen,
                                onOpenModal: { showLocationSheet = true },
                                onOpenAuth: { showAuthSheet = true },
                                onUnpause: {
                                    customFrozen = false
                                    customAnchorDate = Date()
                                }
                            )
                            .padding(.bottom, 8)
                        }
                    }
                }
                
                // BOTTOM PROGRESS BARS (30px)
                BottomProgressBarGroup(
                    longitude: $longitude,
                    latitude: $latitude,
                    gpsState: locationManager.gpsState,
                    trackGrad: trackGrad,
                    fillGrad: fillGrad,
                    onToggleGPS: {
                        locationManager.toggleGPS()
                        // When activating GPS for here and now: unfrozen by normal default!
                        if locationManager.gpsState == .on || locationManager.gpsState == .locating {
                            customTimeMode = false
                            customFrozen = false
                            customTargetDate = nil
                        }
                    },
                    onOpenModal: { showLocationSheet = true }
                )
            }
        }
        .onReceive(timer) { input in
            currentDate = input
        }
        .sheet(isPresented: $showLocationSheet) {
            CustomLocationSheet(
                latitude: $latitude,
                longitude: $longitude,
                customTimeMode: $customTimeMode,
                customTargetDate: $customTargetDate,
                customFrozen: $customFrozen,
                locationManager: locationManager
            )
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView()
        }
    }
}
