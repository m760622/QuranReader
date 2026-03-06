//
//  Color+Extensions.swift
//  QuranReader
//

import SwiftUI
  import UIKit

// MARK: - Color Hex Initializer
extension Color {
    internal init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Color Persistence Helpers
struct StoredRGBAColor: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.r = Double(r)
            self.g = Double(g)
            self.b = Double(b)
            self.a = Double(a)
        } else {
            self.r = 1
            self.g = 1
            self.b = 1
            self.a = 1
        }
    }

    var color: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

func storedColor(from data: Data, fallback: Color) -> Color {
    guard !data.isEmpty else { return fallback }
    if let decoded = try? JSONDecoder().decode(StoredRGBAColor.self, from: data) {
        return decoded.color
    }
    return fallback
}

func encodeStoredColor(_ color: Color) -> Data {
    (try? JSONEncoder().encode(StoredRGBAColor(color: color))) ?? Data()
}
