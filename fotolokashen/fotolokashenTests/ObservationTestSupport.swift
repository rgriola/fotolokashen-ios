import Observation
import XCTest

/// Fulfills `expectation` the first time an `@Observable` property changes to a value matching `predicate`.
///
/// Observation counterpart of `object.$property.dropFirst().filter(predicate).prefix(1).sink { fulfill }`:
/// only changes made after the waiter is created count, never the value it starts with. The value is read on
/// the next main-actor turn after a change, so writes made in the same turn are coalesced and only the latest
/// value is checked. Keep the waiter alive until the expectation is awaited, then call `cancel()`.
@MainActor
final class ObservationWaiter<Root: AnyObject & Observable, Value> {
    private weak var root: Root?
    private let keyPath: KeyPath<Root, Value>
    private let predicate: (Value) -> Bool
    private let expectation: XCTestExpectation
    private var isFinished = false

    init(
        _ root: Root,
        _ keyPath: KeyPath<Root, Value>,
        fulfilling expectation: XCTestExpectation,
        where predicate: @escaping (Value) -> Bool
    ) {
        self.root = root
        self.keyPath = keyPath
        self.predicate = predicate
        self.expectation = expectation
        track()
    }

    func cancel() {
        isFinished = true
    }

    private func track() {
        guard !isFinished, let root else { return }
        let evaluateOnMainActor: @MainActor @Sendable () -> Void = { [weak self] in
            self?.evaluate()
        }
        withObservationTracking {
            _ = root[keyPath: keyPath]
        } onChange: {
            // onChange runs before the new value is stored; read it once the mutation completes.
            Task { @MainActor in
                evaluateOnMainActor()
            }
        }
    }

    private func evaluate() {
        guard !isFinished, let root else { return }
        if predicate(root[keyPath: keyPath]) {
            isFinished = true
            expectation.fulfill()
        } else {
            track()
        }
    }
}
