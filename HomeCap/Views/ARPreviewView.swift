import SwiftUI
import SceneKit // Keep for scaleUSDZ used by working AR path
import WebKit // Import WebKit for WebView

struct ARPreviewView: View {
    // Environment for dismissing the view
    @Environment(\.presentationMode) var presentationMode
    let scan: Scan
    var onScanDeleted: (() -> Void)?  // Callback for parent view

    // State variables from the working AR version
    @State private var isLoading = false // Renamed back to 'isLoading' as in the working AR version
    @State private var errorMessage: String? = nil
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false

    // --- NEW: State to track WebView dragging ---
    @State private var isWebViewDragging: Bool = false

    // Computed property to check if a model path exists
    private var hasValidModelPath: Bool {
        guard let path = scan.modelPath, !path.isEmpty else { return false }
        return true
    }

    // --- NEW: Computed property for the WebView URL ---
    private var webViewURL: URL? {
        // Ensure scan.id is an Int as expected by the URL structure
        return URL(string: "https://gettwin.ai/models/\(scan.id)")
    }


    // MARK: - Body
    var body: some View {
        // --- MODIFIED: Add ScrollView and scrollDisabled ---
        ScrollView {
            VStack(spacing: 20) {
                Text("\(scan.name)")
                    .font(.title)
                    .padding(.top) // Added padding like in WebView version

                AddressTextView(latitudeString: scan.latitude, longitudeString: scan.longitude)

                // --- NEW: WebView Section ---
                if let url = webViewURL {
                    WebView(url: url) // Assumes simplified WebView.swift is used
                         .frame(height: 350) // Adjust height as desired
                         .clipShape(RoundedRectangle(cornerRadius: 10))
                         .overlay(
                              RoundedRectangle(cornerRadius: 10)
                                   .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                         )
                         .padding(.vertical)
                         .contentShape(Rectangle()) // Define hit area for gesture
                         .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in if !isWebViewDragging { isWebViewDragging = true; print("WebView drag gesture started (SwiftUI).") } }
                                .onEnded { _ in DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isWebViewDragging = false; print("WebView drag gesture ended (SwiftUI).") } }
                         )
                } else {
                     // Placeholder if URL couldn't be constructed
                     VStack {
                          Image(systemName: "link.circle.fill")
                               .font(.largeTitle).foregroundColor(.secondary)
                          Text("Önizleme URL'si oluşturulamadı.")
                               .font(.footnote).foregroundColor(.secondary)
                     }
                     .frame(height: 350)
                     .frame(maxWidth: .infinity)
                     .background(Color(uiColor: .secondarySystemBackground))
                     .clipShape(RoundedRectangle(cornerRadius: 10))
                     .padding(.vertical)
                }
                // --- END: WebView Section ---


                // --- AR Preview Button (From working AR version) ---
                if hasValidModelPath {
                    Button {
                        // Use Task for async operation
                        Task {
                            self.errorMessage = nil
                            self.isLoading = true // Use 'isLoading' state variable
                            if let url = scan.modelURL {
                                // Call the async preparation function
                                await prepareAndDownloadForPreview(originalURL: url)
                            }
                            // isLoading is set to false within downloadModelDataAndPresent
                        }
                    } label: {
                        Label("Ortamda Görüntüle", systemImage: "arkit")
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)  // Disable while loading AR

                    if isLoading {
                        ProgressView("Model Yükleniyor")  // Original text
                    }
                    // --- MOVED Error display below delete button ---
                } else {
                    Text("Modelde bir sorun var")
                        .foregroundColor(.orange)
                        .padding(.top)
                }
                // --- END AR Preview Button ---

                Spacer() // Pushes delete button down

                // --- Delete Button (Keep as is) ---
                Button("Modeli Sil", role: .destructive) {
                    showingDeleteAlert = true
                }
                .padding(.horizontal)
                .buttonStyle(.bordered)
                .disabled(isLoading || isDeleting) // Disable if loading AR or deleting

                if isDeleting {
                    ProgressView("Siliniyor...")
                        .padding(.top, 5)
                }
                // --- END Delete Button ---

