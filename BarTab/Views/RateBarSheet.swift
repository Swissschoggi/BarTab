import SwiftUI

/// Lets the current user rate a bar's ambience (multi-select).
struct RateBarSheet: View {

    let bar: Bar

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAmbiences: Set<AmbienceStyle>

    init(bar: Bar, initialAmbience: [AmbienceStyle]) {
        self.bar = bar
        _selectedAmbiences = State(initialValue: Set(initialAmbience))
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 28) {

                VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
                    Text("Ambience")
                        .font(.barTabHeading)

                    Text("What's the vibe at \(bar.name)? Select all that apply.")
                        .font(.barTabSmall)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(AmbienceStyle.allCases) { style in
                            Button {
                                if selectedAmbiences.contains(style) {
                                    selectedAmbiences.remove(style)
                                } else {
                                    selectedAmbiences.insert(style)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: style.icon)
                                        .font(.barTabSmall)
                                    Text(style.displayName)
                                        .font(.barTabSmall)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(selectedAmbiences.contains(style) ? .white : .barTabPrimary)
                                .background(selectedAmbiences.contains(style) ? Color.barTabPrimary : Color.barTabPillFill)
                                .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.chip, style: .continuous))
                            }
                        }
                    }
                }
                .barTabCard()

                Spacer()

                Button {
                    submit()
                } label: {
                    Text("Save rating")
                        .font(.barTabHeading)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .barTabPrimaryButton()
                }
                .disabled(selectedAmbiences.isEmpty)
            }
            .padding()
            .background(
                Color.barTabBackground.ignoresSafeArea()
            )
            .navigationTitle("Rate this bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func submit() {
        guard let user = userSession.currentUser else {
            dismiss()
            return
        }

        HapticEngine.impact()

        Task {
            await barRepository.submitRating(
                for: bar,
                ambience: Array(selectedAmbiences),
                wineQuality: nil,
                by: user
            )
            dismiss()
        }
    }
}
