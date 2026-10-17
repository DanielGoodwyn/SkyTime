import SwiftUI

public struct CustomLocationSheet: View {
    @Binding public var latitude: Double
    @Binding public var longitude: Double
    @Binding public var customTimeMode: Bool
    @Binding public var customTargetDate: Date?
    @Binding public var customFrozen: Bool
    
    @ObservedObject public var locationManager: LocationManager
    @ObservedObject public var favoritesManager = FavoritesManager.shared
    @ObservedObject public var authManager = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var latStr: String = ""
    @State private var lngStr: String = ""
    @State private var selectedDate: Date = Date()
    @State private var freezeToggle: Bool = false
    @State private var isCustomTime: Bool = false
    
    // Favorites creation state
    @State private var favLabel: String = ""
    @State private var favType: SkyFavorite.FavoriteType = .both
    @State private var favSaveSuccess: String? = nil
    @State private var showAuthSheet: Bool = false
    
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
                        
                        // MARK: - Section 1: Saved Favorites (if any exist)
                        if !favoritesManager.favorites.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(Color(red: 242/255, green: 140/255, blue: 64/255))
                                        .font(.system(size: 13))
                                    Text("SAVED FAVORITES")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text("\(favoritesManager.favorites.count)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                
                                ForEach(favoritesManager.favorites) { fav in
                                    HStack(spacing: 12) {
                                        // Tap card to apply favorite
                                        Button(action: {
                                            applyFavorite(fav)
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 8) {
                                                    Text(fav.label)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    
                                                    // Type Badge
                                                    Text(fav.type.rawValue)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(typeBadgeColor(fav.type).opacity(0.25))
                                                        .foregroundColor(typeBadgeColor(fav.type))
                                                        .cornerRadius(4)
                                                }
                                                
                                                Text(favDetailText(fav))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            Spacer()
                                        }
                                        
                                        // Delete Button
                                        Button(action: {
                                            withAnimation {
                                                favoritesManager.deleteFavorite(id: fav.id)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13))
                                                .foregroundColor(.white.opacity(0.35))
                                                .padding(6)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(14)
                        }
                        
                        // MARK: - Section 2: Location Coordinates
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
                                    if locationManager.gpsState == .on || locationManager.gpsState == .locating {
                                        latStr = String(format: "%.4f", locationManager.latitude)
                                        lngStr = String(format: "%.4f", locationManager.longitude)
                                        // Seeing with GPS for here and now: unfrozen by normal default!
                                        isCustomTime = false
                                        freezeToggle = false
                                        customTimeMode = false
                                        customFrozen = false
                                        customTargetDate = nil
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
                                    isCustomTime = false
                                    freezeToggle = false
                                    customTimeMode = false
                                    customFrozen = false
                                    customTargetDate = nil
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
                        
                        // MARK: - Section 3: Date & Time
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
                                
                                if freezeToggle {
                                    Button(action: {
                                        freezeToggle = false
                                        customFrozen = false
                                    }) {
                                        HStack {
                                            Image(systemName: "play.fill")
                                            Text("Unpause (Resume Ticking)")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 242/255, green: 140/255, blue: 64/255).opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
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
                        
                        // MARK: - Section 4: Save as Favorite (For logged in users)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .foregroundColor(Color(red: 242/255, green: 140/255, blue: 64/255))
                                    .font(.system(size: 13))
                                Text("SAVE AS FAVORITE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            if authManager.currentUser != nil {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Label / Name")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    TextField("e.g., Home SF, Solstice 2026, Tokyo Noon", text: $favLabel)
                                        .padding(10)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                        .foregroundColor(.white)
                                    
                                    Text("What to save:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.top, 4)
                                    
                                    Picker("Save Type", selection: $favType) {
                                        ForEach(SkyFavorite.FavoriteType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .colorScheme(.dark)
                                    
                                    if let success = favSaveSuccess {
                                        Text(success)
                                            .font(.caption)
                                            .foregroundColor(Color.green)
                                            .padding(.top, 2)
                                    }
                                    
                                    Button(action: {
                                        saveCurrentAsFavorite()
                                    }) {
                                        HStack {
                                            Image(systemName: "star.fill")
                                            Text("Save to Favorites")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(red: 242/255, green: 140/255, blue: 64/255).opacity(0.9))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    .padding(.top, 6)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sign in to save and sync your favorite locations and moments across devices.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineSpacing(3)
                                    
                                    Button(action: {
                                        showAuthSheet = true
                                    }) {
                                        HStack {
                                            Image(systemName: "person.circle.fill")
                                            Text("Begin / Sign In to Enable Favorites")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.12))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(14)
                        
                        // MARK: - Apply Button
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
            .sheet(isPresented: $showAuthSheet) {
                AuthView()
            }
            .onAppear {
                latStr = String(format: "%.4f", latitude)
                lngStr = String(format: "%.4f", longitude)
                isCustomTime = customTimeMode
                freezeToggle = customFrozen
                selectedDate = customTargetDate ?? Date()
                favoritesManager.loadFavorites()
            }
        }
    }
    
    private func saveCurrentAsFavorite() {
        let curLat = Double(latStr) ?? latitude
        let curLng = Double(lngStr) ?? longitude
        let curDate = isCustomTime ? selectedDate : Date()
        let frozen = freezeToggle
        
        favoritesManager.addFavorite(
            label: favLabel,
            type: favType,
            latitude: curLat,
            longitude: curLng,
            targetDate: curDate,
            isFrozen: frozen
        )
        
        favSaveSuccess = "Saved \"\(favLabel.isEmpty ? "Favorite" : favLabel)\" successfully!"
        favLabel = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            favSaveSuccess = nil
        }
    }
    
    private func applyFavorite(_ fav: SkyFavorite) {
        if fav.type == .location || fav.type == .both {
            if let lat = fav.latitude, let lng = fav.longitude {
                latitude = lat
                longitude = lng
                latStr = String(format: "%.4f", lat)
                lngStr = String(format: "%.4f", lng)
                locationManager.stopGPS()
            }
        }
        // Time freezes by default if you choose a favorite!
        isCustomTime = true
        customTimeMode = true
        freezeToggle = true
        customFrozen = true
        
        if fav.type == .moment || fav.type == .both {
            if let targetDate = fav.targetDate {
                selectedDate = targetDate
                customTargetDate = targetDate
            }
        } else {
            selectedDate = Date()
            customTargetDate = Date()
        }
        favSaveSuccess = "Applied \"\(fav.label)\" (Frozen)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            favSaveSuccess = nil
        }
    }
    
    private func favDetailText(_ fav: SkyFavorite) -> String {
        switch fav.type {
        case .location:
            let lat = fav.latitude ?? 0
            let lng = fav.longitude ?? 0
            return String(format: "Coordinates: %.2f°, %.2f°", lat, lng)
        case .moment:
            let d = fav.targetDate ?? Date()
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return "Moment: \(f.string(from: d))\(fav.isFrozen ? " (Frozen)" : " (Ticking)")"
        case .both:
            let lat = fav.latitude ?? 0
            let lng = fav.longitude ?? 0
            let d = fav.targetDate ?? Date()
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return String(format: "%.2f°, %.2f° · \(f.string(from: d))\(fav.isFrozen ? " (Frozen)" : "")", lat, lng)
        }
    }
    
    private func typeBadgeColor(_ type: SkyFavorite.FavoriteType) -> Color {
        switch type {
        case .location:
            return Color.cyan
        case .moment:
            return Color.purple
        case .both:
            return Color(red: 242/255, green: 140/255, blue: 64/255)
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
