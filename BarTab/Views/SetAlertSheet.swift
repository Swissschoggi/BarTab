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
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {

                    // Alert-for card
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text(String(localized: "ALERT FOR"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        HStack {
                            Text(bar.name)
                                .font(.BartapBody)
                                .foregroundColor(.BartapText)
                            Spacer()
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.BartapPrimary)
                        }

                        HStack {
                            Text(drink.displayName)
                                .font(.BartapBody)
                                .foregroundColor(.BartapText)
                            Spacer()
                            Text(size.displayName)
                                .font(.BartapBody)
                                .foregroundColor(.BartapSecondary)
                        }

                        if let brand {
                            HStack {
                                Text(String(localized: "Brand"))
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapText)
                                Spacer()
                                Text(brand)
                                    .font(.BartapBody)
                                    .foregroundColor(.BartapSecondary)
                            }
                        }
                    }
                    .padding(BartapSpacing.md)
                    .background(Color.BartapCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                    )

                    // Target price card
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text(String(localized: "TARGET PRICE"))
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        HStack {
                            Text(Currency.defaultCurrency.symbol)
                                .font(.BartapBody)
                                .foregroundColor(.BartapSecondary)
                            TextField(String(localized: "Any price"), text: $targetPrice)
                                .keyboardType(.decimalPad)
                                .font(.BartapBody)
                                .foregroundColor(.BartapText)
                        }

                        if let price = parsedPrice, price < 0 {
                            Text(String(localized: "Price cannot be negative."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapDanger)
                        } else if let price = parsedPrice, price == 0 {
                            Text(String(localized: "Price must be greater than zero, or leave empty for any price."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapDanger)
                        } else {
                            Text(String(localized: "Leave empty to be alerted on any new price. Set a value to be notified when the price drops to or below it."))
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                        }
                    }
                    .padding(BartapSpacing.md)
                    .background(Color.BartapCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                    )

                    Button {
                        Task { await createAlert() }
                    } label: {
                        Text(String(localized: "Set Alert"))
                    }
                    .BartapPrimaryButton()
                    .padding(.top, BartapSpacing.xs)
                    .disabled(isSaving)
                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.md)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(String(localized: "Price Alert"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.BartapPrimary)
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