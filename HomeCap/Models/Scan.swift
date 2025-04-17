// Scan.swift
import Foundation

struct Scan: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let modelPath: String?  // *** CHANGED TO OPTIONAL ***
    let createdAt: String  // Keep as String for initial decoding
    let latitude: String?
    let longitude: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case modelPath = "model_path"
        case createdAt = "created_at"
        case latitude
        case longitude
    }

    // Computed property to get the full URL - now handles optional modelPath
    var modelURL: URL? {
        // Only proceed if modelPath is not nil and not empty
        guard let path = modelPath, !path.isEmpty else {
            return nil
        }
        // Assuming baseURL is "https://gettwin.ai" and path is "/path/to/model.glb"
        return URL(string: "https://gettwin.ai" + path)
    }

    // Computed property to format the date (no change needed here)
    var formattedCreatedAt: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds,
        ]

        if let date = isoFormatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd/MM/yyyy"
            return displayFormatter.string(from: date)
        } else {
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: createdAt) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "dd/MM/yyyy"
                return displayFormatter.string(from: date)
            }
        }
        return "Invalid Date"
    }
    
    var latitudeValue: Double? {
        guard let latString = latitude else { return nil }
        return Double(latString)
    }
    var longitudeValue: Double? {
        guard let lonString = longitude else { return nil }
        return Double(lonString)
    }
}

struct ScanResponse: Codable {
    let scans: [Scan]
}
