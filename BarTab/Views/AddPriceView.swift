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
    @State private var showingRequestBrand = false

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BartapSpacing.lg) {
                    
                    // Main Numeric Entry Card
                    VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                        Text("PRICE")
                            .font(.BartapCaption)
                            .foregroundColor(.BartapSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: BartapSpacing.xs) {
                            Text(selectedCurrency.symbol)
                                .font(.BartapTitle)
                                .foregroundColor(.BartapSecondary)

                            TextField("0.00", text: $priceText)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(.BartapText)
                                .keyboardType(.decimalPad)

                            Spacer()

                            Picker("", selection: $selectedCurrency) {
                                ForEach(Currency.allCases) { currency in
                                    Text(currency.rawValue).tag(currency)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.BartapPrimary)
                        }

                        if let error = priceError {
                            Text(error)
                                .font(.BartapCaption)
                                .foregroundColor(.BartapDanger)
                        }
                    }
                    .padding(BartapSpacing.md)
                    .background(Color.BartapCardFill)
                    .clipShape(RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BartapRadius.card, style: .continuous)
                            .stroke(Color.BartapCardBorder, lineWidth: 0.5)
                    )

                    // Category Selection
                    selectorGroup(title: "CATEGORY") {
                        FlowLayout(spacing: BartapSpacing.xs) {
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
                            FlowLayout(spacing: BartapSpacing.xs) {
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
                            FlowLayout(spacing: BartapSpacing.xs) {
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
                    selectorGroup(title: "BRAND") {
                        FlowLayout(spacing: BartapSpacing.xs) {
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
                            Button {
                                showingRequestBrand = true
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus.circle")
                                        .font(.BartapCaption)
                                    Text("Request brand")
                                        .font(.BartapSmall)
                                }
                                .foregroundColor(.BartapAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.BartapAccent.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.BartapAccent.opacity(0.3), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Style Selection
                    if !availableStyles.isEmpty {
                        selectorGroup(title: "STYLE") {
                            FlowLayout(spacing: BartapSpacing.xs) {
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
                    .BartapPrimaryButton()
                    .padding(.top, BartapSpacing.xs)
                    .disabled(isSaving)
                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.md)
            }
            .background(Color.BartapBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(editingPrice != nil ? "Edit Price" : "New Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.BartapPrimary)
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
            .sheet(isPresented: $showingRequestBrand) {
                RequestBrandSheet(drink: selectedDrink)
            }
        }
    }

    // MARK: - Subviews & Helpers

    private func selectorGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BartapSpacing.xs) {
            Text(title)
                .font(.BartapCaption)
                .foregroundColor(.BartapSecondary)
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
                        .font(.BartapCaption)
                }
                Text(title)
                    .font(.BartapCaption)
            }
            .padding(.horizontal, BartapSpacing.sm)
            .padding(.vertical, 8)
            .background(isSelected ? Color.BartapPrimary : Color.BartapSurface)
            .foregroundColor(isSelected ? .white : .BartapText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.BartapCardBorder, lineWidth: 0.5)
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
            toastCenter.show(String(localized: "Price saved"), kind: .success)
            dismiss()
        }
    }
}
