import Foundation
import SwiftData
import Combine

/// Manages SwiftData persistence and caching
@available(iOS 17, *)
@MainActor
class DataManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DataManager()
    
    // MARK: - Published Properties
    
    @Published var pendingUploads: Int = 0
    
    // MARK: - Properties
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    // MARK: - Initialization
    
    private init() {
        do {
            let schema = Schema([
                CachedLocation.self,
                CachedPhoto.self,
                OfflinePhoto.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            modelContext = ModelContext(modelContainer)
            
            // Update pending uploads count
            Task {
                await updatePendingCount()
            }
            
            if ConfigLoader.shared.enableDebugLogging {
                print("[DataManager] SwiftData initialized successfully")
            }
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Location Operations
    
    /// Fetch all cached locations
    func fetchLocations() throws -> [CachedLocation] {
        let descriptor = FetchDescriptor<CachedLocation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Save or update location in cache
    func saveLocation(_ location: Location) throws {
        // Check if already exists
        let predicate = #Predicate<CachedLocation> { $0.id == location.id }
        let descriptor = FetchDescriptor<CachedLocation>(predicate: predicate)
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            existing.name = location.name
            existing.placeId = location.placeId
            existing.lat = location.lat
            existing.lng = location.lng
            existing.address = location.address
            existing.type = location.type
            existing.notes = location.notes
            existing.rating = location.rating
            existing.lastSyncedAt = Date()
            existing.isSynced = true
        } else {
            // Insert new
            let cached = CachedLocation.from(location)
            modelContext.insert(cached)
        }
        
        try modelContext.save()
    }
    
    /// Save multiple locations (batch)
    func saveLocations(_ locations: [Location]) throws {
        for location in locations {
            try saveLocation(location)
        }
    }
    
    /// Delete location from cache
    func deleteLocation(_ locationId: Int) throws {
        let predicate = #Predicate<CachedLocation> { $0.id == locationId }
        let descriptor = FetchDescriptor<CachedLocation>(predicate: predicate)
        
        if let location = try modelContext.fetch(descriptor).first {
            modelContext.delete(location)
            try modelContext.save()
        }
    }
    
    // MARK: - Photo Operations
    
    /// Fetch photos for a location
    func fetchPhotos(for locationId: Int) throws -> [CachedPhoto] {
        let predicate = #Predicate<CachedPhoto> { $0.locationId == locationId }
        let descriptor = FetchDescriptor<CachedPhoto>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    /// Save or update photo in cache
    func savePhoto(_ photo: Photo, locationId: Int) throws {
        let predicate = #Predicate<CachedPhoto> { $0.id == photo.id }
        let descriptor = FetchDescriptor<CachedPhoto>(predicate: predicate)
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            existing.caption = photo.caption
            existing.isPrimary = photo.isPrimary
            existing.lastSyncedAt = Date()
        } else {
            // Insert new
            let cached = CachedPhoto.from(photo, locationId: locationId)
            modelContext.insert(cached)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Offline Photo Queue
    
    /// Queue photo for upload
    func queuePhoto(_ offlinePhoto: OfflinePhoto) throws {
        modelContext.insert(offlinePhoto)
        try modelContext.save()
        Task { await updatePendingCount() }
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[DataManager] Photo queued for upload. Queue size: \(pendingUploads)")
        }
    }
    
    /// Fetch all queued photos
    func fetchQueuedPhotos() throws -> [OfflinePhoto] {
        let descriptor = FetchDescriptor<OfflinePhoto>(
            sortBy: [SortDescriptor(\.queuedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Remove photo from queue after successful upload
    func removeFromQueue(_ photo: OfflinePhoto) throws {
        modelContext.delete(photo)
        try modelContext.save()
        Task { await updatePendingCount() }
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[DataManager] Photo removed from queue. Remaining: \(pendingUploads)")
        }
    }
    
    /// Update pending uploads count
    private func updatePendingCount() async {
        do {
            let descriptor = FetchDescriptor<OfflinePhoto>()
            let count = try modelContext.fetchCount(descriptor)
            pendingUploads = count
        } catch {
            if ConfigLoader.shared.enableDebugLogging {
                print("[DataManager] Error fetching pending count: \(error)")
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data (on logout)
    func clearCache() throws {
        // Delete all locations
        try modelContext.delete(model: CachedLocation.self)
        // Delete all photos
        try modelContext.delete(model: CachedPhoto.self)
        // Keep offline queue for now
        
        try modelContext.save()
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[DataManager] Cache cleared")
        }
    }
    
    /// Clear offline photo queue
    func clearQueue() throws {
        try modelContext.delete(model: OfflinePhoto.self)
        try modelContext.save()
        Task { await updatePendingCount() }
        
        if ConfigLoader.shared.enableDebugLogging {
            print("[DataManager] Upload queue cleared")
        }
    }
}
