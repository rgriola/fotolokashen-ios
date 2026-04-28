//
//  fotolokashenApp.swift
//  fotolokashen
//
//  Created by rgriola on 1/15/26.
//

import SwiftUI
import SwiftData
import GoogleMaps

// MARK: - Launch Timer (DEBUG only)
#if DEBUG
/// Tracks elapsed time from app process start for launch diagnostics
enum LaunchTimer {
    static let processStart = CFAbsoluteTimeGetCurrent()
    
    static func mark(_ label: String) {
        let elapsed = (CFAbsoluteTimeGetCurrent() - processStart) * 1000
        print("[⏱️ +\(String(format: "%7.0f", elapsed))ms] \(label)")
    }
}
#endif

@main
struct FotolokashenApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    init() {
        #if DEBUG
        LaunchTimer.mark("FotolokashenApp.init() START")
        #endif

        // Defer Google Maps SDK init off the main thread
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        DispatchQueue.global(qos: .userInitiated).async {
            GMSServices.provideAPIKey(apiKey)
            #if DEBUG
            DispatchQueue.main.async {
                LaunchTimer.mark("GMSServices.provideAPIKey() completed (background)")
            }
            #endif
        }

        #if DEBUG
        LaunchTimer.mark("FotolokashenApp.init() END")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authService)
                .environmentObject(networkMonitor)
                .onAppear {
                    #if DEBUG
                    LaunchTimer.mark("AppRootView.onAppear — UI VISIBLE")
                    #endif
                }
        }
    }
}

// MARK: - App Root View (iOS 17+ with SwiftData)

struct AppRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var deepLinkManager = DeepLinkManager.shared
    @State private var hasAppearedOnce = false

    var body: some View {
        #if DEBUG
        let _ = LaunchTimer.mark("AppRootView.body evaluated (isAuth=\(authService.isAuthenticated), isLoading=\(authService.isLoading), error=\(authService.errorMessage ?? "nil"), user=\(authService.currentUser?.username ?? "nil"))")
        #endif
        Group {
            if authService.isAuthenticated {
                AuthenticatedRootView()
            } else {
                NavigationStack {
                    LoginView()
                        .environmentObject(deepLinkManager)
                }
            }
        }
        .onOpenURL { url in
            if !deepLinkManager.handleURL(url) {
                if url.scheme == "fotolokashen" {
                    Task {
                        await authService.handleCallback(url: url)
                    }
                }
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            _ = deepLinkManager.handleURL(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Skip the first activation — AuthService.init() already checked auth.
                // Only re-check when returning from background.
                guard hasAppearedOnce else {
                    hasAppearedOnce = true
                    #if DEBUG
                    LaunchTimer.mark("Scene became active (initial — skipping duplicate checkAuthStatus)")
                    #endif
                    return
                }
                #if DEBUG
                LaunchTimer.mark("Scene became active (from background) — re-checking auth")
                #endif
                authService.checkAuthStatus()
            }
        }
    }
}

// MARK: - Authenticated Root View (heavy services init deferred here)

struct AuthenticatedRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @ObservedObject private var deepLinkManager = DeepLinkManager.shared
    private let syncService = SyncService.shared
    private let dataManager = DataManager.shared

    var body: some View {
        LoggedInView()
            .environmentObject(syncService)
            .environmentObject(dataManager)
            .environmentObject(deepLinkManager)
            .modelContainer(dataManager.modelContainer)
            .task(priority: .utility) {
                guard networkMonitor.isConnected else { return }
                await syncService.syncAll()
            }
    }
}
