import Observation
import XCTest

nonisolated final class ObservationWaiterTests: XCTestCase {
    @MainActor
    func testIgnoresStartingValueAndNonMatchingChanges() async {
        let model = WaiterTestModel()
        let matched = expectation(description: "Waiter must not fire for the starting value or non-matching changes")
        matched.isInverted = true
        let waiter = ObservationWaiter(model, \.value, fulfilling: matched) { $0 == 1 }
        defer { waiter.cancel() }

        model.value = 2
        await fulfillment(of: [matched], timeout: 0.3)
    }

    @MainActor
    func testFulfillsOnceWhenValueChangesToMatch() async {
        let model = WaiterTestModel()
        let matched = expectation(description: "Waiter fires when the value changes to a match")
        let waiter = ObservationWaiter(model, \.value, fulfilling: matched) { $0 == 3 }
        defer { waiter.cancel() }

        model.value = 2
        await Task.yield()
        model.value = 3
        await fulfillment(of: [matched], timeout: 2)

        // A second match must not over-fulfill the expectation.
        model.value = 4
        model.value = 3
        await Task.yield()
        await Task.yield()
    }

    @MainActor
    func testCancelPreventsFulfillment() async {
        let model = WaiterTestModel()
        let matched = expectation(description: "Cancelled waiter must not fire")
        matched.isInverted = true
        let waiter = ObservationWaiter(model, \.value, fulfilling: matched) { $0 == 2 }

        waiter.cancel()
        model.value = 2
        await fulfillment(of: [matched], timeout: 0.3)
    }
}

@Observable
@MainActor
private final class WaiterTestModel {
    var value = 1
}
