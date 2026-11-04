import SwiftUI
import MapKit
import CoreLocation

struct EditBarView: View {

    let bar: Bar

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var address: String
    @State private var smokingFriendly: Bool
    @State private var outdoorSeating: Bool
    @State private var isSaving = false

    init(bar: Bar) {
        self.bar = bar
        _name = State(initialValue: bar.name)
        _address = State(initialValue: bar.address)
        _smokingFriendly = State(initialValue: bar.smokingFriendly)
        _outdoorSeating = State(initialValue: bar.outdoorSeating)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    // Name card
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text(String(localized: "BAR NAME"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        TextField(String(localized: "Bar name"), text: $name)
                            .font(.BartapBody)
                            .foregroundColor(.BartapText)
                    }
                    .padding(BartapSpacing.md)
                    .background(Color.BartapCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                    )

                    // Address card
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text(String(localized: "ADDRESS"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        TextField(String(localized: "Address"), text: $address)
                            .font(.BartapBody)
                            .foregroundColor(.BartapText)
                    }
                    .padding(BartapSpacing.md)
                    .background(Color.BartapCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                    )

                    // Details card
                    VStack(alignment: .leading, spacing: BartapSpacing.sm) {
                        Text(String(localized: "DETAILS"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        Toggle(isOn: $smokingFriendly) {
                            Label(String(localized: "Smoking friendly"), systemImage: "smoke.fill")
                        }
                        .tint(.BartapPrimary)

                        Toggle(isOn: $outdoorSeating) {
                            Label(String(localized: "Outdoor seating"), systemImage: "sun.max.fill")
                        }
                        .tint(.BartapPrimary)
                    }
                    .padding(BartapSpacing.md)
                    .background(Color.BartapCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                    )

                    Button {
                        Task { await save() }
                    } label: {
                        Text(String(localized: "Save Bar"))
                    }
                    .BartapPrimaryButton()
                    .padding(.top, BartapSpacing.xs)
                    .disabled(isSaving || !canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.md)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "Edit Bar"))
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

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && !trimmedAddress.isEmpty
            && (trimmedName != bar.name
                || trimmedAddress != bar.address
                || smokingFriendly != bar.smokingFriendly
                || outdoorSeating != bar.outdoorSeating)
    }

    private func save() async {
        guard let user = userSession.currentUser else { return }
        isSaving = true

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        await barRepository.editBar(
            bar,
            name: trimmedName,
            address: trimmedAddress,
            smokingFriendly: smokingFriendly,
            outdoorSeating: outdoorSeating,
            editedBy: user
        )

        HapticEngine.success()
        toastCenter.show(String(localized: "Bar updated"), kind: .success)
        dismiss()
    }
}