                // --- Error Message Display (Moved here for consistent layout) ---
                if let errorMsg = errorMessage {
                    Text("Error: \(errorMsg)") // Use original format
                        .foregroundColor(.red)
                        .padding() // Add padding around error
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // --- END Error Message Display ---


            } // End VStack
            .padding(.horizontal) // Apply horizontal padding to VStack content
            .padding(.bottom) // Apply bottom padding to VStack content

        } // End ScrollView
        .scrollDisabled(isWebViewDragging) // Apply scroll disabling based on state
        .navigationTitle("Model Önizleme") // Use original title
        .navigationBarTitleDisplayMode(.inline)
        .alert("Modeli Sil", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) { Task { await deleteThisScan() } }
        } message: { Text("Bu modeli silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.") }
    }

    // --- Delete Scan Function (Keep as is from working AR version) ---
    private func deleteThisScan() async {
        isDeleting = true
        errorMessage = nil
        print("Attempting to delete scan ID: \(scan.id)")
        API.shared.deleteScan(scanId: scan.id) { result in
            DispatchQueue.main.async {
                isDeleting = false
                switch result {
                case .success:
                    print("Scan \(scan.id) deleted successfully via API.")
                    onScanDeleted?()
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    print("Failed to delete scan \(scan.id): \(error)")
                    errorMessage = "Silme başarısız: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Helper Functions for AR Quick Look

    // --- RESTORED: Original prepareAndDownloadForPreview function ---
    private func prepareAndDownloadForPreview(originalURL: URL) async {
        var usdzURL = originalURL
        let path = originalURL.path
        if path.lowercased().hasSuffix(".glb") {
            if let range = path.range(of: ".glb", options: [.caseInsensitive, .backwards]) {
                var modifiedPath = path; modifiedPath.replaceSubrange(range, with: ".usdz")
                var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false); components?.path = modifiedPath
                if let newURL = components?.url { usdzURL = newURL }
                else { await MainActor.run { self.errorMessage = "Could not create USDZ URL."; self.isLoading = false }; return }
            } else { await MainActor.run { self.errorMessage = "Could not modify path extension."; self.isLoading = false }; return }
        } else if !path.lowercased().hasSuffix(".usdz") { print("Warning: Model path does not end with .glb or .usdz: \(path). Attempting to load anyway.") }
        print("Attempting to download USDZ from: \(usdzURL.absoluteString)")
        await downloadModelDataAndPresent(remoteURL: usdzURL)
    }
    // --- END RESTORED ---


    // --- RESTORED: Original downloadModelDataAndPresent function ---
    private func downloadModelDataAndPresent(remoteURL: URL) async {
        do {
            print("Starting data download...")
            let (downloadedData, response) = try await URLSession.shared.data(from: remoteURL)
            print("Data download finished.")
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw NSError(domain: "DownloadError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(statusCode)). Check file at \(remoteURL.absoluteString)"])
            }
            print("HTTP Response OK (\(httpResponse.statusCode)). Data size: \(downloadedData.count) bytes.")
            let fileManager = FileManager.default; let tempDir = fileManager.temporaryDirectory
            let originalFileURL = tempDir.appendingPathComponent(remoteURL.lastPathComponent)
            print("Attempting to write original data to: \(originalFileURL.path)")
            if fileManager.fileExists(atPath: originalFileURL.path) { try fileManager.removeItem(at: originalFileURL) }
            try downloadedData.write(to: originalFileURL); print("Original file successfully written.")
            print("Starting scaling step...")
            let scaledFileURL = try await scaleUSDZ(inputFileURL: originalFileURL, scaleFactor: 0.03)
            print("Scaling complete. Scaled file at: \(scaledFileURL.path)")
            await MainActor.run {
                if let rootVC = UIViewController.findRootViewController() {
                    print("Presenting scaled file: \(scaledFileURL.lastPathComponent)")
                    rootVC.presentQLPreview(url: scaledFileURL)
                    try? fileManager.removeItem(at: originalFileURL); print("Cleaned up original file: \(originalFileURL.lastPathComponent)")
                    Task { try? await Task.sleep(for: .seconds(10)); print("Attempting to clean up AR scaled temp file: \(scaledFileURL.path)"); try? fileManager.removeItem(at: scaledFileURL) }
                } else {
                    print("Error: Could not find root view controller."); self.errorMessage = "Could not display preview."
                    try? fileManager.removeItem(at: originalFileURL); try? fileManager.removeItem(at: scaledFileURL)
                }
                self.isLoading = false // Use 'isLoading'
            }
        } catch {
            print("Error during download/scaling/presentation: \(error)")
            await MainActor.run { self.errorMessage = "Failed to prepare preview: \(error.localizedDescription)"; self.isLoading = false } // Use 'isLoading'
        }
    }
    // --- END RESTORED ---


    // --- RESTORED: Original scaleUSDZ function ---
    private func scaleUSDZ(inputFileURL: URL, scaleFactor: Float) async throws -> URL {
        print("Starting scaling process (v2 - scaling child nodes) for: \(inputFileURL.lastPathComponent)")
        let scene = try SCNScene(url: inputFileURL, options: [.checkConsistency: true])
        print("Scene loaded successfully.")
        print("Applying scale factor \(scaleFactor) to \(scene.rootNode.childNodes.count) direct child nodes...")
        let scaleVector = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        for childNode in scene.rootNode.childNodes { childNode.scale = scaleVector }
        let fileManager = FileManager.default; let tempDir = fileManager.temporaryDirectory
        let outputFileName = "scaled_\(UUID().uuidString)_\(inputFileURL.lastPathComponent)"
        let outputURL = tempDir.appendingPathComponent(outputFileName)
        print("Preparing output URL: \(outputURL.path)")
        print("Attempting to write scaled scene...")
        do {
            let writeOptions: [String: Any] = [:] // Use String keys if preferred
            _ = try await scene.write(to: outputURL, options: writeOptions, delegate: nil)
            print("Scaled scene successfully written to: \(outputURL.path)")
            return outputURL
        } catch {
            print("-----------------------------------------")
            print("Error exporting scaled USDZ via SceneKit: \(error.localizedDescription)")
            let nsError = error as NSError; print("Error Domain: \(nsError.domain), Code: \(nsError.code), UserInfo: \(nsError.userInfo)")
            print("-----------------------------------------")
            try? fileManager.removeItem(at: outputURL); throw error
        }
    }
    // --- END RESTORED ---

    // --- Keep UIViewController.findRootViewController() if it's defined here ---
    // Or ensure it's accessible from elsewhere (e.g., UIViewController+Utils.swift)
}

// MARK: - Preview Provider
#Preview {
    NavigationStack {
        ARPreviewView(
            scan: Scan(
                id: 1, // Use a valid ID for preview URL construction
                name: "Önizleme Taraması",
                modelPath: "/scanFiles/sample/model.usdz", // Path is less relevant now
                createdAt: "2025-04-29T12:00:00Z",
                latitude: "37.7749",
                longitude: "-122.4194"
            ),
            onScanDeleted: { print("Preview: Scan Deleted") }
        )
    }
}
