import SwiftUI

public struct HUDPillView: View {
    public let gpsState: GPSState
    public let latitude: Double
    public let longitude: Double
    public let datetimeString: String
    public let user: SkyUser?
    public var onOpenModal: () -> Void
    public var onOpenAuth: () -> Void
    
    public init(
        gpsState: GPSState,
        latitude: Double,
        longitude: Double,
        datetimeString: String,
        user: SkyUser?,
        onOpenModal: @escaping () -> Void,
        onOpenAuth: @escaping () -> Void
    ) {
        self.gpsState = gpsState
        self.latitude = latitude
        self.longitude = longitude
        self.datetimeString = datetimeString
        self.user = user
        self.onOpenModal = onOpenModal
        self.onOpenAuth = onOpenAuth
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Main HUD pill: GPS + Coordinates + Date
            Button(action: onOpenModal) {
                HStack(spacing: 6) {
                    // GPS dot
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: dotColor.opacity(0.8), radius: 3)
                    
                    Text(gpsLabel)
                    Text("·").opacity(0.5)
                    Text(String(format: "%.2f°, %.2f°", latitude, longitude))
                    Text("·").opacity(0.5)
                    Text(datetimeString)
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .opacity(0.7)
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            }
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            
            // Auth / Account button
            Button(action: onOpenAuth) {
                HStack(spacing: 4) {
                    if let user = user {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(Color(red: 0.35, green: 0.9, blue: 0.55))
                        Text(user.email.components(separatedBy: "@").first ?? "user")
                            .lineLimit(1)
                    } else {
                        Image(systemName: "person.circle")
                            .foregroundColor(.white.opacity(0.85))
                        Text("Begin")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
            }
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
    }
    
    private var dotColor: Color {
        switch gpsState {
        case .on:
            return Color(red: 0.2, green: 0.9, blue: 0.4)
        case .locating:
            return Color.orange
        case .denied:
            return Color.red.opacity(0.8)
        case .off:
            return Color.gray.opacity(0.6)
        }
    }
    
    private var gpsLabel: String {
        switch gpsState {
        case .on: return "gps: on"
        case .locating: return "gps: locating..."
        case .denied: return "gps: off"
        case .off: return "gps: off"
        }
    }
}
