import SwiftUI

// MARK: - Spacing scale

enum BartapSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40
}

// MARK: - Corner radius scale

enum BartapRadius {
    static let sheet: CGFloat = 20
    static let card: CGFloat = 16
    static let control: CGFloat = 12
    static let chip: CGFloat = 8
}

// MARK: - Typographic scale

extension Font {

    /// Screen title.
    static let BartapDisplay = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Large in-content title.
    static let BartapTitle = Font.system(size: 22, weight: .bold, design: .rounded)

    /// Section / card heading.
    static let BartapHeading = Font.system(size: 15, weight: .semibold, design: .default)

    /// Big numeric stat.
    static let BartapStat = Font.system(size: 20, weight: .bold, design: .rounded)

    /// Primary body text.
    static let BartapBody = Font.system(size: 15, weight: .regular, design: .default)

    /// Emphasized body text.
    static let BartapBodySemibold = Font.system(size: 15, weight: .semibold, design: .default)

    /// Secondary text / captions.
    static let BartapCaption = Font.system(size: 13, weight: .medium, design: .default)

    /// Small captions.
    static let BartapSmall = Font.system(size: 12, weight: .regular, design: .default)

    /// Tiny labels / counts.
    static let BartapTiny = Font.system(size: 11, weight: .medium, design: .default)

    /// Counts inside badge dots.
    static let BartapBadge = Font.system(size: 9, weight: .bold, design: .rounded)

    // MARK: - SF Symbol icon scale

    /// Standard empty-state glyph.
    static let BartapEmptyIcon = Font.system(size: 36, weight: .regular)

    /// Large hero / onboarding glyph.
    static let BartapEmptyIconLarge = Font.system(size: 44, weight: .regular)
}

// MARK: - Date relative formatting

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Screen header

struct BartapScreenHeader: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.BartapDisplay)
                .tracking(-0.4)
                .foregroundColor(.BartapText)

            Text(subtitle)
                .font(.BartapBody)
                .foregroundColor(.BartapSecondary)
                .lineSpacing(4)
        }
        .padding(.top, BartapSpacing.xs)
    }
}

// MARK: - Cards

extension View {

    func BartapCard(
        cornerRadius: CGFloat = BartapRadius.card,
        fill: Color = Color.BartapCardFill,
        padding: CGFloat = BartapSpacing.md,
        shadow: Bool = false
    ) -> some View {
        self
            .padding(padding)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(fill)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(Color.BartapCardBorder, lineWidth: 0.5)
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

    func BartapPrimaryButton(
        cornerRadius: CGFloat = BartapRadius.control
    ) -> some View {
        self
            .font(.BartapBodySemibold)
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.BartapPrimary)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
    }

    /// Quiet secondary action.
    func BartapSecondaryButton(
        cornerRadius: CGFloat = BartapRadius.control
    ) -> some View {
        self
            .font(.BartapBodySemibold)
            .foregroundColor(.BartapText)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.BartapSurface)
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.BartapCardBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Pill button

extension View {

    func BartapPillButton(
        color: Color = .BartapPrimary
    ) -> some View {
        self
            .font(.BartapCaption)
            .foregroundColor(color)
            .padding(.horizontal, BartapSpacing.sm)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Section header

struct BartapSectionHeader: View {

    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.BartapHeading)
                .tracking(-0.2)
                .foregroundColor(.BartapText)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.BartapSmall)
                    .foregroundColor(.BartapPrimary)
                    .padding(.horizontal, BartapSpacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.BartapPrimary.opacity(0.1))
                    )
            }
        }
    }
}

// MARK: - List container

