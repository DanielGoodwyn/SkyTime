import Foundation
import CoreLocation
import Combine

public enum GPSState: String {
    case off
    case locating
    case on
    case denied
}

public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationManager()
    
    @Published public var gpsState: GPSState = .off
    @Published public var latitude: Double = 37.7749
    @Published public var longitude: Double = -122.4194
    
    private let manager = CLLocationManager()
    
    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    public func startGPS() {
        gpsState = .locating
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            gpsState = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        @unknown default:
            gpsState = .denied
        }
    }
    
    public func stopGPS(state: GPSState = .off) {
        manager.stopUpdatingLocation()
        gpsState = state
    }
    
    public func toggleGPS() {
        if gpsState == .on || gpsState == .locating {
            stopGPS(state: .off)
        } else {
            startGPS()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if gpsState == .locating {
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            gpsState = .denied
        default:
            break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.latitude = max(-90.0, min(90.0, loc.coordinate.latitude))
        self.longitude = max(-180.0, min(180.0, loc.coordinate.longitude))
        self.gpsState = .on
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        gpsState = .denied
    }
}
