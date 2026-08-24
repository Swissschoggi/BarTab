import SwiftUI

// MARK: - Screen header

struct BarTabScreenHeader: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.barTabText)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.barTabSecondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Cards

extension View {

    func barTabCard(
        cornerRadius: CGFloat = 16,
        fill: Color = Color.barTabCardFill,
        padding: CGFloat = 16,
        shadow: Bool = true
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
            .overlay(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(Color.barTabCardBorder, lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(shadow ? 0.04 : 0),
                radius: shadow ? 8 : 0,
                x: 0,
                y: shadow ? 2 : 0
            )
    }
}

// MARK: - Primary button

extension View {

    func barTabPrimaryButton(
        cornerRadius: CGFloat = 14
    ) -> some View {
        self
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color.barTabPrimary,
                        Color.barTabPrimary.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.barTabPrimary.opacity(0.25),
                radius: 6,
                x: 0,
                y: 3
            )
    }
}

// MARK: - Pill button

extension View {

    func barTabPillButton(
        color: Color = .barTabPrimary
    ) -> some View {
        self
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Section header

struct BarTabSectionHeader: View {

    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.barTabText)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.barTabSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.barTabPillFill)
                    .clipShape(Capsule())
            }
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

// MARK: - Modifier: subtle card border

struct CardBorder: ViewModifier {

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 0.5)
            )
    }
}

extension View {

    func cardBorder() -> some View {
        modifier(CardBorder())
    }
}
