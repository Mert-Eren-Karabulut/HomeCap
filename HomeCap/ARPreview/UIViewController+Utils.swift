//
//  UIViewController+Utils.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 28.04.2025.
//

// Add this extension, perhaps in a new file like UIViewController+Utils.swift
import UIKit
import QuickLook

extension UIViewController {

    // Store coordinator strongly to keep it alive during presentation
    private static var qlCoordinatorStorage: [ObjectIdentifier: QLPreviewCoordinator] = [:]

    func presentQLPreview(url: URL) {
        guard QLPreviewController.canPreview(url as QLPreviewItem) else {
            print("Error: Cannot preview URL: \(url)")
            // Optionally show an alert to the user
            return
        }

        let previewController = QLPreviewController()
        // Create and store the coordinator. Use the controller's ObjectIdentifier as a key.
        let coordinator = QLPreviewCoordinator(url: url)
        let controllerId = ObjectIdentifier(previewController)
        UIViewController.qlCoordinatorStorage[controllerId] = coordinator

        previewController.dataSource = coordinator
        previewController.delegate = coordinator // Use delegate to clean up coordinator

        // Override delegate method within the helper or ensure coordinator handles cleanup
        // Setup a way to remove coordinator from storage upon dismissal
        // (The delegate method in QLPreviewCoordinator handles this now)

        // Find the topmost view controller to present from
        var presentingVC = self
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        print("Presenting QLPreviewController from: \(type(of: presentingVC))")
        presentingVC.present(previewController, animated: true) {
             // Cleanup coordinator reference after presentation completes (if needed,
             // but dismissal cleanup is usually sufficient)
             // Or perhaps clear it if presentation fails? Delegate handles success path.
             // If delegate method doesn't clear:
             // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay might be needed
             //     if previewController.presentingViewController == nil { // Check if dismissal happened quickly
             //         Self.qlCoordinatorStorage.removeValue(forKey: controllerId)
             //     }
             // }
         }
    }

    // Helper to find the root view controller from the key window scene
    static func findRootViewController() -> UIViewController? {
        // Find the active scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return nil }

        // Find the key window in that scene
        guard let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else { return nil }

        return keyWindow.rootViewController
    }
}
