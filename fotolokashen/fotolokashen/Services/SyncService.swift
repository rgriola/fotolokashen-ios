import Foundation
import SwiftUI
import CoreLocation

/// Manages synchronization between local cache and backend API
class SyncService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SyncService()
    
    // MARK: - Published Properties
    
    @Published var isSyncing: Bool = false
    @Published var progress: Double = 0.0
    @Published var lastSyncDate: Date?
    
    // MARK: - Properties
    
    private let dataManager = DataManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private let locationService = LocationService()
    private let photoUploadService = PhotoUploadService()
    private let config = ConfigLoader.shared
    
    // MARK: - Initialization
    
    private init() {
        // Start observing network changes
        setupNetworkObserver()
    }
    
    // MARK: - Network Observer
    
    private func setupNetworkObserver() {
        // Sync when network becomes available
        Task {
            for await _ in NotificationCenter.default.notifications(named: .init("NetworkConnected")) {
                if networkMonitor.isConnected {
                    await syncAll()
                }
            }
        }
    }
    
    // MARK: - Public Sync Methods
    
    /// Sync all data (locations download + photos upload)
    func syncAll() async {
        guard networkMonitor.isConnected else {
            if config.enableDebugLogging {
                print("[Sync] Skipping sync - offline")
            }
            return
        }
        
        guard !isSyncing else {
            if config.enableDebugLogging {
                print("[Sync] Already syncing")
            }
            return
        }
        
        isSyncing = true
        progress = 0.0
        
        if config.enableDebugLogging {
            print("[Sync] Starting full sync...")
        }
        
        do {
            // Step 1: Download locations from API
            await syncLocationsFromAPI()
            progress = 0.5
            
            // Step 2: Upload queued photos
            await syncPhotosToAPI()
            progress = 1.0
            
            lastSyncDate = Date()
            
            if config.enableDebugLogging {
                print("[Sync] Full sync complete")
            }
            
        } catch {
            if config.enableDebugLogging {
                print("[Sync] Sync error: \(error)")
            }
        }
        
        isSyncing = false
    }
    
    /// Sync locations from API to local cache
    func syncLocationsFromAPI() async {
        guard networkMonitor.isConnected else { return }
        
        do {
            if config.enableDebugLogging {
                print("[Sync] Fetching locations from API...")
            }
            
            // Fetch from API
            let response: LocationsResponse = try await locationService.fetchLocations()
            
            if config.enableDebugLogging {
                print("[Sync] Fetched \(response.locations.count) locations")
            }
            
            // Save to local cache
            try dataManager.saveLocations(response.locations)
            
            if config.enableDebugLogging {
                print("[Sync] Locations saved to cache")
            }
            
        } catch {
            if config.enableDebugLogging {
                print("[Sync] Location sync error: \(error)")
            }
            throw error
        }
    }
    
    /// Upload queued photos to API
    func syncPhotosToAPI() async {
        guard networkMonitor.isConnected else { return }
        
        do {
            let queuedPhotos = try dataManager.fetchQueuedPhotos()
            
            if queuedPhotos.isEmpty {
                if config.enableDebugLogging {
                    print("[Sync] No photos to upload")
                }
                return
            }
            
            if config.enableDebugLogging {
                print("[Sync] Uploading \(queuedPhotos.count) queued photos...")
            }
            
            var uploadedCount = 0
            var failedCount = 0
            
            for (index, offlinePhoto) in queuedPhotos.enumerated() {
                // Skip if exceeded retry limit
                guard offlinePhoto.shouldRetry else {
                    if config.enableDebugLogging {
                        print("[Sync] Skipping photo \(offlinePhoto.clientId) - exceeded retry limit")
                    }
                    failedCount += 1
                    continue
                }
                
                do {
                    // Create UIImage from data
                    guard let image = UIImage(data: offlinePhoto.imageData) else {
                        throw PhotoUploadError.compressionFailed
                    }
                    
                    // Create CLLocation if GPS data available
                    var location: CLLocation?
                    if let lat = offlinePhoto.gpsLatitude,
                       let lon = offlinePhoto.gpsLongitude {
                        location = CLLocation(latitude: lat, longitude: lon)
                    }
                    
                    // Upload photo
                    let _ = try await photoUploadService.uploadPhoto(
                        image: image,
                        locationId: offlinePhoto.locationId,
                        location: location,
                        caption: offlinePhoto.caption
                    )
                    
                    // Remove from queue on success
                    try dataManager.removeFromQueue(offlinePhoto)
                    uploadedCount += 1
                    
                    if config.enableDebugLogging {
                        print("[Sync] Uploaded photo \(index + 1)/\(queuedPhotos.count)")
                    }
                    
                } catch {
                    // Mark as retried
                    offlinePhoto.markRetried()
                    offlinePhoto.setError(error.localizedDescription)
                    failedCount += 1
                    
                    if config.enableDebugLogging {
                        print("[Sync] Failed to upload photo: \(error)")
                        print("[Sync] Retry count: \(offlinePhoto.retryCount)/3")
                    }
                }
            }
            
            if config.enableDebugLogging {
                print("[Sync] Photo upload complete: \(uploadedCount) succeeded, \(failedCount) failed")
            }
            
        } catch {
            if config.enableDebugLogging {
                print("[Sync] Photo sync error: \(error)")
            }
            throw error
        }
    }
    
    /// Force refresh locations (pull-to-refresh)
    func refreshLocations() async {
        await syncLocationsFromAPI()
    }
}

// MARK: - Response Models

struct LocationsResponse: Codable {
    let locations: [Location]
}
