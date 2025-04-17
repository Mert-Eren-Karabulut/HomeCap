// HomeViewModel.swift
import SwiftUI
import Combine
import Charts // Import Charts

@MainActor // Ensure UI updates happen on the main thread
class HomeViewModel: ObservableObject {

    // Published properties for the view to observe
    @Published var totalUnits: Int = 0
    @Published var totalScans: Int = 0
    @Published var chartData: [ChartDataPoint] = []
    @Published var allAnalyticsEntries: [AnalyticsEntry] = [] // Store raw entries for detailed view
    @Published var unitNames: [Int: String] = [:] // Store unit names keyed by ID
    @Published var chartCalendarComponent: Calendar.Component = .day // Store the unit used for the chart

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Store all units fetched for the picker in the detailed view
    @Published var availableUnits: [Unit] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Data is fetched via .onAppear or .refreshable now
    }

    // --- Keep original fetchData for .onAppear or non-async calls ---
    func fetchData() {
        // Avoid fetching if already loading, unless there's an error
        guard !isLoading || errorMessage != nil else { return }

        isLoading = true
        errorMessage = nil // Clear error when starting a fetch
        print("HomeViewModel: Starting data fetch (non-async)...")
        fetchCombinedData() // Call the common data fetching logic
    }

    // --- NEW: Async function for .refreshable ---
    func fetchDataAsync() async {
        // Don't show the main loading indicator for pull-to-refresh
        // isLoading = true // Avoid setting isLoading for pull-to-refresh style
        errorMessage = nil // Clear previous errors on refresh attempt
        print("HomeViewModel: Starting data fetch (async)...")

        await fetchCombinedDataAsync() // Call the async data fetching logic
    }

    // --- Private Helper for Combine-based fetching (used by non-async fetchData) ---
    private func fetchCombinedData() {
        // Combine fetching stats and units
        let statsPublisher = Future<StatsResponse, Error> { promise in
            API.shared.fetchStats { result in
                promise(result)
            }
        }

        let unitsPublisher = Future<(units: [Unit], scans: [Scan]), Error> { promise in
             API.shared.fetchUnitsAndScans { result in // Reuse existing fetch
                 promise(result)
             }
         }

        Publishers.Zip(statsPublisher, unitsPublisher)
            .receive(on: DispatchQueue.main) // Switch to main thread for UI updates
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false // Stop loading indicator
                if case .failure(let error) = completion {
                    print("HomeViewModel: Data fetch failed: \(error.localizedDescription)")
                    self.errorMessage = "Veriler yüklenemedi: \(error.localizedDescription)"
                    self.clearDataOnError() // Clear data
                } else {
                     print("HomeViewModel: Data fetch completed successfully.")
                }
            }, receiveValue: { [weak self] (statsResponse, unitsResponse) in
                guard let self = self else { return }
                print("HomeViewModel: Received stats and units.")
                self.processFetchedData(statsResponse: statsResponse, unitsResponse: unitsResponse) // Process data
            })
            .store(in: &cancellables)
    }

    // --- Private Helper for Async fetching (used by fetchDataAsync) ---
    private func fetchCombinedDataAsync() async {
        // Use Swift concurrency (async/await) to bridge Combine publishers
        let statsResult = await fetchStatsWithContinuation()
        let unitsResult = await fetchUnitsWithContinuation()

        // Process results after both async calls complete
        switch (statsResult, unitsResult) {
        case (.success(let statsResponse), .success(let unitsResponse)):
            print("HomeViewModel (Async): Received stats and units.")
            self.processFetchedData(statsResponse: statsResponse, unitsResponse: unitsResponse)
        case (.failure(let error), _), (_, .failure(let error)):
            print("HomeViewModel (Async): Data fetch failed: \(error.localizedDescription)")
            self.errorMessage = "Veriler yüklenemedi: \(error.localizedDescription)"
            self.clearDataOnError()
        }
        // isLoading = false // Ensure loading state is reset if it was set for async
    }

    // --- Bridging helpers using withCheckedContinuation ---
    private func fetchStatsWithContinuation() async -> Result<StatsResponse, Error> {
        await withCheckedContinuation { continuation in
            API.shared.fetchStats { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func fetchUnitsWithContinuation() async -> Result<(units: [Unit], scans: [Scan]), Error> {
        await withCheckedContinuation { continuation in
            API.shared.fetchUnitsAndScans { result in
                continuation.resume(returning: result)
            }
        }
    }

    // --- Common Data Processing Logic ---
    private func processFetchedData(statsResponse: StatsResponse, unitsResponse: (units: [Unit], scans: [Scan])) {
        // Update basic stats
        self.totalUnits = statsResponse.units
        self.totalScans = statsResponse.scans

        // Store units and create name map
        self.availableUnits = unitsResponse.units.sorted { $0.name < $1.name }
        self.unitNames = Dictionary(uniqueKeysWithValues: unitsResponse.units.map { ($0.id, $0.name) })

        // Flatten and store all analytics entries
        let allEntries = statsResponse.analytics.values.flatMap { $0 }
                            .filter { $0.date != nil }
                            .sorted { $0.date! < $1.date! }
        self.allAnalyticsEntries = allEntries

        // Process data for the chart
        let (processedData, component) = self.processAnalyticsForChart(entries: allEntries)
        self.chartData = processedData
        self.chartCalendarComponent = component
        print("HomeViewModel: Processed \(self.chartData.count) data points for chart using unit: \(component).")
    }

    // --- Helper to clear data on error ---
    private func clearDataOnError() {
         self.totalUnits = 0
         self.totalScans = 0
         self.chartData = []
         self.allAnalyticsEntries = []
         self.availableUnits = []
         self.unitNames = [:]
    }


    // --- Data Processing for Chart ---
    // Returns the Calendar.Component used for grouping
    func processAnalyticsForChart(entries: [AnalyticsEntry]) -> (points: [ChartDataPoint], component: Calendar.Component) {
        guard !entries.isEmpty, let firstDate = entries.first?.date, let lastDate = entries.last?.date else {
            return ([], .day) // Return default component if no data
        }
        let adjustedLastDate = (lastDate <= firstDate) ? Calendar.current.date(byAdding: .second, value: 1, to: firstDate)! : lastDate
        let totalInterval = adjustedLastDate.timeIntervalSince(firstDate)
        let maxDivisions = 10.0
        let calendarComponent: Calendar.Component
        if totalInterval <= 60 * 60 * 24 * (maxDivisions + 2) { calendarComponent = .day }
        else if totalInterval <= 60 * 60 * 24 * 7 * (maxDivisions + 2) { calendarComponent = .weekOfYear }
        else if totalInterval <= 60 * 60 * 24 * 31 * (maxDivisions + 2) { calendarComponent = .month }
        else { calendarComponent = .year }

        var intervalStartDate = Calendar.current.startOfDay(for: firstDate)
        if calendarComponent != .day {
             guard let adjustedStartDate = Calendar.current.dateInterval(of: calendarComponent, for: firstDate)?.start else {
                  print("Chart Processing Error: Could not get start of interval for first date.")
                  return ([], calendarComponent)
             }
             intervalStartDate = adjustedStartDate
        }
        var divisions: [Date] = []
        var currentDateIterator = intervalStartDate
        while currentDateIterator <= adjustedLastDate {
            divisions.append(currentDateIterator)
            guard let nextDate = Calendar.current.date(byAdding: calendarComponent, value: 1, to: currentDateIterator) else { break }
            currentDateIterator = nextDate
        }

        let groupedEntries = Dictionary(grouping: entries) { entry -> Date in
             for i in (0..<divisions.count).reversed() {
                  if entry.date! >= divisions[i] { return divisions[i] }
             }
             print("Chart Processing Warning: Entry date \(String(describing: entry.date)) before first division \(String(describing: divisions.first)). Assigning to first division.")
             return divisions.first!
        }
        let chartPoints = divisions.map { startDate -> ChartDataPoint in
            let count = groupedEntries[startDate]?.count ?? 0
            return ChartDataPoint(date: startDate, count: count)
        }
        return (chartPoints, calendarComponent)
    }
}
