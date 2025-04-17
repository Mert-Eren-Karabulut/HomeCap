//
//  RegisterView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 28.04.2025.
//

import Combine
import Foundation
import SwiftUI
import PDFKit // Import PDFKit for PDF viewing

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager

    // --- Input Fields State ---
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // --- Agreement Checkboxes State ---
    @State private var agreedToKVKK = false
    @State private var agreedToEULA = false

    // --- PDF Presentation State ---
    @State private var pdfURLToShow: PDFDisplayItem? = nil

    // --- Error State ---
    @State private var showingError = false // For general API errors
    @State private var errorMessage = ""

    // --- Helper struct for Identifiable PDF URLs ---
    struct PDFDisplayItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    // --- Validation Computed Properties ---
    var isEmailFormatValid: Bool {
        // Basic email format check using regex
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
        // Only validate if email is not empty
        return email.isEmpty || emailPredicate.evaluate(with: email)
    }

    var isPasswordComplexEnough: Bool {
        // Minimum 8 chars, 1 uppercase, 1 digit, 1 symbol
        // --- MODIFIED --- Added '.' to the allowed symbols list
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", "^(?=.*[A-Z])(?=.*[!@#$&*.,])(?=.*[0-9])(?=.*[a-z]).{8,}$")
        // Explanation of Regex:
        // ^                   Start anchor
        // (?=.*[A-Z])        Must contain at least one uppercase letter
        // (?=.*[!@#$&*.,])   Must contain at least one special symbol (added '.')
        // (?=.*[0-9])        Must contain at least one digit
        // (?=.*[a-z])        Must contain at least one lowercase letter
        // .{8,}              Must contain at least 8 characters
        // $                   End anchor
        // Only validate if password is not empty
        return password.isEmpty || passwordPredicate.evaluate(with: password)
    }

    var doPasswordsMatch: Bool {
        // Only validate if confirmPassword is not empty
        return confirmPassword.isEmpty || (!password.isEmpty && password == confirmPassword)
    }

    // --- MODIFIED --- Computed property to check if registration is allowed
    var canRegister: Bool {
        // Ensure fields are not empty AND all validations pass
        return !name.isEmpty
            && !email.isEmpty && isEmailFormatValid
            && !password.isEmpty && isPasswordComplexEnough
            && !confirmPassword.isEmpty && doPasswordsMatch
            && agreedToKVKK
            && agreedToEULA
    }

    // --- NEW --- Computed properties for specific error messages
    var emailErrorMessage: String? {
        if !email.isEmpty && !isEmailFormatValid {
            return "Geçerli bir email adresi girin."
        }
        return nil
    }

    var passwordErrorMessage: String? {
        if !password.isEmpty && !isPasswordComplexEnough {
            return "Şifre gereksinimleri karşılamıyor." // More specific message below field
        }
        return nil
    }

    var confirmPasswordErrorMessage: String? {
        if !confirmPassword.isEmpty && !doPasswordsMatch {
            return "Şifreler eşleşmiyor."
        }
        return nil
    }


    var body: some View {
        // Wrap content in ScrollView to prevent overflow on smaller screens
        ScrollView {
            VStack(spacing: 20) { // Adjusted spacing slightly
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 32)
                    .frame(width: 150, height: 150)
                Text("HomeCap")
                    .font(.largeTitle).bold()

                // --- Input Fields ---
                VStack(spacing: 16) {
                    TextField("İsim", text: $name) // Using Turkish placeholder from context
                        .textContentType(.name)
                        .keyboardType(.default)
                        .padding()
                        .background(.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // --- Email Field + Error ---
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $email) // Using Turkish placeholder from context
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(emailErrorMessage == nil ? Color.clear : Color.red, lineWidth: 1)
                             )
                        // --- NEW --- Display Email Error
                        if let emailError = emailErrorMessage {
                            Text(emailError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 5)
                        }
                    }


                    // --- Password Field + Requirements + Error ---
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Şifre", text: $password) // Using Turkish placeholder from context
                            .textContentType(.newPassword)
                            .padding()
                            .background(.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(passwordErrorMessage == nil ? Color.clear : Color.red, lineWidth: 1)
                             )

                        // Password requirements text
                        Text("Minimum 8 karakter, en az bir büyük harf, bir rakam ve bir sembol (@!#$&*.,) kullanın.") // Updated symbols
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 5)

                        // --- NEW --- Display Password Complexity Error
                        if let passwordError = passwordErrorMessage {
                             Text(passwordError)
                                 .font(.caption)
                                 .foregroundColor(.red)
                                 .padding(.leading, 5)
                        }
                    }

                    // --- Confirm Password Field + Error ---
                     VStack(alignment: .leading, spacing: 4) {
                        SecureField("Şifreyi Tekrarla", text: $confirmPassword) // Using Turkish placeholder from context
                            .textContentType(.newPassword)
                            .padding()
                            .background(.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(confirmPasswordErrorMessage == nil ? Color.clear : Color.red, lineWidth: 1)
                             )
                         // --- NEW --- Display Password Match Error
                         if let confirmError = confirmPasswordErrorMessage {
                             Text(confirmError)
                                 .font(.caption)
                                 .foregroundColor(.red)
                                 .padding(.leading, 5)
                         }
                    }

                }
                .padding(.horizontal)

                // --- Agreement Checkboxes ---
                VStack(alignment: .leading, spacing: 15) {
                    // KVKK Checkbox
                    HStack(alignment: .top) {
                        Image(systemName: agreedToKVKK ? "checkmark.square.fill" : "square")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(agreedToKVKK ? .blue : .secondary)
                            .onTapGesture {
                                agreedToKVKK.toggle()
                            }

                        (
                            Text("Okudum, onaylıyorum ")
                                .foregroundColor(.secondary)
                            +
                            Text("KVKK Aydınlatma Metni")
                                .foregroundColor(.blue)
                                .underline()
                        )
                        .font(.footnote)
                        .onTapGesture {
                            if let url = Bundle.main.url(forResource: "kvkk", withExtension: "pdf") {
                                pdfURLToShow = PDFDisplayItem(url: url)
                            } else {
                                errorMessage = "KVKK belgesi bulunamadı."
                                showingError = true
                                print("Error: kvkk.pdf not found in bundle.")
                            }
                        }
                    } // End KVKK HStack

                    // EULA Checkbox
                    HStack(alignment: .top) {
                        Image(systemName: agreedToEULA ? "checkmark.square.fill" : "square")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(agreedToEULA ? .blue : .secondary)
                            .onTapGesture {
                                agreedToEULA.toggle()
                            }

                        (
                            Text("Okudum, onaylıyorum ")
                                .foregroundColor(.secondary)
                            +
                            Text("Kullanıcı Sözleşmesi")
                                .foregroundColor(.blue)
                                .underline()
                        )
                        .font(.footnote)
                        .onTapGesture {
                            if let url = Bundle.main.url(forResource: "eula", withExtension: "pdf") {
                                pdfURLToShow = PDFDisplayItem(url: url)
                            } else {
                                errorMessage = "Kullanıcı Sözleşmesi bulunamadı."
                                showingError = true
                                print("Error: eula.pdf not found in bundle.")
                            }
                        }
                    } // End EULA HStack
                }
                .padding(.horizontal)
                // --- End Agreement Checkboxes ---

                // --- Register Button ---
                Button("Kayıt ol") { // Using Turkish text from context
                    authManager.register(
                        name: name,
                        email: email,
                        password: password
                    ) { error in
                        if let err = error {
                            errorMessage = err.localizedDescription
                            showingError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRegister)
                .opacity(canRegister ? 1.0 : 0.6)

                Spacer()
            } // End Main VStack
            .padding(.bottom)
        } // End ScrollView
        .alert("Kayıt Hatası", isPresented: $showingError) { // Using Turkish text from context
            Button("Tamam") {} // Using Turkish text from context
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $pdfURLToShow) { item in
            PDFKitView(pdfURL: item.url)
        }
        .navigationTitle("Kayıt Ol")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
             hideKeyboard()
        }
    } // End body

    // Helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthManager())
    }
}
