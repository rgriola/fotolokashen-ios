//
//  fotolokashenApp.swift
//  fotolokashen
//
//  Created by rgriola on 1/15/26.
//

import SwiftUI

@main
struct fotolokashenApp: App {
    @StateObject private var authService = AuthService()
    
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
