import SwiftUI

struct SetAlertSheet: View {

    let bar: Bar
    let drink: Drink
    let size: DrinkSize
    let brand: String?

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.presentationMode) private var presentationMode

    @State private var targetPrice = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text(bar.name)
                        Spacer()
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.barTabPrimary)
                    }

                    HStack {
                        Text(drink.displayName)
                        Spacer()
                        Text(size.displayName)
                            .foregroundColor(.secondary)
                    }

                    if let brand {
                        HStack {
                            Text("Brand")
                            Spacer()
                            Text(brand)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Alert for")
                }

                Section {
                    HStack {
                        Text(Currency.defaultCurrency.symbol)
                        TextField("Any price", text: $targetPrice)
                            .keyboardType(.decimalPad)
                    }

                    Text("Leave empty to be alerted on any new price. Set a value to be notified when the price drops to or below it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Target price")
                }
            }
            .navigationTitle("Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Set") {
                        Task { await createAlert() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func createAlert() async {
        isSaving = true
        let price = Double(targetPrice.replacingOccurrences(of: ",", with: "."))
        do {
            _ = try await SupabaseClient.shared.createPriceAlert(
                barID: bar.id,
                drink: drink.rawValue,
                size: size.rawValue,
                brand: brand,
                targetPrice: price
            )
            HapticEngine.success()
            toastCenter.show("Alert set", kind: .success)
            presentationMode.wrappedValue.dismiss()
        } catch {
            toastCenter.showError(error)
        }
        isSaving = false
    }
}
