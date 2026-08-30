import SwiftUI

struct AddPriceView: View {

    let bar: Bar
    let editingPrice: Price?

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDrink: Drink = .beer
    @State private var selectedSize: DrinkSize = .fiveDeciliters
    @State private var selectedBrand: String? = nil
    @State private var selectedStyle: DrinkStyle? = nil
    @State private var selectedServing: ServingMethod? = nil
    @State private var selectedCurrency: Currency = Currency.defaultCurrency
    @State private var isSaving = false
    @State private var priceText = ""
    @State private var showingDuplicateWarning = false
    @State private var duplicatePrice: Price?
    @State private var showingRequestBrand = false
    @State private var priceError: String?

    init(
        bar: Bar,
        editingPrice: Price? = nil
    ) {
        self.bar = bar
        self.editingPrice = editingPrice

        if let price = editingPrice {
            _selectedDrink = State(initialValue: price.drink)
            _selectedSize = State(initialValue: price.size)
            _selectedBrand = State(initialValue: price.brand)
            _selectedStyle = State(initialValue: price.style.flatMap { DrinkStyle(rawValue: $0) })
            _selectedServing = State(initialValue: price.serving)
            _selectedCurrency = State(initialValue: Currency(rawValue: price.currency) ?? .defaultCurrency)
            _priceText = State(initialValue: price.formattedAmount)
        }
    }

    private var isEditing: Bool { editingPrice != nil }

    private var availableBrands: [String] {
        barRepository.brands(for: selectedDrink).map(\.name)
    }

    private var availableStyles: [DrinkStyle] {
        DrinkStyle.styles(for: selectedDrink)
    }

    private var availableServingMethods: [ServingMethod] {
        switch selectedDrink {
        case .beer:
            return [.tap, .bottle, .can]
        case .wine:
            return [.glass, .bottle]
        case .cocktail:
            return [.glass]
        case .softDrink:
            return [.bottle, .can, .glass]
        case .coffee:
            return [.glass]
        case .shot:
            return [.glass]
        case .other:
            return ServingMethod.allCases
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

                if !availableStyles.isEmpty {
                    Section(header: Text("Style")) {
                        Picker(
                            "Style",
                            selection: $selectedStyle
                        ) {
                            Text("Not specified")
                                .tag(DrinkStyle?.none)

                            ForEach(availableStyles) { style in
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .font(.caption)
                                    Text(style.displayName)
                                }
                                .tag(DrinkStyle?.some(style))
                            }
                        }
                    }
                }

                if !availableServingMethods.isEmpty {
                    Section(header: Text("Serving")) {
                        Picker(
                            "Serving",
                            selection: $selectedServing
                        ) {
                            Text("Not specified")
                                .tag(ServingMethod?.none)

                            ForEach(availableServingMethods) { method in
                                HStack {
                                    Image(systemName: method.icon)
                                        .font(.caption)
                                    Text(method.displayName)
                                }
                                .tag(ServingMethod?.some(method))
                            }
                        }
                    }
                }


                Section(header: Text("Brand")) {

                    if !availableBrands.isEmpty {

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

                    Button {
                        showingRequestBrand = true
                    } label: {
                        Label(
                            "Can't find it? Request a brand",
                            systemImage: "plus.circle"
                        )
                        .font(.subheadline)
                        .foregroundColor(.barTabPrimary)
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

                    HStack(spacing: 8) {

                        Menu {
                            ForEach(Currency.allCases) { currency in
                                Button {
                                    selectedCurrency = currency
                                } label: {
                                    HStack {
                                        Text(currency.symbol)
                                        Text(currency.rawValue)
                                        if selectedCurrency == currency {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedCurrency.symbol)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.barTabPillFill)
                            .clipShape(Capsule())
                        }

                        TextField(
                            "0.00",
                            text: $priceText
                        )
                        .keyboardType(.decimalPad)
                    }

                    if let error = priceError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }


                Section {

                    Button {

                        savePrice()

                    } label: {

                        Text(isEditing ? "Save Changes" : "Add Drink")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(
                        Color.barTabPrimary
                    )
                    .disabled(isSaving)
                }
            }
            .navigationTitle(isEditing ? "Edit Drink" : "Add Drink")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(
                Color.barTabBackground
                    .ignoresSafeArea()
            )

            .onChange(of: selectedDrink) { _ in

                selectedBrand = nil
                selectedStyle = nil
                selectedServing = nil

                if !availableSizes.contains(selectedSize) {

                    selectedSize =
                        availableSizes.first
                        ?? .glass
                }
            }
            .alert(
                "Drink already exists",
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

                    isSaving = true
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
            .sheet(isPresented: $showingRequestBrand) {
                RequestBrandSheet(drink: selectedDrink)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
            }
        }
    }


    private func savePrice() {

        guard !isSaving else { return }

        guard let amount = Decimal(string: priceText) else {
            priceError = "Please enter a valid price."
            return
        }

        guard amount > 0 else {
            priceError = "Price must be greater than zero."
            return
        }

        priceError = nil

        guard let user = userSession.currentUser else {
            return
        }

        if let editingPrice {
            isSaving = true
            actuallyUpdatePrice(
                editingPrice,
                amount: amount,
                user: user
            )
            return
        }

        let existingPrices = barRepository.getPrices(for: bar)

        if let existing = existingPrices.first(where: { price in

            price.drink == selectedDrink &&
            price.size == selectedSize &&
            price.brand == selectedBrand &&
            price.currency == selectedCurrency.rawValue &&
            price.style == selectedStyle?.rawValue &&
            price.serving == selectedServing
        }) {

            duplicatePrice = existing
            HapticEngine.warning()
            showingDuplicateWarning = true
            return
        }

        isSaving = true
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
                currency: selectedCurrency.rawValue,
                style: selectedStyle?.rawValue,
                serving: selectedServing,
                reportedBy: user
            )

            if success {
                HapticEngine.success()
                toastCenter.show("Price saved", kind: .success)
                dismiss()
            } else {
                isSaving = false
                toastCenter.show(
                    "Couldn't save drink",
                    kind: .error
                )
            }
        }
    }

    private func actuallyUpdatePrice(
        _ price: Price,
        amount: Decimal,
        user: User
    ) {

        Task {

            await barRepository.updatePrice(
                price,
                drink: selectedDrink,
                brand: selectedBrand,
                size: selectedSize,
                amount: amount,
                currency: selectedCurrency.rawValue,
                style: selectedStyle?.rawValue,
                serving: selectedServing,
                reportedBy: user
            )

            HapticEngine.success()
            toastCenter.show("Price updated", kind: .success)
            dismiss()
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
        .environmentObject(
            ToastCenter()
        )
    }
}
