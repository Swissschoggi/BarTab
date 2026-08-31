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

    private var averageData: (average: Double, count: Int)? {
        barRepository.averageDrinkQuality(
            for: bar, drink: drink, brand: brand, size: size
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 6) {
                        Text(drink.displayName)
                            .font(.title3.bold())

                        if let brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(size.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // Average from all users
                    if let data = averageData {
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(data.average.rounded()) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .font(.title2)

                            Text(String(format: "%.1f", data.average))
                                .font(.headline)
                                + Text(" from \(data.count) \(data.count == 1 ? "rating" : "ratings")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .barTabCard()
                    } else {
                        Text("No ratings yet   be the first!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .barTabCard()
                    }

                    // Your rating
                    VStack(spacing: 10) {
                        Text("Your rating")
                            .font(.headline)

                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    HapticEngine.lightTap()
                                    quality = star
                                } label: {
                                    Image(systemName: star <= quality ? "star.fill" : "star")
                                        .font(.system(size: 36))
                                        .foregroundColor(star <= quality ? .yellow : .gray)
                                }
                            }
                        }
                    }
                    .padding()
                    .barTabCard()
                }
                .padding(.horizontal)
            }
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
