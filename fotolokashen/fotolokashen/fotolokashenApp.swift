//
//  fotolokashenApp.swift
//  fotolokashen
//
//  Created by rgriola on 1/15/26.
//

import SwiftUI
import SwiftData
import GoogleMaps

@main
struct FotolokashenApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    init() {
        // Defer Google Maps SDK init off the main thread — it takes 200-500ms
        // and isn't needed until MapView appears.
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        DispatchQueue.global(qos: .userInitiated).async {
            GMSServices.provideAPIKey(apiKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authService)
                .environmentObject(networkMonitor)
        }
    }
}

// MARK: - App Root View (iOS 17+ with SwiftData)

struct AppRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var deepLinkManager = DeepLinkManager.shared
    private let syncService = SyncService.shared
    private let dataManager = DataManager.shared

    var body: some View {
        ContentView()
            .environmentObject(syncService)
            .environmentObject(dataManager)
            .environmentObject(deepLinkManager)
            .modelContainer(dataManager.modelContainer)
            .onOpenURL { url in
                // Try deep link first; if not handled, fall back to OAuth
                if !deepLinkManager.handleURL(url) {
                    if url.scheme == "fotolokashen" {
                        Task {
                            await authService.handleCallback(url: url)
                        }
                    }
                }
            }
            // Universal Links arrive via NSUserActivity
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                _ = deepLinkManager.handleURL(url)
            }
            .task(priority: .utility) {
                // Only sync when authenticated — no point hitting the API
                // if there's no token (it will just fail with 401)
                guard authService.isAuthenticated,
                      networkMonitor.isConnected else { return }
                await syncService.syncAll()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    #if DEBUG
                    print("[App] Scene became active - checking auth status")
                    #endif
                    authService.checkAuthStatus()
                }
            }
    }
}
