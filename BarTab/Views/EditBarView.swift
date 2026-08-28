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
                Section(header: Text("Bar name")) {
                    TextField("Bar name", text: $name)
                }

                Section(header: Text("Address")) {
                    TextField("Address", text: $address)
                }

                Section(header: Text("Details")) {
                    Toggle(isOn: $smokingFriendly) {
                        Label("Smoking friendly", systemImage: "smoke.fill")
                    }
                    .tint(.barTabPrimary)

                    Toggle(isOn: $outdoorSeating) {
                        Label("Outdoor seating", systemImage: "sun.max.fill")
                    }
                    .tint(.barTabPrimary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Edit Bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
        toastCenter.show("Bar updated", kind: .success)
        dismiss()
    }
}
