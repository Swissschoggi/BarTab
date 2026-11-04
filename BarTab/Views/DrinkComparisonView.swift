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
                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)
                        Text(String(localized: "No comparisons found"))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()
                } else {
                    Text(String(localized: "\(results.count) bars have this drink"))
                        .font(.BartapSmall)
                        .foregroundColor(.BartapSecondary)

                    ForEach(Array(results.enumerated()), id: \.element.bar.id) { index, result in
                        Button {
                            selectedBar = result.bar
                        } label: {
                            HStack(spacing: 12) {
                                // Rank
                                Text("\(index + 1)")
                                    .font(.BartapHeading)
                                    .foregroundColor(.BartapPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Color.BartapPrimary.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.bar.name)
                                        .font(.BartapBody)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.BartapText)
                                    Text(result.bar.address)
                                        .font(.BartapTiny)
                                        .foregroundColor(.BartapSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Currency.defaultCurrency.symbol)\(result.summary.convertedAmount.formattedAmount)")
                                        .font(.BartapBody)
                                        .fontWeight(.bold)
                                        .foregroundColor(.BartapPrimary)

                                    Text(String(localized: "\(result.summary.confidence)% confidence"))
                                        .font(.BartapTiny)
                                        .foregroundColor(.BartapSecondary)
                                }
                            }
                            .padding(12)
                            .BartapCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Compare Prices"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedBar) { bar in
            NavigationStack {
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
