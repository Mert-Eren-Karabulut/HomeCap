//
//  UnitEditView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 29.04.2025.
//

import Foundation
import QRCode
// UnitEditView.swift
import SwiftUI

struct UnitEditView: View {
    // Environment for dismissing the view
    @Environment(\.presentationMode) var presentationMode

    // View Model (using @StateObject for lifecycle)
    @StateObject private var viewModel: UnitEditViewModel

    // --- NEW: Access StoreManager from Environment ---
    @EnvironmentObject var storeManager: StoreManager

    // State for delete confirmation
    @State private var showingDeleteAlert = false
    @State private var itemToShare: ShareItem? = nil
    struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var showingQRCodeSheet = false  // Controls presentation of QRCodeSheetView
    @State private var qrCodeImageData: Data? = nil  // Holds the generated QR data
    @State private var isGeneratingQRCode = false  // Progress indicator

    // Initializer to set up the view model
    init(
        mode: UnitEditViewModel.EditMode,
        unitToEdit: Unit? = nil,
        availableScans: [Scan],
        onListNeedsRefresh: @escaping () -> Void
    ) {
        // Create the ViewModel instance here, passing dependencies
        _viewModel = StateObject(
            wrappedValue: UnitEditViewModel(
                mode: mode,
                unitToEdit: unitToEdit,
                availableScans: availableScans,
                onListNeedsRefresh: onListNeedsRefresh
            )
        )
    }

