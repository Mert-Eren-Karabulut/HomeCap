// StoreManager.swift
import Foundation
import StoreKit
import SwiftUI // For MainActor

@MainActor // Ensures @Published properties are updated on main thread
class StoreManager: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isLoadingProducts: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: Error? = nil
    // Removed complex didSet, manage error clearing elsewhere
    @Published var showingErrorAlert: Bool = false

    // IMPORTANT: Replace with your actual Product ID
    private let productIDs = ["com.gettwin.HomeCap.premium.monthly"]
    private var transactionListenerTask: Task<Void, Error>? = nil

    // MARK: - Initialization
    init() {
        transactionListenerTask = listenForTransactions()
        Task { await requestProducts() }
        print("StoreManager initialized.")
    }

    deinit {
        transactionListenerTask?.cancel()
        print("StoreManager deinitialized.")
    }

    // MARK: - Public Methods
    func requestProducts() async {
        guard !isLoadingProducts else { return }
        print("Requesting products...")
        isLoadingProducts = true
        purchaseError = nil // Clear error before request
        // showingErrorAlert = false // Don't reset alert here

        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            print("Fetched \(products.count) products.")
        } catch {
            print("Failed to fetch products: \(error)")
            purchaseError = error
            showingErrorAlert = true // Show alert on error
        }
        isLoadingProducts = false
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        print("Attempting to purchase product: \(product.id)")
        isPurchasing = true
        purchaseError = nil // Clear error before purchase
        // showingErrorAlert = false // Don't reset alert here

        do {
            let result = try await product.purchase()
            // --- FIX: Call correct handle method ---
            await handle(purchaseResult: result) // Pass Product.PurchaseResult
        } catch {
            print("Purchase failed: \(error)")
            purchaseError = error
            showingErrorAlert = true // Show alert on error
        }
        isPurchasing = false
    }

    func restorePurchases() async {
        print("Attempting to restore purchases...")
        isPurchasing = true
        purchaseError = nil
        // showingErrorAlert = false

        do {
            try await AppStore.sync()
            print("AppStore.sync() completed.")
            // Optionally show a simple success message if needed (e.g., using a separate @Published var)
        } catch {
            print("Restore purchases failed: \(error)")
            purchaseError = error
            showingErrorAlert = true
        }
         isPurchasing = false
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                 // --- FIX: No MainActor.run needed, handle method is @MainActor ---
                 // --- FIX: Call correct handle method ---
                 await self.handle(transactionVerificationResult: result) // Pass VerificationResult<Transaction>
            }
        }
    }

    // MARK: - Transaction Handling

    /// Processes the result of a purchase attempt (Product.PurchaseResult).
    private func handle(purchaseResult: Product.PurchaseResult) async {
        switch purchaseResult {
        case .success(let verificationResult):
            print("Purchase successful, handling verification result...")
             // --- FIX: Call correct handle method ---
            await handle(transactionVerificationResult: verificationResult) // Pass VerificationResult<Transaction>
        case .pending:
            print("Purchase is pending final confirmation.")
             purchaseError = StoreError.purchasePending // Use custom error
             showingErrorAlert = true
        case .userCancelled:
            print("Purchase cancelled by user.")
            // Clear error state if one was somehow set before cancellation
            purchaseError = nil
            showingErrorAlert = false
        @unknown default:
            print("Unknown purchase result.")
            purchaseError = StoreError.unknownPurchaseError
            showingErrorAlert = true
        }
    }

    /// Processes a verified or unverified transaction (VerificationResult<StoreKit.Transaction>).
    private func handle(transactionVerificationResult result: VerificationResult<StoreKit.Transaction>) async {
        // --- FIX: Explicitly use StoreKit.Transaction ---
        switch result {
        case .unverified(let unverifiedTransaction, let verificationError):
            print("Transaction verification failed: \(verificationError.localizedDescription)")
            purchaseError = verificationError
            showingErrorAlert = true
            await unverifiedTransaction.finish()

        case .verified(let verifiedTransaction):
             // --- FIX: Explicitly use StoreKit.Transaction ---
            print("Transaction verified successfully: ID \(verifiedTransaction.id), ProductID: \(verifiedTransaction.productID)")
            await processVerifiedTransaction(verifiedTransaction)
        }
    }

    /// Sends transaction details to backend for validation and updates local status.
    private func processVerifiedTransaction(_ transaction: StoreKit.Transaction) async { // --- FIX: Explicitly use StoreKit.Transaction ---
        print("Processing verified transaction ID: \(transaction.id), Original ID: \(transaction.originalID)")
        isPurchasing = true // Show loading indicator

        // --- FIX: Call the correct (soon to be added) API method ---
        // Ensure API.swift has this method defined, even if empty for now
        let success = await API.shared.verifySubscription(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID)
        )

        if success {
            print("Backend verification successful for Tx ID: \(transaction.id). Updating purchased status.")
            purchasedProductIDs.insert(transaction.productID)
            purchaseError = nil // Clear any previous error on success
             // Optional: Trigger user profile refresh
             // NotificationCenter.default.post(name: .userSubscriptionStatusDidChange, object: nil)
        } else {
            print("Backend verification failed for Tx ID: \(transaction.id)")
            purchaseError = StoreError.backendVerificationFailed
            showingErrorAlert = true
        }

        print("Finishing transaction ID: \(transaction.id)")
        await transaction.finish()
        isPurchasing = false
    }
}

// --- FIX: Define custom errors ---
enum StoreError: LocalizedError {
    case unknownPurchaseError
    case backendVerificationFailed
    case productNotFound
    case purchasePending // Added

    var errorDescription: String? {
        switch self {
        case .unknownPurchaseError: return "An unknown error occurred during purchase."
        case .backendVerificationFailed: return "Could not verify purchase with our server. Please restore purchases or try again later."
        case .productNotFound: return "Subscription product could not be loaded."
        case .purchasePending: return "Your purchase is pending confirmation from the App Store."
        }
    }
}
