import SwiftUI

struct AttributeDetailSheet: View {
    let bar: Bar
    let attribute: BarAttribute
    let currentUser: User

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var showingConfirmDialog = false
    @State private var showingReportDialog = false

    private var reportLabel: String {
        attribute.totalReports == 1 ? String(localized: "report") : String(localized: "reports")
    }

    private var confirmLabel: String {
        attribute.isConfirmed ? String(localized: "Confirmed") : String(localized: "Yes, this is correct")
    }

    private var confirmIcon: String {
        attribute.isConfirmed ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var confirmBG: Color {
        attribute.isConfirmed ? .barTabSuccess.opacity(0.1) : .barTabPrimary.opacity(0.1)
    }

    private var confirmFG: Color {
        attribute.isConfirmed ? .barTabSuccess : .barTabPrimary
    }

    private var confirmStroke: Color {
        attribute.isConfirmed ? .barTabSuccess.opacity(0.3) : .barTabPrimary.opacity(0.3)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: BarTabSpacing.md) {
                    Image(systemName: attribute.key.icon)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.barTabPrimary)

                    Text(attribute.key.displayName)
                        .font(.barTabHeading)
                        .fontWeight(.bold)

                    if let value = attribute.consensusValue {
                        VStack(spacing: 4) {
                            Text(value)
                                .font(.barTabDisplay)
                                .fontWeight(.bold)
                                .foregroundColor(.barTabPrimary)

                            HStack(spacing: 8) {
                                Text("\(attribute.totalReports) \(reportLabel)")
                                    .font(.barTabCaption)
                                    .foregroundColor(.barTabSecondary)

                                Circle()
                                    .fill(confidenceColor(attribute.consensusConfidence))
                                    .frame(width: 8, height: 8)

                                Text("\(attribute.consensusConfidence)% confidence")
                                    .font(.barTabCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(confidenceColor(attribute.consensusConfidence))
                            }
                        }
                    } else {
                        Text(String(localized: "No consensus yet"))
                            .font(.barTabBody)
                            .foregroundColor(.barTabSecondary)
                    }

                    if let lastConfirmed = attribute.lastConfirmedAt {
                        Text("Last confirmed \(lastConfirmed.relativeFormatted)")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabSecondary)
                    }
                }
                .padding(.vertical, BarTabSpacing.xl)

                Divider()
                    .padding(.horizontal, BarTabSpacing.md)

                VStack(spacing: BarTabSpacing.sm) {
                    Button {
                        showingConfirmDialog = true
                    } label: {
                        HStack {
                            Image(systemName: confirmIcon)
                            Text(confirmLabel)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(confirmBG)
                        .foregroundColor(confirmFG)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                .stroke(confirmStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingReportDialog = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text(String(localized: "Report a change"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.barTabWarning.opacity(0.1))
                        .foregroundColor(.barTabWarning)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                .stroke(Color.barTabWarning.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.top, BarTabSpacing.md)

                Spacer()

                if attribute.consensus.count > 1 {
                    Divider()
                        .padding(.horizontal, BarTabSpacing.md)

                    VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                        Text(String(localized: "Other reports"))
                            .font(.barTabSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabSecondary)
                            .padding(.horizontal, BarTabSpacing.md)

                        ForEach(attribute.consensus.dropFirst()) { consensus in
                            HStack {
                                Text(consensus.displayValue)
                                    .font(.barTabSmall)
                                    .foregroundColor(.barTabText)
                                Spacer()
                                Text(consensusCountLabel(consensus.reportCount))
                                    .font(.barTabCaption)
                                    .foregroundColor(.barTabSecondary)
                                Text("\(consensus.confidencePct)%")
                                    .font(.barTabCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(confidenceColor(consensus.confidencePct))
                            }
                            .padding(.horizontal, BarTabSpacing.md)
                            .padding(.vertical, BarTabSpacing.xs)
                        }
                    }
                    .padding(.bottom, BarTabSpacing.lg)
                }
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Attribute"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .foregroundColor(.barTabPrimary)
                }
            }
            .confirmationDialog(
                confirmDialogTitle,
                isPresented: $showingConfirmDialog,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Yes, confirm")) {
                    Task {
                        await barRepository.submitAttributeReport(
                            for: bar,
                            attributeKey: attribute.key.rawValue,
                            value: topConsensusValue,
                            by: currentUser
                        )
                        HapticEngine.success()
                        toastCenter.show(String(localized: "Confirmed!"), kind: .success)
                        dismiss()
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "This adds your confirmation to the community consensus."))
            }
            .confirmationDialog(
                String(localized: "Report a different value?"),
                isPresented: $showingReportDialog,
                titleVisibility: .visible
            ) {
                ForEach(attribute.key.possibleValues.filter { $0 != attribute.consensusValue }, id: \.self) { value in
                    Button(attribute.key.displayValue(value)) {
                        Task {
                            await barRepository.submitAttributeReport(
                                for: bar,
                                attributeKey: attribute.key.rawValue,
                                value: value,
                                by: currentUser
                            )
                            HapticEngine.impact()
                            toastCenter.show(String(localized: "Change reported"), kind: .info)
                            dismiss()
                        }
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "What should the correct value be?"))
            }
        }
    }

    private var topConsensusValue: String {
        attribute.consensusValue ?? ""
    }

    private var confirmDialogTitle: String {
        "Confirm \(attribute.key.displayName) is \(topConsensusValue)?"
    }

    private func consensusCountLabel(_ count: Int) -> String {
        count == 1 ? String(localized: "1 report") : String(localized: "\(count) reports")
    }

    func confidenceColor(_ pct: Int) -> Color {
        switch pct {
        case 80...100: return .barTabSuccess
        case 50..<80: return .barTabWarning
        default: return .barTabDanger
        }
    }
}
