import SwiftUI
import UIKit

struct SurahHeaderOrnament: View {
    let name: String
    let color: Color
    let titleFontName: String?
    let basmalaFontName: String?

    init(
        name: String,
        color: Color,
        titleFontName: String? = nil,
        basmalaFontName: String? = nil
    ) {
        self.name = name
        self.color = color
        self.titleFontName = titleFontName
        self.basmalaFontName = basmalaFontName
    }

    private var normalizedSurahName: String {
        let strippedScalars = name.unicodeScalars.filter { scalar in
            !CharacterSet.nonBaseCharacters.contains(scalar)
                && scalar.properties.generalCategory != .format
                && scalar != "\u{0640}"
        }
        return String(String.UnicodeScalarView(strippedScalars))
            .replacingOccurrences(of: "سورة", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private var shouldShowBasmala: Bool {
        !normalizedSurahName.contains("الفاتحة") && !normalizedSurahName.contains("التوبة")
    }

    private var basmalaFont: Font {
        if let basmalaFontName, UIFont(name: basmalaFontName, size: 26) != nil {
            return .custom(basmalaFontName, size: 26)
        }
        return .system(size: 26, weight: .medium, design: .serif)
    }

    private var titleFont: Font {
        if let titleFontName, UIFont(name: titleFontName, size: 34) != nil {
            return .custom(titleFontName, size: 34)
        }
        return .system(size: 34, weight: .bold, design: .serif)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                DecorativeStar(color: color)
                    .frame(width: 40, height: 40)

                Text(name)
                    .font(titleFont)
                    .foregroundColor(color)
                    .multilineTextAlignment(.center)

                DecorativeStar(color: color)
                    .frame(width: 40, height: 40)
            }

            if shouldShowBasmala {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0), color.opacity(0.14)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 36, height: 1)

                    Text("﷽")
                        .font(basmalaFont)
                        .foregroundColor(.white.opacity(0.96))
                        .padding(.horizontal, 38)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .stroke(color.opacity(0.28), lineWidth: 1)
                                )
                        )
                        .multilineTextAlignment(.center)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.14), color.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 36, height: 1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.vertical, 10)
    }
}

struct DecorativeStar: View {
    let color: Color

    var body: some View {
        ZStack {
            // Rotating square 1
            Rectangle()
                .stroke(color, lineWidth: 1.5)
                .rotationEffect(.degrees(0))

            // Rotating square 2
            Rectangle()
                .stroke(color, lineWidth: 1.5)
                .rotationEffect(.degrees(45))

            // Inner Circle
            Circle()
                .fill(color.opacity(0.1))
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 1)
                )
                .frame(width: 20, height: 20)
        }
    }
}

/// A decorative marker for Ayah numbers
struct AyahMarker: View {
    let number: Int
    let color: Color
    var size: CGFloat = 32

    private var numberFontSize: CGFloat {
        max(9, size * 0.34)
    }

    var body: some View {
        ZStack {
            // Islamic Star Background
            DecorativeStar(color: color)
                .frame(width: size, height: size)

            // Ayah Number
            Text("\(number)")
                .font(.system(size: numberFontSize, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .environment(\.layoutDirection, .leftToRight)  // Numbers stay LTR
    }
}

#Preview {
    VStack(spacing: 40) {
        SurahHeaderOrnament(name: "سورة الفاتحة", color: Color(red: 0.2, green: 0.6, blue: 0.45))

        AyahMarker(number: 7, color: Color(red: 0.2, green: 0.6, blue: 0.45))
    }
    .padding()
}
