import SwiftUI

struct AdminReportsView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var pendingDeleteReport: ContentReport?
    @State private var showingDeleteConfirmation = false

    private var reports: [ContentReport] {
        barRepository.reports.sorted {
            $0.reportedAt > $1.reportedAt
        }
    }

    var body: some View {
        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                if reports.isEmpty {

                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "checkmark.shield")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)

                        Text(String(localized: "All clear"))
                            .font(.BartapHeading)

                        Text(String(localized: "Flagged bars and drinks will show up here for review."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()

                } else {

                    HStack {
                        Label(
                            String(localized: "\(barRepository.unreviewedReportCount) \(barRepository.unreviewedReportCount == 1 ? "needs" : "need") review"),
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.BartapBody)
                        .foregroundColor(.secondary)

                        Spacer()
                    }

                    VStack(spacing: 12) {

                        ForEach(reports) { report in
                            reportCard(report)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Reported content"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ReportNotificationService.requestPermission()
        }
        .alert(String(localized: "Delete this report?"), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: "Delete"), role: .destructive) {
                guard let report = pendingDeleteReport else { return }
                Task {
                    await barRepository.deleteReport(report)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This removes the report permanently."))
        }
    }

    private func reportCard(
        _ report: ContentReport
    ) -> some View {

        let barForReport: Bar? = {
            if report.targetType == .bar {
                return barRepository.bars.first { $0.id.uuidString == report.targetID }
            }
            // For drink reports, find a bar that has this price group
            return barRepository.barForPriceGroupKey(report.targetID)
        }()

        return VStack(alignment: .leading, spacing: BartapSpacing.sm) {

            if let bar = barForReport {
                NavigationLink {
                    BarView(bar: bar)
                        .environmentObject(barRepository)
                        .environmentObject(userSession)
                        .environmentObject(toastCenter)
                } label: {
                    reportCardHeader(report, tappable: true)
                }
                .buttonStyle(.plain)
            } else {
                reportCardHeader(report, tappable: false)
            }

            Text(report.reason.title)
                .font(.BartapBody)
                .foregroundColor(.primary)

            reportCardActions(report)
        }
        .BartapCard()
    }

    private func reportCardHeader(
        _ report: ContentReport,
        tappable: Bool
    ) -> some View {
        HStack(spacing: 8) {

            Image(
                systemName: report.targetType == .bar
                    ? "mappin.and.ellipse"
                    : "dollarsign.circle"
            )
            .font(.BartapBody)
            .foregroundColor(.BartapWarning)

            Text(report.targetLabel)
                .font(.BartapHeading)
                .lineLimit(1)

            Spacer()

            if tappable {
                Image(systemName: "chevron.right")
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)
            }

            if !report.isReviewed {
                Text(String(localized: "New"))
                    .font(.BartapTiny)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.BartapAccent)
                    .clipShape(Capsule())
            } else {
                Label(
                    String(localized: "Reviewed"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.BartapSmall)
                .fontWeight(.semibold)
                .foregroundColor(.BartapSuccess)
            }
        }
    }

    private func reportCardActions(
        _ report: ContentReport
    ) -> some View {
        HStack(spacing: 6) {

            Text(String(localized: "by \(report.reportedByName)"))
                .font(.BartapSmall)
                .foregroundColor(.secondary)

            Text("\u{00B7}")
                .font(.BartapSmall)
                .foregroundColor(.secondary)

            Text(relativeDate(report.reportedAt))
                .font(.BartapSmall)
                .foregroundColor(.secondary)

            Spacer()

            if report.isReviewed {
                Button {
                    pendingDeleteReport = report
                    showingDeleteConfirmation = true
                } label: {
                    Label(String(localized: "Remove"), systemImage: "trash")
                        .font(.BartapSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.BartapDanger)
                }
            } else {
                Button {
                    Task {
                        await barRepository.markReportReviewed(report)
                    }
                } label: {
                    Text(String(localized: "Mark reviewed"))
                        .font(.BartapSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.BartapPrimary)
                }
            }
        }
    }

    private func relativeDate(
        _ date: Date
    ) -> String {

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short

        return formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }
}
