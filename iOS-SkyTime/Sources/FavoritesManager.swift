import Foundation
import Combine

public struct SkyFavorite: Codable, Identifiable, Equatable {
    public var id: String
    public var label: String
    public var type: FavoriteType
    public var latitude: Double?
    public var longitude: Double?
    public var targetDate: Date?
    public var isFrozen: Bool
    public var createdAt: Date
    
    public enum FavoriteType: String, Codable, CaseIterable {
        case location = "Location"
        case moment = "Moment"
        case both = "Both"
    }
    
    public init(
        id: String = UUID().uuidString,
        label: String,
        type: FavoriteType,
        latitude: Double? = nil,
        longitude: Double? = nil,
        targetDate: Date? = nil,
        isFrozen: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.targetDate = targetDate
        self.isFrozen = isFrozen
        self.createdAt = createdAt
    }
}

@MainActor
public final class FavoritesManager: ObservableObject {
    public static let shared = FavoritesManager()
    
    @Published public var favorites: [SkyFavorite] = []
    
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
    
    public func loadFavorites() {
        let key = currentStorageKey
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([SkyFavorite].self, from: data) {
            self.favorites = list
        } else {
            self.favorites = []
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
        
        // Add to front of list
        favorites.insert(newFav, at: 0)
        saveFavorites()
    }
    
    public func deleteFavorite(id: String) {
        favorites.removeAll(where: { $0.id == id })
        saveFavorites()
    }
}
