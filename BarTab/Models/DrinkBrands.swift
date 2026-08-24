import Foundation

extension DrinkBrand {

    static let all: [DrinkBrand] = [

        // MARK: - Beer

        DrinkBrand(id: "feldschloesschen", name: "Feldschlösschen", drink: .beer),
        DrinkBrand(id: "calanda", name: "Calanda", drink: .beer),
        DrinkBrand(id: "quoellfrisch", name: "Quöllfrisch", drink: .beer),
        DrinkBrand(id: "cardinal", name: "Cardinal", drink: .beer),
        DrinkBrand(id: "appenzeller", name: "Appenzeller", drink: .beer),
        DrinkBrand(id: "heineken", name: "Heineken", drink: .beer),
        DrinkBrand(id: "corona", name: "Corona", drink: .beer),
        DrinkBrand(id: "guinness", name: "Guinness", drink: .beer),

        // MARK: - Wine

        DrinkBrand(id: "fechy", name: "Féchy", drink: .wine),
        DrinkBrand(id: "epesses", name: "Epesses", drink: .wine),
        DrinkBrand(id: "pinot-noir", name: "Pinot Noir", drink: .wine),
        DrinkBrand(id: "merlot", name: "Merlot", drink: .wine),
        DrinkBrand(id: "chardonnay", name: "Chardonnay", drink: .wine),
        DrinkBrand(id: "sauvignon-blanc", name: "Sauvignon Blanc", drink: .wine),

        // MARK: - Cocktail

        DrinkBrand(id: "mojito", name: "Mojito", drink: .cocktail),
        DrinkBrand(id: "negroni", name: "Negroni", drink: .cocktail),
        DrinkBrand(id: "old-fashioned", name: "Old Fashioned", drink: .cocktail),
        DrinkBrand(id: "margarita", name: "Margarita", drink: .cocktail),
        DrinkBrand(id: "aperol-spritz", name: "Aperol Spritz", drink: .cocktail),
        DrinkBrand(id: "gin-tonic", name: "Gin Tonic", drink: .cocktail),
        DrinkBrand(id: "moscow-mule", name: "Moscow Mule", drink: .cocktail),
        DrinkBrand(id: "espresso-martini", name: "Espresso Martini", drink: .cocktail),

        // MARK: - Shot

        DrinkBrand(id: "jaegermeister", name: "Jägermeister", drink: .shot),
        DrinkBrand(id: "tequila", name: "Tequila", drink: .shot),
        DrinkBrand(id: "vodka", name: "Vodka", drink: .shot),
        DrinkBrand(id: "grappa", name: "Grappa", drink: .shot),
        DrinkBrand(id: "underberg", name: "Underberg", drink: .shot),

        // MARK: - Soft Drink

        DrinkBrand(id: "coca-cola", name: "Coca-Cola", drink: .softDrink),
        DrinkBrand(id: "rivella", name: "Rivella", drink: .softDrink),
        DrinkBrand(id: "red-bull", name: "Red Bull", drink: .softDrink),
        DrinkBrand(id: "fanta", name: "Fanta", drink: .softDrink),
        DrinkBrand(id: "sprite", name: "Sprite", drink: .softDrink),
        DrinkBrand(id: "ramseier", name: "Ramseier", drink: .softDrink),

        // MARK: - Coffee

        DrinkBrand(id: "espresso", name: "Espresso", drink: .coffee),
        DrinkBrand(id: "cappuccino", name: "Cappuccino", drink: .coffee),
        DrinkBrand(id: "latte-macchiato", name: "Latte Macchiato", drink: .coffee),
        DrinkBrand(id: "cafe-creme", name: "Café Crème", drink: .coffee),
        DrinkBrand(id: "ristretto", name: "Ristretto", drink: .coffee)
    ]

    static func brands(
        for drink: Drink
    ) -> [DrinkBrand] {

        all.filter {
            $0.drink == drink
        }
        .sorted { $0.name < $1.name }
    }
}
