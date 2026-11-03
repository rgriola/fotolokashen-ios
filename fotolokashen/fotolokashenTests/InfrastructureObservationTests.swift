@testable import fotolokashen
import Observation
import SwiftData
import XCTest

nonisolated final class InfrastructureObservationTests: XCTestCase {
    @MainActor
    func testLocationServiceLoadingStateIsObservable() async {
        let locationService = LocationService()
        let changed = expectation(description: "LocationService.isLoading change is observed")
        let waiter = ObservationWaiter(
            locationService,
            \.isLoading,
            fulfilling: changed,
            where: { $0 }
        )

        locationService.isLoading = true

        await fulfillment(of: [changed], timeout: 1)
        waiter.cancel()
        XCTAssertTrue(locationService.isLoading)
    }

    @MainActor
    func testNetworkMonitorConnectivityIsObservable() async {
        let networkMonitor = NetworkMonitor(startMonitoring: false)
        let changed = expectation(description: "NetworkMonitor.isConnected change is observed")
        let waiter = ObservationWaiter(
            networkMonitor,
            \.isConnected,
            fulfilling: changed,
            where: { !$0 }
        )

        networkMonitor.isConnected = false

        await fulfillment(of: [changed], timeout: 1)
        waiter.cancel()
        XCTAssertFalse(networkMonitor.isConnected)
    }

    @MainActor
    func testPhotoUploadServiceProgressStateIsObservable() async {
        let photoUploadService = PhotoUploadService()
        let uploadingChanged = expectation(description: "PhotoUploadService.isUploading change is observed")
        let progressChanged = expectation(description: "PhotoUploadService.uploadProgress change is observed")
        let uploadingWaiter = ObservationWaiter(
            photoUploadService,
            \.isUploading,
            fulfilling: uploadingChanged,
            where: { $0 }
        )
        let progressWaiter = ObservationWaiter(
            photoUploadService,
            \.uploadProgress,
            fulfilling: progressChanged,
            where: { $0 == 0.5 }
        )

        photoUploadService.isUploading = true
        photoUploadService.uploadProgress = 0.5

        await fulfillment(of: [uploadingChanged, progressChanged], timeout: 1)
        uploadingWaiter.cancel()
        progressWaiter.cancel()
        XCTAssertTrue(photoUploadService.isUploading)
        XCTAssertEqual(photoUploadService.uploadProgress, 0.5)
    }

    @MainActor
    func testStoreRecoveryNoticeDismissalIsObservable() async throws {
        let schema = Schema([
            CachedLocation.self,
            CachedPhoto.self,
            OfflinePhoto.self
        ])
        let configuration = ModelConfiguration(
            "InfrastructureObservationTests",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let dataManager = DataManager(
            modelContainer: container,
            initialStoreRecoveryMessage: "Recovery required"
        )
        let changed = expectation(description: "DataManager store recovery dismissal is observed")
        let waiter = ObservationWaiter(
            dataManager,
            \.storeRecoveryMessage,
            fulfilling: changed,
            where: { $0 == nil }
        )

        dataManager.dismissStoreRecoveryNotice()

        await fulfillment(of: [changed], timeout: 1)
        waiter.cancel()
        XCTAssertNil(dataManager.storeRecoveryMessage)
    }

    @MainActor
    func testSyncServiceStatusIsObservable() async {
        let syncService = SyncService.shared
        let initialIsSyncing = syncService.isSyncing
        let initialProgress = syncService.progress
        let initialSyncDate = syncService.lastSyncDate
        let isSyncingChanged = expectation(description: "SyncService.isSyncing change is observed")
        let progressChanged = expectation(description: "SyncService.progress change is observed")
        let syncDateChanged = expectation(description: "SyncService.lastSyncDate change is observed")
        let isSyncingWaiter = ObservationWaiter(
            syncService,
            \.isSyncing,
            fulfilling: isSyncingChanged,
            where: { $0 }
        )
        let progressWaiter = ObservationWaiter(
            syncService,
            \.progress,
            fulfilling: progressChanged,
            where: { $0 == 0.5 }
        )
        let syncDateWaiter = ObservationWaiter(
            syncService,
            \.lastSyncDate,
            fulfilling: syncDateChanged,
            where: { $0 != nil }
        )

        syncService.isSyncing = true
        syncService.progress = 0.5
        syncService.lastSyncDate = Date()

        await fulfillment(of: [isSyncingChanged, progressChanged, syncDateChanged], timeout: 1)
        isSyncingWaiter.cancel()
        progressWaiter.cancel()
        syncDateWaiter.cancel()
        XCTAssertTrue(syncService.isSyncing)
        XCTAssertEqual(syncService.progress, 0.5)
        XCTAssertNotNil(syncService.lastSyncDate)
        syncService.isSyncing = initialIsSyncing
        syncService.progress = initialProgress
        syncService.lastSyncDate = initialSyncDate
    }
}
