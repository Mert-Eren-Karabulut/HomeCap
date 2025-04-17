//
//  PasswordPromptSheet.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 3.05.2025.
//


// PasswordPromptSheet.swift
import SwiftUI

struct PasswordPromptSheet: View {
    @Environment(\.dismiss) var dismiss // To close the sheet
    @State private var enteredPassword = "" // Local state for the input

    // Closure to call when the user confirms with the password
    let onConfirm: (String) -> Void

    var body: some View {
        NavigationView { // Use NavigationView for title and standard dismissal
            VStack(alignment: .leading, spacing: 20) {
                Text("Hesabınızı kalıcı olarak silmek üzeresiniz. Hesabınıza bağlı bütün daire ve modeller silinecek. Bu işlem geri alınamaz.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom)

                Text("Devam etmek için mevcut şifrenizi girin:")
                    .font(.headline)

                SecureField("Mevcut Şifre", text: $enteredPassword)
                    .padding(12)
                    .background(Color(.secondarySystemBackground)) // Adapts to light/dark
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .keyboardType(.default) // Standard keyboard

                Spacer() // Pushes buttons down

                HStack {
                    Button("İptal", role: .cancel) {
                        dismiss() // Close the sheet without action
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("Hesabı Sil") { // Confirmation button
                        // Basic check if password is empty before confirming
                        if !enteredPassword.isEmpty {
                            onConfirm(enteredPassword) // Pass the password back
                            dismiss() // Close the sheet
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red) // Make confirmation destructive
                    .frame(maxWidth: .infinity)
                    .disabled(enteredPassword.isEmpty) // Disable if password is empty
                }
            }
            .padding()
            .navigationTitle("Şifrenizi Onaylayın")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Add explicit close button if needed, though swipe down works
                     Button("Kapat") { dismiss() }
                }
            }
             // Dismiss keyboard on tap outside text field
             .onTapGesture {
                  hideKeyboard()
             }
        }
    }

    // Helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Preview Provider
#Preview {
    PasswordPromptSheet { password in
        print("Preview Confirmed with password: \(password)")
    }
}
