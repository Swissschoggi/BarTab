import SwiftUI
import UIKit

extension Color {

    private static func barTabAdaptive(
        light: UIColor,
        dark: UIColor
    ) -> Color {
        Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? dark
                    : light
            }
        )
    }

    // MARK: - Primary (burgundy)

    static let barTabPrimary = barTabAdaptive(
        light: UIColor(
            red: 0x6B / 255,
            green: 0x27 / 255,
            blue: 0x37 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xD4 / 255,
            green: 0x89 / 255,
            blue: 0x9A / 255,
            alpha: 1
        )
    )

    // MARK: - Accent (gold)

    static let barTabAccent = barTabAdaptive(
        light: UIColor(
            red: 0xC9 / 255,
            green: 0xA2 / 255,
            blue: 0x27 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xE6 / 255,
            green: 0xC0 / 255,
            blue: 0x65 / 255,
            alpha: 1
        )
    )

    // MARK: - Background (warm cream)

    static let barTabBackground = barTabAdaptive(
        light: UIColor(
            red: 0xF7 / 255,
            green: 0xF1 / 255,
            blue: 0xE3 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x1A / 255,
            green: 0x16 / 255,
            blue: 0x13 / 255,
            alpha: 1
        )
    )

    // MARK: - Text (warm charcoal)

    static let barTabText = barTabAdaptive(
        light: UIColor(
            red: 0x2C / 255,
            green: 0x26 / 255,
            blue: 0x22 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xF5 / 255,
            green: 0xF0 / 255,
            blue: 0xE8 / 255,
            alpha: 1
        )
    )

    // MARK: - Secondary text (warm gray)

    static let barTabSecondary = barTabAdaptive(
        light: UIColor(
            red: 0x9A / 255,
            green: 0x90 / 255,
            blue: 0x84 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xA0 / 255,
            green: 0x98 / 255,
            blue: 0x8C / 255,
            alpha: 1
        )
    )

    // MARK: - Card fill (warm cream)

    static let barTabCardFill = barTabAdaptive(
        light: UIColor(
            red: 0xFF / 255,
            green: 0xFA / 255,
            blue: 0xF0 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x20 / 255,
            green: 0x1C / 255,
            blue: 0x18 / 255,
            alpha: 1
        )
    )

    // MARK: - Card border (soft warm edge)

    static let barTabCardBorder = barTabAdaptive(
        light: UIColor(
            red: 0xEC / 255,
            green: 0xE4 / 255,
            blue: 0xD8 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x30 / 255,
            green: 0x2A / 255,
            blue: 0x24 / 255,
            alpha: 1
        )
    )

    // MARK: - Success green (sage)

    static let barTabSuccess = barTabAdaptive(
        light: UIColor(
            red: 0x5A / 255,
            green: 0x9E / 255,
            blue: 0x6F / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x7A / 255,
            green: 0xBE / 255,
            blue: 0x8F / 255,
            alpha: 1
        )
    )

    // MARK: - Soft pill fill (warm sand)

    static let barTabPillFill = barTabAdaptive(
        light: UIColor(
            red: 0xF2 / 255,
            green: 0xEB / 255,
            blue: 0xDF / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x2C / 255,
            green: 0x26 / 255,
            blue: 0x20 / 255,
            alpha: 1
        )
    )

    // MARK: - Gradient helpers

    static let barTabGradientStart = barTabPrimary

    static let barTabGradientEnd = barTabAccent
}
