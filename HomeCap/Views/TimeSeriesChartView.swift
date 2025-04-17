// TimeSeriesChartView.swift
import SwiftUI
import Charts // Requires iOS 16+

struct TimeSeriesChartView: View {
    let data: [ChartDataPoint]
    let unit: Calendar.Component // Receive the unit used for grouping

    // State for tracking selected data point
    @State private var selectedDataPoint: ChartDataPoint?
    // --- FIX: Change to Range<Date>? ---
    @State private var selectedRange: Range<Date>? // For highlighting selected bar range

    // Formatter for X-axis labels - depends on the unit
    private func xAxisLabelFormat(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR") // Use Turkish locale for month names etc.
        switch unit {
        case .day:
            formatter.dateFormat = "d MMM" // "5 May"
        case .weekOfYear:
            formatter.dateFormat = "d MMM" // "12 May" (Start of Week 19)
        case .month:
            formatter.dateFormat = "MMM yy" // "May 25" (Short year)
        case .year:
            formatter.dateFormat = "yyyy" // "2025"
        default:
            formatter.dateStyle = .short // Fallback
        }
        return formatter.string(from: date)
    }

    // Calculate the end date of a bar's interval (exclusive)
    private func calculateEndDate(for startDate: Date) -> Date {
        Calendar.current.date(byAdding: unit, value: 1, to: startDate) ?? startDate
    }

    // Calculate the display end date (inclusive, usually day before next interval)
    private func calculateDisplayEndDate(for startDate: Date) -> Date {
         let nextIntervalStart = calculateEndDate(for: startDate)
         // Go back one day from the start of the next interval
         return Calendar.current.date(byAdding: .day, value: -1, to: nextIntervalStart) ?? startDate
    }


    // Find min/max counts for Y-axis domain (add padding)
    private var yAxisDomain: ClosedRange<Int> {
        let counts = data.map { $0.count }
        let minCount = counts.min() ?? 0
        let maxCount = counts.max() ?? 0
        let upperBound = maxCount + max(1, maxCount / 10) // Add 10% padding or at least 1
        return 0...upperBound
    }

