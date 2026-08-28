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

                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 44))
                            .foregroundColor(.barTabPrimary)

                        Text("All clear")
                            .font(.headline)

                        Text("Flagged bars and drinks will show up here for review.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()

                } else {

                    HStack {
                        Label(
                            "\(barRepository.unreviewedReportCount) "
                            + "\(barRepository.unreviewedReportCount == 1 ? "needs" : "need") review",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.subheadline)
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
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Reported content")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ReportNotificationService.requestPermission()
        }
        .alert("Delete this report?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                guard let report = pendingDeleteReport else { return }
                Task {
                    await barRepository.deleteReport(report)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the report permanently.")
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

        return VStack(alignment: .leading, spacing: 10) {

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
                .font(.subheadline)
                .foregroundColor(.primary)

            reportCardActions(report)
        }
        .barTabCard()
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
            .font(.subheadline)
            .foregroundColor(.orange)

            Text(report.targetLabel)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            if tappable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.barTabSecondary)
            }

            if !report.isReviewed {
                Text("New")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.barTabAccent)
                    .clipShape(Capsule())
            } else {
                Label(
                    "Reviewed",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.green)
            }
        }
    }

    private func reportCardActions(
        _ report: ContentReport
    ) -> some View {
        HStack(spacing: 6) {

            Text("by \(report.reportedByName)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\u{00B7}")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(relativeDate(report.reportedAt))
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if report.isReviewed {
                Button {
                    pendingDeleteReport = report
                    showingDeleteConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            } else {
                Button {
                    Task {
                        await barRepository.markReportReviewed(report)
                    }
                } label: {
                    Text("Mark reviewed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.barTabPrimary)
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
