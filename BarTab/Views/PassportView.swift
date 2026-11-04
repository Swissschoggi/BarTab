import SwiftUI

/// The "beer passport": a Flighty-style collection of every distinct bar
/// the user has checked into — hero stat, milestone progress and a
/// timeline of stamps.
struct PassportView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    private var currentUser: User? {
        userSession.currentUser
    }

    private var visits: [BarVisit] {
        guard let user = currentUser else { return [] }
        return barRepository.barVisits(for: user)
    }

    // MARK: - Derived stats

    private var totalDistinct: Int {
        visits.count
    }

    private var totalCheckIns: Int {
        visits.reduce(0) { $0 + $1.visitCount }
    }

    private var mostVisitedBarName: String {
        guard let top = visits.max(by: { $0.visitCount < $1.visitCount }) else { return "-" }
        return barRepository.getBar(id: top.barID)?.name ?? "-"    }

    private var firstVisitDate: Date? {
        visits.map(\.firstVisitedAt).min()
    }

    private let milestones = [5, 10, 25, 50, 100, 250]

    private var nextMilestone: Int? {
        milestones.first { $0 > totalDistinct }
    }

    private var milestoneProgress: CGFloat {
        guard let next = nextMilestone else { return 1 }
        let previous = milestones.filter { $0 <= totalDistinct }.max() ?? 0
        let span = CGFloat(next - previous)
        guard span > 0 else { return 1 }
        return CGFloat(totalDistinct - previous) / span
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                if currentUser != nil {
                    heroCard

                    if !visits.isEmpty {
                        statsRow
                    }

                    if visits.isEmpty {
                        emptyState
                    } else {
                        timelineSection
                    }
                } else {
                    signedOutState
                }
            }
            .padding(.horizontal, BartapSpacing.md)
            .padding(.vertical, BartapSpacing.md)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Passport"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .center, spacing: BartapSpacing.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "PASSPORT"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.7))

                Text("\(totalDistinct)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(totalDistinct == 1
                     ? String(localized: "bar visited")
                     : String(localized: "bars visited"))
                    .font(.BartapBodySemibold)
                    .foregroundColor(.white.opacity(0.9))

                if let next = nextMilestone {
                    Text(String(localized: "\(next - totalDistinct) to go for \(next)"))
                        .font(.BartapCaption)
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer(minLength: 0)

            progressRing
        }
        .padding(BartapSpacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0x3E / 255, green: 0x14 / 255, blue: 0x20 / 255),
                    Color.BartapAccent
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: BartapRadius.sheet, style: .continuous))
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 7)

            Circle()
                .trim(from: 0, to: milestoneProgress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(nextMilestone.map { "\($0)" } ?? "★")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(String(localized: "stamps"))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: 82, height: 82)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: BartapSpacing.sm) {
            statCard(value: "\(totalCheckIns)", label: String(localized: "Check-ins"))
            statCard(value: mostVisitedBarName, label: String(localized: "Most visited"), isText: true)
            statCard(value: firstVisitText, label: String(localized: "Since"), isText: true)
        }
    }

    private var firstVisitText: String {
        guard let date = firstVisitDate else { return "-" }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    private func statCard(
        value: String,
        label: String,
        isText: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(isText ? .BartapCaption : .BartapStat)
                .fontWeight(isText ? .semibold : .bold)
                .foregroundColor(.BartapText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.BartapTiny)
                .foregroundColor(.BartapSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .BartapCard(padding: BartapSpacing.sm)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {
            Text(String(localized: "Stamps"))
                .font(.BartapHeading)
                .foregroundColor(.BartapText)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                    if let bar = barRepository.getBar(id: visit.barID) {
                        NavigationLink {
                            BarView(bar: bar)
                                .environmentObject(barRepository)
                                .environmentObject(userSession)
                                .environmentObject(toastCenter)
                        } label: {
                            timelineRow(
                                bar: bar,
                                visit: visit,
                                isLast: index == visits.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func timelineRow(
        bar: Bar,
        visit: BarVisit,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: BartapSpacing.md) {
            // Marker + connecting line
            VStack(spacing: 0) {
                stampMarker(bar: bar)

                if !isLast {
                    Rectangle()
                        .fill(Color.BartapCardBorder)
                        .frame(width: 2)
                        .frame(height: 56)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: BartapSpacing.sm) {
                    Text(bar.name)
                        .font(.BartapBodySemibold)
                        .foregroundColor(.BartapText)
                        .lineLimit(1)

                    Spacer()

                    if visit.visitCount > 1 {
                        Text("×\(visit.visitCount)")
                            .font(.BartapTiny)
                            .fontWeight(.bold)
                            .foregroundColor(.BartapPrimary)
                            .padding(.horizontal, BartapSpacing.xs)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.BartapPrimary.opacity(0.12)))
                    }
                }

                HStack(spacing: BartapSpacing.xs) {
                    if let ambience = barRepository.popularAmbience(for: bar) {
                        Image(systemName: ambience.icon)
                            .font(.BartapTiny)
                        Text(ambience.displayName)
                            .font(.BartapTiny)
                    }

                    Text("·")
                        .font(.BartapTiny)

                    Text(visit.lastVisitedAt.relativeFormatted)
                        .font(.BartapTiny)
                }
                .foregroundColor(.BartapSecondary)
            }
            .padding(.bottom, BartapSpacing.lg)
        }
    }

    private func stampMarker(bar: Bar) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.BartapPrimary, .BartapAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            Circle()
                .stroke(
                    Color.BartapCardFill,
                    style: StrokeStyle(lineWidth: 2, dash: [3, 3])
                )
                .frame(width: 36, height: 36)

            Text(String(bar.name.prefix(1)).uppercased())
                .font(.BartapHeading)
                .foregroundColor(.white)
        }
    }

    // MARK: - Empty / signed out

    private var emptyState: some View {
        VStack(spacing: BartapSpacing.sm) {
            Image(systemName: "ticket")
                .font(.BartapEmptyIconLarge)
                .foregroundColor(.BartapPrimary.opacity(0.5))

            Text(String(localized: "No stamps yet"))
                .font(.BartapBodySemibold)
                .foregroundColor(.BartapText)

            Text(String(localized: "Head to a bar and tap \"I'm here\" to start your collection."))
                .font(.BartapCaption)
                .foregroundColor(.BartapSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BartapSpacing.xl)
        .BartapCard()
    }

    private var signedOutState: some View {
        VStack(spacing: BartapSpacing.sm) {
            Image(systemName: "book.closed")
                .font(.BartapEmptyIcon)
                .foregroundColor(.BartapPrimary.opacity(0.6))

            Text(String(localized: "Sign in to collect stamps"))
                .font(.BartapBody)
                .foregroundColor(.BartapText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BartapSpacing.xl)
    }
}
