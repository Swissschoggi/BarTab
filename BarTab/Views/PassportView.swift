import SwiftUI

/// The "beer passport": a stamp collection of every distinct bar the
/// user has checked into, newest visit first.
struct PassportView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    private var currentUser: User? {
        userSession.currentUser
    }

    private var visits: [BarVisit] {
        guard let user = currentUser else { return [] }
        return barRepository.barVisits(for: user)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if let user = currentUser {
                    headerCard(user: user)

                    if visits.isEmpty {
                        emptyState
                    } else {
                        Text(String(localized: "Stamps"))
                            .font(.barTabHeading)
                            .foregroundColor(.barTabText)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(visits) { visit in
                                if let bar = barRepository.getBar(id: visit.barID) {
                                    NavigationLink {
                                        BarView(bar: bar)
                                            .environmentObject(barRepository)
                                            .environmentObject(userSession)
                                            .environmentObject(toastCenter)
                                    } label: {
                                        stampCard(bar: bar, visit: visit)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else {
                    signedOutState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Passport"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private func headerCard(user: User) -> some View {
        let count = barRepository.distinctBarVisitCount(for: user)

        return HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.barTabTitle)
                .foregroundColor(.barTabPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "\(count) \(count == 1 ? "bar" : "bars") visited"))
                    .font(.barTabHeading)
                    .foregroundColor(.barTabText)
                Text(String(localized: "Check in at a bar to collect a stamp."))
                    .font(.barTabSmall)
                    .foregroundColor(.barTabSecondary)
            }

            Spacer()
        }
        .padding(16)
        .barTabCard()
    }

    // MARK: - Stamp

    private func stampCard(bar: Bar, visit: BarVisit) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.barTabPrimary.opacity(0.08))
                    .frame(width: 56, height: 56)

                Circle()
                    .stroke(
                        Color.barTabPrimary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                    )
                    .frame(width: 56, height: 56)

                Text(String(bar.name.prefix(1)).uppercased())
                    .font(.barTabHeading)
                    .foregroundColor(.barTabPrimary)
            }

            Text(bar.name)
                .font(.barTabSmall)
                .fontWeight(.semibold)
                .foregroundColor(.barTabText)
                .lineLimit(1)

            if visit.visitCount > 1 {
                Text(String(localized: "\(visit.visitCount) visits"))
                    .font(.barTabTiny)
                    .foregroundColor(.barTabPrimary)
            }

            Text(visit.lastVisitedAt.relativeFormatted)
                .font(.barTabTiny)
                .foregroundColor(.barTabSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BarTabSpacing.sm)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                .fill(Color.barTabCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                .stroke(Color.barTabCardBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Empty / signed out

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "ticket")
                .font(.barTabEmptyIcon)
                .foregroundColor(.barTabPrimary.opacity(0.6))

            Text(String(localized: "No stamps yet"))
                .font(.barTabBody)
                .fontWeight(.medium)
                .foregroundColor(.barTabText)

            Text(String(localized: "Head to a bar and tap \"I'm here\" to start your collection."))
                .font(.barTabSmall)
                .foregroundColor(.barTabSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var signedOutState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.barTabEmptyIcon)
                .foregroundColor(.barTabPrimary.opacity(0.6))

            Text(String(localized: "Sign in to collect stamps"))
                .font(.barTabBody)
                .foregroundColor(.barTabText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
