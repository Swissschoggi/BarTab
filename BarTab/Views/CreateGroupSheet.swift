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
                    TextField("Group name", text: $groupName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name your group")
                } footer: {
                    Text("Friends you invite can create polls and vote on where to go.")
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
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
            toastCenter.show("Group created", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}
