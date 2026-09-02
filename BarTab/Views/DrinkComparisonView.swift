import SwiftUI

struct DrinkComparisonView: View {

    let drink: Drink
    let brand: String?
    let size: DrinkSize
    let style: String?
    let serving: ServingMethod?

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var results: [(bar: Bar, summary: PriceSummary)] = []
    @State private var selectedBar: Bar?

    private var title: String {
        var parts = [drink.displayName]
        if let brand { parts.append(brand) }
        parts.append(size.displayName)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                if results.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "barchart.xaxis.2")
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)
                        Text("No comparisons found")
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()
                } else {
                    Text("\(results.count) bars have this drink")
                        .font(.barTabSmall)
                        .foregroundColor(.barTabSecondary)

                    ForEach(Array(results.enumerated()), id: \.element.bar.id) { index, result in
                        Button {
                            selectedBar = result.bar
                        } label: {
                            HStack(spacing: 12) {
                                // Rank
                                Text("\(index + 1)")
                                    .font(.barTabHeading)
                                    .foregroundColor(.barTabPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Color.barTabPrimary.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.bar.name)
                                        .font(.barTabBody)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.barTabText)
                                    Text(result.bar.address)
                                        .font(.barTabTiny)
                                        .foregroundColor(.barTabSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Currency.defaultCurrency.symbol)\(result.summary.convertedAmount.formattedAmount)")
                                        .font(.barTabBody)
                                        .fontWeight(.bold)
                                        .foregroundColor(.barTabPrimary)

                                    Text("\(result.summary.confidence)% confidence")
                                        .font(.barTabTiny)
                                        .foregroundColor(.barTabSecondary)
                                }
                            }
                            .padding(12)
                            .barTabCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Compare Prices")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBar) { bar in
            NavigationView {
                BarView(bar: bar, allowsDismissal: true)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            results = barRepository.compareDrink(
                drink: drink,
                brand: brand,
                size: size,
                style: style,
                serving: serving
            )
        }
    }
}
