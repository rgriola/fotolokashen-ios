import XCTest
@testable import fotolokashen

nonisolated final class ErrorPresenterTests: XCTestCase {
    @MainActor
    func testBannerAutoDismissNotifiesObservers() async {
        let presenter = ErrorPresenter()
        let shown = expectation(description: "Banner presentation is observed")
        let dismissed = expectation(description: "Banner auto-dismissal is observed")
        let showWaiter = ObservationWaiter(presenter, \.banner, fulfilling: shown) { $0 != nil }
        let dismissWaiter = ObservationWaiter(presenter, \.banner, fulfilling: dismissed) { $0 == nil }
        defer {
            showWaiter.cancel()
            dismissWaiter.cancel()
        }

        presenter.present(.init(message: "Offline"), autoDismissAfter: 0.1)
        await fulfillment(of: [shown, dismissed], timeout: 2, enforceOrder: true)
    }

    @MainActor
    func testNewerBannerIsNotDismissedByEarlierTimer() async throws {
        let presenter = ErrorPresenter()
        presenter.present(.init(message: "First"), autoDismissAfter: 0.05)
        let second = AppError(message: "Second")
        presenter.present(second, autoDismissAfter: 10)

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(presenter.banner, second)
    }

    @MainActor
    func testAlertStyleRoutesToAlertAndDismisses() {
        let presenter = ErrorPresenter()
        let alert = AppError(message: "Failed", style: .alert)
        presenter.present(alert)
        XCTAssertEqual(presenter.alert, alert)
        XCTAssertNil(presenter.banner)

        presenter.dismissAlert()
        XCTAssertNil(presenter.alert)
    }
}
