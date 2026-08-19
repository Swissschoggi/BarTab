import Foundation

extension DrinkBrand {

    static let all: [DrinkBrand] = [


        DrinkBrand(
            id: "feldschloesschen",
            name: "Feldschlösschen",
            drink: .beer
        ),

        DrinkBrand(
            id: "calanda",
            name: "Calanda",
            drink: .beer
        ),

        DrinkBrand(
            id: "quöllfrisch",
            name: "Quöllfrisch",
            drink: .beer
        ),

        DrinkBrand(
            id: "cardinal",
            name: "Cardinal",
            drink: .beer
        ),

        DrinkBrand(
            id: "appenzeller",
            name: "Appenzeller",
            drink: .beer
        ),

        DrinkBrand(
            id: "heineken",
            name: "Heineken",
            drink: .beer
        ),

        DrinkBrand(
            id: "corona",
            name: "Corona",
            drink: .beer
        ),

        DrinkBrand(
            id: "guinness",
            name: "Guinness",
            drink: .beer
        ),


        DrinkBrand(
            id: "fechy",
            name: "Féchy",
            drink: .wine
        ),

        DrinkBrand(
            id: "epesses",
            name: "Epesses",
            drink: .wine
        ),

        DrinkBrand(
            id: "pinot-noir",
            name: "Pinot Noir",
            drink: .wine
        ),

        DrinkBrand(
            id: "merlot",
            name: "Merlot",
            drink: .wine
        ),

        DrinkBrand(
            id: "chardonnay",
            name: "Chardonnay",
            drink: .wine
        ),

        DrinkBrand(
            id: "sauvignon-blanc",
            name: "Sauvignon Blanc",
            drink: .wine
        )
    ]

    static func brands(
        for drink: Drink
    ) -> [DrinkBrand] {

        all.filter {
            $0.drink == drink
        }
    }
}
