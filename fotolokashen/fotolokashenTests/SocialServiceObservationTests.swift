import Observation
import XCTest
@testable import fotolokashen

nonisolated final class SocialServiceObservationTests: XCTestCase {
    @MainActor
    func testFollowServiceLoadingStateIsObservable() {
        let service = FollowService()
        let changed = expectation(description: "FollowService.isLoading change is observed")

        withObservationTracking {
            _ = service.isLoading
        } onChange: {
            changed.fulfill()
        }

        service.isLoading = true

        wait(for: [changed], timeout: 0)
        XCTAssertTrue(service.isLoading)
    }

    @MainActor
    func testUserServiceLoadingAndUploadProgressAreObservable() {
        let service = UserService()
        let loadingChanged = expectation(description: "UserService.isLoading change is observed")
        let uploadingChanged = expectation(description: "UserService.isUploading change is observed")
        let progressChanged = expectation(description: "UserService.uploadProgress change is observed")

        withObservationTracking {
            _ = service.isLoading
        } onChange: {
            loadingChanged.fulfill()
        }
        withObservationTracking {
            _ = service.isUploading
        } onChange: {
            uploadingChanged.fulfill()
        }
        withObservationTracking {
            _ = service.uploadProgress
        } onChange: {
            progressChanged.fulfill()
        }

        service.isLoading = true
        service.isUploading = true
        service.uploadProgress = 0.5

        wait(for: [loadingChanged, uploadingChanged, progressChanged], timeout: 0)
        XCTAssertTrue(service.isLoading)
        XCTAssertTrue(service.isUploading)
        XCTAssertEqual(service.uploadProgress, 0.5)
    }

    @MainActor
    func testLocationGroupServiceLoadingStateIsObservable() {
        let service = LocationGroupService()
        let changed = expectation(description: "LocationGroupService.isLoading change is observed")

        withObservationTracking {
            _ = service.isLoading
        } onChange: {
            changed.fulfill()
        }

        service.isLoading = true

        wait(for: [changed], timeout: 0)
        XCTAssertTrue(service.isLoading)
    }
}