    var body: some View {
        Form {  // Use Form for standard editing UI elements
            Section("Temel Bilgiler") {
                TextField("Daire Adı", text: $viewModel.name)
                TextField("Adres (Opsiyonel)", text: $viewModel.address)
                VStack(alignment: .leading) {
                    Text("Açıklama (Opsiyonel)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    TextEditor(text: $viewModel.description)
                        .frame(height: 100)  // Give TextEditor some height
                        .overlay(
                            RoundedRectangle(cornerRadius: 5).stroke(
                                Color.gray.opacity(0.3)
                            )
                        )  // Optional border
                }
            }

            Section("Bağlı Model") {
                // Picker requires Identifiable items or using tags explicitly
                Picker(
                    "Taranmış Model Seç",
                    selection: $viewModel.selectedScanId
                ) {
                    Text("Model Yok").tag(Int?.none)  // Explicitly tag nil case
                    ForEach(viewModel.availableScans) { scan in
                        Text(scan.name).tag(Int?(scan.id))  // Tag with optional Int
                    }
                }
                .pickerStyle(.navigationLink)  // Use navigation link style for long lists
                // Show error if scans couldn't be loaded
                if let scanLoadError = viewModel.scanLoadError {
                    Text("Modeller yüklenemedi: \(scanLoadError)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("Dış Bağlantılar") {
                // Use indices to get stable bindings
                ForEach($viewModel.externalLinkSuffixes.indices, id: \.self) {
                    index in
                    HStack {
                        Text("https://")  // Display prefix visually
                            .foregroundColor(.gray)  // Make prefix less prominent
                        TextField(
                            "example.com",
                            text: $viewModel.externalLinkSuffixes[index]
                        )  // Bind to suffix
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        // Add onChange to clean pasted prefixes within existing items
                        .onChange(of: viewModel.externalLinkSuffixes[index]) {
                            _,
                            newValue in
                            viewModel.cleanLinkSuffixInput(
                                newValue,
                                index: index
                            )
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteExternalLink)  // Delete works on suffix array

                // --- Input for new link ---
                HStack {
                    Text("https://")  // Display prefix visually
                        .foregroundColor(.gray)
                    TextField(
                        "Yeni Bağlantı Ekle",
                        text: $viewModel.newLinkSuffix
                    )  // Bind to new suffix state
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    // Add onChange to clean pasted prefixes in the new link field
                    .onChange(of: viewModel.newLinkSuffix) { _, newValue in
                        viewModel.cleanNewLinkSuffixInput(newValue)
                    }
                    .onSubmit {  // Add on submit
                        viewModel.addExternalLink()
                    }

                    Button("Ekle") {
                        viewModel.addExternalLink()
                    }
                    // Disable based on the *suffix* being empty
                    .disabled(
                        viewModel.newLinkSuffix.trimmingCharacters(
                            in: .whitespaces
                        ).isEmpty
                    )
                }
                // --- End Input for new link ---
            }

            // --- Delete Button (Edit Mode Only) ---
            if viewModel.mode == .edit {
                Section("Eylemler") {
                    // --- MODIFIED: Use VStack for vertical layout ---
                    VStack(spacing: 15) {  // Add spacing between button groups
                        // Share URL Button & QR Code Button (only if conditions met)
                        if viewModel.canShareUnit {
                            HStack {  // Keep Share and QR side-by-side
                                Spacer()

                                // Share URL Button
                                Button {
                                    prepareAndShowShareSheet()
                                } label: {
                                    Label(
                                        "Paylaş",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                                .tint(.blue)
                                .disabled(
                                    isGeneratingQRCode || viewModel.isProcessing
                                )  // Disable if generating QR or saving

                                Spacer()

                                // QR Code Button
                                Button {
                                    Task { await generateAndShowQRCode() }
                                } label: {
                                    if isGeneratingQRCode {
                                        ProgressView().frame(height: 20)
                                    } else {
                                        Label("QR Kod", systemImage: "qrcode")
                                    }
                                }
                                .tint(.secondary)
                                .disabled(
                                    isGeneratingQRCode || viewModel.isProcessing
                                )

                                Spacer()
                            }
                            .buttonStyle(.bordered)  // Apply bordered style to this group
                        }  // End if canShareUnit

                        // Delete Button - Centered below the others
                        Button("Daireyi Sil", role: .destructive) {
                            showingDeleteAlert = true
                        }
                        .frame(maxWidth: .infinity, alignment: .center)  // Ensure it's centered
                        .disabled(viewModel.isProcessing || isGeneratingQRCode)  // Also disable if generating QR

                    }  // --- END VStack ---
                }  // End Section
            }
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(viewModel.saveButtonText) {
                    Task {  // Perform save/create in a Task
                        await viewModel.saveOrCreatUnit()
                    }
                }
                // Disable Save/Create button based on ViewModel logic
                .disabled(!viewModel.canSaveChanges)
            }
        }
        .overlay {  // Show processing indicator
            if viewModel.isProcessing {
                VStack {
                    ProgressView(viewModel.processingMessage)
                        .padding()
                        .background(.thickMaterial)
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))  // Dim background slightly
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)  // Prevent interaction during processing
            }
        }
        .alert(
            "Hata",
            isPresented: $viewModel.showErrorAlert,
            presenting: viewModel.errorMessage
        ) { _ in
            Button("OK") { viewModel.errorMessage = nil }  // Clear error on dismiss
        } message: { message in
            Text(message)
        }
        // Delete Confirmation Alert
        .alert("Daireyi Sil", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                Task {
                    await viewModel.deleteThisUnit()
                }
            }
        } message: {
            Text(
                "Bu daireyi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz."
            )
        }
        .onChange(of: viewModel.dismissView) { _, shouldDismiss in
            if shouldDismiss {
                print(
                    "DismissView flag changed to true, dismissing UnitEditView."
                )
                presentationMode.wrappedValue.dismiss()
                // Optional: Reset flag in VM if needed, though usually not necessary
                // as the view disappears.
                // viewModel.dismissView = false
            }
        }
        .sheet(item: $itemToShare) { item in
            // Reuse ActivityView if available, otherwise create inline
            ActivityView(items: [item.url])  // Pass URL in an array
        }
        .sheet(isPresented: $showingQRCodeSheet) {
            // Present the dedicated QR Code sheet view
            QRCodeSheetView(
                qrCodeImageData: qrCodeImageData,
                unitName: viewModel.name  // Pass unit name for context
            )
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            // Present PaywallView and pass the StoreManager from this view's environment
            PaywallView()
                .environmentObject(storeManager)
        }
        .onAppear {
            // Optional: Reload scans if needed, though they are passed in now
            // viewModel.loadAvailableScansIfNeeded()
        }
        // Dismiss keyboard when scrolling starts in the Form
        .scrollDismissesKeyboard(.immediately)
    }

    private func prepareAndShowShareSheet() {
        guard viewModel.canShareUnit, let unitId = viewModel.unitToEdit?.id
        else {
            print("Share conditions not met.")
            // --- FIX: Explicitly use self.viewModel ---
            self.viewModel.errorMessage =
                "Paylaşım bağlantısı oluşturmak için daire adı ve bağlı bir model gereklidir."
            self.viewModel.showErrorAlert = true
            // --- END FIX ---
            return
        }

        let urlString = "https://gettwin.ai/homes/\(unitId)"  // Ensure this is your correct URL structure
        if let url = URL(string: urlString) {
            itemToShare = ShareItem(url: url)
            print("Prepared URL for sharing: \(url.absoluteString)")
        } else {
            print("Error creating share URL from string: \(urlString)")
            // --- FIX: Explicitly use self.viewModel ---
            self.viewModel.errorMessage = "Paylaşım bağlantısı oluşturulamadı."
            self.viewModel.showErrorAlert = true
            // --- END FIX ---
        }
    }

    // Modified function to fix QR Code generation call
    private func generateAndShowQRCode() async {
        guard viewModel.canShareUnit, let unitId = viewModel.unitToEdit?.id
        else {
            print("QR Code generation conditions not met.")
            await MainActor.run {  // Ensure UI updates on main thread
                self.viewModel.errorMessage =
                    "QR Kodu oluşturmak için daire adı ve bağlı bir model gereklidir."
                self.viewModel.showErrorAlert = true
            }
            return
        }

        // Use your specific URL structure
        let urlString = "https://gettwin.ai/homes/\(unitId)"  // Changed back based on your file
        print("Generating QR Code for URL: \(urlString)")

        // Update UI state immediately on main thread before starting async work
        await MainActor.run {
            isGeneratingQRCode = true
            self.viewModel.errorMessage = nil
            qrCodeImageData = nil
        }

        do {
            // --- QR Code Generation using the library ---
            // 1. Create the document
            let doc = try QRCode.Document(
                utf8String: urlString,
                errorCorrection: .high
            )

            // 2. Prepare the logo template (ensure "logo" image is in Assets)
            guard let logoImage = UIImage(named: "logo"),
                let cgLogoImage = logoImage.cgImage
            else {
                // Throw specific error if logo cannot be loaded or cgImage fails
                throw NSError(
                    domain: "QRCodeError",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Logo image 'logo' not found or invalid."
                    ]
                )
            }

            // Define path for the logo (center 30% area)
            // Note: Values are relative to the QR code dimension (0.0 to 1.0)
            let logoRect = CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)
            let logoPath = CGPath(rect: logoRect, transform: nil)

            // Create the logo template
            let logoTemplate = QRCode.LogoTemplate(
                image: cgLogoImage,  // Use the CGImage
                path: logoPath,  // Use the defined path
                inset: 2  // Optional inset within the path (pixels)
            )

            // --- 3. Assign the template to the document ---
            doc.logoTemplate = logoTemplate
            print("Assigned logo template to QR Code document.")
            // --- End Assignment ---

            // 4. Generate the PNG data - WITHOUT the logoTemplate argument here
            // The document now holds the logo information.
            print("Attempting to generate PNG data...")
            let generatedData = try doc.imageData(.png(), dimension: 512)  // Generate 512x512 PNG
            print(
                "QR Code PNG Data generated successfully (\(generatedData.count) bytes)."
            )

            // Update state on Main thread
            await MainActor.run {
                qrCodeImageData = generatedData
                showingQRCodeSheet = true  // Trigger sheet presentation
                isGeneratingQRCode = false
            }

        } catch {
            print("Error generating QR Code: \(error)")
            await MainActor.run {
                self.viewModel.errorMessage =
                    "QR Kodu oluşturulamadı: \(error.localizedDescription)"
                self.viewModel.showErrorAlert = true
                isGeneratingQRCode = false
            }
        }
    }

    // Simple URL validation helper
    private func isValidURL(_ string: String) -> Bool {
        // Basic check for common schemes and presence of "."
        guard let url = URL(string: string),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil,  // Check if host exists
            string.contains(".")  // Check if it contains a dot
        else {
            return false
        }
        return true  // Passes basic checks
    }
}

// MARK: - ViewModel

@MainActor  // Ensure @Published properties are updated on main thread
class UnitEditViewModel: ObservableObject {

