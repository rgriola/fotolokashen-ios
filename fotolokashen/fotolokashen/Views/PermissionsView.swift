import SwiftUI
import CoreLocation
import AVFoundation
import Photos
import UserNotifications

/// Permissions — shows iOS permission status for GPS, Camera, Photo Library, and Notifications.
/// Tapping any row opens iOS Settings.app where the user can grant or revoke access.
/// Profile → App Settings → Permissions
struct PermissionsView: View {

    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var photoStatus: PHAuthorizationStatus = .notDetermined
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    icon: "location.fill",
                    label: "Location (GPS)",
                    description: "Used to show nearby locations on the map.",
                    isGranted: locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
                )
                PermissionRow(
                    icon: "camera.fill",
                    label: "Camera",
                    description: "Used to take photos for your profile and locations.",
                    isGranted: cameraStatus == .authorized
                )
                PermissionRow(
                    icon: "photo.fill",
                    label: "Photo Library",
                    description: "Used to upload photos from your library.",
                    isGranted: photoStatus == .authorized || photoStatus == .limited
                )
                PermissionRow(
                    icon: "bell.fill",
                    label: "Notifications",
                    description: "Used to send alerts for followers and activity.",
                    isGranted: notificationStatus == .authorized || notificationStatus == .provisional
                )
            } header: {
                Text("App Permissions")
            } footer: {
                Text("Tap any row to open iOS Settings where you can change permissions.")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshPermissions() }
    }

    // MARK: - Refresh

    private func refreshPermissions() {
        locationStatus = CLLocationManager().authorizationStatus
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run { notificationStatus = settings.authorizationStatus }
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let label: String
    let description: String
    let isGranted: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconColumnWidth: CGFloat = 24

    private var permissionIcon: some View {
        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(isGranted ? Color.green : Color.secondary)
            .frame(minWidth: iconColumnWidth)
            .accessibilityHidden(true)
    }

    private var status: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isGranted ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(isGranted ? "On" : "Off")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isGranted ? Color.green : Color.red)
        }
    }

    private var settingsIcon: some View {
        Image(systemName: "arrow.up.right.square")
            .font(.caption)
            .foregroundStyle(Color.secondary)
            .accessibilityHidden(true)
    }

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Group {
                if dynamicTypeSize >= .accessibility1 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            permissionIcon
                            Text(label)
                                .foregroundStyle(Color.primary)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(description)
                            .foregroundStyle(Color.secondary)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            status
                            settingsIcon
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        permissionIcon

                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .foregroundStyle(Color.primary)
                                .font(.body)
                            Text(description)
                                .foregroundStyle(Color.secondary)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                        status
                        settingsIcon
                    }
                }
            }
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label), \(description)"))
        .accessibilityValue(Text(isGranted ? "On" : "Off"))
        .accessibilityHint("Opens iOS Settings to change permissions.")
    }
}

#Preview {
    NavigationStack {
        PermissionsView()
    }
}
