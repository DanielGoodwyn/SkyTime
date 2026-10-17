import Foundation
import Combine

public struct SkyFavorite: Codable, Identifiable, Equatable {
    public var id: String
    public var label: String
    public var type: FavoriteType
    public var latitude: Double?
    public var longitude: Double?
    public var targetDate: Date?
    public var dateText: String?
    public var timeText: String?
    public var isFrozen: Bool
    public var createdAt: Date
    
    public enum FavoriteType: String, Codable, CaseIterable {
        case location = "Location"
        case moment = "Moment"
        case both = "Both"
        
        public static func fromString(_ str: String) -> FavoriteType {
            let lower = str.lowercased()
            if lower == "location" { return .location }
            if lower == "moment" { return .moment }
            return .both
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        label: String,
        type: FavoriteType,
        latitude: Double? = nil,
        longitude: Double? = nil,
        targetDate: Date? = nil,
        dateText: String? = nil,
        timeText: String? = nil,
        isFrozen: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.targetDate = targetDate
        self.dateText = dateText
        self.timeText = timeText
        self.isFrozen = isFrozen
        self.createdAt = createdAt
        
        // Derive dateText & timeText from targetDate if not supplied
        if let d = targetDate {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            if self.dateText == nil {
                df.dateFormat = "yyyy-MM-dd"
                self.dateText = df.string(from: d)
            }
            if self.timeText == nil {
                df.dateFormat = "HH:mm:ss"
                self.timeText = df.string(from: d)
            }
        }
    }
    
    // Dynamic coding keys to accept both legacy and canonical cross-platform fields
    enum CodingKeys: String, CodingKey {
        case id, label, type
        case latitude, lat
        case longitude, lng
        case targetDate, date, dateText
        case time, timeText
        case isFrozen, frozen
        case createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.label = (try? container.decode(String.self, forKey: .label)) ?? "Favorite"
        
        let typeStr = (try? container.decode(String.self, forKey: .type)) ?? "Both"
        self.type = FavoriteType.fromString(typeStr)
        
        self.latitude = (try? container.decode(Double.self, forKey: .latitude))
            ?? (try? container.decode(Double.self, forKey: .lat))
            
        self.longitude = (try? container.decode(Double.self, forKey: .longitude))
            ?? (try? container.decode(Double.self, forKey: .lng))
            
        self.dateText = (try? container.decode(String.self, forKey: .dateText))
            ?? (try? container.decode(String.self, forKey: .date))
            
        self.timeText = (try? container.decode(String.self, forKey: .timeText))
            ?? (try? container.decode(String.self, forKey: .time))
            
        self.isFrozen = (try? container.decode(Bool.self, forKey: .isFrozen))
            ?? (try? container.decode(Bool.self, forKey: .frozen))
            ?? false
            
        if let ms = try? container.decode(Double.self, forKey: .createdAt) {
            self.createdAt = Date(timeIntervalSince1970: ms / 1000.0)
        } else if let d = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = d
        } else {
            self.createdAt = Date()
        }
        
        // Resolve targetDate from targetDate or dateText + timeText
        if let d = try? container.decode(Date.self, forKey: .targetDate) {
            self.targetDate = d
        } else if let dt = self.dateText {
            let tm = self.timeText ?? "12:00:00"
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let parsed = df.date(from: "\(dt) \(tm)") {
                self.targetDate = parsed
            } else {
                df.dateFormat = "yyyy-MM-dd HH:mm"
                self.targetDate = df.date(from: "\(dt) \(tm)")
            }
        } else {
            self.targetDate = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(type.rawValue, forKey: .type)
        
        if let lat = latitude {
            try container.encode(lat, forKey: .lat)
            try container.encode(lat, forKey: .latitude)
        }
        if let lng = longitude {
            try container.encode(lng, forKey: .lng)
            try container.encode(lng, forKey: .longitude)
        }
        
        var dStr = dateText
        var tStr = timeText
        if let d = targetDate {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone.current
            if dStr == nil {
                df.dateFormat = "yyyy-MM-dd"
                dStr = df.string(from: d)
            }
            if tStr == nil {
                df.dateFormat = "HH:mm:ss"
                tStr = df.string(from: d)
            }
        }
        
        if let ds = dStr {
            try container.encode(ds, forKey: .date)
            try container.encode(ds, forKey: .dateText)
        }
        if let ts = tStr {
            try container.encode(ts, forKey: .time)
            try container.encode(ts, forKey: .timeText)
        }
        
        try container.encode(isFrozen, forKey: .frozen)
        try container.encode(isFrozen, forKey: .isFrozen)
        
        let ms = createdAt.timeIntervalSince1970 * 1000.0
        try container.encode(ms, forKey: .createdAt)
    }
}

@MainActor
public final class FavoritesManager: ObservableObject {
    public static let shared = FavoritesManager()
    
