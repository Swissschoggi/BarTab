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

    // MARK: - Primary (rich burgundy)

    static let barTabPrimary = barTabAdaptive(
        light: UIColor(
            red: 0x7A / 255,
            green: 0x1B / 255,
            blue: 0x2E / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xE8 / 255,
            green: 0x6B / 255,
            blue: 0x7A / 255,
            alpha: 1
        )
    )

    // MARK: - Accent (warm gold)

    static let barTabAccent = barTabAdaptive(
        light: UIColor(
            red: 0xB8 / 255,
            green: 0x8A / 255,
            blue: 0x1F / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xE8 / 255,
            green: 0xC5 / 255,
            blue: 0x47 / 255,
            alpha: 1
        )
    )

    // MARK: - Background (clean warm white)

    static let barTabBackground = barTabAdaptive(
        light: UIColor(
            red: 0xFA / 255,
            green: 0xF8 / 255,
            blue: 0xF5 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x12 / 255,
            green: 0x10 / 255,
            blue: 0x0E / 255,
            alpha: 1
        )
    )

    // MARK: - Text (near-black / warm white)

    static let barTabText = barTabAdaptive(
        light: UIColor(
            red: 0x1C / 255,
            green: 0x1A / 255,
            blue: 0x18 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xF5 / 255,
            green: 0xF2 / 255,
            blue: 0xED / 255,
            alpha: 1
        )
    )

    // MARK: - Secondary text

    static let barTabSecondary = barTabAdaptive(
        light: UIColor(
            red: 0x8A / 255,
            green: 0x85 / 255,
            blue: 0x7D / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x9A / 255,
            green: 0x95 / 255,
            blue: 0x8D / 255,
            alpha: 1
        )
    )

    // MARK: - Card fill (pure white / dark elevated)

    static let barTabCardFill = barTabAdaptive(
        light: UIColor(
            red: 0xFF / 255,
            green: 0xFF / 255,
            blue: 0xFF / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x1E / 255,
            green: 0x1C / 255,
            blue: 0x19 / 255,
            alpha: 1
        )
    )

    // MARK: - Card border (subtle)

    static let barTabCardBorder = barTabAdaptive(
        light: UIColor(
            red: 0xE8 / 255,
            green: 0xE4 / 255,
            blue: 0xDE / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x2C / 255,
            green: 0x29 / 255,
            blue: 0x25 / 255,
            alpha: 1
        )
    )

    // MARK: - Success green

    static let barTabSuccess = barTabAdaptive(
        light: UIColor(
            red: 0x2D / 255,
            green: 0x8C / 255,
            blue: 0x5A / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x4C / 255,
            green: 0xAF / 255,
            blue: 0x7A / 255,
            alpha: 1
        )
    )

    // MARK: - Soft pill fill

    static let barTabPillFill = barTabAdaptive(
        light: UIColor(
            red: 0xF0 / 255,
            green: 0xEB / 255,
            blue: 0xE3 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x2A / 255,
            green: 0x26 / 255,
            blue: 0x22 / 255,
            alpha: 1
        )
    )
}
