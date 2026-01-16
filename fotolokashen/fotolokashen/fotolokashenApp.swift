//
//  fotolokashenApp.swift
//  fotolokashen
//
//  Created by rgriola on 1/15/26.
//

import SwiftUI
import GoogleMaps

@main
struct fotolokashenApp: App {
    @StateObject private var authService = AuthService()
    
    init() {
        // Initialize Google Maps SDK
        let config = ConfigLoader.shared
        GMSServices.provideAPIKey(config.googleMapsAPIKey)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onOpenURL { url in
                    // Handle OAuth callback
                    if url.scheme == "fotolokashen" {
                        Task {
                            await authService.handleCallback(url: url)
                        }
                    }
                }
        }
    }
}
