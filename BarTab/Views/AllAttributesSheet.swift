import SwiftUI

struct AllAttributesSheet: View {
    let bar: Bar
    let currentUser: User?

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let attributes = barRepository.allAttributeConsensus(for: bar, currentUser: currentUser)

        NavigationView {
            List {
                if attributes.isEmpty {
                    VStack(spacing: BarTabSpacing.md) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.barTabSecondary)
                        Text(String(localized: "No attribute reports yet"))
                            .font(.barTabHeading)
                            .foregroundColor(.barTabText)
                        Text(String(localized: "Be the first to report on this bar's amenities!"))
                            .font(.barTabBody)
                            .foregroundColor(.barTabSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.barTabBackground)
                } else {
                    ForEach(attributes) { attr in
                        AttributeRow(attribute: attr) {
                            selectedAttribute = attr
                            showingDetail = true
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "All Attributes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .foregroundColor(.barTabPrimary)
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let attr = selectedAttribute,
                   let user = currentUser {
                    AttributeDetailSheet(
                        bar: bar,
                        attribute: attr,
                        currentUser: user
                    )
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
                }
            }
        }
    }

    @State private var selectedAttribute: BarAttribute?
    @State private var showingDetail = false
}

private struct AttributeRow: View {
    let attribute: BarAttribute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: attribute.key.icon)
                    .font(.barTabBody)
                    .foregroundColor(.barTabPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attribute.key.displayName)
                        .font(.barTabBody)
                        .fontWeight(.medium)
                        .foregroundColor(.barTabText)

                    if let value = attribute.consensusValue {
                        HStack(spacing: 6) {
                            Text(value)
                                .font(.barTabCaption)
                                .fontWeight(.medium)
                                .foregroundColor(.barTabPrimary)

                            Text("\(attribute.consensusConfidence)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(confidenceColor(attribute.consensusConfidence))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(confidenceColor(attribute.consensusConfidence).opacity(0.15))
                                .clipShape(Capsule())

                            Text("\(attribute.totalReports) report\(attribute.totalReports == 1 ? "" : "s")")
                                .font(.barTabTiny)
                                .foregroundColor(.barTabSecondary)
                        }
                    } else {
                        Text(String(localized: "No reports yet"))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.barTabTiny)
                    .foregroundColor(.barTabSecondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.barTabSurface)
        .listRowSeparatorTint(Color.barTabCardBorder)
    }

    func confidenceColor(_ pct: Int) -> Color {
        switch pct {
        case 80...100: return .barTabSuccess
        case 50..<80: return .barTabWarning
        default: return .barTabDanger
        }
    }
}