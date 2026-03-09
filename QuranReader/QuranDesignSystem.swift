//
//  QuranDesignSystem.swift
//  QuranReader
//

import SwiftUI
import UIKit

// MARK: - Core Design Constants
struct QuranDesign {
    // Colors
    static let primaryGreen = Color(hex: "065B33")
    static let secondaryAccentColor = Color(hex: "816B2E")

    static let dayPrimaryGreen = Color(hex: "065B33")
    static let nightPrimaryGreen = Color(hex: "2ECC71")

    static let daySecondaryAccent = Color(hex: "816B2E")
    static let nightSecondaryAccent = Color(hex: "D4AF37")

    // Spacing & Layout
    static let standardPadding: CGFloat = 16
    static let tightPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 12
    static let tightCornerRadius: CGFloat = 8

    // Premium Effects
    static let glassOpacity: CGFloat = 0.75
    static let cardOpacity: CGFloat = 0.85
    static let surfaceBlur: Material = .ultraThinMaterial
    static let premiumShadowColor = Color.black.opacity(0.12)
    static let premiumShadowRadius: CGFloat = 8
}

// MARK: - View Helpers
extension View {
    func performLightHaptic(enabled: Bool = true) {
        #if !targetEnvironment(simulator)
            guard enabled else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        #endif
    }

    func performMediumHaptic(enabled: Bool = true) {
        #if !targetEnvironment(simulator)
            guard enabled else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        #endif
    }
}
