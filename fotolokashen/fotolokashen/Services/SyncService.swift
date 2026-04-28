import Foundation
import SwiftUI
import CoreLocation
import Combine

/// Manages synchronization between local cache and backend API
@MainActor
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
    
    // REVIEW: Dead code — Notification.Name("NetworkConnected") is never posted anywhere in the codebase.
    // Either wire up NetworkMonitor to post this notification, or remove this observer and use
    // NetworkMonitor.$isConnected.sink {} instead for reactive sync-on-reconnect.
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
    
    // REVIEW: No exponential backoff on photo upload retries — all 3 retries fire immediately.
    // Consider adding delay between retries (e.g., 1s, 3s, 9s) to handle transient network issues.
    
    /// Sync all data (locations download + photos upload)
    func syncAll() async {
        guard networkMonitor.isConnected else {
            if config.enableDebugLogging {
                print("[Sync] Skipping sync - offline")
            }
            return
        }
        
        // Don't attempt sync if not authenticated — API calls will just fail with 401
        guard KeychainService.shared.getAccessToken() != nil else {
            if config.enableDebugLogging {
                print("[Sync] Skipping sync - no auth token")
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
        
        isSyncing = false
    }
    
    /// Sync locations from API to local cache
    func syncLocationsFromAPI() async {
        guard networkMonitor.isConnected else { return }

        do {
            // If LocationStore already fetched locations (from view .task), reuse them
            // instead of making a duplicate API call
            let locations: [Location]
            if !LocationStore.shared.locations.isEmpty {
                locations = LocationStore.shared.locations
                if config.enableDebugLogging {
                    print("[Sync] Reusing \(locations.count) locations from LocationStore (skipping duplicate API call)")
                }
            } else {
                if config.enableDebugLogging {
                    print("[Sync] Fetching locations from API...")
                }
                locations = try await locationService.fetchLocations()

                // Update the shared LocationStore so all views stay in sync
                LocationStore.shared.locations = locations

                if config.enableDebugLogging {
                    print("[Sync] LocationStore updated with \(locations.count) locations")
                }
            }

            // Save to local cache
            try dataManager.saveLocations(locations)

            if config.enableDebugLogging {
                print("[Sync] \(locations.count) locations saved to cache")
            }

        } catch {
            if config.enableDebugLogging {
                print("[Sync] Location sync error: \(error)")
            }
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
            // Error already logged, don't rethrow
        }
    }
    
    /// Force refresh locations (pull-to-refresh)
    func refreshLocations() async {
        await syncLocationsFromAPI()
    }
}
