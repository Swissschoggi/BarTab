import SwiftUI

/// Lets the current user rate a bar's ambience.
/// Submitting upserts their existing rating for this bar, if any.
struct RateBarSheet: View {

    let bar: Bar

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var ambience: AmbienceStyle?

    init(bar: Bar, initialAmbience: AmbienceStyle?) {
        self.bar = bar
        _ambience = State(initialValue: initialAmbience)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 28) {

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ambience")
                        .font(.headline)

                    Text("What's the vibe at \(bar.name)?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Ambience", selection: $ambience) {
                        Text("Select...").tag(AmbienceStyle?.none)
                        ForEach(AmbienceStyle.allCases) { style in
                            HStack {
                                Image(systemName: style.icon)
                                Text(style.displayName)
                            }
                            .tag(AmbienceStyle?.some(style))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.barTabPrimary)
                }
                .barTabCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Drink quality")
                        .font(.headline)

                    Text("Rate the quality of specific drinks in the menu below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .barTabCard()

                Spacer()

                Button {
                    submit()
                } label: {
                    Text("Save rating")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .barTabPrimaryButton()
                }
                .disabled(ambience == nil)
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

        Task {
            await barRepository.submitRating(
                for: bar,
                ambience: ambience,
                wineQuality: nil,
                by: user
            )
            dismiss()
        }
    }
}
