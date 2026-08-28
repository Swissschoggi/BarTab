import SwiftUI

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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.barTabText)

            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.barTabSecondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Cards (soft, warm, organic)

extension View {

    func barTabCard(
        cornerRadius: CGFloat = 24,
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
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(fill)
                .shadow(
                    color: Color.barTabPrimary.opacity(shadow ? 0.04 : 0),
                    radius: shadow ? 16 : 0,
                    x: 0,
                    y: shadow ? 6 : 0
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.barTabCardBorder.opacity(0.6),
                            Color.barTabCardBorder.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            )
    }
}

// MARK: - Primary button (warm gradient, soft shadow)

extension View {

    func barTabPrimaryButton(
        cornerRadius: CGFloat = 18
    ) -> some View {
        self
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.vertical, 14)
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
                color: Color.barTabPrimary.opacity(0.2),
                radius: 12,
                x: 0,
                y: 6
            )
    }
}

// MARK: - Pill button

extension View {

    func barTabPillButton(
        color: Color = .barTabPrimary
    ) -> some View {
        self
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
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
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.barTabText)

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.barTabPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.barTabPrimary.opacity(0.1))
                    )
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
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.barTabCardBorder, lineWidth: 0.5)
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
                        Color.gray.opacity(0.15),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.15)
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
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.barTabPrimary.opacity(0.6))

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.barTabText)

            Text(message)
                .font(.caption)
                .foregroundColor(.barTabSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Search field

struct BarTabSearchField: View {

    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.barTabSecondary)
                .font(.subheadline)

            TextField(placeholder, text: $text)
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
        .padding(10)
        .background(Color.barTabPillFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct BarRowSkeleton: View {

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 80, height: 10)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .skeleton()
    }
}
