//
//  CatalogError.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 27.04.2025.
//


//  CatalogModelProvider.swift
//  HomeCap
//
//  Loads the bundled RoomPlanCatalog so exports can replace
//  detected objects with high-fidelity models.
//

import Foundation
import RoomPlan

extension CapturedRoom.ModelProvider {

    enum CatalogError: LocalizedError {
        case cannotFindCatalog
        var errorDescription: String? {
            switch self {
            case .cannotFindCatalog: return "Cannot find RoomPlanCatalog.bundle"
            }
        }
    }

    /// Returns a `ModelProvider` backed by *RoomPlanCatalog.bundle*.
    static func load() throws -> CapturedRoom.ModelProvider {
        guard let url = Bundle.main.url(
            forResource: "RoomPlanCatalog",
            withExtension: "bundle"
        ) else {
            throw CatalogError.cannotFindCatalog
        }
        return try RoomPlanCatalog.load(at: url)
    }
}
