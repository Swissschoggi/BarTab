import SwiftUI

struct DrinkRatingSheet: View {

    let bar: Bar
    let drink: Drink
    let brand: String?
    let size: DrinkSize
    let initialQuality: Int?

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var quality: Int

    init(
        bar: Bar,
        drink: Drink,
        brand: String?,
        size: DrinkSize,
        initialQuality: Int?
    ) {
        self.bar = bar
        self.drink = drink
        self.brand = brand
        self.size = size
        self.initialQuality = initialQuality
        _quality = State(initialValue: initialQuality ?? 3)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {

                VStack(spacing: 6) {
                    Text(drink.displayName)
                        .font(.headline)

                    if let brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(size.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("How's the quality?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            HapticEngine.lightTap()
                            quality = star
                        } label: {
                            Image(systemName: star <= quality ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(star <= quality ? .yellow : .gray)
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticEngine.impact()
                        Task {
                            guard let user = userSession.currentUser else { return }
                            await barRepository.submitDrinkRating(
                                for: bar,
                                drink: drink,
                                brand: brand,
                                size: size,
                                quality: quality,
                                by: user
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
