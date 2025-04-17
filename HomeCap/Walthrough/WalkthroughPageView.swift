// WalkthroughPageView.swift
import SwiftUI

struct WalkthroughPageView: View {
    let page: WalkthroughPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer() // Pushes content down slightly

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 350) // Adjust size as needed
                .padding(.bottom, 30)
                .padding(.top, 30)

            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                // --- ADDED MODIFIER ---
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion

            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40) // Keep horizontal padding
                // --- ADDED MODIFIER ---
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion

            Spacer() // Pushes content towards center vertically
            Spacer() // Add more space at bottom
        }
        .padding(.bottom, 60) // Extra padding at the bottom to avoid button overlap
        // Add horizontal padding to the whole VStack if needed,
        // or adjust text padding above.
        // .padding(.horizontal)
    }
}

#Preview {
    WalkthroughPageView(page: WalkthroughPage.samplePages[0])
}
