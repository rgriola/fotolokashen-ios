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
    @StateObject private var authService: AuthService
    @StateObject private var networkMonitor: NetworkMonitor
    
    init() {
        #if DEBUG
        LaunchTimer.mark("FotolokashenApp.init() START")
        #endif

        // Create StateObjects manually so we can time them
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent()
        #endif
        let auth = AuthService()
        #if DEBUG
        LaunchTimer.mark("AuthService() created (\(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))ms)")
        #endif
        
        _authService = StateObject(wrappedValue: auth)
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor.shared)

        #if DEBUG
        let t1 = CFAbsoluteTimeGetCurrent()
        #endif
        // Defer Google Maps SDK init off the main thread
        let apiKey = ConfigLoader.shared.googleMapsAPIKey
        #if DEBUG
        LaunchTimer.mark("ConfigLoader.shared accessed (\(Int((CFAbsoluteTimeGetCurrent() - t1) * 1000))ms)")
        #endif
        
        DispatchQueue.global(qos: .userInitiated).async {
            let t = CFAbsoluteTimeGetCurrent()
            GMSServices.provideAPIKey(apiKey)
            #if DEBUG
            DispatchQueue.main.async {
                print("[⏱️ BG] GMSServices.provideAPIKey() took \(Int((CFAbsoluteTimeGetCurrent() - t) * 1000))ms")
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

    var body: some View {
        #if DEBUG
        let _ = LaunchTimer.mark("AppRootView.body evaluated (isAuthenticated=\(authService.isAuthenticated))")
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
                #if DEBUG
                LaunchTimer.mark("Scene became active - checking auth status")
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
