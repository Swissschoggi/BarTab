import SwiftUI

// MARK: - Spacing scale
//
// One 4pt-based scale used everywhere instead of ad-hoc padding numbers,
// so rhythm stays consistent across all 40+ screens.

enum BarTabSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40
}

// MARK: - Corner radius scale
//
// Radius now communicates hierarchy instead of being one flat 24 on
// everything: bigger surfaces get more room to breathe, small controls
// stay tight.

enum BarTabRadius {
    static let sheet: CGFloat = 28
    static let card: CGFloat = 20
    static let control: CGFloat = 14
    static let chip: CGFloat = 10
}

// MARK: - Typographic scale
//
// Display and stat numbers keep the rounded design for personality;
// reading text (body/caption/small) moves to the system default design,
// which renders crisper at small sizes and reads as considered rather
// than uniformly "soft." Spend the rounded, expressive treatment where
// it earns its keep: headlines, hero numbers, the tab bar.

extension Font {

    /// Screen title (e.g. "Discover", "Me").
    static let barTabDisplay = Font.system(size: 30, weight: .bold, design: .rounded)

    /// Large in-content title (e.g. login welcome, onboarding).
    static let barTabTitle = Font.system(size: 23, weight: .bold, design: .rounded)

    /// Section / card heading.
    static let barTabHeading = Font.system(size: 16, weight: .semibold, design: .default)

    /// Big numeric stat (e.g. a price, a score).
    static let barTabStat = Font.system(size: 21, weight: .bold, design: .rounded)

    /// Primary body text.
    static let barTabBody = Font.system(size: 15, weight: .regular, design: .default)

    /// Emphasized body text (row titles, buttons).
    static let barTabBodySemibold = Font.system(size: 15, weight: .semibold, design: .default)

    /// Secondary text / captions.
    static let barTabCaption = Font.system(size: 13, weight: .medium, design: .default)

    /// Small captions.
    static let barTabSmall = Font.system(size: 12, weight: .regular, design: .default)

    /// Tiny labels / counts.
    static let barTabTiny = Font.system(size: 11, weight: .medium, design: .default)

    /// Counts inside badge dots.
    static let barTabBadge = Font.system(size: 9, weight: .bold, design: .rounded)

    // MARK: - SF Symbol icon scale

    /// Standard empty-state glyph.
    static let barTabEmptyIcon = Font.system(size: 36, weight: .regular)

    /// Large hero / onboarding glyph.
    static let barTabEmptyIconLarge = Font.system(size: 44, weight: .regular)
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

struct BarTabScreenHeader: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.barTabDisplay)
                .foregroundColor(.barTabText)

            Text(subtitle)
                .font(.barTabBody)
                .foregroundColor(.barTabSecondary)
        }
        .padding(.top, BarTabSpacing.xs)
    }
}

// MARK: - Cards
//
// Flat by default — a filled surface plus a single crisp hairline.
// Shadow is opt-in and reserved for content that should feel like it's
// floating above the page (sheets, the tab bar, the primary CTA), not
// sprayed under every card as ambient decoration.

extension View {

    func barTabCard(
        cornerRadius: CGFloat = BarTabRadius.card,
        fill: Color = Color.barTabCardFill,
        padding: CGFloat = BarTabSpacing.md,
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
                .stroke(Color.barTabCardBorder, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(shadow ? 0.06 : 0),
                radius: shadow ? 10 : 0,
                x: 0,
                y: shadow ? 3 : 0
            )
    }
}

// MARK: - Primary button
//
// The gradient is the one loud element per screen — keep it here and
// on the tab bar's selection pill, nowhere else.

extension View {

    func barTabPrimaryButton(
        cornerRadius: CGFloat = BarTabRadius.control
    ) -> some View {
        self
            .font(.barTabBodySemibold)
            .foregroundColor(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color.barTabGradientStart,
                        Color.barTabGradientEnd
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
                color: Color.barTabPrimary.opacity(0.18),
                radius: 10,
                x: 0,
                y: 4
            )
    }

    /// Quiet secondary action — flat surface, no gradient, hairline edge.
    func barTabSecondaryButton(
        cornerRadius: CGFloat = BarTabRadius.control
    ) -> some View {
        self
            .font(.barTabBodySemibold)
            .foregroundColor(.barTabText)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Color.barTabSurface)
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Pill button

extension View {

    func barTabPillButton(
        color: Color = .barTabPrimary
    ) -> some View {
        self
            .font(.barTabCaption)
            .foregroundColor(color)
            .padding(.horizontal, BarTabSpacing.sm)
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
                .font(.barTabHeading)
                .foregroundColor(.barTabText)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.barTabSmall)
                    .foregroundColor(.barTabPrimary)
                    .padding(.horizontal, BarTabSpacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.barTabPrimary.opacity(0.1))
                    )
            }
        }
    }
}

