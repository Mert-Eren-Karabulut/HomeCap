// DetailedAnalyticsView.swift
import SwiftUI
import Charts

struct DetailedAnalyticsView: View {
    // Use ObservedObject as the ViewModel's lifecycle is managed by HomeView
    @ObservedObject var viewModel: HomeViewModel

    // State for the selected unit ID in the picker
    @State private var selectedUnitId: Int? = nil // Start with no selection

    // Define grid columns for the stat boxes
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    // --- Computed properties for filtered data ---
    private var selectedUnitAnalytics: [AnalyticsEntry] {
        guard let unitId = selectedUnitId else { return [] }
        // Filter the already fetched entries
        return viewModel.allAnalyticsEntries.filter { $0.unitId == unitId }
    }

    // Also get the calendar component used for this specific unit's chart
    private var selectedUnitChartDataAndComponent: (points: [ChartDataPoint], component: Calendar.Component) {
        guard let unitId = selectedUnitId else { return ([], .day) } // Default component
        let entries = viewModel.allAnalyticsEntries.filter { $0.unitId == unitId }
                                    .filter { $0.date != nil }
                                    .sorted { $0.date! < $1.date! }
        // Use the processing function from the ViewModel
        return viewModel.processAnalyticsForChart(entries: entries)
    }

    private var totalClicksForSelectedUnit: Int {
        selectedUnitAnalytics.count
    }

    private var clicksLast3DaysForSelectedUnit: Int {
        guard let unitId = selectedUnitId else { return 0 }
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let startOfThreeDaysAgo = Calendar.current.startOfDay(for: threeDaysAgo)

        return viewModel.allAnalyticsEntries.filter {
            $0.unitId == unitId && $0.date != nil && $0.date! >= startOfThreeDaysAgo
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // --- Unit Picker ---
                if viewModel.availableUnits.isEmpty {
                     Text("Analiz için daire bulunamadı.")
                          .foregroundColor(.secondary)
                          .padding()
                } else {
                     Picker("Daire Seçin", selection: $selectedUnitId) {
                          Text("Daire Seçilmedi").tag(Int?.none) // Option for no selection
                          ForEach(viewModel.availableUnits) { unit in
                               Text(unit.name).tag(Int?(unit.id)) // Tag with Optional<Int>
                          }
                     }
                     .pickerStyle(.navigationLink) // Good style for potentially long lists
                }


                // --- Display stats and chart ONLY if a unit is selected ---
                if selectedUnitId != nil {
                    // --- Stat Boxes ---
                    LazyVGrid(columns: columns, spacing: 15) {
                        StatBox(title: "Toplam Tıklanma", value: "\(totalClicksForSelectedUnit)", iconName: "cursorarrow.click.2")
                        StatBox(title: "Son 3 Gün", value: "\(clicksLast3DaysForSelectedUnit)", iconName: "calendar.badge.clock")
                    }
                    .padding(.bottom)

                    // --- Chart Section ---
                    VStack(alignment: .leading) {
                         Text("Tıklanmalar (\(viewModel.unitNames[selectedUnitId ?? 0] ?? "Seçili Daire"))") // Show unit name in title
                              .font(.headline)
                              .padding(.bottom, 5)

                         // Use computed property for data and component
                         let chartInfo = selectedUnitChartDataAndComponent
                         if chartInfo.points.isEmpty {
                              Text("Bu daire için tıklanma verisi yok.")
                                   .foregroundColor(.secondary)
                                   .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
                         } else {
                              // Pass both data and the unit
                              TimeSeriesChartView(data: chartInfo.points, unit: chartInfo.component)
                         }
                    }
                } else {
                     // Placeholder when no unit is selected
                     Text("Lütfen analizini görmek için bir daire seçin.")
                          .foregroundColor(.secondary)
                          .frame(maxWidth: .infinity, alignment: .center)
                          .padding(.top, 50)
                }

                Spacer() // Push content up
            }
            .padding()
        }
        .navigationTitle("Detaylı Analiz")
        .navigationBarTitleDisplayMode(.inline)
         // Set initial selection if possible when view appears
         .onAppear {
              if selectedUnitId == nil && !viewModel.availableUnits.isEmpty {
                   // Optionally select the first unit by default
                   // selectedUnitId = viewModel.availableUnits.first?.id
              }
         }
    }

     // --- Removed Duplicated Processing Logic ---
     // Now relies on the ViewModel's processing function
}


#Preview {
     // Create a mock ViewModel with sample data for preview
     let mockViewModel = HomeViewModel()
     mockViewModel.totalUnits = 5
     mockViewModel.totalScans = 10
     mockViewModel.availableUnits = [
          Unit(id: 1, name: "Örnek Daire 1"),
          Unit(id: 2, name: "Örnek Daire 2")
     ]
     mockViewModel.unitNames = [1: "Örnek Daire 1", 2: "Örnek Daire 2"]
     // Add some sample analytics entries spanning a few days/weeks
     let today = Date()
     mockViewModel.allAnalyticsEntries = [
         AnalyticsEntry(id: 1, unitId: 1, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -10, to: today)!)),
         AnalyticsEntry(id: 2, unitId: 1, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -9, to: today)!)),
         AnalyticsEntry(id: 3, unitId: 2, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -8, to: today)!)),
         AnalyticsEntry(id: 4, unitId: 1, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -5, to: today)!)),
         AnalyticsEntry(id: 5, unitId: 1, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -5, to: today)!)),
         AnalyticsEntry(id: 6, unitId: 2, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -3, to: today)!)),
         AnalyticsEntry(id: 7, unitId: 1, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -2, to: today)!)),
         AnalyticsEntry(id: 8, unitId: 1, createdAt: ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -1, to: today)!)),
         AnalyticsEntry(id: 9, unitId: 1, createdAt: ISO8601DateFormatter().string(from: today)),
     ]
     // Process data for the mock view model (needed for detailed view preview)
     let (points, component) = mockViewModel.processAnalyticsForChart(entries: mockViewModel.allAnalyticsEntries)
     mockViewModel.chartData = points
     mockViewModel.chartCalendarComponent = component

     return NavigationStack { // Wrap preview in NavigationStack
          DetailedAnalyticsView(viewModel: mockViewModel)
     }
}