    enum EditMode { case create, edit }

    // Dependencies & State
    let mode: EditMode
    let unitToEdit: Unit?  // Original unit for comparison
    let availableScans: [Scan]  // Passed from list view
    private let onListNeedsRefresh: () -> Void  // Callback to refresh list

    // Published properties bound to UI
    @Published var name: String = ""
    @Published var address: String = ""
    @Published var description: String = ""
    @Published var externalLinkSuffixes: [String] = []  // Store only the part AFTER "https://"
    @Published var newLinkSuffix: String = ""  // For adding new links
    @Published var selectedScanId: Int? = nil  // Use optional Int directly
    @Published var newLinkUrl: String = ""  // For adding new links

    // Processing/Error State
    @Published var isProcessing = false
    @Published var processingMessage = "Kaydediliyor..."
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert = false
    @Published var dismissView = false  // Flag to trigger dismissal

    // --- NEW: State to control Paywall presentation ---
    @Published var showPaywall = false

    // Error state for loading scans (if loaded here)
    @Published var scanLoadError: String? = nil

    // Original values for checking changes (Edit mode)
    private var originalName: String = ""
    private var originalAddress: String = ""
    private var originalDescription: String = ""
    private var originalExternalLinkSuffixes: [String] = []
    private var originalSelectedScanId: Int? = nil

