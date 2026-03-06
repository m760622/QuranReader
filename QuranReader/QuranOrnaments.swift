import SwiftUI

struct SurahHeaderOrnament: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Left Pattern
            DecorativeStar(color: color)
                .frame(width: 40, height: 40)

            // Surah Name
            Text(name)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(color)
                .multilineTextAlignment(.center)

            // Right Pattern
            DecorativeStar(color: color)
                .frame(width: 40, height: 40)
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
