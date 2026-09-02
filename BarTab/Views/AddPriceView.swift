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

    private var isEditing: Bool { editingPrice != nil }

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

                    // Drink type
                    sectionHeader("Drink")
                    drinkPicker

                    // Size
                    if !availableSizes.isEmpty {
                        sectionHeader("Size")
                        sizePicker
                    }

                    // Style
                    if !availableStyles.isEmpty {
                        sectionHeader("Style")
                        stylePicker
                    }

                    // Serving
                    if !availableServingMethods.isEmpty {
                        sectionHeader("Serving")
                        servingPicker
                    }

                    // Brand
                    sectionHeader("Brand")
                    brandPicker

                    // Price
                    sectionHeader("Price")
                    priceInput

                    if let error = priceError {
                        errorBanner(error)
                    }
                }
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.lg)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Drink" : "Add Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
            .alert("Drink already exists", isPresented: $showingDuplicateWarning) {
                Button("Add Anyway") {
                    guard let duplicatePrice,
                          let user = userSession.currentUser,
                          let amount = Decimal(string: priceText)
                    else { return }
                    isSaving = true
                    actuallySavePrice(amount: amount, user: user)
                }
                Button("Cancel", role: .cancel) { duplicatePrice = nil }
            } message: {
                if let duplicatePrice {
                    Text("\(duplicatePrice.brand ?? duplicatePrice.drink.displayName) · \(duplicatePrice.size.displayName) already has a price of \(duplicatePrice.formattedAmount) \(duplicatePrice.currency) at this bar.")
                } else {
                    Text("A price for this drink and size already exists at this bar.")
                }
            }
            .sheet(isPresented: $showingRequestBrand) {
                RequestBrandSheet(drink: selectedDrink)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.barTabHeading)
            .foregroundColor(.barTabText)
    }

    // MARK: - Drink Picker

    private var drinkPicker: some View {
        FlowLayout(spacing: BarTabSpacing.xs) {
            ForEach(Drink.allCases, id: \.self) { drink in
                Button {
                    selectedDrink = drink
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: drink.icon)
                            .font(.barTabSmall)
                        Text(drink.displayName)
                            .font(.barTabSmall)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, BarTabSpacing.sm)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedDrink == drink ? .white : .barTabPrimary)
                    .background(selectedDrink == drink ? Color.barTabPrimary : Color.barTabSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedDrink == drink ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Size Picker

    private var sizePicker: some View {
        FlowLayout(spacing: BarTabSpacing.xs) {
            ForEach(availableSizes, id: \.self) { size in
                Button {
                    selectedSize = size
                } label: {
                    Text(size.displayName)
                        .font(.barTabSmall)
                        .fontWeight(.medium)
                        .padding(.horizontal, BarTabSpacing.sm)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedSize == size ? .white : .barTabPrimary)
                        .background(selectedSize == size ? Color.barTabPrimary : Color.barTabSurface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(selectedSize == size ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Style Picker

    private var stylePicker: some View {
        FlowLayout(spacing: BarTabSpacing.xs) {
            Button {
                selectedStyle = nil
            } label: {
                Text("Not specified")
                    .font(.barTabSmall)
                    .fontWeight(.medium)
                    .padding(.horizontal, BarTabSpacing.sm)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedStyle == nil ? .white : .barTabPrimary)
                    .background(selectedStyle == nil ? Color.barTabPrimary : Color.barTabSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedStyle == nil ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            ForEach(availableStyles) { style in
                Button {
                    selectedStyle = style
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.barTabTiny)
                        Text(style.displayName)
                            .font(.barTabSmall)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, BarTabSpacing.sm)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedStyle == style ? .white : .barTabPrimary)
                    .background(selectedStyle == style ? Color.barTabPrimary : Color.barTabSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedStyle == style ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Serving Picker

    private var servingPicker: some View {
        FlowLayout(spacing: BarTabSpacing.xs) {
            Button {
                selectedServing = nil
            } label: {
                Text("Not specified")
                    .font(.barTabSmall)
                    .fontWeight(.medium)
                    .padding(.horizontal, BarTabSpacing.sm)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedServing == nil ? .white : .barTabPrimary)
                    .background(selectedServing == nil ? Color.barTabPrimary : Color.barTabSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedServing == nil ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            ForEach(availableServingMethods) { method in
                Button {
                    selectedServing = method
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: method.icon)
                            .font(.barTabTiny)
                        Text(method.displayName)
                            .font(.barTabSmall)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, BarTabSpacing.sm)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedServing == method ? .white : .barTabPrimary)
                    .background(selectedServing == method ? Color.barTabPrimary : Color.barTabSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedServing == method ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Brand Picker

    private var brandPicker: some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.sm) {
            if !availableBrands.isEmpty {
                FlowLayout(spacing: BarTabSpacing.xs) {
                    Button {
                        selectedBrand = nil
                    } label: {
                        Text("Not specified")
                            .font(.barTabSmall)
                            .fontWeight(.medium)
                            .padding(.horizontal, BarTabSpacing.sm)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedBrand == nil ? .white : .barTabPrimary)
                            .background(selectedBrand == nil ? Color.barTabPrimary : Color.barTabSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(selectedBrand == nil ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(availableBrands, id: \.self) { brand in
                        Button {
                            selectedBrand = brand
                        } label: {
                            Text(brand)
                                .font(.barTabSmall)
                                .fontWeight(.medium)
                                .padding(.horizontal, BarTabSpacing.sm)
                                .padding(.vertical, 8)
                                .foregroundColor(selectedBrand == brand ? .white : .barTabPrimary)
                                .background(selectedBrand == brand ? Color.barTabPrimary : Color.barTabSurface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(selectedBrand == brand ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                showingRequestBrand = true
            } label: {
                Label("Can't find it? Request a brand", systemImage: "plus.circle")
                    .font(.barTabCaption)
                    .foregroundColor(.barTabPrimary)
            }
        }
    }

    // MARK: - Price Input

    private var priceInput: some View {
        HStack(spacing: BarTabSpacing.sm) {
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
                        .font(.barTabTiny)
                }
                .font(.barTabBody)
                .padding(.horizontal, BarTabSpacing.sm)
                .padding(.vertical, 10)
                .background(Color.barTabSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.barTabCardBorder, lineWidth: 0.5)
                )
            }

            TextField("0.00", text: $priceText)
                .keyboardType(.decimalPad)
                .font(.barTabStat)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.barTabCaption)
            .foregroundColor(.barTabDanger)
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.vertical, BarTabSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.barTabDanger.opacity(0.08),
                in: RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
            )
    }

    // MARK: - Save

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

        guard let user = userSession.currentUser else { return }

        if let editingPrice {
            isSaving = true
            actuallyUpdatePrice(editingPrice, amount: amount, user: user)
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
        actuallySavePrice(amount: amount, user: user)
    }

    private func actuallySavePrice(amount: Decimal, user: User) {
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
                toastCenter.show("Couldn't save drink", kind: .error)
            }
        }
    }

    private func actuallyUpdatePrice(_ price: Price, amount: Decimal, user: User) {
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
