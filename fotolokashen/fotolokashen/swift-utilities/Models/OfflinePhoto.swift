import Foundation
import SwiftData

/// SwiftData model for photos queued for upload when offline
@available(iOS 17, *)
@Model
final class OfflinePhoto {
    @Attribute(.unique) var clientId: UUID
    var imageData: Data
    var locationId: Int
    var caption: String?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var capturedAt: Date
    var queuedAt: Date
    var retryCount: Int
    var lastRetryAt: Date?
    var errorMessage: String?
    
    init(
        imageData: Data,
        locationId: Int,
        caption: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil,
        capturedAt: Date = Date()
    ) {
        self.clientId = UUID()
        self.imageData = imageData
        self.locationId = locationId
        self.caption = caption
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
        self.capturedAt = capturedAt
        self.queuedAt = Date()
        self.retryCount = 0
        self.lastRetryAt = nil
        self.errorMessage = nil
    }
    
    /// Check if photo should be retried
    var shouldRetry: Bool {
        retryCount < 3
    }
    
    /// Mark as retried
    func markRetried() {
        retryCount += 1
        lastRetryAt = Date()
    }
    
    /// Set error
    func setError(_ message: String) {
        errorMessage = message
    }
}