    // Computed properties for UI logic
    var navigationTitle: String {
        mode == .create ? "Yeni Daire Oluştur" : "Daireyi Düzenle"
    }

    var saveButtonText: String {
        mode == .create ? "Oluştur" : "Kaydet"
    }

    var isDirty: Bool {
        guard mode == .edit else { return true }  // Always considered "dirty" in create mode until saved
        return name != originalName || address != originalAddress
            || description != originalDescription
            || externalLinkSuffixes != originalExternalLinkSuffixes  // Compare suffixes
            || selectedScanId != originalSelectedScanId
    }

    var canSaveChanges: Bool {
        // Cannot save if processing
        if isProcessing { return false }
        // In create mode, name is required
        if mode == .create {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        // In edit mode, changes must have been made
        return isDirty
    }

    var canShareUnit: Bool {
        // Must be in edit mode, have a unit, a non-empty name, and an associated scan ID
        return mode == .edit && unitToEdit != nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedScanId != nil
    }

    // Initializer
    init(
        mode: EditMode,
        unitToEdit: Unit? = nil,
        availableScans: [Scan],
        onListNeedsRefresh: @escaping () -> Void
    ) {
        self.mode = mode
        self.unitToEdit = unitToEdit
        self.availableScans = availableScans  // Use passed scans
        self.onListNeedsRefresh = onListNeedsRefresh

        if let unit = unitToEdit, mode == .edit {
            // Populate fields for editing
            self.name = unit.name
            self.address = unit.address ?? ""
            self.description = unit.description ?? ""
            self.externalLinkSuffixes = unit.safeExternalLinks.map {
                stripPrefix($0)
            }
            self.selectedScanId = unit.scanId

            // Store original values
            self.originalName = unit.name
            self.originalAddress = unit.address ?? ""
            self.originalDescription = unit.description ?? ""
            self.originalExternalLinkSuffixes = self.externalLinkSuffixes
            self.originalSelectedScanId = unit.scanId
        }
        print(
            "UnitEditViewModel initialized. Mode: \(mode). Unit ID: \(unitToEdit?.id ?? -1)"
        )
    }

    // MARK: - Actions

    /// Adds the `newLinkSuffix` to the list after cleaning and prefixing.
    func addExternalLink() {
        let cleanedSuffix = stripPrefix(newLinkSuffix)  // Clean potential pasted prefix
        guard !cleanedSuffix.isEmpty else { return }
        // Append the cleaned suffix (without prefix) to our state array
        externalLinkSuffixes.append(cleanedSuffix)
        newLinkSuffix = ""  // Clear input field
    }

    /// Deletes a link suffix at the specified offsets.
    func deleteExternalLink(at offsets: IndexSet) {
        externalLinkSuffixes.remove(atOffsets: offsets)
    }

    /// Handles changes in a link suffix TextField, cleaning pasted prefixes.
    func cleanLinkSuffixInput(_ suffix: String, index: Int) {
        let cleaned = stripPrefix(suffix)
        if cleaned != suffix {  // Update only if cleaning occurred
            externalLinkSuffixes[index] = cleaned
        }
    }
    /// Handles changes in the new link suffix TextField, cleaning pasted prefixes.
    func cleanNewLinkSuffixInput(_ suffix: String) {
        let cleaned = stripPrefix(suffix)
        if cleaned != suffix {  // Update only if cleaning occurred
            newLinkSuffix = cleaned
        }
    }

    // --- MODIFIED: saveOrCreatUnit ---
    func saveOrCreatUnit() async {  // Changed to async as API call might be async now
        guard canSaveChanges else { return }

        isProcessing = true
        processingMessage =
            (mode == .create) ? "Oluşturuluyor..." : "Kaydediliyor..."
        errorMessage = nil
        showErrorAlert = false  // Reset error alert
        showPaywall = false  // Reset paywall state
        // dismissView = false // Reset dismiss view state? Typically only set true on success.

        let fullExternalLinks = externalLinkSuffixes.map { "https://\($0)" }
            .filter {
                !$0.replacingOccurrences(of: "https://", with: "").isEmpty
            }

        // Prepare data payload
        var payload: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),  // Trim whitespace
            "address": address.isEmpty ? NSNull() : address,
            "description": description.isEmpty ? NSNull() : description,
            "external_links": fullExternalLinks.isEmpty
                ? NSNull() : fullExternalLinks,
            "scan_id": selectedScanId == nil ? NSNull() : selectedScanId!,  // Explicitly use NSNull if nil
        ]

