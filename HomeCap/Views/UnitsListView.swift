//
//  UnitsListView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 29.04.2025.
//

// UnitsListView.swift
import SwiftUI

struct UnitsListView: View {
    @State private var units: [Unit] = []
    @State private var availableScans: [Scan] = []  // Store scans for passing to edit view
    @State private var isLoading = false
    @State private var fetchError: String?
    @State private var needsRefresh = true  // Start with true to load on first appear

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {  // Use VStack, remove spacing if List handles it
            // Header can be part of the list or separate Hstack if needed outside scrolling
            if isLoading && units.isEmpty {
                ProgressView("Daireler yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = fetchError {
                VStack {
                    Spacer()
                    Text("Daireler yüklenemedi:\n\(errorMsg)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Tekrar Dene") {
                        needsRefresh = true  // Trigger refresh
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if units.isEmpty {
                VStack(alignment: .center) {
                    Spacer()
                    Image(systemName: "building.2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                    Text("Henüz bir daire oluşturmadınız.")
                        .foregroundColor(.primary)
                    Text("Eklemek için '+' düğmesine dokunun.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(units) { unit in
                        // NavigationLink to edit view
                        NavigationLink(value: unit) {
                            VStack(alignment: .leading) {
                                Text(unit.name).font(.headline)
                                if let address = unit.address, !address.isEmpty
                                {
                                    Text(address).font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                // Optionally show associated scan name if available
                                if let scanName = unit.scan?.name,
                                    unit.scanId != nil
                                {
                                    Text("Model: \(scanName)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                } else if unit.scanId != nil {
                                    Text("Model: (Model bulunamadı)")  // Scan ID exists but scan data missing?
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }

                            }
                        }
                    }
                    // Optional: Swipe to delete
                    //.onDelete(perform: deleteUnit)
                }
                .listStyle(.plain)
                .refreshable {  // Pull-to-refresh
                    await loadUnitsAndScansAsync()
                }
            }

            // --- "Create New Unit" Button ---
            if !units.isEmpty {
                Spacer()
            }
            NavigationLink(value: "CreateNewUnit") {
                Label("Yeni Daire Oluştur", systemImage: "building.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
        .navigationTitle("Daireler")
        // Navigation Destination for editing an existing Unit
        .navigationDestination(for: Unit.self) { unit in
            // Pass available scans to avoid refetching
            UnitEditView(
                mode: .edit,
                unitToEdit: unit,
                availableScans: availableScans,
                onListNeedsRefresh: {
                    self.needsRefresh = true  // Set flag when edit view signals change
                }
            )
        }
        // Navigation Destination for creating a new Unit
        .navigationDestination(for: String.self) { value in
            if value == "CreateNewUnit" {
                UnitEditView(
                    mode: .create,
                    availableScans: availableScans,
                    onListNeedsRefresh: {
                        self.needsRefresh = true
                    }
                )
            }
        }
        .onAppear {
            if needsRefresh {  // Load only if flagged
                loadUnitsAndScans()
            }
        }
        .onChange(of: needsRefresh) { _, newValue in
            if newValue {
                loadUnitsAndScans()
            }
        }
    }

    // MARK: - Data Loading

    private func loadUnitsAndScans() {
        // Don't reset lists immediately, only on success/failure
        isLoading = true
        fetchError = nil
        needsRefresh = false  // Reset flag as we are attempting load

        API.shared.fetchUnitsAndScans { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    // Sort units, perhaps alphabetically or by newest?
                    self.units = data.units.sorted { $0.name < $1.name }
                    // Store scans for the picker, maybe add a "None" option representation later
                    self.availableScans = data.scans.sorted { $0.id > $1.id }
                    print(
                        "Fetched \(data.units.count) units and \(data.scans.count) scans."
                    )
                case .failure(let error):
                    self.fetchError = error.localizedDescription
                    print("Error fetching units/scans: \(error)")
                    self.units = []  // Clear data on error
                    self.availableScans = []
                }
            }
        }
    }

    @MainActor
    private func loadUnitsAndScansAsync() async {
        fetchError = nil  // Clear error for pull-to-refresh
        needsRefresh = false

        await withCheckedContinuation { continuation in
            API.shared.fetchUnitsAndScans { result in
                switch result {
                case .success(let data):
                    self.units = data.units.sorted { $0.name < $1.name }
                    self.availableScans = data.scans.sorted { $0.id > $1.id }
                    print(
                        "Refreshed \(data.units.count) units and \(data.scans.count) scans."
                    )
                case .failure(let error):
                    self.fetchError = error.localizedDescription
                    print("Error refreshing units/scans: \(error)")
                    self.units = []
                    self.availableScans = []
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Deletion (Swipe Action)

    private func deleteUnit(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let unitToDelete = units[index]

        print("Attempting swipe-delete for unit ID: \(unitToDelete.id)")
        isLoading = true  // Show loading indicator during delete

        API.shared.deleteUnit(unitId: unitToDelete.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    print(
                        "Successfully deleted unit ID \(unitToDelete.id) via swipe."
                    )
                    units.remove(atOffsets: offsets)  // Update local list
                // Optionally, trigger a full refresh if needed, but removing locally is often sufficient
                // self.needsRefresh = true
                case .failure(let error):
                    print(
                        "Swipe-delete failed for unit ID \(unitToDelete.id): \(error.localizedDescription)"
                    )
                    fetchError =
                        "Silme başarısız: \(error.localizedDescription)"  // Show error
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        UnitsListView()
            .environmentObject(AuthManager())  // Provide if needed
    }
}
