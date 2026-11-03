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
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    if didSubmit {

                        VStack(spacing: BartapSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.BartapEmptyIcon)
                                .foregroundColor(.BartapPrimary)

                            Text(String(localized: "Request sent"))
                                .font(.BartapHeading)

                            Text(
                                String(localized: "We'll review \"\(trimmedName)\" and add it if it's a good fit.")
                            )
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BartapSpacing.lg)
                        .BartapCard()

                    } else {

                        VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                            Text(String(localized: "REQUESTING A \(drink.displayName.uppercased()) BRAND"))
                                .font(.BartapCaption)
                                .foregroundColor(.BartapSecondary)

                            Text(String(localized: "Requesting a \(drink.displayName.lowercased()) brand"))
                                .font(.BartapBody)
                                .foregroundColor(.BartapSecondary)

                            TextField(String(localized: "Brand name"), text: $name)
                                .autocorrectionDisabled()
                                .font(.BartapBody)
                                .foregroundColor(.BartapText)
                                .padding(.vertical, BartapSpacing.xs)
                        }
                        .padding(BartapSpacing.md)
                        .background(Color.BartapCardFill)
                        .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                                .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                        )

                        if !trimmedName.isEmpty && trimmedName.count > InputValidator.maxBrandNameLength {
                            Text(String(localized: "Name must be \(InputValidator.maxBrandNameLength) characters or fewer."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapWarning)
                        } else if !trimmedName.isEmpty && alreadyExists {
                            Text(String(localized: "That brand is already in the list."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapWarning)
                        } else if !trimmedName.isEmpty && alreadyPending {
                            Text(String(localized: "You've already requested this brand."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapWarning)
                        }

                        Button {
                            submit()
                        } label: {
                            Text(String(localized: "Send request"))
                        }
                        .BartapPrimaryButton()
                        .padding(.top, BartapSpacing.xs)
                        .disabled(
                            trimmedName.isEmpty
                            || trimmedName.count > InputValidator.maxBrandNameLength
                            || alreadyExists
                            || alreadyPending
                        )
                    }
                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.md)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "Request a brand"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.BartapPrimary)
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