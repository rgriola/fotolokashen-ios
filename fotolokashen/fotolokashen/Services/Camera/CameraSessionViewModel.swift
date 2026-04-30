//
//  CameraSessionViewModel.swift
//  fotolokashen
//
//  Phase 2a-2: owns the multi-photo capture session for `CameraView`.
//
//  Responsibilities:
//  - Hold the in-flight `[SessionCapture]` (disk-backed, memory stays flat).
//  - Persist captured `UIImage` to a temp directory off the main thread.
//  - Generate a 150×150 thumbnail for the strip UI.
//  - Track `isWritingToDisk` (disables capture button) and `captureFlash` (white overlay).
//  - Provide remove + finish entry points.
//
//  Behavior parity: this class is a 1:1 extraction of the disk-write pipeline that
//  previously lived inline in `CameraView.handleCapturedPhoto(_:)`.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
final class CameraSessionViewModel: ObservableObject {

    // MARK: - Published State

    @Published var sessionCaptures: [SessionCapture] = []
    @Published var isWritingToDisk = false
    @Published var captureFlash = false

    // MARK: - Constants

    /// Maximum photos per session (disk-backed, memory stays flat).
    static let maxSessionPhotos = 50

    // MARK: - Capture Pipeline

    /// Handle a captured photo — write to disk, generate thumbnail, append to session.
    /// Mirrors the original `CameraView.handleCapturedPhoto(_:)` exactly.
    func handleCapturedPhoto(_ image: UIImage, location: CLLocation?) {
        isWritingToDisk = true

        // Flash animation
        withAnimation(.easeIn(duration: 0.05)) { captureFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            withAnimation(.easeOut(duration: 0.15)) { self?.captureFlash = false }
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            // Compress to JPEG
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                await MainActor.run { self?.isWritingToDisk = false }
                return
            }

            // Write to temp directory
            let filename = "capture_\(UUID().uuidString).jpg"
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("fotolokashen_session", isDirectory: true)

            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let fileURL = tempDir.appendingPathComponent(filename)

            do {
                try jpegData.write(to: fileURL)
            } catch {
                #if DEBUG
                print("[Camera] Failed to write capture to disk: \(error)")
                #endif
                await MainActor.run { self?.isWritingToDisk = false }
                return
            }

            // Generate small thumbnail (150×150)
            let thumbnailSize = CGSize(width: 150, height: 150)
            let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
            let thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
            }

            let capture = SessionCapture(
                fileURL: fileURL,
                thumbnail: thumbnail,
                location: location,
                capturedAt: Date()
            )

            await MainActor.run {
                guard let self else { return }
                self.sessionCaptures.append(capture)
                self.isWritingToDisk = false
                #if DEBUG
                print("[Camera] Session capture \(self.sessionCaptures.count) saved to \(fileURL.lastPathComponent)")
                #endif
            }
        }
    }

    /// Remove a capture and delete its temp file.
    func removeCapture(_ capture: SessionCapture) {
        sessionCaptures.removeAll { $0.id == capture.id }
        try? FileManager.default.removeItem(at: capture.fileURL)
    }

    /// Whether the capture button should be disabled (writing in flight or session full).
    var isCaptureDisabled: Bool {
        isWritingToDisk || sessionCaptures.count >= Self.maxSessionPhotos
    }

    // MARK: - Cleanup

    /// Clean up temp files for any captures not handed off.
    static func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fotolokashen_session", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
    }
}
