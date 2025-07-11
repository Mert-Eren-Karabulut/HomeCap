// HomeCapApp.swift
import SwiftUI

@main
struct HomeCapApp: App {
    @StateObject private var authManager = AuthManager()
    @AppStorage("hasCompletedWalkthrough") var hasCompletedWalkthrough: Bool = false

    var body: some Scene {
        WindowGroup {
            if !hasCompletedWalkthrough {
                WalkthroughView()
            } else if authManager.isLoggedIn {
                MainTabView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
