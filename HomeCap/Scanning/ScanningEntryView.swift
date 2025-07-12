//
//  ScanningEntryView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 23.04.2025.
//

import AVKit
import RoomPlan
import SwiftUI
import UIKit

// --- CaptureView (Uses initializer injection) ---
struct CaptureView: UIViewRepresentable {
    // Passed from ScanningView via initializer
    let captureController: RoomCaptureController

    func makeUIView(context: Context) -> RoomCaptureView {
        // Controller's view should be ready
        return captureController.roomCaptureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // Usually no updates needed here for RoomCaptureView
    }
}

// --- ActivityView (Needed for local download/share) ---
struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]  // Expecting [URL] from filesToShare
    var activities: [UIActivity]? = nil

    func makeUIViewController(
        context: UIViewControllerRepresentableContext<ActivityView>
    ) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: activities
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: UIViewControllerRepresentableContext<ActivityView>
    ) {}
}

// --- ScanningView (Using @StateObject, Updated UI, Fixed Timing) ---
struct ScanningView: View {
    @Environment(\.dismiss) var dismiss  // New way for sheets/covers
    // Use @StateObject for stable lifecycle management
    @StateObject private var captureController = RoomCaptureController()
    let scanName: String
    let latitude: Double?
    let longitude: Double?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Pass controller via initializer to CaptureView
            CaptureView(captureController: captureController)
                .ignoresSafeArea()
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("İptal") {  // Cancel button
                            Task { @MainActor in
                                print("Idle Timer Disabled (Cancel Button)")
                                UIApplication.shared.isIdleTimerDisabled = false
                                captureController.stopSession()  // Stop scanning
                                dismiss()  // Dismiss the fullScreenCover
                            }
                        }
                        // Disable Cancel button while processing results
                        .disabled(captureController.isProcessing)
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Bitti") {  // Done button
                            Task { @MainActor in
                                captureController.stopSession()
                                print("Idle Timer Disabled (Done Button)")
                                UIApplication.shared.isIdleTimerDisabled = false
                            }
                        }
                        // Hide Done button if Action button is visible,
                        // OR if not scanning, OR if processing results.
                        .opacity(
                            captureController.showActionButton
                                || !captureController.isScanning
                                || captureController.isProcessing ? 0 : 1
                        )
                        .disabled(
                            !captureController.isScanning
                                || captureController.isProcessing
                        )
                    }
                }
                .onAppear {
                    captureController.scanName = self.scanName  // Pass name to controller
                    captureController.latitude = self.latitude
                    captureController.longitude = self.longitude
                    print(
                        "ScanningView appeared, setting scan name: \(self.scanName)"
                    )

                    // Start session cleanly when view appears
                    Task { @MainActor in
                        captureController.startSession()
                    }
                }
                .onDisappear {
                    // Ensure idle timer is re-enabled when the view disappears
                    print("ScanningView disappeared. Re-enabling idle timer.")
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .overlay {  // Show activity indicator during processing
                    if captureController.isProcessing {
                        VStack {
                            ProgressView(
                                captureController.forceLocalDownloadForTesting
                                    ? "Dosyalar İşleniyor..."
                                    : "Model Yükleniyor..."
                            )
                            .padding()
                            .background(.thickMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                        .allowsHitTesting(false)  // Block interaction during processing
                    }
                }

            // --- Process Button (Shows after "Done" and result received) ---
            VStack {
                Spacer()  // Pushes button to bottom
                if captureController.showActionButton {
                    Button {
                        // Trigger the processing function in the controller
                        Task {
                            await captureController.processScanResult()
                        }
                    } label: {
                        // Label changes based on the testing flag
                        Text(
                            captureController.forceLocalDownloadForTesting
                                ? "Save Locally" : "Tamamla ve Daire Oluştur"
                        )
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)  // Make button wide
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(
                        captureController.forceLocalDownloadForTesting
                            ? .green : .blue
                    )  // Different colors
                    .cornerRadius(25)
                    .disabled(captureController.isProcessing)  // Disable while processing
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }

        }  // End ZStack
        .onChange(of: captureController.isScanning) { _, isScanningActive in
            print(
                "Scanning state changed: \(isScanningActive). Setting idle timer disabled: \(isScanningActive)"
            )
            UIApplication.shared.isIdleTimerDisabled = isScanningActive
            // REMOVED the logic for showing action button from here
        }
        // --- NEW: Handle Action Button based on finalResult state ---
        .onChange(of: captureController.isScanning) { _, newValue in
            // Show the action button only when scanning stops AND a new non-nil result arrives
            // Check isScanning *before* setting showActionButton
            guard !captureController.isScanning else { return }

            if newValue != nil {
                // Update state on the main thread
                Task { @MainActor in
                    // Only show if not already processing something else
                    if !captureController.isProcessing {
                        captureController.showActionButton = true
                        print("Scan result received, showing action button.")
                    }
                }
            }
        }
        .sheet(isPresented: $captureController.showShareSheet) {  // Present share sheet
            // Use filesToShare state variable from controller
            if let urls = captureController.filesToShare, !urls.isEmpty {
                ActivityView(items: urls)  // Pass the file URLs
                    .onDisappear {
                        print("Share sheet dismissed.")
                        // Decide if view should dismiss after sharing
                        // presentationMode.wrappedValue.dismiss()
                    }
            } else {
                // Fallback if URLs are missing (shouldn't happen if logic is correct)
                Text("Error: No files available to share.")
                    .padding()
                    .onAppear {  // Auto-dismiss fallback alert/text
                        Task { @MainActor in
                            try await Task.sleep(nanoseconds: 2_000_000_000)  // Show for 2 secs
                            captureController.showShareSheet = false
                        }
                    }
            }
        }
        .alert(item: $captureController.currentScanError) { errorWrapper in
            // Alert logic remains the same, but ensure idle timer is off after alert dismissal if needed
            let isSuccess =
                (errorWrapper.error as NSError).domain == "UploadSuccess"
            let title = isSuccess ? "Başarılı" : "Hata"
            return Alert(
                title: Text(title),
                message: Text(
                    "\(errorWrapper.guidance)\(isSuccess ? "" : "\nDetails: \(errorWrapper.error.localizedDescription)")"
                ),
                dismissButton: .default(Text("OK")) {
                    // --- Ensure idle timer is off after potentially pausing for alert ---
                    print("Alert dismissed. Ensuring idle timer is disabled.")
                    UIApplication.shared.isIdleTimerDisabled = false
                    // --- End Ensure ---

                    if isSuccess {
                        print(
                            "Upload successful, dismissing scanner via alert."
                        )
                        NotificationCenter.default.post(name: .scanUploadDidSucceed, object: nil)
                        dismiss()
                    }
                    captureController.currentScanError = nil
                }
            )
        }
    }  // End body

}  // End ScanningView

// --- ScanningEntryView definition ---
struct ScanningEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scanName: String = ""
    @State private var player: AVPlayer? = nil
    @StateObject private var locationManager = LocationManager()
    @State private var showingLidarAlert = false
    @State private var shouldNavigateToScanner = false

    var body: some View {
        // Keep existing NavigationStack if preferred, or remove if nested in ModelsView's stack
        // Assuming it's presented within ModelsView's NavigationStack, remove this one:
        // NavigationStack {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.matrix")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .foregroundColor(.accentColor)
                .padding(.top, 30)  // Add padding back if NavigationStack removed

            Text("Hadi Başlayalım").font(.title).bold()

            //            Text(
            //                "Modelinize bir isim verin ve eğitici videomuzu izleyin"
            //            )
            //            .font(.body)
            //            .multilineTextAlignment(.center)
            //            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 5) {  // Group label and textfield
                Text("Model Adı")
                    .font(.headline)
                // .padding(.leading) // Add leading padding if needed within the horizontal padding below

                TextField("Modele bir isim verin...", text: $scanName)  // Updated placeholder
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                // Removed horizontal padding here, applied to VStack instead
            }
            .padding(.horizontal)  // Apply horizontal padding to the VStack
            // --- Video Player Section ---
            VStack(alignment: .leading, spacing: 5) {
                Text("Nasıl Yapılır?")
                    .font(.subheadline).bold()

                // Use the player state variable
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 200)  // Adjust height as needed
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                        )
                        // --- MODIFICATION: Autoplay on Appear ---
                        .onAppear {
                            print(
                                "VideoPlayer appeared, seeking to zero and playing."
                            )
                            player.seek(to: .zero)  // Seek to beginning
                            player.play()  // Start playback
                        }
                    // --- END MODIFICATION ---
                } else {
                    // Placeholder if video failed to load in view's onAppear
                    HStack {
                        Spacer()
                        VStack {  // Center placeholder content
                            ProgressView()  // Show activity indicator while loading URL
                            Text("Video yükleniyor...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(height: 200)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            Group {
                if let location = locationManager.lastKnownLocation {
                    //                    Text(
                    //                        "Konum Bilgisi Alındı"
                    //                    )
                    //                    .font(.caption)
                    //                    .foregroundColor(.secondary)
                    Label(
                        "Konum bilgisi alındı",
                        systemImage: "location.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else if locationManager.locationError != nil {
                    Text("Konum alınamadı.")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if locationManager.authorizationStatus == .denied {
                    Text("Konum izni gerekli.")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    // Show nothing or a loading indicator while waiting
                    // ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 5)  // Add small space below location text
            Spacer()

            // --- MODIFIED: NavigationLink ---
            Button {
                // --- NEW --- Perform LiDAR check before navigating
                if RoomCaptureSession.isSupported {
                    // Device supports RoomPlan (has LiDAR)
                    shouldNavigateToScanner = true  // Trigger navigation
                } else {
                    // Device does not support RoomPlan
                    showingLidarAlert = true  // Trigger alert
                }
            } label: {
                Text("Başla")
                    .font(.title2).bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        scanName.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty ? Color.gray : Color.blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .disabled(
                scanName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .padding(.horizontal)
            .padding(.bottom)
            // --- END MODIFICATION ---

        }
        // Remove padding top if NavigationStack is removed and relying on parent padding
        // .padding(.top, 30)
        .navigationTitle("Yeni Model Oluştur")  // More specific title
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("İptal") {
                    dismiss()  // Dismiss the fullScreenCover
                }
            }
        }
        // --- NEW --- Navigation Destination for programmatic navigation
        .navigationDestination(isPresented: $shouldNavigateToScanner) {
            ScanningView(
                scanName: scanName,
                latitude: locationManager.lastKnownLocation?.latitude,
                longitude: locationManager.lastKnownLocation?.longitude
            )
        }
        .alert("Desteklenmeyen Cihaz", isPresented: $showingLidarAlert) {
            Button("Tamam") {}  // Simple dismiss button
        } message: {
            Text(
                "Bu cihazda modelleme yapmak için gerekli LiDAR sensörü bulunmamaktadır. Modelleme özelliği yalnızca iPhone 12 Pro ve üzeri Pro modellerde veya iPad Pro'larda kullanılabilir."
            )
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            // Create player only if it hasn't been created yet
            if player == nil {
                guard
                    let url = Bundle.main.url(
                        forResource: "guidance",
                        withExtension: "mp4"
                    )
                else {
                    print(
                        "Error: Could not find guidance.mp4 in the app bundle."
                    )
                    // Optionally set an error state here to show a different message
                    return
                }
                player = AVPlayer(url: url)
                print("AVPlayer initialized.")
            }
            // If player exists, ensure it seeks to start if view reappears but video shouldn't autoplay again unless desired
            // player?.seek(to: .zero) // Optionally seek here too if needed on every appear
            locationManager.requestLocationAccessOrUpdate()
        }
        .onDisappear {
            // --- NEW: Pause player when view disappears ---
            player?.pause()
            // --- END NEW ---
        }
    }
    // Helper to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// --- Preview definition ---
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ScanningEntryView()
            .environmentObject(AuthManager())
        // Previews for ScanningView might require mocking/adjustments
    }
}