    @Published public var favorites: [SkyFavorite] = []
    @Published public var isSyncing: Bool = false
    
    private let baseStorageKey = "skytime_favorites"
    
    public init() {
        loadFavorites()
    }
    
    private var currentStorageKey: String {
        if let uid = AuthManager.shared.currentUser?.uid {
            return "\(baseStorageKey)_\(uid)"
        }
        return "\(baseStorageKey)_guest"
    }
    
    public func onUserChanged(_ uid: String?) {
        loadFavorites()
        if let uid = uid {
            fetchCloudFavorites(uid: uid)
        }
    }
    
    public func loadFavorites() {
        let key = currentStorageKey
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([SkyFavorite].self, from: data) {
            self.favorites = list
        } else {
            self.favorites = []
        }
        
        if let uid = AuthManager.shared.currentUser?.uid {
            fetchCloudFavorites(uid: uid)
        }
    }
    
    public func saveFavorites() {
        let key = currentStorageKey
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    public func addFavorite(
        label: String,
        type: SkyFavorite.FavoriteType,
        latitude: Double?,
        longitude: Double?,
        targetDate: Date?,
        isFrozen: Bool
    ) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLabel = trimmed.isEmpty ? "Favorite \(favorites.count + 1)" : trimmed
        
        let newFav = SkyFavorite(
            label: finalLabel,
            type: type,
            latitude: (type == .location || type == .both) ? latitude : nil,
            longitude: (type == .location || type == .both) ? longitude : nil,
            targetDate: (type == .moment || type == .both) ? targetDate : nil,
            isFrozen: (type == .moment || type == .both) ? isFrozen : false
        )
        
        favorites.insert(newFav, at: 0)
        saveFavorites()
        
        if let uid = AuthManager.shared.currentUser?.uid {
            syncFavoritesToCloud(uid: uid)
        }
    }
    
    public func deleteFavorite(id: String) {
        favorites.removeAll(where: { $0.id == id })
        saveFavorites()
        
        if let uid = AuthManager.shared.currentUser?.uid {
            syncFavoritesToCloud(uid: uid)
        }
    }
    
    // MARK: - Firestore Cloud Sync via REST API
    
    public func fetchCloudFavorites(uid: String) {
        guard let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/skytime_favorites/\(uid)?key=\(FirebaseConfig.apiKey)") else {
            return
        }
        
        isSyncing = true
        Task {
            defer { self.isSyncing = false }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpRes = response as? HTTPURLResponse else { return }
                
                if httpRes.statusCode == 200 {
                    if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let fields = root["fields"] as? [String: Any],
                       let jsonField = fields["json"] as? [String: Any],
                       let jsonString = jsonField["stringValue"] as? String,
                       let jsonData = jsonString.data(using: .utf8),
                       let cloudList = try? JSONDecoder().decode([SkyFavorite].self, from: jsonData) {
                        self.favorites = cloudList
                        self.saveFavorites()
                    }
                } else if httpRes.statusCode == 404 {
                    // Document does not exist yet on cloud. If we have local favorites, push them up!
                    if !self.favorites.isEmpty {
                        self.syncFavoritesToCloud(uid: uid)
                    }
                }
            } catch {
                // Keep local cached favorites on network error
                print("FavoritesManager fetch error: \(error.localizedDescription)")
            }
        }
    }
    
    public func syncFavoritesToCloud(uid: String) {
        guard let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/skytime_favorites/\(uid)?key=\(FirebaseConfig.apiKey)") else {
            return
        }
        
        guard let encodedData = try? JSONEncoder().encode(favorites),
              let jsonString = String(data: encodedData, encoding: .utf8) else {
            return
        }
        
        isSyncing = true
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "fields": [
                "json": [
                    "stringValue": jsonString
                ]
            ]
        ]
        
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = bodyData
        
        Task {
            defer { self.isSyncing = false }
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode >= 200 && http.statusCode < 300 {
                    // Successfully synced to Firestore!
                }
            } catch {
                print("FavoritesManager sync error: \(error.localizedDescription)")
            }
        }
    }
}
