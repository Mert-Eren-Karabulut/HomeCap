import StoreKit
// PaywallView.swift
import SwiftUI

struct PaywallView: View {
    // Access the shared StoreManager instance from the environment
    @EnvironmentObject var storeManager: StoreManager
    // Get dismiss action for closing the sheet
    @Environment(\.dismiss) var dismiss

    // Optional: Access AuthManager if you need to trigger a profile refresh
    // immediately after successful backend verification.
    // @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationView {  // Embed in NavigationView for title and standard close button
            VStack(spacing: 20) {
                Spacer()  // Push content down slightly

                // Header Icon and Text
                Image(systemName: "lock.shield.fill")  // Or "crown.fill", "star.fill" etc.
                    .resizable()
                    .scaledToFit()
                    .frame(height: 70)
                    .foregroundColor(.blue)  // Or your premium color
                    .padding(.bottom, 10)

                Text("HomeCap Premium")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(
                    "Sınırsız daire oluşturma ve tüm premium özelliklere erişim için abone olun."
                )
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom)

                // Check loading state
                if storeManager.isLoadingProducts {
                    ProgressView("Abonelik bilgisi yükleniyor...")
                        .padding(.vertical, 50)
                }
                // Check if product is available
                else if let product = storeManager.products.first {
                    // Display Product Info (extracted to helper)
                    productInfoView(product: product)
                        .padding(.vertical)

                    // Subscribe Button (extracted to helper)
                    purchaseButton(product: product)

                } else {
                    // Error/Empty State
                    Text(
                        "Abonelik seçenekleri şu anda yüklenemedi.\nİnternet bağlantınızı kontrol edin ve tekrar deneyin."
                    )
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    // Optionally add a manual refresh button
                    Button("Tekrar Dene") {
                        Task { await storeManager.requestProducts() }
                    }
                    .buttonStyle(.bordered)
                }

                // Restore Purchases Button (extracted to helper)
                restoreButton()

                Spacer()  // Push legal text and buttons down

                // Legal Text (extracted to helper)
                legalTextView()
                    .padding(.bottom, 20)  // Padding at the very bottom
            }
            .padding(.horizontal)  // Horizontal padding for the main VStack content
            .navigationTitle("Premium'a Geç")  // Set title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            // Alert for purchase errors from StoreManager
            .alert(
                "İşlem Hatası",
                isPresented: $storeManager.showingErrorAlert,
                presenting: storeManager.purchaseError
            ) { error in
                Button("Tamam") {
                    // Reset error state when alert is dismissed
                    storeManager.purchaseError = nil
                    // storeManager.showingErrorAlert = false // This is implicitly handled by isPresented
                }
            } message: { error in
                Text(error.localizedDescription)
            }
            // --- Optional: Auto-dismiss on successful purchase ---
            // This watches the `purchasedProductIDs` set in StoreManager.
            // When the backend confirms a purchase via `processVerifiedTransaction`,
            // it adds the ID to this set, triggering this onChange.
            .onChange(of: storeManager.purchasedProductIDs) { _, newValue in
                guard let purchasedProductID = storeManager.products.first?.id
                else { return }
                if newValue.contains(purchasedProductID) {
                    print(
                        "Paywall detected successful purchase via purchasedProductIDs change. Dismissing."
                    )
                    // Optional: Trigger user profile refresh to get new status from backend
                    // Task { await authManager.refreshUserProfile() } // Requires AuthManager access
                    dismiss()  // Dismiss the paywall sheet
                }
            }
            // --- End Optional ---
        }
        // Ensure StoreManager is available in the environment when this view is presented
        // The presenting view (e.g., UnitEditView) needs to have it in its environment.
    }

    // MARK: - Subviews / Helpers

    @ViewBuilder
    private func productInfoView(product: Product) -> some View {
        VStack(spacing: 8) {
            Text(product.displayName)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(product.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Display price and trial info clearly
            HStack(spacing: 5) {
                // Check specifically for the introductory offer being a free trial
                if let introOffer = product.subscription?.introductoryOffer,
                    introOffer.paymentMode == .freeTrial
                {
                    Text("\(introOffer.displayPrice) ÜCRETSİZ deneyin, sonra")  // e.g., "7 gün ÜCRETSİZ deneyin, sonra"
                        .font(.callout)
                        .foregroundColor(.green.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                // Display the regular price per period
                Text(product.displayPrice)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.top, 5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)  // Use thin material for background
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(  // Add a subtle border
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func purchaseButton(product: Product) -> some View {
        Button {
            Task {
                await storeManager.purchase(product)
            }
        } label: {
            // Show spinner overlayed on text while purchasing
            ZStack {
                // Text is always present but hidden when loading
                // --- FIXED: Check trial via product.subscription ---
                Text(
                    product.subscription?.introductoryOffer?.paymentMode
                        == .freeTrial ? "Ücretsiz Denemeyi Başlat" : "Abone Ol"
                )
                .bold()
                .opacity(storeManager.isPurchasing ? 0 : 1)

                if storeManager.isPurchasing {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                }
            }
            .frame(maxWidth: .infinity)  // Ensure ZStack takes full width for label
        }
        .buttonStyle(.borderedProminent)  // Prominent style
        .controlSize(.large)  // Larger button size
        .disabled(storeManager.isPurchasing)  // Disable while action is in progress
        .padding(.horizontal, 30)  // Adjust padding as needed
    }

    @ViewBuilder
    private func restoreButton() -> some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            // Show spinner inline if restoring
            HStack(spacing: 5) {
                Text("Alımları Geri Yükle")
                if storeManager.isPurchasing {  // Reuse isPurchasing flag for restore too
                    ProgressView().controlSize(.small)
                }
            }
        }
        .buttonStyle(.plain)  // Less prominent
        .disabled(storeManager.isPurchasing)  // Disable during any purchase/restore
        .padding(.top, 5)
    }

    @ViewBuilder
    private func legalTextView() -> some View {
        VStack(spacing: 5) {
            // Standard Apple legal text for auto-renewable subscriptions
            Text(
                "Abonelikler, mevcut dönemin bitiminden en az 24 saat önce App Store hesap ayarlarınızdan iptal edilmediği sürece otomatik olarak yenilenir. Ödeme, satın alma onayı ile App Store hesabınızdan tahsil edilir."
            )
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            HStack(spacing: 20) {
                // Replace with your actual URLs
                Link(
                    "Mesafeli Satış Sözleşmesi",
                    destination: URL(string: "https://gettwin.io/mesafeli-satis")!
                )
                Link(
                    "Gizlilik Politikası",
                    destination: URL(string: "https://gettwin.io/gizlilik-politikasi")!
                )
            }
            .font(.caption)
        }
        .padding(.horizontal, 10)  // Padding around legal text
    }
}

// MARK: - Preview

#Preview {
    // Create a dummy StoreManager for preview purposes
    // You might need to add mock products for the preview to show more detail
    PaywallView()
        .environmentObject(StoreManager())
}
