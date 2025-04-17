// WebView.swift
import SwiftUI
import WebKit // Import WebKit

struct WebView: UIViewRepresentable {
    let url: URL? // The URL to load

    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        // Optional: Add configurations
        // webConfiguration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        // webView.navigationDelegate = context.coordinator // Remove delegate if not needed
        webView.backgroundColor = .secondarySystemBackground
        webView.isOpaque = false

        // Keep scrolling enabled in the webview itself if the content
        // within model-viewer needs it (though often it doesn't rely on WKWebView scrolling)
        // If model-viewer handles all interaction without scrolling the page,
        // you *could* set this to false, but true is safer for compatibility.
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true // Allow bouncing

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let validURL = url else {
            uiView.loadHTMLString("<html><body style='background-color: transparent;'></body></html>", baseURL: nil)
            print("WebView: URL is nil, loading empty page.")
            return
        }

        // Load only if URL changed and not currently loading
        if uiView.url?.absoluteString != validURL.absoluteString && !uiView.isLoading {
            let request = URLRequest(url: validURL)
            uiView.load(request)
            print("WebView: Loading URL: \(validURL)")
        }
    }

    // --- REMOVED Coordinator ---
}

#Preview {
    // Preview with a sample URL
    if let previewURL = URL(string: "https://modelviewer.dev/") { // Model viewer example
        WebView(url: previewURL)
             .frame(height: 300)
             .border(Color.red)
             .padding()
    } else {
        Text("Invalid preview URL")
    }
}