        print("API Payload: \(payload)")

        if mode == .create {
            // Use the API method with the specific Error type
            API.shared.createUnit(unitData: payload) { result in  // Result<Unit, APIError>
                // Ensure UI updates are on main thread
                DispatchQueue.main.async {
                    self.handleAPIResult(
                        result: result,
                        successMessage: "Daire başarıyla oluşturuldu."
                    )
                }
            }
        } else if let unitId = unitToEdit?.id {
            // Assuming updateUnit also needs APIError handling eventually
            // For now, keep original or update similarly if needed
            API.shared.updateUnit(unitId: unitId, unitData: payload) {
                result in  // Assuming Result<Unit, Error> for now
                DispatchQueue.main.async {
                    // Use a temporary handler or update handleAPIResult if updateUnit changes error type
                    self.isProcessing = false
                    switch result {
                    case .success(let unit):
                        print("Daire başarıyla güncellendi. ID: \(unit.id)")
                        self.onListNeedsRefresh()
                        self.dismissView = true
                    case .failure(let error):
                        print("API Error (Update): \(error)")
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                    }
                }
            }
        } else {
            errorMessage =
                "Bilinmeyen hata: Düzenlenecek daire ID'si bulunamadı."
            showErrorAlert = true
            isProcessing = false
        }
    }

