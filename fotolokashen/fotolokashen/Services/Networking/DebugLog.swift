import Foundation
import os.log

/// Debug-only logging helper. Stripped from release builds via `#if DEBUG`.
///
/// Usage:
///     dlog("ServiceName", "message with interpolation: \(value)")
///
/// Replaces the verbose pattern:
///     #if DEBUG
///     if ConfigLoader.shared.enableDebugLogging {
///         print("[ServiceName] message")
///     }
///     #endif
///
/// In DEBUG builds, messages are routed through `os.Logger` under the
/// `com.fotolokashen.app` subsystem, with the `tag` as the category. This
/// makes per-service filtering possible in Console.app and Instruments while
/// preserving the legacy `[Tag] message` shape in Xcode's debug console.
///
/// In RELEASE builds, the function body is empty and call sites are stripped.
public func dlog(_ tag: String, _ message: @autoclosure () -> String) {
    #if DEBUG
    let resolved = message()
    let logger = Logger(subsystem: "com.fotolokashen.app", category: tag)
    logger.debug("\(resolved, privacy: .public)")
    #endif
}
