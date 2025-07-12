// ModelsView.swift
import SwiftUI

struct ModelsView: View {
    @State private var scans: [Scan] = []
    @State private var isLoadingScans = false
    @State private var scanError: String?
    @State private var needsRefresh = false  // Flag to trigger refresh from detail view
    @State private var isPresentingScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {  // Use VStack, set spacing to 0

            // --- REMOVED: HStack with manual refresh button ---

            // --- Content ---
            if isLoadingScans && scans.isEmpty {
                ProgressView("Modeller yükleniyor...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
                    .padding(.top)
            } else if let errorMsg = scanError {
                // Error View (Centered)
                VStack(alignment: .center) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.orange)
                        .padding(.bottom, 5)
                    Text("Model yükleme hatası")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Tekrar Dene") {
                        loadScans()  // Use non-async version for button tap
                    }
                    .buttonStyle(.bordered)
                    .padding(.top)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if scans.isEmpty {
                // Empty State View (Centered)
                VStack(alignment: .center) {
                    Spacer()
                    Image(systemName: "cube.box")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                    Text("Henüz bir model oluşturmadınız.")
                        .foregroundColor(.primary)
                    Text("Başlamak için aşağıdaki düğmeyi kullanın.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Scan List
                List {
                    ForEach(scans) { scan in
                        NavigationLink(value: scan) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(scan.name)
                                        .font(.headline)
                                    // Show filename if path exists
                                    AddressTextView(
                                        latitudeString: scan.latitude,
                                        longitudeString: scan.longitude
                                    )
                                }
                                Spacer()
                                Text(scan.formattedCreatedAt)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    // Optional: .onDelete(perform: deleteScan)
                }
                .listStyle(.plain)
                .refreshable {  // Pull-to-refresh modifier
                    await loadScansAsync()
                }
            }

            // --- "Create New Model" Button ---
            // This Spacer pushes the button down only if the content above is short
            if !scans.isEmpty || scanError != nil {  // Add Spacer only if there's content or error above
                Spacer()
            }

            Button {
                isPresentingScanner = true
            } label: {
                Label("Yeni Model Oluştur", systemImage: "plus.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 5)  // Padding from bottom edge

        }  // End main VStack
        .navigationDestination(for: Scan.self) { scan in
            ARPreviewView(
                scan: scan,
                onScanDeleted: {
                    needsRefresh = true  // Set flag to refresh list when returning
                }
            )
        }
        .navigationTitle("Modeller")
        .onAppear {
            // Load only if list is empty and there wasn't a previous error
            if scans.isEmpty && scanError == nil {
                loadScans()
            }
        }
        .onChange(of: needsRefresh) { _, newValue in
            // Refresh the list if the flag was set (e.g., by ARPreviewView)
            if newValue {
                print("Detected scan deletion, refreshing ModelsView list.")
                loadScans()  // Use non-async here, as it's not from pull-to-refresh
                needsRefresh = false  // Reset flag
            }
        }
        .fullScreenCover(isPresented: $isPresentingScanner) {
            NavigationStack {  // Present scanner in its own stack
                ScanningEntryView()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .scanUploadDidSucceed)
        ) { _ in
            self.isPresentingScanner = false
        }
    }

    // Non-async version for onAppear, button taps, etc.
    private func loadScans() {
        isLoadingScans = true
        scanError = nil  // Clear error on new load attempt
        API.shared.fetchScans { result in
            DispatchQueue.main.async {
                isLoadingScans = false
                switch result {
                case .success(let fetchedScans):
                    self.scans = fetchedScans.sorted { $0.id > $1.id }
                    print(
                        "Successfully fetched \(fetchedScans.count) scans for ModelsView."
                    )
                case .failure(let error):
                    self.scanError = error.localizedDescription
                    print(
                        "Error fetching scans for ModelsView: \(error.localizedDescription)"
                    )
                    self.scans = []  // Clear scans on error
                }
            }
        }
    }

    // Async version for pull-to-refresh
    @MainActor
    private func loadScansAsync() async {
        scanError = nil  // Clear error for refresh attempt
        // isLoadingScans = false // Keep false for pull-to-refresh UI

        await withCheckedContinuation { continuation in
            API.shared.fetchScans { result in
                switch result {
                case .success(let fetchedScans):
                    self.scans = fetchedScans.sorted { $0.id > $1.id }
                    print("Successfully refreshed \(fetchedScans.count) scans.")
                case .failure(let error):
                    // Don't necessarily clear scans on refresh error, maybe keep old data?
                    // self.scans = []
                    self.scanError = error.localizedDescription  // Show error message
                    print(
                        "Error refreshing scans: \(error.localizedDescription)"
                    )
                }
                continuation.resume()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModelsView()
            .environmentObject(AuthManager())
    }
}
