//
//  Unit.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 29.04.2025.
//


// Unit.swift
import Foundation

struct Unit: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int? // Assuming user_id might be useful
    let scanId: Int? // Nullable scan ID
    var name: String
    var description: String?
    var address: String?
    var externalLinks: [String]? // Array of strings, nullable
    let createdAt: String? // Add if needed, e.g., created_at
    let updatedAt: String? // Add if needed, e.g., updated_at

    // Nested Scan object if the API includes it via `with('scan')`
    // Make sure the nested Scan matches your Scan.swift definition
    // Mark optional if it might not always be present
    let scan: Scan?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case scanId = "scan_id"
        case name
        case description
        case address
        case externalLinks = "external_links"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case scan // Key for the nested scan object
    }

    // Helper to provide default empty array for easier handling in views
    var safeExternalLinks: [String] {
        get { externalLinks ?? [] }
        set { externalLinks = newValue.isEmpty ? nil : newValue } // Store nil if empty
    }

    // Default initializer if needed
    init(id: Int = 0, userId: Int? = nil, scanId: Int? = nil, name: String = "", description: String? = nil, address: String? = nil, externalLinks: [String]? = nil, createdAt: String? = nil, updatedAt: String? = nil, scan: Scan? = nil) {
        self.id = id
        self.userId = userId
        self.scanId = scanId
        self.name = name
        self.description = description
        self.address = address
        self.externalLinks = externalLinks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scan = scan
    }
}

// Wrapper struct for the /units API response
struct UnitsResponse: Codable {
    let units: [Unit]
    let scans: [Scan] // Also includes scans for the picker
}