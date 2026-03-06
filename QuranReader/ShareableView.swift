import SwiftUI

struct ShareableView: View {
    let ayahText: String
    let surahName: String
    let ayahNumber: Int
    let translationText: String?
    let isDarkMode: Bool
    
    var body: some View {
        ZStack {
            // Background Color
            Color(isDarkMode ? UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0) : UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1.0))
                .edgesIgnoringSafeArea(.all)
            
            // Outer Thick Border
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.06, green: 0.73, blue: 0.51), lineWidth: 12)
                .padding(40)
            
            // Inner Thin Border
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.06, green: 0.73, blue: 0.51), lineWidth: 2)
                .padding(55)
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Arabic Text (Ayah)
                Text(ayahText)
                    .font(.custom("Amiri Quran", size: 55)) // Will fallback to system serif if not installed
                    .multilineTextAlignment(.center)
                    .lineSpacing(15)
                    .foregroundColor(isDarkMode ? Color(red: 0.97, green: 0.98, blue: 0.99) : Color(red: 0.12, green: 0.16, blue: 0.23))
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: 850) // Limits the text width safely within borders
                    .padding(.bottom, (translationText != nil && !translationText!.isEmpty) ? 60 : 0) // Space between Arabic and English
                
                // English Translation (Optional)
                if let translation = translationText, !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 32, weight: .regular, design: .default))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(red: 0.39, green: 0.45, blue: 0.55))
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: 850)
                }
                
                Spacer()
                
                // Surah Name & Ayah Number
                Text("سورة \(surahName) - الآية \(ayahNumber)")
                    .font(.system(size: 35, weight: .bold, design: .default))
                    .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51))
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.bottom, 80)
            }
        }
        .frame(width: 1080, height: 1080) // Standard post size (1:1 ratio)
    }
}

#Preview {
    ShareableView(
        ayahText: "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
        surahName: "الفاتحة",
        ayahNumber: 1,
        translationText: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
        isDarkMode: false
    )
}
