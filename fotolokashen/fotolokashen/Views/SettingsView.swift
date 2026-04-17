import SwiftUI

/// SettingsView — redirects to AccountSecurityView.
/// This file is kept for compatibility. The old SettingsView content
/// has been reorganised into purpose-specific views:
///   - AccountSecurityView  (email, password, delete account)
///   - PrivacySettingsView  (visibility, follow settings)
///   - NotificationPreferencesView (email/push toggles)
///
/// All are reachable from ProfileView.
typealias SettingsView = AccountSecurityView
