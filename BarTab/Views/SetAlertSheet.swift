import SwiftUI

struct SetAlertSheet: View {

    let bar: Bar
    let drink: Drink
    let size: DrinkSize
    let brand: String?

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var targetPrice = ""
    @State private var isSaving = false

    private var parsedPrice: Double? {
        Double(targetPrice.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {

                    // Alert-for card
                    VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
                        Text(String(localized: "ALERT FOR"))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        HStack {
                            Text(bar.name)
                                .font(.barTabBody)
                                .foregroundColor(.barTabText)
                            Spacer()
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.barTabPrimary)
                        }

                        HStack {
                            Text(drink.displayName)
                                .font(.barTabBody)
                                .foregroundColor(.barTabText)
                            Spacer()
                            Text(size.displayName)
                                .font(.barTabBody)
                                .foregroundColor(.barTabSecondary)
                        }

                        if let brand {
                            HStack {
                                Text(String(localized: "Brand"))
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabText)
                                Spacer()
                                Text(brand)
                                    .font(.barTabBody)
                                    .foregroundColor(.barTabSecondary)
                            }
                        }
                    }
                    .padding(BarTabSpacing.md)
                    .background(Color.barTabCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                            .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                    )

                    // Target price card
                    VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
                        Text(String(localized: "TARGET PRICE"))
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        HStack {
                            Text(Currency.defaultCurrency.symbol)
                                .font(.barTabBody)
                                .foregroundColor(.barTabSecondary)
                            TextField(String(localized: "Any price"), text: $targetPrice)
                                .keyboardType(.decimalPad)
                                .font(.barTabBody)
                                .foregroundColor(.barTabText)
                        }

                        if let price = parsedPrice, price < 0 {
                            Text(String(localized: "Price cannot be negative."))
                                .font(.barTabSmall)
                                .foregroundColor(.barTabDanger)
                        } else if let price = parsedPrice, price == 0 {
                            Text(String(localized: "Price must be greater than zero, or leave empty for any price."))
                                .font(.barTabSmall)
                                .foregroundColor(.barTabDanger)
                        } else {
                            Text(String(localized: "Leave empty to be alerted on any new price. Set a value to be notified when the price drops to or below it."))
                                .font(.barTabSmall)
                                .foregroundColor(.barTabSecondary)
                        }
                    }
                    .padding(BarTabSpacing.md)
                    .background(Color.barTabCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                            .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                    )

                    Button {
                        Task { await createAlert() }
                    } label: {
                        Text(String(localized: "Set Alert"))
                    }
                    .barTabPrimaryButton()
                    .padding(.top, BarTabSpacing.xs)
                    .disabled(isSaving)
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "Price Alert"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.barTabPrimary)
                }
            }
        }
    }

    private func createAlert() async {
        ReportNotificationService.requestPermission()
        isSaving = true
        let price = parsedPrice
        do {
            _ = try await SupabaseClient.shared.createPriceAlert(
                barID: bar.id,
                drink: drink.rawValue,
                size: size.rawValue,
                brand: brand,
                targetPrice: price
            )
            HapticEngine.success()
            toastCenter.show(String(localized: "Alert set"), kind: .success)
            dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}