    func deleteThisUnit() async {
        guard mode == .edit, let unitId = unitToEdit?.id else { return }

        isProcessing = true
        processingMessage = "Siliniyor..."
        errorMessage = nil
        dismissView = false

        API.shared.deleteUnit(unitId: unitId) { result in
            self.isProcessing = false
            switch result {
            case .success:
                print("Unit \(unitId) deleted successfully.")
                self.onListNeedsRefresh()  // Trigger refresh in parent
                self.dismissView = true  // Signal dismissal
            case .failure(let error):
                print("Failed to delete unit \(unitId): \(error)")
                self.errorMessage =
                    "Silme işlemi başarısız oldu: \(error.localizedDescription)"
                self.showErrorAlert = true
            }
        }
    }

    private func handleAPIResult(
        result: Result<Unit, APIError>,
        successMessage: String
    ) {  // Takes APIError
        isProcessing = false
        switch result {
        case .success(let unit):
            print("\(successMessage) ID: \(unit.id)")
            onListNeedsRefresh()
            dismissView = true
        case .failure(let error):
            // --- Check for the specific subscription error ---
            if case .subscriptionRequired = error {
                print(
                    "Subscription required error caught in ViewModel. Triggering paywall."
                )
                errorMessage = nil  // Don't show generic error alert for this case
                showErrorAlert = false
                showPaywall = true  // << TRIGGER PAYWALL SHEET >>
            } else {
                // Handle other APIErrors
                print("API Error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription  // Use localized description from APIError
                showErrorAlert = true
                showPaywall = false  // Ensure paywall isn't shown for other errors
            }
        // --- End Check ---
        }
    }

    /// Removes "http://" or "https://" from the beginning of a string.
    private func stripPrefix(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "://") {
            return String(trimmed[range.upperBound...])
        }
        return trimmed  // Return original (trimmed) if no prefix found
    }

    // Optional: Function to load scans if not passed via init
    /*
    func loadAvailableScansIfNeeded() {
        guard availableScans.isEmpty else { return } // Only load if empty
        print("Loading available scans for picker...")
        scanLoadError = nil
        // Indicate loading specific to scans if needed
        // isProcessing = true
        API.shared.fetchUnitsAndScans { result in // Reuse fetchUnitsAndScans
             // isProcessing = false
             switch result {
             case .success(let data):
                 self.availableScans = data.scans.sorted { $0.id > $1.id }
                 print("Loaded \(self.availableScans.count) scans for picker.")
             case .failure(let error):
                 print("Failed to load scans for picker: \(error)")
                 self.scanLoadError = error.localizedDescription
             }
        }
    }
    */

}

#Preview {
    // Preview for Creating
    NavigationView {
        UnitEditView(
            mode: .create,
            availableScans: [
                Scan(
                    id: 1,
                    name: "Oturma Odası",
                    modelPath: "/path1.glb",
                    createdAt: "2025-01-01T10:00:00Z",
                    latitude: "37.7749",
                    longitude: "-122.4194",
                ),
                Scan(
                    id: 2,
                    name: "Mutfak",
                    modelPath: "/path2.glb",
                    createdAt: "2025-01-02T11:00:00Z",
                    latitude: "37.7749",
                    longitude: "-122.4194",
                ),
            ],
            onListNeedsRefresh: { print("Preview: List refresh triggered") }
        )
    }
    .previewDisplayName("Create Unit")

    // Preview for Editing
    NavigationView {
        UnitEditView(
            mode: .edit,
            unitToEdit: Unit(
                id: 10,
                scanId: 1,
                name: "Mevcut Daire",
                description: "Test açıklaması",
                address: "Test Adres",
                externalLinks: ["https://example.com"]
            ),
            availableScans: [
                Scan(
                    id: 1,
                    name: "Oturma Odası",
                    modelPath: "/path1.glb",
                    createdAt: "2025-01-01T10:00:00Z",
                    latitude: "37.7749",
                    longitude: "-122.4194",
                ),
                Scan(
                    id: 2,
                    name: "Mutfak",
                    modelPath: "/path2.glb",
                    createdAt: "2025-01-02T11:00:00Z",
                    latitude: "37.7749",
                    longitude: "-122.4194",
                ),
            ],
            onListNeedsRefresh: { print("Preview: List refresh triggered") }
        )
    }
    .previewDisplayName("Edit Unit")
}
