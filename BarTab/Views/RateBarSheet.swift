import SwiftUI

/// Lets the current user rate a bar's ambience and wine selection.
/// Submitting upserts their existing rating for this bar, if any.
struct RateBarSheet: View {

    let bar: Bar

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @State private var ambience: Int?
    @State private var wineQuality: Int?

    init(bar: Bar, initialAmbience: Int?, initialWineQuality: Int?) {
        self.bar = bar
        _ambience = State(initialValue: initialAmbience)
        _wineQuality = State(initialValue: initialWineQuality)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 28) {

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ambience")
                        .font(.headline)

                    Text("How's the vibe at \(bar.name)?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    StarRatingView(rating: $ambience)
                }
                .barTabCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Wine selection")
                        .font(.headline)

                    Text("How good is the wine here?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    StarRatingView(rating: $wineQuality)
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
                .disabled(ambience == nil && wineQuality == nil)
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
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func submit() {
        guard let user = userSession.currentUser else {
            presentationMode.wrappedValue.dismiss()
            return
        }

        Task {
            await barRepository.submitRating(
                for: bar,
                ambience: ambience,
                wineQuality: wineQuality,
                by: user
            )
            presentationMode.wrappedValue.dismiss()
        }
    }
}
