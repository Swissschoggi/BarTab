import SwiftUI

struct CreatePollSheet: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.presentationMode) private var presentationMode

    @State private var pollTitle = ""
    @State private var optionTexts: [String] = ["", ""]
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("What are we deciding?", text: $pollTitle)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Poll question")
                }

                Section {
                    ForEach(0..<optionTexts.count, id: \.self) { index in
                        TextField("Option \(index + 1)", text: $optionTexts[index])
                            .textInputAutocapitalization(.words)
                    }

                    Button {
                        optionTexts.append("")
                    } label: {
                        Label("Add option", systemImage: "plus")
                    }
                } header: {
                    Text("Options")
                } footer: {
                    Text("Add bars, drinks, or whatever you're deciding on.")
                }
            }
            .navigationTitle("New Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await createPoll() }
                    }
                    .disabled(pollTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func createPoll() async {
        let title = pollTitle.trimmingCharacters(in: .whitespaces)
        let options = optionTexts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { (barID: nil, label: $0) }

        guard !title.isEmpty, options.count >= 2 else { return }

        isSaving = true
        do {
            _ = try await SupabaseClient.shared.createPoll(
                groupID: group.id,
                title: title,
                options: options
            )
            HapticEngine.success()
            toastCenter.show("Poll created", kind: .success)
            presentationMode.wrappedValue.dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}