    var body: some View {
        VStack(alignment: .leading) {
            // --- FIX: Structure for conditional selection display ---
            // Use a dedicated ViewBuilder or ensure content is consistent
            VStack(alignment: .leading) { // Wrap selection text in a VStack
                if let selected = selectedDataPoint {
                     let startDateStr = xAxisLabelFormat(for: selected.date)
                     let displayEndDate = calculateDisplayEndDate(for: selected.date)
                     let endDateStr = xAxisLabelFormat(for: displayEndDate)

                     let periodText: String = {
                         if unit == .day {
                             return startDateStr
                         } else if selected.date == displayEndDate { // Handles single day intervals if unit is week/month
                             return startDateStr
                         } else if unit == .year && startDateStr == endDateStr { // Handle yearly case
                             return startDateStr
                         } else {
                             return "\(startDateStr) - \(endDateStr)"
                         }
                     }()

                     Text("Seçili Dönem: \(periodText)")
                          .font(.callout)
                          .foregroundStyle(.secondary)
                     Text("Tıklanma: \(selected.count)")
                          .font(.headline)
                          .bold()
                } else {
                     Text("Bir çubuğa dokunarak detayları görün")
                          .font(.callout)
                          .foregroundStyle(.secondary)
                     Text("Tıklanma: -") // Keep space
                          .font(.headline)
                          .bold()
                          .accessibilityHidden(true)
                          .opacity(0) // Use opacity 0 to maintain layout space
                }
            }
            .frame(height: 40, alignment: .leading) // Give the text area a fixed height and alignment
            .padding(.bottom, 5)
            // --- End Fix ---


            Chart(data) { dataPoint in
                BarMark(
                    x: .value("Tarih", dataPoint.date, unit: unit),
                    y: .value("Tıklanma", dataPoint.count)
                )
                .foregroundStyle(selectedDataPoint?.id == dataPoint.id ? Color.green.opacity(0.8) : Color.blue.opacity(0.7))
                .cornerRadius(3)
            }
            // Customize Axes
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
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    AxisValueLabel(format: .dateTimeChartFormat(unit: unit),
                                   centered: true,
                                   collisionResolution: .greedy) // Allow labels to overlap slightly if needed
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
             .chartYScale(domain: yAxisDomain)
             .chartScrollableAxes(.horizontal)
             .chartOverlay { proxy in
                  GeometryReader { geometry in
                       Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                 DragGesture(minimumDistance: 0)
                                      .onChanged { value in
                                           updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                      }
                            )
                  }
             }
             .chartOverlay { proxy in
                 // Check selectedRange (now Range<Date>?)
                 if let range = selectedRange {
                     GeometryReader { geometry in
                         // Use lowerBound and upperBound for Range
                         let startX = proxy.position(forX: range.lowerBound) ?? 0
                         let endX = proxy.position(forX: range.upperBound) ?? geometry.size.width

                         let clampedStartX = max(0, startX)
                         let clampedEndX = min(geometry.size.width, endX)
                         // Ensure width is not negative
                         let selectionWidth = max(0, clampedEndX - clampedStartX)

                         // Only draw if width is positive and within bounds
                         if selectionWidth > 0 && clampedEndX > clampedStartX {
                             Rectangle()
                                 .fill(.gray.opacity(0.15))
                                 .frame(width: selectionWidth, height: geometry.size.height)
                                 .offset(x: clampedStartX)
                         }
                     }
                 }
             }
            .frame(height: 250)
        }
    }

    // Helper function to update selection based on gesture
    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
         // Find the date corresponding to the gesture's x-position within the plot area
         let plotAreaFrame = geometry[proxy.plotAreaFrame] // Get plot area frame
         // Ensure location is within plot area horizontally before proceeding
         guard location.x >= plotAreaFrame.minX && location.x <= plotAreaFrame.maxX else {
             // Tap outside plot area horizontally, optionally clear selection
             // selectedDataPoint = nil
             // selectedRange = nil
             return
         }
         let xPosition = location.x - plotAreaFrame.origin.x
         guard let date : Date = proxy.value(atX: xPosition) else { return }


         // Find the data point whose interval contains the tapped date
         var foundDataPoint: ChartDataPoint? = nil
         for dataPoint in data {
              let intervalStartDate = dataPoint.date
              let intervalEndDate = calculateEndDate(for: intervalStartDate)
              // Use half-open range check: >= start AND < end
              if date >= intervalStartDate && date < intervalEndDate {
                   foundDataPoint = dataPoint
                   break
              }
         }

         // Update the selected state if a point was found
         if let foundPoint = foundDataPoint {
              if selectedDataPoint?.id != foundPoint.id { // Update only if selection changed
                   selectedDataPoint = foundPoint
                   let endDate = calculateEndDate(for: foundPoint.date)
                   // --- FIX: Assign Range<Date> ---
                   selectedRange = foundPoint.date..<endDate // Use half-open range
              }
         } else {
             // Optional: Clear selection if tap is between bars or outside data range
             // selectedDataPoint = nil
             // selectedRange = nil
         }
    }

    // (calculateVisibleDomainLength remains the same)
     private func calculateVisibleDomainLength() -> TimeInterval {
        let typicalIntervalDuration: TimeInterval
        switch unit {
            case .day: typicalIntervalDuration = 60 * 60 * 24
            case .weekOfYear: typicalIntervalDuration = 60 * 60 * 24 * 7
            case .month: typicalIntervalDuration = 60 * 60 * 24 * 30 // Approx
            case .year: typicalIntervalDuration = 60 * 60 * 24 * 365 // Approx
            default: typicalIntervalDuration = 60 * 60 * 24 // Default to day
        }
        return typicalIntervalDuration * 7 // Show roughly 7 intervals initially
    }
}

// Date.FormatStyle extension (Keep as is)
extension FormatStyle where Self == Date.FormatStyle {
    static func dateTimeChartFormat(unit: Calendar.Component) -> Self {
        let style = Date.FormatStyle()
        switch unit {
            case .day: return style.day().month() // e.g., 5 May
            case .weekOfYear: return style.month(.abbreviated).day() // e.g., May 12 (Start of week)
            case .month: return style.month(.abbreviated).year(.twoDigits) // e.g., May 25
            case .year: return style.year() // e.g., 2025
            default: return style.day().month() // Fallback
        }
    }
}


#Preview {
    let calendar = Calendar.current
    let today = Date()
    let sampleDataDaily: [ChartDataPoint] = (0..<15).map { i in
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        let count = Int.random(in: 2...20)
        return ChartDataPoint(date: calendar.startOfDay(for: date), count: count)
    }.reversed()

     let sampleDataWeekly: [ChartDataPoint] = (0..<10).map { i in
         let date = calendar.date(byAdding: .weekOfYear, value: -i, to: today)!
         let count = Int.random(in: 10...50)
         let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
         return ChartDataPoint(date: startOfWeek, count: count)
     }.reversed()


    return VStack {
         Text("Daily Chart")
         TimeSeriesChartView(data: sampleDataDaily, unit: .day)
              .padding()
         Divider()
         Text("Weekly Chart")
         TimeSeriesChartView(data: sampleDataWeekly, unit: .weekOfYear)
             .padding()
    }
}
