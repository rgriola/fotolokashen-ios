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
        // Initialize Google Maps SDK
        let config = ConfigLoader.shared
        GMSServices.provideAPIKey(config.googleMapsAPIKey)
    }
    
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentViewiOS17()
                    .environmentObject(authService)
                    .environmentObject(networkMonitor)
            } else {
                ContentViewLegacy()
                    .environmentObject(authService)
                    .environmentObject(networkMonitor)
            }
        }
    }
}

// MARK: - Legacy iOS View (pre-iOS 17)

struct ContentViewLegacy: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ContentView()
            .onOpenURL { url in
                // Handle OAuth callback
                if url.scheme == "fotolokashen" {
                    Task {
                        await authService.handleCallback(url: url)
                    }
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Re-check auth status when app becomes active
                    print("[App] Scene became active - checking auth status")
                    authService.checkAuthStatus()
                }
            }
    }
}

// MARK: - iOS 17+ View with SwiftData

@available(iOS 17.0, *)
struct ContentViewiOS17: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    
    private let syncService = SyncService.shared
    private let dataManager = DataManager.shared
    
    var body: some View {
        ContentView()
            .environmentObject(syncService)
            .environmentObject(dataManager)
            .modelContainer(dataManager.modelContainer)
            .onOpenURL { url in
                // Handle OAuth callback
                if url.scheme == "fotolokashen" {
                    Task {
                        await authService.handleCallback(url: url)
                    }
                }
            }
            .task {
                // Sync on app launch if online
                if networkMonitor.isConnected {
                    await syncService.syncAll()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Re-check auth status when app becomes active
                    // This will detect if the token was invalidated on another device
                    print("[App] Scene became active - checking auth status")
                    authService.checkAuthStatus()
                }
            }
    }
}
