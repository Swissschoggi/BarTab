import SwiftUI

struct CreatePollSheet: View {

    let group: BarGroup

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var pollTitle = ""
    @State private var optionTexts: [String] = ["", ""]
    @State private var optionBarIDs: [UUID?] = [nil, nil]
    @State private var showingBarPicker = false
    @State private var barPickerIndex: Int = 0
    @State private var barSearchQuery = ""
    @State private var isSaving = false

    private var filteredBars: [Bar] {
        let query = barSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return Array(barRepository.bars.prefix(20)) }
        return barRepository.bars.filter {
            $0.name.lowercased().contains(query) ||
            $0.address.lowercased().contains(query)
        }
    }

    private var filledOptionCount: Int {
        optionTexts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var canCreate: Bool {
        !pollTitle.trimmingCharacters(in: .whitespaces).isEmpty
        && filledOptionCount >= 2
        && !isSaving
    }

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
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Option \(index + 1)", text: $optionTexts[index])
                                .textInputAutocapitalization(.words)

                            if let barID = optionBarIDs[index],
                               let bar = barRepository.getBar(id: barID) {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.barTabPrimary)
                                    Text(bar.name)
                                        .font(.caption)
                                        .foregroundColor(.barTabPrimary)
                                    Spacer()
                                    Button {
                                        optionBarIDs[index] = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.barTabSecondary)
                                    }
                                }
                                .padding(.horizontal, 4)
                            } else {
                                Button {
                                    barPickerIndex = index
                                    showingBarPicker = true
                                } label: {
                                    Label("Link a bar", systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }
                        }
                    }

                    Button {
                        optionTexts.append("")
                        optionBarIDs.append(nil)
                    } label: {
                        Label("Add option", systemImage: "plus")
                    }
                } header: {
                    Text("Options")
                } footer: {
                    if filledOptionCount < 2 {
                        Text("Add at least 2 options to create a poll.")
                            .foregroundColor(.red)
                    } else {
                        Text("Add bars, drinks, or whatever you're deciding on. Link bars to show their location in the poll.")
                    }
                }
            }
            .navigationTitle("New Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task { await createPoll() }
                    }
                    .disabled(!canCreate)
                }
            }
            .sheet(isPresented: $showingBarPicker) {
                NavigationView {
                    List {
                        TextField("Search bars...", text: $barSearchQuery)
                            .textInputAutocapitalization(.never)
                            .listRowSeparator(.hidden)

                        ForEach(filteredBars) { bar in
                            Button {
                                optionBarIDs[barPickerIndex] = bar.id
                                showingBarPicker = false
                                barSearchQuery = ""
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bar.name)
                                        .font(.subheadline)
                                        .foregroundColor(.barTabText)
                                    Text(bar.address)
                                        .font(.caption2)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Bar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingBarPicker = false
                                barSearchQuery = ""
                            }
                        }
                    }
                }
            }
        }
    }

    private func createPoll() async {
        let title = pollTitle.trimmingCharacters(in: .whitespaces)
        let texts = optionTexts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let options: [(barID: UUID?, label: String)] = zip(texts, Array(optionBarIDs.prefix(texts.count))).map { (barID: $1, label: $0) }

        guard !title.isEmpty, options.count >= 2 else {
            toastCenter.show("Add at least 2 options to create a poll.", kind: .error)
            return
        }

        isSaving = true
        do {
            _ = try await SupabaseClient.shared.createPoll(
                groupID: group.id,
                title: title,
                options: options
            )
            HapticEngine.success()
            toastCenter.show("Poll created", kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}
