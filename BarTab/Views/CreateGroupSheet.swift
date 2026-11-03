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
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    // Name entry card
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text(String(localized: "GROUP NAME"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        TextField(String(localized: "Group name"), text: $groupName)
                            .textInputAutocapitalization(.words)
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

                    Text(String(localized: "Friends you invite can create polls and vote on where to go."))
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)

                    // Create action
                    Button {
                        Task { await createGroup() }
                    } label: {
                        Text(String(localized: "Create Group"))
                    }
                    .BartapPrimaryButton()
                    .padding(.top, BartapSpacing.xs)
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.md)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "New Group"))
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