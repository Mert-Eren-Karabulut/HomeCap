//
//  RoomCaptureController.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 23.04.2025.
//

import ARKit  // Keep for NSObject requirement
import CoreLocation
import Foundation
import Observation
import RoomPlan

// Helper struct for identifiable errors in Alerts
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: Error
    let guidance: String

    init(error: Error, guidance: String = "Bir Hata Oluştu") {
        self.error = error
        self.guidance = guidance
    }
}

// Ensure final, inherits NSObject, conforms to ObservableObject, uses @Observable
@Observable
final class RoomCaptureController: NSObject, RoomCaptureViewDelegate,
    RoomCaptureSessionDelegate, ObservableObject
{

    // --- Configuration ---
    /// Set to true to force local download/share via the 'Process' button for testing.
    let forceLocalDownloadForTesting: Bool = false  // <-- USER TESTING FLAG

    // --- Properties ---
    var roomCaptureView: RoomCaptureView
    var sessionConfig: RoomCaptureSession.Configuration
    var scanName: String = "Untitled Scan"
    var latitude: Double? = nil
    var longitude: Double? = nil

    // --- State ---
    var isScanning: Bool = false
    var finalResult: CapturedRoom? = nil  // Stores the single scan result
    var showActionButton: Bool = false  // Controls visibility of the final "Process" button
    var isProcessing: Bool = false  // Tracks export/upload/sharing activity
    var currentScanError: ErrorWrapper? = nil  // For showing errors/success in alerts

    // State for local download/share sheet
    var showShareSheet: Bool = false
    var filesToShare: [URL]? = nil

    // --- Initialization ---
    override init() {
        roomCaptureView = RoomCaptureView(frame: .zero)  // Use .zero frame
        sessionConfig = RoomCaptureSession.Configuration()
        super.init()  // Call super.init() because we inherit from NSObject
        // Set delegates AFTER super.init()
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        print("RoomCaptureController Initialized")
    }

    // --- NSCoding Stubs (Required due to NSObject inheritance) ---
    required init?(coder: NSCoder) {
        fatalError(
            "init(coder:) has not been implemented - NSCoding not needed"
        )
    }

    func encode(with coder: NSCoder) {
        fatalError(
            "encode(with:) has not been implemented - NSCoding not needed"
        )
    }

    // --- Session Control ---
    @MainActor
    func startSession() {
        print("Starting session...")
        // Reset all relevant state for a new session
        isScanning = true
        finalResult = nil
        showActionButton = false
        isProcessing = false
        showShareSheet = false
        filesToShare = nil
        currentScanError = nil  // Clear previous errors
        roomCaptureView.captureSession.run(configuration: sessionConfig)
        print("RoomCapture Session Started.")
    }

    @MainActor
    func stopSession() {
        guard isScanning else {
            print("Stop session called but not scanning.")
            return
        }  // Prevent stopping if already stopped
        print("Stopping session...")
        isScanning = false  // Set state immediately
        roomCaptureView.captureSession.stop()
        print("RoomCapture Session Stop requested.")
        // Result assignment and button visibility handled by delegate + .onChange
    }

    // --- Delegate Methods ---
    func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        Task { @MainActor in currentScanError = nil }  // Clear previous error
        guard error == nil else {
            print("Error during capture: \(error!)")
            Task { @MainActor in
                currentScanError = ErrorWrapper(
                    error: error!,
                    guidance: "Modelleme Hatası"
                )
            }
            return false
        }
        print("Received room data for processing...")
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        guard error == nil else {
            print("Error processing final room data: \(error!)")
            // Update state on main thread
            Task { @MainActor in
                currentScanError = ErrorWrapper(
                    error: error!,
                    guidance: "Model verisi işleme hatası."
                )
            }
            return
        }
        // Store the single final result on main thread
        // This will trigger the .onChange modifier in the View
        Task { @MainActor in
            finalResult = processedResult
            print("Final room data processed and stored.")
        }
    }

    /// Exports the given captured structure in JSON format to a URL.
    func exportJson(from capturedRoom: CapturedRoom, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(capturedRoom)
        try data.write(to: url)
    }

    // --- Process Scan Result (Upload or Save Locally) ---
    @MainActor
    func processScanResult() async {
        guard let resultToProcess = finalResult else {
            print("Attempted processing with no final result.")
            currentScanError = ErrorWrapper(
                error: NSError(
                    domain: "ProcessingError",
                    code: 4001,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Scan result not available."
                    ]
                ),
                guidance: "Modelleme sonucu kullanılabilir değil"
            )
            return
        }

        let performUpload = !forceLocalDownloadForTesting  // Determine action based on flag

        isProcessing = true
        currentScanError = nil  // Clear previous errors
        showShareSheet = false
        filesToShare = nil
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempDir = FileManager.default.temporaryDirectory

        // Define temporary file URLs
        let metadataJsonUrl = tempDir.appendingPathComponent(
            "scan_metadata_\(timestamp).json"
        )
        let usdzUrl = tempDir.appendingPathComponent(
            "scan_model_\(timestamp).usdz"
        )

        var createdUrls: [URL] = []  // Track successfully created files

        // Defer cleanup block (only runs on successful upload path)
        defer {
            Task { @MainActor in
                // Check if upload succeeded (isProcessing is false AND no error OR specific success error domain)
                let noErrorOrSuccess =
                    self.currentScanError == nil
                    || (self.currentScanError!.error as NSError).domain
                        == "UploadSuccess"
                if performUpload && !self.isProcessing && noErrorOrSuccess {
                    self.cleanupTempFiles(urls: createdUrls)
                } else if self.currentScanError != nil
                    && (self.currentScanError!.error as NSError).domain
                        != "UploadSuccess"
                {
                    print("Skipping cleanup due to processing error.")
                } else if !performUpload {
                    print("Skipping cleanup for local share.")
                }
            }
        }

        do {
            // --- Export Files ---
            print("Exporting files...")
            // 1. Load the catalog and export a detailed USDZ model
            let modelProvider = try? CapturedRoom.ModelProvider.load()
            try resultToProcess.export(
                to: usdzUrl,
                modelProvider: modelProvider,  // <-- NEW
                exportOptions: .model
            )

            //also export the json
            try exportJson(from: resultToProcess, to: metadataJsonUrl)

            createdUrls.append(metadataJsonUrl)
            createdUrls.append(usdzUrl)
            print(
                "Parametric metadata JSON export successful: \(metadataJsonUrl.lastPathComponent)"
            )
            print("USDZ model export successful: \(usdzUrl.lastPathComponent)")

            // --- <<< NEW: Modify the exported USDZ >>> ---
            //            print("Attempting to modify USDZ materials...")
            //            // Ensure you have valid URLs for your textures
            //            guard let floorTexture = Bundle.main.url(forResource: "floorTex", withExtension: "jpg"), // Replace with your actual texture names/types
            //                  let archTexture = Bundle.main.url(forResource: "wallTex", withExtension: "jpg") else {
            //                throw NSError(domain: "TextureError", code: 4005, userInfo: [NSLocalizedDescriptionKey: "Could not find texture files in bundle."])
            //            }
            //
            //            try modifyRoomPlanUSDZ(at: usdzUrl, floorTextureURL: floorTexture, archTextureURL: archTexture)
            //            print("USDZ material modification successful.")
            // --- <<< End of Modification >>> ---

            // --- Modify the exported USDZ (using intermediate + new output) ---
            print("Attempting to modify USDZ materials using SceneKit...")
            guard
                let floorTexture = Bundle.main.url(
                    forResource: "floorTex",
                    withExtension: "jpg"
                ),  // Use actual names/extensions
                let archTexture = Bundle.main.url(
                    forResource: "wallTex",
                    withExtension: "jpg"
                )
            else {
                throw NSError(
                    domain: "TextureError",
                    code: 4005,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not find texture files in bundle."
                    ]
                )
            }

            // Call the SceneKit modification function, passing the ORIGINAL usdzUrl as sourceUrl
            let modifiedUsdzUrl = try modifyRoomPlanUSDZ_SceneKit(
                sourceUrl: usdzUrl,  // Pass the original URL here
                floorTextureURL: floorTexture,
                archTextureURL: archTexture
                    // tintColor is optional, defaults to blue
            )
            print(
                "SceneKit USDZ material modification successful. New file at: \(modifiedUsdzUrl.path)"
            )
            // --- End of Modification ---

            // --- Conditional Action ---
            if performUpload {
                // 3a. Prepare Data for Upload - Use the MODIFIED URL
                print("Preparing data for upload...")
                let metadataJsonData = try Data(contentsOf: metadataJsonUrl)
                // Load data from the NEWLY created modified file
                let modifiedUsdzData = try Data(contentsOf: modifiedUsdzUrl)

                // 4a. Upload JSON and USDZ
                print("Starting upload...")
                let uploadEndpoint = "scans"  // !!! REPLACE !!!

                await API.shared.uploadScanResults(
                    endpoint: uploadEndpoint,
                    name: self.scanName,
                    latitude: self.latitude,
                    longitude: self.longitude,
                    jsonFileName: metadataJsonUrl.lastPathComponent,  // Keep original JSON name
                    jsonData: metadataJsonData,
                    modelFileName: modifiedUsdzUrl.lastPathComponent,  // Use NEW filename
                    modelData: modifiedUsdzData  // Use NEW data
                ) { result in
                    Task { @MainActor in  // Ensure state updates run on main thread
                        self.isProcessing = false  // Finished network activity
                        switch result {
                        case .success:
                            print("Upload finished successfully!")
                            self.showActionButton = false  // Hide button on success
                            self.currentScanError = nil  // Clear potential previous errors
                            // Use ErrorWrapper for success message via alert
                            self.currentScanError = ErrorWrapper(
                                error: NSError(
                                    domain: "UploadSuccess",
                                    code: 0
                                ),
                                guidance: "Model Yüklendi!"
                            )
                            self.cleanupTempFiles(
                                urls: createdUrls + [modifiedUsdzUrl]
                            )
                        // Cleanup will happen in defer block
                        case .failure(let uploadError):
                            print("Upload failed: \(uploadError)")
                            self.currentScanError = ErrorWrapper(
                                error: uploadError,
                                guidance: "Model Yüklenirken Hata Oluştu!"
                            )
                            self.showActionButton = true  // Allow retry by keeping button visible
                        }
                    }
                }
            } else {
                // 3b. Prepare for Local Download (Share Sheet) - Use MODIFIED URL
                print("Preparing files for local share...")
                // Share original JSON and the NEW modified USDZ
                self.filesToShare = [metadataJsonUrl, modifiedUsdzUrl]
                if self.filesToShare?.isEmpty ?? true {
                    throw NSError(
                        domain: "ProcessingError",
                        code: 4004,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "No files were exported for sharing."
                        ]
                    )
                }

                // 4b. Trigger Share Sheet
                self.showShareSheet = true
                self.isProcessing = false
                self.showActionButton = false
                print(
                    "Ready to show share sheet for: \(self.filesToShare?.map { $0.lastPathComponent } ?? [])"
                )
            }

        } catch {
            // Catch errors from export or file I/O
            print("Error during export or processing: \(error)")
            Task { @MainActor in  // Ensure UI update runs on main thread
                currentScanError = ErrorWrapper(
                    error: error,
                    guidance: "Dosya hazırlama hatası"
                )
                isProcessing = false  // Ensure processing state is reset on error
                showActionButton = true  // Allow retry
            }
        }
    }

    // --- Helper to clean up temp files ---
    private func cleanupTempFiles(urls: [URL]) {
        let fileManager = FileManager.default
        print("Attempting cleanup of temp files...")
        for url in urls {
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    print("Removed temporary file: \(url.lastPathComponent)")
                } else {
                    print(
                        "Temp file not found for removal: \(url.lastPathComponent)"
                    )
                }
            } catch {
                print(
                    "Warning: Could not remove temporary file \(url.path): \(error)"
                )
            }
        }
    }
}
