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
    @State private var priceError: String?

    init(bar: Bar, editingPrice: Price? = nil) {
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

    private var availableBrands: [String] {
        barRepository.brands(for: selectedDrink).map(\.name)
    }

    private var availableStyles: [DrinkStyle] {
        DrinkStyle.styles(for: selectedDrink)
    }

    private var availableServingMethods: [ServingMethod] {
        switch selectedDrink {
        case .beer: return [.tap, .bottle, .can]
        case .wine: return [.glass, .bottle]
        case .cocktail: return [.glass]
        case .softDrink: return [.bottle, .can, .glass]
        case .coffee: return [.glass]
        case .shot: return [.glass]
        case .other: return ServingMethod.allCases
        }
    }

    private var availableSizes: [DrinkSize] {
        switch selectedDrink {
        case .beer: return [.twentyCentiliters, .twentyFiveCentiliters, .thirtyThreeCentiliters, .fiveDeciliters, .bottle]
        case .wine: return [.oneDeciliter, .twoDeciliters, .threeDeciliters, .bottle, .glass]
        case .cocktail: return [.glass]
        case .shot: return [.shot]
        case .softDrink: return [.twentyCentiliters, .twentyFiveCentiliters, .thirtyThreeCentiliters, .fiftyCentiliters, .bottle]
        case .coffee: return [.oneDeciliter, .twoDeciliters, .threeDeciliters, .glass]
        case .other: return DrinkSize.allCases
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: BarTabSpacing.lg) {
                    
                    // Main Numeric Entry Card
                    VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
                        Text("PRICE")
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: BarTabSpacing.xs) {
                            Text(selectedCurrency.symbol)
                                .font(.barTabTitle)
                                .foregroundColor(.barTabSecondary)

                            TextField("0.00", text: $priceText)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(.barTabText)
                                .keyboardType(.decimalPad)

                            Spacer()

                            Picker("", selection: $selectedCurrency) {
                                ForEach(Currency.allCases) { currency in
                                    Text(currency.rawValue).tag(currency)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.barTabPrimary)
                        }

                        if let error = priceError {
                            Text(error)
                                .font(.barTabCaption)
                                .foregroundColor(.barTabDanger)
                        }
                    }
                    .padding(BarTabSpacing.md)
                    .background(Color.barTabCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BarTabRadius.card, style: .continuous)
                            .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                    )

                    // Category Selection
                    selectorGroup(title: "CATEGORY") {
                        FlowLayout(spacing: BarTabSpacing.xs) {
                            ForEach(Drink.allCases) { drink in
                                pillButton(
                                    title: drink.displayName,
                                    icon: drink.icon,
                                    isSelected: selectedDrink == drink
                                ) {
                                    selectedDrink = drink
                                }
                            }
                        }
                    }

                    // Size Selection
                    if !availableSizes.isEmpty {
                        selectorGroup(title: "SIZE") {
                            FlowLayout(spacing: BarTabSpacing.xs) {
                                ForEach(availableSizes, id: \.self) { size in
                                    pillButton(
                                        title: size.displayName,
                                        isSelected: selectedSize == size
                                    ) {
                                        selectedSize = size
                                    }
                                }
                            }
                        }
                    }

                    // Serving Method
                    if !availableServingMethods.isEmpty {
                        selectorGroup(title: "SERVING METHOD") {
                            FlowLayout(spacing: BarTabSpacing.xs) {
                                pillButton(
                                    title: "Any",
                                    isSelected: selectedServing == nil
                                ) {
                                    selectedServing = nil
                                }
                                ForEach(availableServingMethods, id: \.self) { method in
                                    pillButton(
                                        title: method.displayName,
                                        icon: method.icon,
                                        isSelected: selectedServing == method
                                    ) {
                                        selectedServing = method
                                    }
                                }
                            }
                        }
                    }

                    // Brand Selection
                    if !availableBrands.isEmpty {
                        selectorGroup(title: "BRAND") {
                            FlowLayout(spacing: BarTabSpacing.xs) {
                                pillButton(
                                    title: "Any",
                                    isSelected: selectedBrand == nil
                                ) {
                                    selectedBrand = nil
                                }
                                ForEach(availableBrands, id: \.self) { brand in
                                    pillButton(
                                        title: brand,
                                        isSelected: selectedBrand == brand
                                    ) {
                                        selectedBrand = brand
                                    }
                                }
                            }
                        }
                    }

                    // Style Selection
                    if !availableStyles.isEmpty {
                        selectorGroup(title: "STYLE") {
                            FlowLayout(spacing: BarTabSpacing.xs) {
                                pillButton(
                                    title: "Any",
                                    isSelected: selectedStyle == nil
                                ) {
                                    selectedStyle = nil
                                }
                                ForEach(availableStyles, id: \.self) { style in
                                    pillButton(
                                        title: style.displayName,
                                        isSelected: selectedStyle == style
                                    ) {
                                        selectedStyle = style
                                    }
                                }
                            }
                        }
                    }

                    // Save Action Button
                    Button(action: savePrice) {
                        Text(editingPrice != nil ? "Update Price" : "Save Price")
                    }
                    .barTabPrimaryButton()
                    .padding(.top, BarTabSpacing.xs)
                    .disabled(isSaving)
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.md)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle(editingPrice != nil ? "Edit Price" : "New Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.barTabPrimary)
                }
            }
            .onChange(of: selectedDrink) { _ in
                selectedBrand = nil
                selectedStyle = nil
                selectedServing = nil
                if !availableSizes.contains(selectedSize) {
                    selectedSize = availableSizes.first ?? .glass
                }
            }
        }
    }

    // MARK: - Subviews & Helpers

    private func selectorGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.xs) {
            Text(title)
                .font(.barTabCaption)
                .foregroundColor(.barTabSecondary)
            content()
        }
    }

    private func pillButton(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.barTabCaption)
                }
                Text(title)
                    .font(.barTabCaption)
            }
            .padding(.horizontal, BarTabSpacing.sm)
            .padding(.vertical, 8)
            .background(isSelected ? Color.barTabPrimary : Color.barTabSurface)
            .foregroundColor(isSelected ? .white : .barTabText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func savePrice() {
        guard !isSaving else { return }

        guard let amount = Decimal(string: priceText), amount > 0 else {
            priceError = "Please enter a valid price."
            return
        }

        priceError = nil
        guard let user = userSession.currentUser else { return }
        isSaving = true

        Task {
            if let editingPrice = editingPrice {
                await barRepository.updatePrice(
                    editingPrice,
                    drink: selectedDrink,
                    brand: selectedBrand,
                    size: selectedSize,
                    amount: amount,
                    currency: selectedCurrency.rawValue,
                    style: selectedStyle?.rawValue,
                    serving: selectedServing,
                    reportedBy: user
                )
            } else {
                _ = await barRepository.addPrice(
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
            }

            HapticEngine.success()
            toastCenter.show("Price saved", kind: .success)
            dismiss()
        }
    }
}
