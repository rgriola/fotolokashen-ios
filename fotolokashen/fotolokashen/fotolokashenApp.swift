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
    @StateObject private var syncService = SyncService.shared
    @StateObject private var dataManager = DataManager.shared
    
    init() {
        // Initialize Google Maps SDK
        let config = ConfigLoader.shared
        GMSServices.provideAPIKey(config.googleMapsAPIKey)
    }
    
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView()
                    .environmentObject(authService)
                    .environmentObject(networkMonitor)
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
            } else {
                ContentView()
                    .environmentObject(authService)
                    .environmentObject(networkMonitor)
                    .environmentObject(syncService)
                    .environmentObject(dataManager)
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
            }
        }
    }
}
