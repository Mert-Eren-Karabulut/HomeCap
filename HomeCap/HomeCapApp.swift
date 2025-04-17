// HomeCapApp.swift
import SwiftUI

@main
struct HomeCapApp: App {
    // Keep existing AuthManager
    @StateObject private var authManager = AuthManager()
    // --- NEW: Instantiate StoreManager ---
    @StateObject private var storeManager = StoreManager()
    // Keep existing walkthrough flag
    @AppStorage("hasCompletedWalkthrough") var hasCompletedWalkthrough: Bool = false

    var body: some Scene {
        WindowGroup {
            // Root view logic
            if !hasCompletedWalkthrough {
                WalkthroughView()
                    // Note: Walkthrough likely doesn't need StoreManager,
                    // but passing it won't hurt if ever needed later.
                    .environmentObject(storeManager)
            } else if authManager.isLoggedIn {
                MainTabView()
                    .environmentObject(authManager)
                    // --- NEW: Pass StoreManager down ---
                    .environmentObject(storeManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
                    // --- NEW: Pass StoreManager down ---
                    .environmentObject(storeManager)
            }
        }
    }
}
