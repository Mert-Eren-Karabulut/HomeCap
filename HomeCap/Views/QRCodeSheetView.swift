//
//  ShareableImage.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 1.05.2025.
//


// QRCodeSheetView.swift
import SwiftUI
import QRCode

// Wrapper for sharing the image data via ActivityView
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct QRCodeSheetView: View {
    @Environment(\.dismiss) var dismiss // Use new dismiss environment variable
    let qrCodeImageData: Data?
    let unitName: String // Pass unit name for context

    @State private var itemToShare: ShareableImage? = nil

    var body: some View {
        NavigationView { // Embed in NavigationView for title and close button
            VStack(spacing: 20) {
                if let data = qrCodeImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding(30) // Add padding around QR code

                    Text("QR Kodu: \(unitName)")
                         .font(.headline)

                    Spacer() // Pushes button to bottom

                    Button {
                        // Prepare image and trigger share sheet
                        itemToShare = ShareableImage(image: uiImage)
                    } label: {
                        Label("QR Kodunu Paylaş", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom)

                } else {
                    Spacer()
                    Text("QR Kodu oluşturulamadı.")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .navigationTitle("QR Kod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { // Changed to trailing for convention
                    Button("Kapat") {
                        dismiss() // Dismiss the sheet
                    }
                }
            }
            // Sheet to present ActivityView for sharing the QR image
            .sheet(item: $itemToShare) { shareable in
                ActivityView(items: [shareable.image]) // Share the UIImage
            }
        }
    }
}

