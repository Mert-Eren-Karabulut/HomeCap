import Charts  // Import Charts
// HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = HomeViewModel()

    // Define grid columns for the stat boxes
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15),
    ]

    var body: some View {
        // --- MODIFIED: Use List for ScrollView + Refreshable ---
        // List provides scrollability and works well with .refreshable
        List {
            // Section to group the main content, prevents List styling on individual items
            Section {
                VStack(alignment: .leading, spacing: 20) {  // Add spacing
                    // --- Analytics Section ---
                    // Show loading only on initial load (when chartData is empty and not errored)
                    if viewModel.isLoading && viewModel.chartData.isEmpty
                        && viewModel.errorMessage == nil
                    {
                        ProgressView("İstatistikler yükleniyor...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 50)
                    } else if let errorMsg = viewModel.errorMessage {
                        // Display error message
                        VStack(alignment: .center) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.orange)
                                .padding(.bottom, 5)
                            Text("İstatistikler yüklenemedi.")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            // Provide a way to retry if needed, even with pull-to-refresh
                            Button("Tekrar Dene") {
                                viewModel.fetchData()  // Use non-async for button tap
                            }
                            .buttonStyle(.bordered)
                            .padding(.top)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)

                    } else {
                        // --- Stat Boxes ---
                        LazyVGrid(columns: columns, spacing: 15) {
                            StatBox(
                                title: "Toplam Daire",
                                value: "\(viewModel.totalUnits)",
                                iconName: "building.2.fill"
                            )
                            StatBox(
                                title: "Toplam Model",
                                value: "\(viewModel.totalScans)",
                                iconName: "cube.box.fill"
                            )
                        }
                        .padding(.bottom)  // Space below boxes

                        // --- Chart Section ---
                        VStack(alignment: .leading) {
                            Text("Tıklanmalar")
                                .font(.headline)
                                .padding(.bottom, 5)

                            // Show chart or empty state
                            if viewModel.chartData.isEmpty {
                                Text("Görüntülenecek tıklanma verisi yok.")
                                    .foregroundColor(.secondary)
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: 250,
                                        alignment: .center
                                    )
                            } else {
                                TimeSeriesChartView(
                                    data: viewModel.chartData,
                                    unit: viewModel.chartCalendarComponent
                                )
                            }
                        }
                        .padding(.bottom)  // Space below chart

                    }  // End else (data loaded or empty)
                    // --- End Analytics Section ---

                }  // End main content VStack
                // Remove padding here, let List/Section handle it
                // .padding(.vertical)

            }  // End Section
            .listRowSeparator(.hidden)  // Hide default separators
            // Remove default insets to use full width

        }  // End List
        .listStyle(.plain)  // Use plain style to remove inset grouping appearance
        .refreshable {  // Add refreshable modifier to the List
            await viewModel.fetchDataAsync()
        }

        .navigationDestination(for: String.self) { value in  // Handle navigation
            if value == "DetailedAnalytics" {
                DetailedAnalyticsView(viewModel: viewModel)
            }
        }
        .navigationTitle("Anasayfa")
        // --- REMOVED: Toolbar with manual refresh button ---
        .onAppear {
            // Fetch data when the view appears if not already loaded or errored
            if viewModel.totalUnits == 0 && viewModel.totalScans == 0
                && viewModel.chartData.isEmpty && viewModel.errorMessage == nil
                && !viewModel.isLoading
            {
                print("HomeView appeared, triggering initial data fetch.")
                viewModel.fetchData()  // Use non-async version for onAppear
            }
        }
        // --- Detailed Analytics Link ---
        // NavigationLink works inside List rows
        if (!viewModel.chartData.isEmpty) {
    
            NavigationLink(value: "DetailedAnalytics") {  // Navigate using a value
                HStack {
                    Text("Detaylı Analiz")
                }
            }
            // Apply padding within the row content if needed, or rely on List defaults
            .padding(.bottom, 40)
        }
    }
}

// --- Stat Box View ---
struct StatBox: View {
    let title: String
    let value: String
    let iconName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: iconName)
                    .foregroundColor(.blue)
            }
            Text(value)
                .font(.title.bold())
                .foregroundColor(.primary)
        }
        .padding()
        // Use a system background color that adapts to light/dark mode
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AuthManager())
    }
}
