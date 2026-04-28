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
        #if DEBUG
        let launchStart = CFAbsoluteTimeGetCurrent()
        #endif

        // Defer Google Maps SDK init off the main thread — it takes 200-500ms
        // and isn't needed until MapView appears.
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        DispatchQueue.global(qos: .userInitiated).async {
            GMSServices.provideAPIKey(apiKey)
        }

        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - launchStart) * 1000
        print("[App] init() completed in \(String(format: "%.0f", elapsed))ms")
        #endif
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

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Only create DataManager/SyncService/ModelContainer when authenticated
                // SwiftData ModelContainer init is expensive (~200-500ms) and unnecessary
                // on the login screen
                AuthenticatedRootView()
            } else {
                NavigationStack {
                    LoginView()
                        .environmentObject(deepLinkManager)
                }
            }
        }
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
