import SwiftUI

/// Lets a user request that a new brand be added to the catalog
/// for a given drink. Submitted requests are reviewed by an admin.
struct RequestBrandSheet: View {

    let drink: Drink

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var didSubmit = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var alreadyExists: Bool {
        barRepository.brands(for: drink).contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private var alreadyPending: Bool {
        guard let user = userSession.currentUser else { return false }
        return barRepository.hasPendingRequest(
            name: trimmedName,
            for: drink,
            by: user
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {

                    if didSubmit {

                        VStack(spacing: BarTabSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.barTabEmptyIcon)
                                .foregroundColor(.barTabPrimary)

                            Text(String(localized: "Request sent"))
                                .font(.barTabHeading)

                            Text(
                                String(localized: "We'll review \"\(trimmedName)\" and add it if it's a good fit.")
                            )
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BarTabSpacing.lg)
                        .barTabCard()

                    } else {

                        VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
                            Text(String(localized: "REQUESTING A \(drink.displayName.uppercased()) BRAND"))
                                .font(.barTabCaption)
                                .foregroundColor(.barTabSecondary)

                            Text(String(localized: "Requesting a \(drink.displayName.lowercased()) brand"))
                                .font(.barTabBody)
                                .foregroundColor(.barTabSecondary)

                            TextField(String(localized: "Brand name"), text: $name)
                                .autocorrectionDisabled()
                                .font(.barTabBody)
                                .foregroundColor(.barTabText)
                                .padding(.vertical, BarTabSpacing.xs)
                        }
                        .padding(BarTabSpacing.md)
                        .background(Color.barTabCardFill)
                        .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                                .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                        )

                        if !trimmedName.isEmpty && trimmedName.count > InputValidator.maxBrandNameLength {
                            Text(String(localized: "Name must be \(InputValidator.maxBrandNameLength) characters or fewer."))
                                .font(.barTabSmall)
                                .foregroundColor(.barTabWarning)
                        } else if !trimmedName.isEmpty && alreadyExists {
                            Text(String(localized: "That brand is already in the list."))
                                .font(.barTabSmall)
                                .foregroundColor(.barTabWarning)
                        } else if !trimmedName.isEmpty && alreadyPending {
                            Text(String(localized: "You've already requested this brand."))
                                .font(.barTabSmall)
                                .foregroundColor(.barTabWarning)
                        }

                        Button {
                            submit()
                        } label: {
                            Text(String(localized: "Send request"))
                        }
                        .barTabPrimaryButton()
                        .padding(.top, BarTabSpacing.xs)
                        .disabled(
                            trimmedName.isEmpty
                            || trimmedName.count > InputValidator.maxBrandNameLength
                            || alreadyExists
                            || alreadyPending
                        )
                    }
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "Request a brand"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.barTabPrimary)
                }
            }
        }
    }

    private func submit() {
        guard let user = userSession.currentUser else { return }

        HapticEngine.impact()

        Task {
            await barRepository.requestBrand(
                name: trimmedName,
                for: drink,
                by: user
            )

            withAnimation {
                didSubmit = true
            }
        }
    }
}