import Foundation
import SceneKit
import ARKit // Still needed for CapturedRoom export initially
// ModelIO might not be needed anymore if SCNScene loads directly

// Define potential errors during modification
enum SceneKitModificationError: Error {
    case sceneLoadingFailed(Error)
    case sceneExportFailed(Error)
    case textureURLError(String)
    case nodeNotFound(String)
}

// --- Main Modification Function using SceneKit ---

/// Modifies the materials of a USDZ asset exported from RoomPlan using SceneKit and PBR properties.
/// - Applies a blue tint to the diffuse property of objects under the 'Object_grp' node.
/// - Replaces the diffuse texture under 'Floor_grp' and adjusts its tiling.
/// - Replaces the diffuse texture under 'Arch_grp' and adjusts its tiling.
/// - Saves the result to a NEW file URL.
///
/// - Parameters:
///   - sourceUrl: The file URL of the *original* USDZ file to load and modify.
///   - floorTextureURL: The file URL of the image for the floor texture (must be in the app bundle).
///   - archTextureURL: The file URL of the image for the architecture textures (must be in the app bundle).
///   - objectTintColor: The color to tint objects with (as UIColor). Defaults to a medium blue.
///   - floorTextureScale: A CGSize specifying how many times the texture should repeat across the floor (e.g., CGSize(width: 5.0, height: 5.0)). Defaults to 1x1.
///   - archTextureScale: A CGSize specifying how many times the texture should repeat across architecture elements. Defaults to 1x1.
/// - Returns: The URL of the newly created, modified USDZ file in the temporary directory.
/// - Throws: `SceneKitModificationError` if any step fails.
func modifyRoomPlanUSDZ_SceneKit(
    sourceUrl: URL,
    floorTextureURL: URL,
    archTextureURL: URL,
    objectTintColor: UIColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),
    floorTextureScale: CGSize = CGSize(width: 1.0, height: 1.0), // Added scale parameter
    archTextureScale: CGSize = CGSize(width: 1.0, height: 1.0)  // Added scale parameter
) throws -> URL {
    print("Starting USDZ modification using SceneKit (PBR) for: \(sourceUrl.lastPathComponent)")

    // --- 1. Load the Scene ---
    let scene: SCNScene
    do {
        scene = try SCNScene(url: sourceUrl, options: [.checkConsistency: true])
        print("Successfully loaded SCNScene.")
    } catch {
        print("Error loading SCNScene: \(error)")
        throw SceneKitModificationError.sceneLoadingFailed(error)
    }

    // --- 2. Find and Modify Nodes/Materials ---
    var floorModified = false
    var objectsModifiedCount = 0 // Tracks number of GEOMETRY nodes modified
    var archMeshesModifiedCount = 0 // Tracks number of GEOMETRY nodes modified

    // Load textures as UIImage
    guard let floorImage = UIImage(contentsOfFile: floorTextureURL.path) else {
        throw SceneKitModificationError.textureURLError("Failed to load floor texture image at \(floorTextureURL.path)")
    }
    guard let archImage = UIImage(contentsOfFile: archTextureURL.path) else {
        throw SceneKitModificationError.textureURLError("Failed to load arch texture image at \(archTextureURL.path)")
    }
    print("Successfully loaded texture UIImages.")


    // Helper function to apply modifications recursively
    // Now includes texture scaling
    func modifyNodeMaterialsRecursive(node: SCNNode, textureImage: UIImage?, tintColor: UIColor?, textureScale: CGSize?) -> Int {
        var modifiedGeometryCount = 0
        if let geometry = node.geometry {
            var materialModified = false
            for material in geometry.materials {
                // Ensure PBR lighting model (often default for USDZ, but good to be explicit)
                material.lightingModel = .physicallyBased

                if let image = textureImage {
                    material.diffuse.contents = image // Set texture to diffuse slot
                    // Apply texture scaling if provided
                    if let scale = textureScale {
                        // Create a scaling transform for the texture coordinates
                        // SCNMatrix4MakeScale requires Float values
                        material.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(scale.width), Float(scale.height), 1.0)
                        // Ensure wrapping mode allows tiling
                        material.diffuse.wrapS = .repeat
                        material.diffuse.wrapT = .repeat
                    } else {
                        // Reset transform if no scale provided
                         material.diffuse.contentsTransform = SCNMatrix4Identity
                    }
                    materialModified = true
                } else if let color = tintColor {
                    // Set diffuse color directly for tinting effect
                    material.diffuse.contents = color
                    materialModified = true
                }
            }
            if materialModified {
                modifiedGeometryCount += 1
            }
        }

        // Recursively call for children
        for child in node.childNodes {
            // Pass the scale parameter down the recursion
            modifiedGeometryCount += modifyNodeMaterialsRecursive(node: child, textureImage: textureImage, tintColor: tintColor, textureScale: textureScale)
        }
        return modifiedGeometryCount
    }

    // Find top-level nodes by name
    let rootNode = scene.rootNode

    // Find Floor group node
    if let floorGroupNode = rootNode.childNode(withName: "Floor_grp", recursively: true) {
         print("Found 'Floor_grp' node. Applying texture with scale \(floorTextureScale)...")
         // Pass the floor texture scale
         let modifiedCount = modifyNodeMaterialsRecursive(node: floorGroupNode, textureImage: floorImage, tintColor: nil, textureScale: floorTextureScale)
         if modifiedCount > 0 { floorModified = true }
         print("Applied floor texture to \(modifiedCount) geometry nodes under Floor_grp.")
    } else {
         print("Warning: 'Floor_grp' node not found.")
    }

    // Find Objects group node
    if let objectsGroupNode = rootNode.childNode(withName: "Object_grp", recursively: true) {
        print("Found 'Object_grp' node. Applying tint to children...")
        // No texture scale needed for tinting
        objectsModifiedCount = modifyNodeMaterialsRecursive(node: objectsGroupNode, textureImage: nil, tintColor: objectTintColor, textureScale: nil)
        print("Applied tint to \(objectsModifiedCount) geometry nodes within 'Object_grp' group.")
    } else {
         print("Warning: 'Object_grp' node not found.")
    }

     // Find Arch group node
     if let archGroupNode = rootNode.childNode(withName: "Arch_grp", recursively: true) {
         print("Found 'Arch_grp' node. Applying texture with scale \(archTextureScale)...")
         // Pass the arch texture scale
         archMeshesModifiedCount = modifyNodeMaterialsRecursive(node: archGroupNode, textureImage: archImage, tintColor: nil, textureScale: archTextureScale)
         print("Applied arch texture to \(archMeshesModifiedCount) geometry nodes within 'Arch_grp' group.")
     } else {
         // Fallback check for "Walls_grp"
         if let wallsGroupNode = rootNode.childNode(withName: "Walls_grp", recursively: true) {
             print("Found 'Walls_grp' node. Applying texture with scale \(archTextureScale)...")
             archMeshesModifiedCount = modifyNodeMaterialsRecursive(node: wallsGroupNode, textureImage: archImage, tintColor: nil, textureScale: archTextureScale)
             print("Applied arch texture to \(archMeshesModifiedCount) geometry nodes within 'Walls_grp' group.")
         } else {
            print("Warning: 'Arch_grp' or 'Walls_grp' node not found.")
         }
     }


    // --- 3. Export Final Scene to NEW USDZ ---
    let tempDir = FileManager.default.temporaryDirectory
    let finalOutputUrl = tempDir.appendingPathComponent("modified_scenekit_\(UUID().uuidString).usdz")
    print("Attempting to export final scene to NEW USDZ: \(finalOutputUrl.path)")

    var exportError: Error? = nil
    let dispatchGroup = DispatchGroup()
    dispatchGroup.enter()

    // Use scene.write which is asynchronous
    scene.write(to: finalOutputUrl, options: nil, delegate: nil, progressHandler: { totalProgress, error, stop in
        if let error = error {
            print("Error during SceneKit export: \(error)")
            exportError = error
            stop.pointee = true
            dispatchGroup.leave()
        } else if totalProgress >= 1.0 {
            print("SceneKit export progress: Completed")
            dispatchGroup.leave()
        }
    })

    // Wait for the asynchronous export to complete
    dispatchGroup.wait()

    // Check if an error occurred during export
    if let error = exportError {
        print("-----------------------------------------")
        print("Error exporting final USDZ via SceneKit: \(error.localizedDescription)")
        let nsError = error as NSError
        print("Error Domain: \(nsError.domain), Code: \(nsError.code), UserInfo: \(nsError.userInfo)")
        print("-----------------------------------------")
        try? FileManager.default.removeItem(at: finalOutputUrl)
        throw SceneKitModificationError.sceneExportFailed(error)
    }

    guard FileManager.default.fileExists(atPath: finalOutputUrl.path) else {
         print("Error: Export reported success, but final file not found at \(finalOutputUrl.path)")
         throw SceneKitModificationError.sceneExportFailed(NSError(domain: "SceneKitExportError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export finished but file not found."]))
    }

    print("Successfully exported final modified USDZ via SceneKit to: \(finalOutputUrl.path)")


     // --- 4. Final Checks (Optional) ---
     if !floorModified { print("Warning: Floor_grp node was not found or modified.") }
     if objectsModifiedCount == 0 { print("Warning: No geometry was modified under 'Object_grp' group.") }
     if archMeshesModifiedCount == 0 { print("Warning: No geometry was modified under 'Arch_grp'/'Walls_grp' group.") }

     // --- 5. Return the URL of the new file ---
     return finalOutputUrl
}
