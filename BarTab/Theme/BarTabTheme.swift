import SwiftUI

// MARK: - Screen header

struct BarTabScreenHeader: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(
                    .system(
                        size: 30,
                        weight: .bold
                    )
                )
                .foregroundColor(.barTabText)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Cards

extension View {

    func barTabCard(
        cornerRadius: CGFloat = 18,
        fill: Color = Color.barTabCardFill,
        padding: CGFloat = 16
    ) -> some View {
        self
            .padding(padding)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(fill)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
    }
}

// MARK: - Primary button

extension View {

    func barTabPrimaryButton(
        cornerRadius: CGFloat = 16
    ) -> some View {
        self
            .foregroundColor(.white)
            .background(
                Color.barTabPrimary
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
    }
}

// MARK: - Drink icons

extension Drink {

    var icon: String {
        switch self {
        case .beer:
            return "mug.fill"

        case .wine:
            return "wineglass.fill"

        case .cocktail:
            return "wineglass"

        case .shot:
            return "flask.fill"

        case .softDrink:
            return "cup.and.saucer.fill"

        case .coffee:
            return "cup.and.saucer.fill"

        case .other:
            return "fork.knife"
        }
    }
}

// MARK: - Price formatting

extension Decimal {

    var formattedAmount: String {

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(
            from: self as NSDecimalNumber
        ) ?? description
    }
}

extension Price {

    var formattedAmount: String {
        amount.formattedAmount
    }
}

extension PriceSummary {

    var formattedAmount: String {
        amount.formattedAmount
    }
}