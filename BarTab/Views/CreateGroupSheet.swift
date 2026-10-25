import SwiftUI

struct CreateGroupSheet: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var groupName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {

                    // Name entry card
                    VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
                        Text(String(localized: "GROUP NAME"))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        TextField(String(localized: "Group name"), text: $groupName)
                            .textInputAutocapitalization(.words)
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

                    Text(String(localized: "Friends you invite can create polls and vote on where to go."))
                        .font(.barTabSmall)
                        .foregroundColor(.barTabSecondary)

                    // Create action
                    Button {
                        Task { await createGroup() }
                    } label: {
                        Text(String(localized: "Create Group"))
                    }
                    .barTabPrimaryButton()
                    .padding(.top, BarTabSpacing.xs)
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "New Group"))
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