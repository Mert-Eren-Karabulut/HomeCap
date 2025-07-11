import SwiftUI
import Charts

/// This is the struct TimeSeriesChartView expects.
/// Ensure your data model is `Identifiable` for the Chart to work correctly.
///
/// public struct ChartDataPoint: Identifiable {
///     public let id = UUID()
///     let date: Date
///     let count: Int
/// }

struct TimeSeriesChartView: View {
    /// The chart now uses your original data directly.
    let data: [ChartDataPoint]
    
    /// The unit is used for correct calendar-based grouping of bars.
    let unit: Calendar.Component

    /// A simple formatter for the date labels on the X-axis.
    private func xAxisLabelFormat(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        switch unit {
        case .day:
            formatter.dateFormat = "d MMM"
        case .weekOfYear:
            formatter.dateFormat = "d MMM"
        case .month:
            formatter.dateFormat = "MMM yy"
        case .year:
            formatter.dateFormat = "yyyy"
        default:
            formatter.dateStyle = .short
        }
        return formatter.string(from: date)
    }

    /// Calculates a reasonable scale for the Y-axis with some padding at the top.
    private var yAxisDomain: ClosedRange<Int> {
        let maxCount = data.map { $0.count }.max() ?? 0
        // Add 10% padding, or a default of 10 if all counts are zero.
        let upperBound = maxCount > 0 ? maxCount + max(1, maxCount / 10) : 10
        return 0...upperBound
    }

    /// This function sets the initial visible "window" for the scrollable chart.
    /// It determines how many bars are visible at once.
    private func calculateVisibleDomainLength() -> TimeInterval {
        let typicalIntervalDuration: TimeInterval
        switch unit {
            case .day: typicalIntervalDuration = 60 * 60 * 24
            case .weekOfYear: typicalIntervalDuration = 60 * 60 * 24 * 7
            case .month: typicalIntervalDuration = 60 * 60 * 24 * 30 // Approx.
            case .year: typicalIntervalDuration = 60 * 60 * 24 * 365 // Approx.
            default: typicalIntervalDuration = 60 * 60 * 24
        }
        // Show roughly 8 intervals (bars) at a time.
        return typicalIntervalDuration * 4
    }

    var body: some View {
        // We use a basic VStack, as the complex header is removed.
        VStack(alignment: .leading, spacing: 12) {
            // A simple, static title for the chart. also display total click
            
            Text("Toplam Tıklanma Sayısı: \(data.reduce(0) { $0 + $1.count })")
                .font(.headline)
                .padding(.horizontal)

            // The Chart view, simplified to its core.
            Chart(data) { dataPoint in
                BarMark(
                    x: .value("Tarih", dataPoint.date, unit: unit),
                    y: .value("Tıklanma", dataPoint.count)
                )
                // All bars have a single, non-interactive color.
                .foregroundStyle(Color.blue.opacity(0.7))
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                     AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                     AxisValueLabel(centered: false) {
                         if let intValue = value.as(Int.self) {
                             Text("\(intValue)")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                         }
                     }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: unit)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                         AxisValueLabel(xAxisLabelFormat(for: date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            
            // **THE FIX:** Use the Chart framework's native, robust scrolling.
            // This correctly handles gestures and avoids alignment bugs.
            .chartScrollableAxes(.horizontal)
            
            // **THE FIX:** Set an initial visible "window" to make scrolling obvious and effective.
            .chartXVisibleDomain(length: calculateVisibleDomainLength())
            
            // Set a fixed height for the chart area.
            .frame(height: 250)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}
