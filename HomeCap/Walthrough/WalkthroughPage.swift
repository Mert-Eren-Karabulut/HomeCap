//
//  WalkthroughPage.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 3.05.2025.
//


// WalkthroughPage.swift
import Foundation
import SwiftUI // Needed for Hashable conformance on Color if used directly

// Data structure for a single walkthrough page
struct WalkthroughPage: Identifiable, Hashable {
    let id = UUID()
    let imageName: String // Name of the image in your Assets catalog
    let title: String
    let description: String
}

// Extension to provide sample data (replace with your actual content)
extension WalkthroughPage {
    static var samplePages: [WalkthroughPage] = [
        WalkthroughPage(
            imageName: "1", // Placeholder: Add 'walkthrough_scan.png' to Assets
            title: "HomeCap’e Hoş Geldiniz",
            description: "Bu uygulama ile dairelerinizi dakikalar içerisinde 3D modelleyebilir, ilan linkleri ekleyebilir ve QR kodla kolayca paylaşabilirsiniz."
        ),
        WalkthroughPage(
            imageName: "2", // Placeholder: Add 'walkthrough_edit.png' to Assets
            title: "Önce Dairenizi Modellemelisiniz",
            description: "Modeller sekmesinden “Yeni Model Oluştur” butonuna basın."
        ),
        WalkthroughPage(
            imageName: "3", // Placeholder: Add 'walkthrough_share.png' to Assets
            title: "Modelleme Nasıl Yapılır?",
            description: "'Yeni Model Oluştur' butonuna basıldıktan sonra eğitici videomuzdan destek alabilirsiniz."
        ),
         WalkthroughPage(
             imageName: "4", // Placeholder: Add 'walkthrough_analytics.png' to Assets
             title: "3D Modelinizi İnceleyin",
             description: "3D Modelinizi anında görüntüleyip beğenmediğiniz taktirde tekrar modelleme yapabilirsiniz."
         ),
        WalkthroughPage(
            imageName: "5", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "Dairenizi Oluşturun",
            description: "Daireler sekmesinden 'Yeni Daire Oluştur' butonuna basın."
        ),
        WalkthroughPage(
            imageName: "6", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "Kısaca Dairenizi Tanıtın",
            description: "Burada daha önceden oluşturduğunuz daire 3D Model'ini seçebilirsiniz."
        ),
        WalkthroughPage(
            imageName: "7", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "İlan Linkleri Ekleyin",
            description: "Dairenize farklı sitelerdeki ilan linklerini ekleyebilirsiniz."
        ),
        WalkthroughPage(
            imageName: "8", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "QR Code ve Linkleriniz Hazır ",
            description: "Müşterilerinizle paylaşabileceğiniz QR Code ve canlı linkiniz hazır."
        ),
        WalkthroughPage(
            imageName: "9", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "3D İlan Linkiniz Yayında",
            description: "Müşterilerinize hızlıca interaktif bir deneyim sunabilirsiniz."
        ),
        WalkthroughPage(
            imageName: "10", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "3D İlan Linkiniz Yayında",
            description: "Daireniz ile ilgili tüm detaylar için ilanlara yönlendirebilirsiniz."
        ),
        WalkthroughPage(
            imageName: "11", // Placeholder: Add 'walkthrough_analytics.png' to Assets
            title: "Kullanım Klavuzu",
            description: "Dilediğiniz zaman ayarlar menüsünden bu eğitici içeriğe tekrar ulaşabilirsiniz."
        )
    ]
}
