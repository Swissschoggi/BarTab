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
        NavigationView {
            Form {
                Section(header: Text(String(localized: "Bar name"))) {
                    TextField(String(localized: "Bar name"), text: $name)
                }

                Section(header: Text(String(localized: "Address"))) {
                    TextField(String(localized: "Address"), text: $address)
                }

                Section(header: Text(String(localized: "Details"))) {
                    Toggle(isOn: $smokingFriendly) {
                        Label(String(localized: "Smoking friendly"), systemImage: "smoke.fill")
                    }
                    .tint(.barTabPrimary)

                    Toggle(isOn: $outdoorSeating) {
                        Label(String(localized: "Outdoor seating"), systemImage: "sun.max.fill")
                    }
                    .tint(.barTabPrimary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "Edit Bar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Save")) {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                    .opacity(canSave ? 1 : 0.5)
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
