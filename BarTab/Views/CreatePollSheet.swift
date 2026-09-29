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
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {

                    // Question Section
                    selectorGroup(title: String(localized: "QUESTION")) {
                        TextField(String(localized: "What are we deciding?"), text: $pollTitle)
                            .textInputAutocapitalization(.sentences)
                            .padding(.vertical, 12)
                            .padding(.horizontal, BarTabSpacing.md)
                            .background(Color.barTabSurface)
                            .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                                    .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                            )
                    }

                    // Options Section
                    VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                        HStack {
                            Text(String(localized: "OPTIONS"))
                                .font(.barTabCaption)
                                .foregroundColor(.barTabSecondary)
                            Spacer()
                        }

                        VStack(spacing: BarTabSpacing.sm) {
                            ForEach(0..<optionTexts.count, id: \.self) { index in
                                optionRow(index: index)
                            }

                            Button {
                                optionTexts.append("")
                                optionBarIDs.append(nil)
                            } label: {
                                Label(String(localized: "Add option"), systemImage: "plus")
                                    .barTabSecondaryButton()
                            }
                        }
                    }
                    .barTabCard()

                    if filledOptionCount < 2 {
                        Text(String(localized: "Add at least 2 options to create a poll."))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabDanger)
                    } else {
                        Text(String(localized: "Add bars, drinks, or whatever you're deciding on. Link bars to show their location in the poll."))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)
                    }
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "New Poll"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Create")) {
                        Task { await createPoll() }
                    }
                    .disabled(!canCreate)
                }
            }
            .sheet(isPresented: $showingBarPicker) {
                NavigationView {
                    List {
                        TextField(String(localized: "Search bars..."), text: $barSearchQuery)
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
                                        .font(.barTabBody)
                                        .foregroundColor(.barTabText)
                                    Text(bar.address)
                                        .font(.barTabTiny)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }
                        }
                    }
                    .navigationTitle(String(localized: "Select Bar"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(String(localized: "Cancel")) {
                                showingBarPicker = false
                                barSearchQuery = ""
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private func selectorGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
            Text(title)
                .font(.barTabCaption)
                .foregroundColor(.barTabSecondary)
            content()
        }
    }

    private func optionRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
            TextField(String(localized: "Option \(index + 1)"), text: $optionTexts[index])
                .textInputAutocapitalization(.words)
                .padding(.vertical, 12)
                .padding(.horizontal, BarTabSpacing.md)
                .background(Color.barTabSurface)
                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                        .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                )

            HStack(spacing: 8) {
                if let barID = optionBarIDs[index],
                   let bar = barRepository.getBar(id: barID) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.barTabTiny)
                            .foregroundColor(.barTabPrimary)
                        Text(bar.name)
                            .font(.barTabSmall)
                            .foregroundColor(.barTabPrimary)
                        Spacer()
                        Button {
                            optionBarIDs[index] = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.barTabPrimary.opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    Button {
                        barPickerIndex = index
                        showingBarPicker = true
                    } label: {
                        Label(String(localized: "Link a bar"), systemImage: "mappin.and.ellipse")
                            .font(.barTabSmall)
                            .foregroundColor(.barTabSecondary)
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
            toastCenter.show(String(localized: "Add at least 2 options to create a poll."), kind: .error)
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
            toastCenter.show(String(localized: "Poll created"), kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}

struct CreatePollSheet_Previews: PreviewProvider {
    static var previews: some View {
        CreatePollSheet(group: BarGroup(id: UUID(), name: "Test Group", createdBy: UUID(), createdAt: Date()))
            .environmentObject(BarRepository())
            .environmentObject(UserSession())
            .environmentObject(ToastCenter())
    }
}