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

    static let barTabPrimary = barTabAdaptive(
        light: UIColor(
            red: 0x6B / 255,
            green: 0x27 / 255,
            blue: 0x37 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x9E / 255,
            green: 0x4E / 255,
            blue: 0x5B / 255,
            alpha: 1
        )
    )

    static let barTabAccent = barTabAdaptive(
        light: UIColor(
            red: 0xC9 / 255,
            green: 0xA2 / 255,
            blue: 0x27 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xD8 / 255,
            green: 0xB8 / 255,
            blue: 0x4E / 255,
            alpha: 1
        )
    )

    static let barTabBackground = barTabAdaptive(
        light: UIColor(
            red: 0xF7 / 255,
            green: 0xF1 / 255,
            blue: 0xE3 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x19 / 255,
            green: 0x15 / 255,
            blue: 0x12 / 255,
            alpha: 1
        )
    )

    static let barTabText = barTabAdaptive(
        light: UIColor(
            red: 0x29 / 255,
            green: 0x25 / 255,
            blue: 0x24 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0xF4 / 255,
            green: 0xF0 / 255,
            blue: 0xE9 / 255,
            alpha: 1
        )
    )

    static let barTabSecondary = barTabAdaptive(
        light: UIColor(
            red: 0xE8 / 255,
            green: 0xDF / 255,
            blue: 0xCC / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x2E / 255,
            green: 0x27 / 255,
            blue: 0x22 / 255,
            alpha: 1
        )
    )

    static let barTabCardFill = barTabAdaptive(
        light: UIColor(
            red: 0xFC / 255,
            green: 0xFA / 255,
            blue: 0xF4 / 255,
            alpha: 1
        ),
        dark: UIColor(
            red: 0x26 / 255,
            green: 0x20 / 255,
            blue: 0x1B / 255,
            alpha: 1
        )
    )
}