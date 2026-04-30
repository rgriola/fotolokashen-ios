import Foundation
import SwiftUI
import Combine

/// App-wide presenter for user-facing errors and notices.
///
/// Phase 2c: provides a single, consistent surface for banner + alert
/// presentation so individual services don't each invent their own
/// `@Published var errorMessage` UI conventions.
///
/// Usage:
///   • Service-side:  `ErrorPresenter.shared.present(.init(message: ...))`
///   • View-side:     attach `.errorPresenter()` once at the app root.
@MainActor
final class ErrorPresenter: ObservableObject {
    static let shared = ErrorPresenter()

    /// The currently visible banner (auto-dismisses).
    @Published var banner: AppError?
    /// The currently visible alert (modal, requires acknowledgement).
    @Published var alert: AppError?

    private var bannerDismissTask: Task<Void, Never>?

    init() {}

    /// Present an error/notice. Routes to banner or alert based on `style`.
    func present(_ error: AppError, autoDismissAfter seconds: TimeInterval = 4) {
        switch error.style {
        case .banner:
            banner = error
            bannerDismissTask?.cancel()
            bannerDismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if self?.banner?.id == error.id {
                    self?.banner = nil
                }
            }
        case .alert:
            alert = error
        }
    }

    /// Convenience for the most common case — an error message string.
    func present(
        message: String,
        title: String = "",
        severity: AppErrorSeverity = .error,
        style: AppErrorStyle = .banner,
        retry: (@MainActor () -> Void)? = nil
    ) {
        present(.init(title: title, message: message, severity: severity, style: style, retry: retry))
    }

    /// Dismiss the current banner immediately.
    func dismissBanner() {
        bannerDismissTask?.cancel()
        banner = nil
    }

    /// Dismiss the current alert immediately.
    func dismissAlert() {
        alert = nil
    }
}
