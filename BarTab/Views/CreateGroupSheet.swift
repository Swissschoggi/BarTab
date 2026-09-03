import SwiftUI

struct CreateGroupSheet: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var groupName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(String(localized: "Group name"), text: $groupName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text(String(localized: "Name your group"))
                } footer: {
                    Text(String(localized: "Friends you invite can create polls and vote on where to go."))
                }
            }
            .navigationTitle(String(localized: "New Group"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Create")) {
                        Task { await createGroup() }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func createGroup() async {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isSaving = true
        do {
            _ = try await SupabaseClient.shared.createGroup(name: name)
            HapticEngine.success()
            toastCenter.show(String(localized: "Group created"), kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}
