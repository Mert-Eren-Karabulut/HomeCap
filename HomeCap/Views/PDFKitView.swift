//
//  PDFKitView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 2.05.2025.
//


// PDFKitView.swift
import SwiftUI
import PDFKit // Import PDFKit

// A SwiftUI view that wraps the UIKit PDFView for displaying PDFs.
struct PDFKitView: View {
    @Environment(\.dismiss) var dismiss // Use dismiss environment variable
    let pdfURL: URL // The URL of the PDF file to display

    var body: some View {
        NavigationView { // Embed in NavigationView for title and close button
            PDFViewRepresentable(url: pdfURL)
                .navigationTitle(pdfURL.lastPathComponent.prefix(Int(pdfURL.lastPathComponent.count / 2)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { // Changed to trailing
                        Button("Kapat") {
                            dismiss() // Dismiss the sheet
                        }
                    }
                }
        }
    }
}

// The UIViewRepresentable wrapper for PDFView
struct PDFViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true // Scale document to fit view
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update the view if needed, e.g., if the URL changes
        // Check if the document needs updating
        if uiView.document?.documentURL != self.url {
             uiView.document = PDFDocument(url: self.url)
        }
    }
}

// MARK: - Preview
#Preview {
    // Attempt to load a dummy PDF for preview.
    // IMPORTANT: Replace "kvkk" with an actual PDF file added to your project bundle for preview to work.
    if let previewURL = Bundle.main.url(forResource: "eula", withExtension: "pdf") {
         PDFKitView(pdfURL: previewURL)
    } else {
         Text("Error: Add kvkk.pdf to your project bundle for preview.")
    }
}