// MARK: - List container
//
// A set of rows sharing one card surface with hairline dividers between
// them, instead of each row being its own floating card. This is the
// standard "list" pattern (Mail, Revolut, Yelp) — reach for it whenever
// you're about to put >1 similar row in a ForEach; it reads as considered
// hierarchy where a stack of identical shadowed cards reads as a template.

struct BarTabListContainer<Data: RandomAccessCollection, RowContent: View>: View
where Data.Element: Identifiable {

    let data: Data
    @ViewBuilder let rowContent: (Data.Element) -> RowContent

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                rowContent(element)
                    .padding(.vertical, BarTabSpacing.sm)
                    .padding(.horizontal, BarTabSpacing.md)

                if index < data.count - 1 {
                    Divider()
                        .padding(.leading, BarTabSpacing.md)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                .fill(Color.barTabCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                .stroke(Color.barTabCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Compact info bar
//
// A single-row summary control (icon + label + value + chevron) used to
// collapse what would otherwise be several stacked settings cards
// (location, radius, filters) into one tappable strip that opens detail
// in a sheet.

struct BarTabInfoBar: View {

    let icon: String
    let title: String
    let value: String
    var trailingValue: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BarTabSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.barTabPrimary.opacity(0.1))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.barTabCaption)
                        .foregroundColor(.barTabPrimary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.barTabTiny)
                        .foregroundColor(.barTabSecondary)
                    Text(value)
                        .font(.barTabBodySemibold)
                        .foregroundColor(.barTabText)
                        .lineLimit(1)
                }

                Spacer(minLength: BarTabSpacing.xs)

                if let trailingValue {
                    Text(trailingValue)
                        .font(.barTabCaption)
                        .foregroundColor(.barTabPrimary)
                }

                Image(systemName: "chevron.down")
                    .font(.barTabTiny.weight(.semibold))
                    .foregroundColor(.barTabSecondary)
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.vertical, BarTabSpacing.xs)
        }
        .buttonStyle(.plain)
        .background(Color.barTabCardFill)
        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                .stroke(Color.barTabCardBorder, lineWidth: 1)
        )
    }
}

/// Shared input style: flat surface, hairline edge, tight radius — used
/// in place of each screen hand-rolling its own `.background(...opacity(0.08))`.
struct BarTabFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.barTabBody)
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.vertical, 13)
            .background(Color.barTabSurface)
            .clipShape(
                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 1)
            )
    }
}

extension View {
    /// Wraps content (e.g. an `HStack` with a `TextField` + trailing icon)
    /// in the same flat field surface `BarTabFieldStyle` gives a plain field.
    func barTabFieldSurface() -> some View {
        self
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.vertical, 13)
            .background(Color.barTabSurface)
            .clipShape(
                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 1)
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

// MARK: - Organic blob shape (for decorative backgrounds)

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.4),
            control1: CGPoint(x: w * 0.8, y: 0),
            control2: CGPoint(x: w, y: h * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.7, y: h),
            control1: CGPoint(x: w, y: h * 0.7),
            control2: CGPoint(x: w * 0.8, y: h)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.6),
            control1: CGPoint(x: w * 0.4, y: h),
            control2: CGPoint(x: 0, y: h * 0.8)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: 0, y: h * 0.3),
            control2: CGPoint(x: w * 0.2, y: 0)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Gradient accent bar (used for top accents)

struct AccentBar: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.barTabGradientStart,
                Color.barTabGradientEnd
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 3)
        .clipShape(Capsule())
    }
}

// MARK: - Subtle divider

struct WarmDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.barTabCardBorder.opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

// MARK: - Modifier: subtle card border

struct CardBorder: ViewModifier {

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 1)
            )
    }
}

extension View {

    func cardBorder() -> some View {
        modifier(CardBorder())
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
                        Color.barTabPillFill,
                        Color.barTabCardBorder,
                        Color.barTabPillFill
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
        VStack(spacing: BarTabSpacing.sm) {
            Image(systemName: icon)
                .font(.barTabEmptyIcon)
                .foregroundColor(.barTabPrimary.opacity(0.55))

            Text(title)
                .font(.barTabBodySemibold)
                .foregroundColor(.barTabText)

            Text(message)
                .font(.barTabCaption)
                .foregroundColor(.barTabSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BarTabSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BarTabSpacing.xl)
    }
}

// MARK: - Search field

struct BarTabSearchField: View {

    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: BarTabSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.barTabSecondary)
                .font(.barTabBody)

            TextField(placeholder, text: $text)
                .font(.barTabBody)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.barTabSecondary)
                }
            }
        }
        .barTabFieldSurface()
    }
}

struct BarRowSkeleton: View {

    var body: some View {
        HStack(spacing: BarTabSpacing.sm) {
            RoundedRectangle(cornerRadius: BarTabRadius.chip)
                .fill(Color.barTabSurface)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.barTabSurface)
                    .frame(width: 140, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.barTabCardBorder.opacity(0.7))
                    .frame(width: 100, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.barTabCardBorder.opacity(0.7))
                    .frame(width: 80, height: 10)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .skeleton()
    }
}
