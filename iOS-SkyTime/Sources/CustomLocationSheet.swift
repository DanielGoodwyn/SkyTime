import SwiftUI

public struct CustomLocationSheet: View {
    @Binding public var latitude: Double
    @Binding public var longitude: Double
    @Binding public var customTimeMode: Bool
    @Binding public var customTargetDate: Date?
    @Binding public var customFrozen: Bool
    
    @ObservedObject public var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var latStr: String = ""
    @State private var lngStr: String = ""
    @State private var selectedDate: Date = Date()
    @State private var freezeToggle: Bool = false
    @State private var isCustomTime: Bool = false
    
    public init(
        latitude: Binding<Double>,
        longitude: Binding<Double>,
        customTimeMode: Binding<Bool>,
        customTargetDate: Binding<Date?>,
        customFrozen: Binding<Bool>,
        locationManager: LocationManager
    ) {
        self._latitude = latitude
        self._longitude = longitude
        self._customTimeMode = customTimeMode
        self._customTargetDate = customTargetDate
        self._customFrozen = customFrozen
        self.locationManager = locationManager
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Section 1: Location Coordinates
                        VStack(alignment: .leading, spacing: 14) {
                            Text("LOCATION COORDINATES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Latitude (-90 to 90)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    TextField("Latitude", text: $latStr)
                                        .keyboardType(.numbersAndPunctuation)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Longitude (-180 to 180)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    TextField("Longitude", text: $lngStr)
                                        .keyboardType(.numbersAndPunctuation)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    locationManager.toggleGPS()
                                    if locationManager.gpsState == .on {
                                        latStr = String(format: "%.4f", locationManager.latitude)
                                        lngStr = String(format: "%.4f", locationManager.longitude)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: locationManager.gpsState == .on ? "location.fill" : "location")
                                        Text("GPS: \(locationManager.gpsState.rawValue.uppercased())")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(locationManager.gpsState == .on ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                                    .foregroundColor(locationManager.gpsState == .on ? .green : .white)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    locationManager.stopGPS()
                                    latitude = 37.7749
                                    longitude = -122.4194
                                    latStr = "37.7749"
                                    lngStr = "-122.4194"
                                }) {
                                    Text("Default (SF)")
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                        
                        // Section 2: Date & Time
                        VStack(alignment: .leading, spacing: 14) {
                            Text("DATE & TIME")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Toggle(isOn: $isCustomTime) {
                                Text("Custom Date & Time Mode")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .tint(Color(red: 242/255, green: 140/255, blue: 64/255))
                            
                            if isCustomTime {
                                DatePicker("Date & Time", selection: $selectedDate)
                                    .datePickerStyle(.graphical)
                                    .colorScheme(.dark)
                                
                                Toggle(isOn: $freezeToggle) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Freeze Time")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        Text("Pause live ticking at this exact moment")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .tint(Color.cyan)
                            }
                            
                            Button(action: {
                                isCustomTime = false
                                freezeToggle = false
                                customTimeMode = false
                                customTargetDate = nil
                                customFrozen = false
                                selectedDate = Date()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset to Live Time")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                        
                        // Apply Button
                        Button(action: {
                            applyChanges()
                            dismiss()
                        }) {
                            Text("Apply Settings")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 24/255, green: 54/255, blue: 122/255),
                                            Color(red: 242/255, green: 140/255, blue: 64/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Location & Date / Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applyChanges()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                latStr = String(format: "%.4f", latitude)
                lngStr = String(format: "%.4f", longitude)
                isCustomTime = customTimeMode
                freezeToggle = customFrozen
                selectedDate = customTargetDate ?? Date()
            }
        }
    }
    
    private func applyChanges() {
        if let newLat = Double(latStr), let newLng = Double(lngStr) {
            latitude = max(-90.0, min(90.0, newLat))
            longitude = max(-180.0, min(180.0, newLng))
            if abs(latitude - locationManager.latitude) > 1e-4 || abs(longitude - locationManager.longitude) > 1e-4 {
                locationManager.stopGPS()
            }
        }
        customTimeMode = isCustomTime
        customFrozen = freezeToggle
        customTargetDate = isCustomTime ? selectedDate : nil
    }
}