struct BartapListContainer<Data: RandomAccessCollection, RowContent: View>: View
where Data.Element: Identifiable {

    let data: Data
    @ViewBuilder let rowContent: (Data.Element) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                rowContent(element)
                    .padding(.vertical, BartapSpacing.sm)
                    .padding(.horizontal, BartapSpacing.md)

                if index < data.count - 1 {
                    Divider()
                        .padding(.leading, BartapSpacing.md)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                .fill(Color.BartapCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                .stroke(Color.BartapCardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Compact info bar

struct BartapInfoBar: View {

    let icon: String
    let title: String
    let value: String
    var trailingValue: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BartapSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.BartapPrimary.opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.BartapCaption)
                        .foregroundColor(.BartapPrimary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.BartapTiny)
                        .foregroundColor(.BartapSecondary)
                    Text(value)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.BartapText)
                        .lineLimit(1)
                }

                Spacer(minLength: BartapSpacing.xs)

                if let trailingValue {
                    Text(trailingValue)
                        .font(.BartapCaption)
                        .foregroundColor(.BartapPrimary)
                }

                Image(systemName: "chevron.down")
                    .font(.BartapTiny.weight(.semibold))
                    .foregroundColor(.BartapSecondary)
            }
            .padding(.horizontal, BartapSpacing.md)
            .padding(.vertical, BartapSpacing.xs)
        }
        .buttonStyle(.plain)
        .background(Color.BartapCardFill)
        .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                .stroke(Color.BartapCardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Input field

struct BartapFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.BartapBody)
            .padding(.horizontal, BartapSpacing.md)
            .padding(.vertical, 12)
            .background(Color.BartapSurface)
            .clipShape(
                RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                    .stroke(Color.BartapCardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func BartapFieldSurface() -> some View {
        self
            .padding(.horizontal, BartapSpacing.md)
            .padding(.vertical, 12)
            .background(Color.BartapSurface)
            .clipShape(
                RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                    .stroke(Color.BartapCardBorder, lineWidth: 0.5)
            )
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

// MARK: - Input validation

enum InputValidator {

    static let maxDisplayNameLength = 40
    static let maxBrandNameLength = 60
    static let maxCommentLength = 200

    static func validateDisplayName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Please enter a name." }
        if trimmed.count > maxDisplayNameLength {
            return "Name must be \(maxDisplayNameLength) characters or fewer."
        }
        return nil
    }

    static func validateBrandName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Please enter a brand name." }
        if trimmed.count > maxBrandNameLength {
            return "Name must be \(maxBrandNameLength) characters or fewer."
        }
        return nil
    }

    static func validateEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(
            of: #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
            options: .regularExpression
        ) != nil
    }
}

// MARK: - Skeleton loading

struct SkeletonModifier: ViewModifier {

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.BartapPillFill,
                        Color.BartapCardBorder,
                        Color.BartapPillFill
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 400)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {

    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Empty state

struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: BartapSpacing.sm) {
            Image(systemName: icon)
                .font(.BartapEmptyIcon)
                .foregroundColor(.BartapPrimary.opacity(0.5))
                .accessibilityHidden(true)

            Text(title)
                .font(.BartapBodySemibold)
                .tracking(-0.2)
                .foregroundColor(.BartapText)

            Text(message)
                .font(.BartapCaption)
                .foregroundColor(.BartapSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, BartapSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BartapSpacing.xl)
    }
}

// MARK: - Search field

struct BartapSearchField: View {

    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: BartapSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.BartapSecondary)
                .font(.BartapBody)

            TextField(placeholder, text: $text)
                .font(.BartapBody)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.BartapSecondary)
                }
            }
        }
        .BartapFieldSurface()
    }
}

struct BarRowSkeleton: View {

    var body: some View {
        HStack(spacing: BartapSpacing.sm) {
            RoundedRectangle(cornerRadius: BartapRadius.chip)
                .fill(Color.BartapSurface)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.BartapSurface)
                    .frame(width: 140, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.BartapCardBorder.opacity(0.7))
                    .frame(width: 100, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.BartapCardBorder.opacity(0.7))
                    .frame(width: 80, height: 10)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .skeleton()
    }
}
