//
//  SettingsView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 29.04.2025.
//

import StoreKit
// SettingsView.swift
import SwiftUI
import UIKit

// Helper struct for identifiable Error
struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}

// --- NEW: Helper struct for identifiable String messages ---
struct IdentifiableMessage: Identifiable {
    let id = UUID()
    let message: String
}
// --- END NEW ---

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager

    // State for account deletion flow
    @State private var isDeletingAccount = false

    @State private var showingWalkthroughSheet = false
    @State private var showingPasswordSheet = false
    @State private var manageSubErrorItem: IdentifiableError? = nil
    @State private var deletionErrorItem: IdentifiableMessage? = nil

    var body: some View {
        // Keep NavigationStack provided by MainTabView
        List {  // Use List for standard settings layout
            Section("Yardım") {  // Section title "Help"
                Button("Nasıl Kullanılır?") {
                    showingWalkthroughSheet = true  // Set state to show the sheet
                }
            }

            Section("Abonelik") {
                // Optional: Display current status fetched from backend
                if let user = authManager.currentUser {  // Ensure user exists
                    HStack {
                        Text("Mevcut Durum:")
                        Spacer()
                        Text(displayTier(user.subscriptionTier))  // Use helper
                            .foregroundColor(.secondary)
                    }
                }

                Button("Aboneliği Yönet") {
                    manageSubscriptions()
                }
            }

            Section {
                Button("Çıkış Yap") {
                    authManager.logOut()
                }
            }

            Section {
                Button("Hesabımı Sil", role: .destructive) {
                    // Reset state and show the password SHEET
                    isDeletingAccount = false  // Ensure progress view is hidden initially
                    showingPasswordSheet = true  // Trigger the sheet presentation
                }
                .disabled(isDeletingAccount)  // Disable if already deleting
            }

            // Show progress indicator while deleting
            if isDeletingAccount {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Hesap siliniyor...")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Ayarlar")
        .alert(item: $manageSubErrorItem) { errorItem in  // errorItem is the non-nil IdentifiableError
            Alert(
                title: Text("Hata"),
                message: Text(
                    "Abonelik yönetimi sayfası açılamadı: \(errorItem.error.localizedDescription)"
                ),
                dismissButton: .default(Text("Tamam")) {
                    // Action on dismiss if needed, like clearing the state
                    // manageSubErrorItem = nil // State is automatically set to nil on dismiss
                }
            )
        }
        // Error Alert for Deletion Failure
        .alert(item: $deletionErrorItem) { errorItem in  // Binds to Optional<IdentifiableMessage>
            Alert(
                title: Text("Hesap Silme Hatası"),
                message: Text(errorItem.message),  // Display the message from the item
                dismissButton: .default(Text("Tamam"))
            )
        }
        .sheet(isPresented: $showingPasswordSheet) {
            PasswordPromptSheet { confirmedPassword in
                // This closure is called when the user taps "Sil Onayla" in the sheet
                // Directly call the async action with the received password
                Task {
                    await deleteAccountAction(password: confirmedPassword)
                }
            }
            // Optional: Set sheet size if desired
            // .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showingWalkthroughSheet) {
            WalkthroughView()  // Present the walkthrough view modally
        }

        // --- Alternative: Trigger a Sheet for Password Input ---
        /*
        .sheet(isPresented: $showingPasswordSheet) {
             PasswordPromptSheet(password: $passwordForDelete) { confirmedPassword in
                  // Callback when password entered in sheet
                  if !confirmedPassword.isEmpty {
                       Task {
                            await deleteAccountAction(password: confirmedPassword)
                       }
                  }
             }
        }
        // Replace Button action with: showingPasswordSheet = true
        // Requires creating PasswordPromptSheet view
        */
    }

    // --- Action to Delete Account ---
    // Note: Needs password handling improvement (e.g., using a Sheet)
    private func deleteAccountAction(password: String) async {
        guard !password.isEmpty else {
            // Set the identifiable error item
            deletionErrorItem = IdentifiableMessage(
                message: "Şifre alanı boş bırakılamaz."
            )
            return
        }
        isDeletingAccount = true
        deletionErrorItem = nil  // Clear previous error

        await authManager.deleteAccount(password: password) { result in
            isDeletingAccount = false
            switch result {
            case .success:
                print("Account deletion success handled by AuthManager logout.")
            case .failure(let error):
                print("Account deletion failed in SettingsView: \(error)")
                var errorMessage: String
                if let nsError = error as NSError?,
                    nsError.code == 422
                        || error.localizedDescription.lowercased().contains(
                            "password"
                        )
                {
                    errorMessage = "Girilen şifre yanlış."
                } else {
                    errorMessage =
                        "Hesap silinemedi: \(error.localizedDescription)"
                }
                // Set the identifiable error item
                deletionErrorItem = IdentifiableMessage(message: errorMessage)
            }
        }
    }

    func manageSubscriptions() {
            manageSubErrorItem = nil
            Task {
                // --- NEW: Get WindowScene manually ---
                // Find the first active foreground scene that is a UIWindowScene
                let windowScene = await UIApplication.shared.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .first(where: { $0 is UIWindowScene })
                    as? UIWindowScene
                // --- END NEW ---

                guard let scene = windowScene else {
                    print("Window scene could not be retrieved.")
                    manageSubErrorItem = IdentifiableError(error: NSError(domain: "SettingsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Aktif pencere (scene) bulunamadı."]))
                    return
                }

                // Continue with presenting the sheet
                do {
                    try await AppStore.showManageSubscriptions(in: scene)
                    print("Opened manage subscriptions sheet.")
                } catch {
                    print("Failed to show manage subscriptions sheet: \(error)")
                    manageSubErrorItem = IdentifiableError(error: error)
                }
            }
        }
    
    func displayTier(_ tier: String?) -> String {
        switch tier?.lowercased() {
        case "premium": return "Premium"
        case "trial": return "Deneme Süresi"
        case "free": return "Ücretsiz"
        default: return "Bilinmiyor"
        }
    }

}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager())
    }
}
