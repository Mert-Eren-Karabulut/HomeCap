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

    @State private var isDeletingAccount = false
    @State private var showingWalkthroughSheet = false
    @State private var showingPasswordSheet = false
    @State private var deletionErrorItem: IdentifiableMessage? = nil

    var body: some View {
        List {
            Section("Yardım") {
                Button("Nasıl Kullanılır?") {
                    showingWalkthroughSheet = true
                }
            }

            Section {
                Button("Çıkış Yap") {
                    authManager.logOut()
                }
            }

            Section {
                Button("Hesabımı Sil", role: .destructive) {
                    isDeletingAccount = false
                    showingPasswordSheet = true
                }
                .disabled(isDeletingAccount)
            }

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
        .alert(item: $deletionErrorItem) { errorItem in
            Alert(
                title: Text("Hesap Silme Hatası"),
                message: Text(errorItem.message),
                dismissButton: .default(Text("Tamam"))
            )
        }
        .sheet(isPresented: $showingPasswordSheet) {
            PasswordPromptSheet { confirmedPassword in
                Task {
                    await deleteAccountAction(password: confirmedPassword)
                }
            }
        }
        .sheet(isPresented: $showingWalkthroughSheet) {
            WalkthroughView()
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
