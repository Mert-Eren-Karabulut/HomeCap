//
//  class.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 28.04.2025.
//


// QLPreviewCoordinator.swift
import QuickLook
import UIKit // Needed for NSObject

// Standalone Coordinator class
class QLPreviewCoordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    let previewItemURL: URL

    init(url: URL) {
        self.previewItemURL = url
        print("QLPreviewCoordinator initialized with URL: \(url)")
        super.init()
    }

    // MARK: - QLPreviewControllerDataSource

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        print("QLPreviewCoordinator: Providing number of items (1)")
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        print("QLPreviewCoordinator: Providing preview item for URL: \(previewItemURL)")
        return previewItemURL as NSURL // Use NSURL for QLPreviewItem conformance
        // Or: return ARQuickLookPreviewItem(fileAt: previewItemURL)
    }

    // MARK: - QLPreviewControllerDelegate (Optional but good practice)
    func previewControllerWillDismiss(_ controller: QLPreviewController) {
         print("QLPreviewCoordinator: Preview will dismiss")
         // Clean up coordinator reference if needed (see presentation helper)
         controller.dataSource = nil // Break retain cycle
         controller.delegate = nil
     }
}