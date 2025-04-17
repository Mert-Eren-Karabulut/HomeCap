//
//  WalkthroughView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 3.05.2025.
//


// WalkthroughView.swift
import SwiftUI

struct WalkthroughView: View {
    // State for the currently selected page index
    @State private var currentPageIndex = 0
    // Access AppStorage to track if the walkthrough has been completed
    @AppStorage("hasCompletedWalkthrough") var hasCompletedWalkthrough: Bool = false
    // Environment variable to dismiss the view (used when presented as a sheet)
    @Environment(\.dismiss) var dismiss

    // Load the page data
    let pages = WalkthroughPage.samplePages

    var body: some View {
        VStack {
            // TabView for swipeable pages
            TabView(selection: $currentPageIndex) {
                ForEach(pages.indices, id: \.self) { index in
                    WalkthroughPageView(page: pages[index])
                        .tag(index) // Tag each page with its index
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Page style, hide default dots
            .animation(.interactiveSpring, value: currentPageIndex) // Animate page transitions
            .padding(.bottom, 10)
            // Space between TabView and indicators/button

            // Custom Page Indicators
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(currentPageIndex == index ? Color.primary : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .animation(.spring(), value: currentPageIndex == index) // Animate indicator change
                }
            }
            .padding(.bottom, 30) // Space between indicators and button

            // Next / Finish Button
            Button {
                handleButtonTap()
            } label: {
                HStack {
                    Text(isLastPage() ? "Hadi Başlayalım!" : "İleri") // Change label based on page
                        .bold()
                    Image(systemName: "arrow.right")
                        .bold()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 40)
                .foregroundColor(.white)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .padding(.bottom, 50) // Bottom padding for the button
            // Smooth button transition (optional)
            .animation(.easeInOut, value: isLastPage())

        }
        .background(Color(uiColor: .systemBackground)) // Ensure background color adapts
        .edgesIgnoringSafeArea(.top) // Allow content to go under status bar if needed
    }

    // Check if the current page is the last one
    private func isLastPage() -> Bool {
        return currentPageIndex == pages.count - 1
    }

    // Handle button tap action
    private func handleButtonTap() {
        if isLastPage() {
            // If it's the last page, mark walkthrough as completed and dismiss
            finishWalkthrough()
        } else {
            // Go to the next page with animation
            withAnimation {
                currentPageIndex += 1
            }
        }
    }

    // Action to perform when finishing the walkthrough
    private func finishWalkthrough() {
        print("Walkthrough finished.")
        // Only set the flag if it's the first time (i.e., it's currently false)
        // Although modifying AppStorage directly often handles this, being explicit is safer.
        if !hasCompletedWalkthrough {
             hasCompletedWalkthrough = true
        }
        // Dismiss the view (relevant if presented as a sheet from Settings)
        // For the first launch, the view change in HomeCapApp will handle removal.
        dismiss()
    }
}

#Preview {
    WalkthroughView()
}
