//
//  LoginView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 18.04.2025.
//

import Combine
import Foundation
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    // --- YENİ --- SSS sayfasını göstermek için state
    @State private var showingFAQSheet = false

    var body: some View {
        NavigationStack {
            // --- DEĞİŞTİRİLDİ --- ScrollView ekleyerek küçük ekranlarda taşmayı önle
            ScrollView {
                VStack(spacing: 32) {

                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 32)
                        .frame(width: 150, height: 150)

                    Text("HomeCap")
                        .font(.largeTitle).bold()

                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        SecureField("Şifre", text: $password) // Türkçe placeholder
                            .textContentType(.password)
                            .padding()
                            .background(.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    Button("Giriş Yap") { // Türkçe buton metni
                        authManager.logIn(email: email, password: password) {
                            error in
                            if let err = error {
                                errorMessage = err.localizedDescription
                                showingError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    // --- YENİ --- Giriş yap butonu için minimum genişlik ve dolgu
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal) // Butonun kenarlara yapışmasını önle

                    HStack {
                        Text("Hesabınız yok mu?") // Türkçe metin
                        NavigationLink(destination: RegisterView()) {
                            Text("Kayıt Ol") // Türkçe metin
                        }
                    }

                    Spacer() // İçeriği yukarı iter

                    // --- YENİ --- SSS Bağlantısı
                    Button("Sıkça Sorulan Sorular") {
                        showingFAQSheet = true // Sayfayı göstermek için state'i değiştir
                    }
                    .font(.footnote) // Daha küçük font
                    .foregroundColor(.blue) // Mavi renk
                    .padding(.bottom) // Altına biraz boşluk ekle

                } // Ana VStack sonu
                // --- DEĞİŞTİRİLDİ --- ScrollView içeriğinin altına padding ekle
                .padding(.bottom)

            } // ScrollView sonu
            .alert("Hata", isPresented: $showingError) { // Türkçe başlık
                Button("Tamam") {} // Türkçe buton
            } message: {
                Text(errorMessage)
            }
            // --- YENİ --- SSS sayfasını göstermek için .sheet modifier
            .sheet(isPresented: $showingFAQSheet) {
                FAQSheetView() // Oluşturduğumuz SSS sayfasını göster
            }
            .navigationTitle("Giriş Yap") // Türkçe başlık
            .navigationBarTitleDisplayMode(.inline)
             // --- YENİ --- Dışarı tıklayınca klavyeyi kapat
            .onTapGesture {
                 hideKeyboard()
            }
        } // NavigationStack sonu
    } // body sonu

     // --- YENİ --- Klavyeyi kapatma yardımcısı
     private func hideKeyboard() {
         UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
     }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
