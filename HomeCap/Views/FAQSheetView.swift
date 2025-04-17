//
//  FAQSheetView.swift
//  HomeCap
//
//  Created by Mert Eren Karabulut on 2.05.2025.
//


// FAQSheetView.swift
import SwiftUI

struct FAQSheetView: View {
    @Environment(\.dismiss) var dismiss // Sayfayı kapatmak için

    var body: some View {
        NavigationView { // Başlık ve kapatma düğmesi için NavigationView
            ScrollView { // Uzun içerik için ScrollView
                VStack(alignment: .leading, spacing: 15) {
                    // SSS içeriği
                    faqItem(
                        question: "1. HomeCap ne işe yarar?",
                        answer: "HomeCap, portföyünüzü alıcılarınıza en iyi şekilde tanıtabilmeniz için tasarlanmıştır. Evleri 3 boyutlu bir şekilde modelleyerek emlak piyasasındaki en yorucu ve zaman alan aşama olan ev turlarını sadece ciddi alıcılar ile yapabilmenizi sağlar."
                    )

                    Divider() // Sorular arasına ayırıcı

                    faqItem(
                        question: "2. Neden üye olmak zorundayım?",
                        answer: "Sistemimiz oluşturacağınız üyelik sayesinde verileriniz gizli bir şekilde tutulur. Size özel sayfa tıklanma ve envanter analizleri gibi önemli metrikleri sağlayabilmemiz için bir hesabınız olmalıdır."
                    )

                    Divider()

                    faqItem(
                        question: "3. Telefonumda çalışır mı?",
                        answer: "HomeCap modelleme yapabilmek için iPhone Pro modellerindeki Lidar sensörü kullanır. Bu sebeple modelleme yapabilmek için iPhone 12 Pro ve sonrası bir Pro modelli telefona veya bir iPad Pro ya sahip olmanız gerekir."
                    )

                    Divider()

                    faqItem(
                        question: "4. Nasıl kullanırım?",
                        answer: "HomeCap'e kaydolduktan sonra uygulama içerisindeki video yönergelerle çok basit bir şekilde dakikalar içerisinde portföyünüzdeki daireler için özel sayfalar oluşturabileceksiniz."
                    )
                }
                .padding() // İçeriğe padding ekle
            }
            .navigationTitle("Sıkça Sorulan Sorular") // Sayfa başlığı
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss() // Sayfayı kapat
                    }
                }
            }
        }
    }

    // SSS öğesini biçimlendirmek için yardımcı fonksiyon
    @ViewBuilder
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(question)
                .font(.headline) // Soru başlık fontunda
                .foregroundColor(.primary) // Ana metin rengi
            Text(answer)
                .font(.body) // Cevap normal metin fontunda
                .foregroundColor(.secondary) // İkincil metin rengi
        }
    }
}

#Preview {
    FAQSheetView()
}
