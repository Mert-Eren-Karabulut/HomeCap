// StatsModels.swift
import Foundation

// Represents a single analytics click entry
struct AnalyticsEntry: Codable, Identifiable {
    let id: Int
    let unitId: Int
    let createdAt: String // Keep as String for initial decoding

    // Coding keys to match JSON response (snake_case)
    enum CodingKeys: String, CodingKey {
        case id
        case unitId = "unit_id"
        case createdAt = "created_at"
    }

    // Computed property to parse the date string into a Date object
    var date: Date? {
        let formatter = ISO8601DateFormatter()
        // Try multiple formats common in ISO8601
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: createdAt) {
            return d
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: createdAt) {
            return d
        }
        // Add more formats if needed
        print("Warning: Could not parse date string: \(createdAt)")
        return nil
    }
}

// Represents the overall response from the /stats endpoint
struct StatsResponse: Codable {
    let units: Int // Total number of units for the user
    let scans: Int // Total number of scans for the user
    // Analytics are keyed by unit_id (String) and contain an array of entries
    let analytics: [String: [AnalyticsEntry]]

    // --- NEW: Custom Initializer to handle empty array case for analytics ---
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode standard properties
        units = try container.decode(Int.self, forKey: .units)
        scans = try container.decode(Int.self, forKey: .scans)

        // Decode 'analytics' flexibly
        do {
            // Try decoding as the expected dictionary first
            analytics = try container.decode([String: [AnalyticsEntry]].self, forKey: .analytics)
        } catch let DecodingError.typeMismatch(_, context) where context.codingPath.last?.stringValue == "analytics" {
            // If it's a type mismatch for 'analytics', try decoding as an empty array
            // This handles the case where Laravel returns [] instead of {}
            if let _ = try? container.decode([Never].self, forKey: .analytics) {
                 // If decoding as an empty array succeeds, assign an empty dictionary
                 print("Decoding Warning: 'analytics' field was an empty array, interpreting as empty dictionary.")
                 analytics = [:]
            } else {
                 // If it's not an empty array either, rethrow the original error
                 print("Decoding Error: 'analytics' field type mismatch, but not an empty array.")
                 throw DecodingError.typeMismatch([String: [AnalyticsEntry]].self, context)
            }
        } catch {
             // Rethrow any other kind of error
             print("Decoding Error: Failed to decode 'analytics' for other reasons.")
             throw error
        }
    }

     // --- Need to define CodingKeys if using custom init ---
     enum CodingKeys: String, CodingKey {
          case units
          case scans
          case analytics
     }
}

// Structure to hold processed data points for the chart
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date // Represents the start of the time interval
    let count: Int // Number of clicks in this interval
}
