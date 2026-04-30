import Foundation
import SwiftUI

/// Severity level for a user-facing error/notice.
enum AppErrorSeverity {
    case info
    case warning
    case error

    var systemImage: String {
        switch self {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        }
    }
}

/// Presentation style hint — the presenter ultimately decides which UI to use.
enum AppErrorStyle {
    /// Transient banner that auto-dismisses (default for non-blocking errors).
    case banner
    /// Modal alert that requires user acknowledgement (use sparingly).
    case alert
}

/// A user-facing error/notice routed through `ErrorPresenter`.
struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let severity: AppErrorSeverity
    let style: AppErrorStyle
    let retry: (@MainActor () -> Void)?

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }

    init(
        title: String = "",
        message: String,
        severity: AppErrorSeverity = .error,
        style: AppErrorStyle = .banner,
        retry: (@MainActor () -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.severity = severity
        self.style = style
        self.retry = retry
    }
}
