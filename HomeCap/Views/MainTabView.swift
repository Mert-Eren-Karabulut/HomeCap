//
//  MainTabView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 29.04.2025.
//


// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .anasayfa // Default tab

    // Enum to represent tabs for type safety
    enum Tab {
        case anasayfa, modeller, daireler, ayarlar
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Anasayfa (Home)
            NavigationStack { // Each tab gets its own Navigation Stack
                HomeView() // Renamed from DashboardView
            }
            .tabItem {
                Label("Anasayfa", systemImage: "house.fill")
            }
            .tag(Tab.anasayfa)

            // Tab 2: Modeller (Models)
            NavigationStack {
                ModelsView() // New View for scans/models
            }
            .tabItem {
                Label("Modeller", systemImage: "cube.box.fill")
            }
            .tag(Tab.modeller)

            // Tab 3: Daireler (Units)
            NavigationStack {
                UnitsListView() // New View for units
            }
            .tabItem {
                Label("Daireler", systemImage: "building.2.fill")
            }
            .tag(Tab.daireler)

            // Tab 4: Ayarlar (Settings)
            NavigationStack {
                SettingsView() // New View for settings
            }
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
            .tag(Tab.ayarlar)
        }
         // Pass AuthManager down if needed by child views (e.g., SettingsView)
         // .environmentObject(AuthManager.shared) // If using shared instance
         // Or rely on it being passed from HomeCapApp
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager()) // Provide for preview
}