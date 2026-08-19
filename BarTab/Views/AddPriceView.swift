import SwiftUI

struct AddPriceView: View {

    let bar: Bar

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedDrink: Drink = .beer
    @State private var selectedSize: DrinkSize = .fiveDeciliters
    @State private var selectedBrand: String? = nil
    @State private var priceText = ""
    @State private var showingDuplicateWarning = false
    @State private var duplicatePrice: Price?
    @State private var errorMessage: String?

    private var availableBrands: [String] {

        switch selectedDrink {

        case .beer:
            return [
                "Feldschlösschen",
                "Calanda",
                "Quöllfrisch",
                "Cardinal",
                "Appenzeller",
                "Heineken",
                "Corona",
                "Guinness"
            ]

        case .wine:
            return [
                "Féchy",
                "Epesses",
                "Pinot Noir",
                "Merlot",
                "Chardonnay",
                "Sauvignon Blanc"
            ]

        default:
            return []
        }
    }


    private var availableSizes: [DrinkSize] {

        switch selectedDrink {

        case .beer:
            return [
                .twentyCentiliters,
                .twentyFiveCentiliters,
                .thirtyThreeCentiliters,
                .fiveDeciliters,
                .bottle
            ]

        case .wine:
            return [
                .oneDeciliter,
                .twoDeciliters,
                .threeDeciliters,
                .bottle,
                .glass
            ]

        case .cocktail:
            return [
                .glass
            ]

        case .shot:
            return [
                .shot
            ]

        case .softDrink:
            return [
                .twentyCentiliters,
                .twentyFiveCentiliters,
                .thirtyThreeCentiliters,
                .fiftyCentiliters,
                .bottle
            ]

        case .coffee:
            return [
                .oneDeciliter,
                .twoDeciliters,
                .threeDeciliters,
                .glass
            ]

        case .other:
            return DrinkSize.allCases
        }
    }


    var body: some View {

        NavigationView {

            Form {


                Section(header: Text("Drink")) {

                    Picker(
                        "Type",
                        selection: $selectedDrink
                    ) {

                        ForEach(
                            Drink.allCases,
                            id: \.self
                        ) { drink in

                            Text(drink.displayName)
                                .tag(drink)
                        }
                    }
                }


                if !availableBrands.isEmpty {

                    Section(header: Text("Brand / Type")) {

                        Picker(
                            "Brand",
                            selection: Binding(
                                get: {
                                    selectedBrand ?? ""
                                },
                                set: { value in
                                    selectedBrand =
                                        value.isEmpty
                                        ? nil
                                        : value
                                }
                            )
                        ) {

                            Text("Not specified")
                                .tag("")

                            ForEach(
                                availableBrands,
                                id: \.self
                            ) { brand in

                                Text(brand)
                                    .tag(brand)
                            }
                        }
                    }
                }


                Section(header: Text("Size")) {

                    Picker(
                        "Size",
                        selection: $selectedSize
                    ) {

                        ForEach(
                            availableSizes,
                            id: \.self
                        ) { size in

                            Text(size.displayName)
                                .tag(size)
                        }
                    }
                }


                Section(header: Text("Price")) {

                    HStack {

                        Text("CHF")

                        TextField(
                            "0.00",
                            text: $priceText
                        )
                        .keyboardType(.decimalPad)
                    }
                }


                Section {

                    Button {

                        savePrice()

                    } label: {

                        Text("Add Price")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(
                        Color.barTabPrimary
                    )
                }
            }
            .navigationTitle("Add Price")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(
                Color.barTabBackground
                    .ignoresSafeArea()
            )

            .onChange(of: selectedDrink) { _ in

                selectedBrand = nil

                if !availableSizes.contains(selectedSize) {

                    selectedSize =
                        availableSizes.first
                        ?? .glass
                }
            }
            .alert(
                "Price already exists",
                isPresented: $showingDuplicateWarning
            ) {

                Button("Add Anyway") {

                    guard
                        let duplicatePrice,
                        let user = userSession.currentUser,
                        let amount = Decimal(string: priceText)
                    else {
                        return
                    }

                    actuallySavePrice(
                        amount: amount,
                        user: user
                    )
                }

                Button("Cancel", role: .cancel) {
                    duplicatePrice = nil
                }

            } message: {

                if let duplicatePrice {

                    Text(
                        "\(duplicatePrice.brand ?? duplicatePrice.drink.displayName) · \(duplicatePrice.size.displayName) already has a price of \(duplicatePrice.formattedAmount) \(duplicatePrice.currency) at this bar."
                    )

                } else {

                    Text(
                        "A price for this drink and size already exists at this bar."
                    )
                }
            }
            .alert(
                "Couldn't save price",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }


    private func savePrice() {

        guard let amount = Decimal(string: priceText) else {
            return
        }

        guard amount > 0 else {
            return
        }

        guard let user = userSession.currentUser else {
            return
        }

        let existingPrices = barRepository.getPrices(for: bar)

        if let existing = existingPrices.first(where: { price in

            price.drink == selectedDrink &&
            price.size == selectedSize &&
            price.brand == selectedBrand
        }) {

            duplicatePrice = existing
            showingDuplicateWarning = true
            return
        }

        actuallySavePrice(
            amount: amount,
            user: user
        )
    }
    private func actuallySavePrice(
        amount: Decimal,
        user: User
    ) {

        Task {

            let success = await barRepository.addPrice(
                to: bar,
                drink: selectedDrink,
                brand: selectedBrand,
                size: selectedSize,
                amount: amount,
                reportedBy: user
            )

            if success {
                presentationMode
                    .wrappedValue
                    .dismiss()
            } else {
                self.errorMessage =
                    "Could not save the price. "
                    + "Check your connection and try again."
            }
        }
    }


}


struct AddPriceView_Previews: PreviewProvider {

    static var previews: some View {

        AddPriceView(
            bar: Bar.mockBars[0]
        )
        .environmentObject(
            BarRepository()
        )
        .environmentObject(
            UserSession()
        )
    }
}
