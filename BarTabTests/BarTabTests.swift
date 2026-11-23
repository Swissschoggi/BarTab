import XCTest
import CoreLocation
@testable import Bartap

final class BartapTests: XCTestCase {

    private var originalCurrency: Currency!

    override func setUpWithError() throws {
        originalCurrency = Currency.defaultCurrency
        Currency.defaultCurrency = .chf
        ExchangeRateService.shared.clearCache()
        AuthTokenStore.shared.clear()
    }

    override func tearDownWithError() throws {
        Currency.defaultCurrency = originalCurrency
        ExchangeRateService.shared.clearCache()
        AuthTokenStore.shared.clear()
    }

    // MARK: - Volume & normalisation

    func testDrinkSizeVolumes() {
        XCTAssertEqual(DrinkSize.oneDeciliter.volumeInMilliliters, 100)
        XCTAssertEqual(DrinkSize.fiveDeciliters.volumeInMilliliters, 500)
        XCTAssertEqual(DrinkSize.thirtyThreeCentiliters.volumeInMilliliters, 330)
        XCTAssertNil(DrinkSize.bottle.volumeInMilliliters)
        XCTAssertNil(DrinkSize.glass.volumeInMilliliters)
        XCTAssertTrue(DrinkSize.twoDeciliters.isVolumeBased)
        XCTAssertFalse(DrinkSize.shot.isVolumeBased)
    }

    func testPricePer100mlUsesStandardVolume() {
        let price = makePrice(amount: 8, currency: "CHF", size: .fiveDeciliters)

        XCTAssertEqual(
            NSDecimalNumber(decimal: price.pricePer100ml ?? 0).doubleValue,
            1.6,
            accuracy: 0.0001
        )
        XCTAssertTrue(price.formattedPricePer100ml?.hasPrefix("CHF") == true)
        XCTAssertTrue(price.formattedPricePer100ml?.hasSuffix(" / 100 ml") == true)
    }

    func testPricePer100mlNilForVariableSizes() {
        let price = makePrice(amount: 8, currency: "CHF", size: .bottle)
        XCTAssertNil(price.pricePer100ml)
        XCTAssertNil(price.formattedPricePer100ml)
    }

    func testPriceSummaryNormalisesMixedCurrencyReports() {
        let chf = makePrice(amount: 8, currency: "CHF", size: .fiveDeciliters)
        let eur = makePrice(amount: 8, currency: "EUR", size: .fiveDeciliters)

        let summary = PriceSummary(
            id: chf.id,
            barID: chf.barID,
            drink: .beer,
            brand: nil,
            size: .fiveDeciliters,
            amount: 8,
            currency: "CHF",
            reports: [chf, eur],
            confidence: 60,
            style: nil,
            serving: nil
        )

        // 8 EUR converts to ~8.51 CHF with the fallback EUR rate.
        XCTAssertEqual(
            NSDecimalNumber(decimal: summary.convertedAmount).doubleValue,
            8.5106,
            accuracy: 0.01
        )
        XCTAssertEqual(summary.pricePer100ml ?? 0, 1.7021, accuracy: 0.01)
        XCTAssertNotNil(summary.formattedPricePer100ml)
    }

    // MARK: - Price input

    func testPriceInputAcceptsCommonSeparators() {
        XCTAssertEqual(PriceInput.parseAmount("5.50"), Decimal(string: "5.5"))
        XCTAssertEqual(PriceInput.parseAmount("5,50"), Decimal(string: "5.5"))
        XCTAssertEqual(PriceInput.parseAmount("CHF 5.50"), Decimal(string: "5.5"))
        XCTAssertEqual(PriceInput.parseAmount("1'234.50"), Decimal(string: "1234.5"))
        XCTAssertEqual(PriceInput.parseAmount("1.234,56"), Decimal(string: "1234.56"))
        XCTAssertEqual(PriceInput.parseAmount("1,234.56"), Decimal(string: "1234.56"))
        XCTAssertNil(PriceInput.parseAmount("abc"))
        XCTAssertNil(PriceInput.parseAmount(""))
        XCTAssertNil(PriceInput.parseAmount("-5.00"))
    }

    func testPriceInputValidationAndRounding() {
        XCTAssertTrue(PriceInput.isValidAmount(Decimal(string: "0.01")!))
        XCTAssertFalse(PriceInput.isValidAmount(0))
        XCTAssertFalse(PriceInput.isValidAmount(Decimal(string: "10000.01")!))
        XCTAssertEqual(
            PriceInput.roundedToCents(Decimal(string: "5.555")!),
            Decimal(string: "5.56")
        )
    }

    // MARK: - Suspicious submissions

    func testSanityFlagsExtremePrice() {
        let issues = PriceSanity.issues(
            amount: 600,
            currency: "CHF",
            size: .fiveDeciliters,
            drink: .beer,
            existingPrices: []
        )

        XCTAssertTrue(issues.contains { $0.id == "too-high" })
    }

    func testSanityFlagsOutlierAgainstExistingReports() {
        let barID = UUID()
        let userID = UUID()
        let existing = [
            makePrice(amount: 2, currency: "CHF", size: .fiveDeciliters, barID: barID, userID: userID),
            makePrice(amount: 2.2, currency: "CHF", size: .fiveDeciliters, barID: barID, userID: userID)
        ]

        let issues = PriceSanity.issues(
            amount: 8,
            currency: "CHF",
            size: .fiveDeciliters,
            drink: .beer,
            existingPrices: existing
        )

        XCTAssertTrue(issues.contains { $0.id == "outlier" })
    }

    func testSanityAcceptsNormalPrice() {
        let issues = PriceSanity.issues(
            amount: 5,
            currency: "CHF",
            size: .fiveDeciliters,
            drink: .beer,
            existingPrices: []
        )

        XCTAssertTrue(issues.isEmpty)
    }

    // MARK: - Area coverage

    func testAreaNameUsesPostalCityAndSkipsCountry() {
        let bar = makeBar(address: "Langstrasse 1, 8004 Zürich, Switzerland")
        XCTAssertEqual(AreaCoverage.areaName(for: bar), "8004 Zürich")

        let cityOnly = makeBar(address: "Some Bar, Zürich")
        XCTAssertEqual(AreaCoverage.areaName(for: cityOnly), "Zürich")
    }

    func testAreaCoverageCountsBarsAndDistinctPrices() {
        let bar1 = makeBar(name: "Bar 1", address: "Street 1, 8004 Zürich, Switzerland")
        let bar2 = makeBar(name: "Bar 2", address: "Street 2, 8004 Zürich, Switzerland")
        let bar3 = makeBar(name: "Bar 3", address: "Street 3, 8001 Zürich, Switzerland")

        let price1 = makePrice(amount: 8, currency: "CHF", size: .fiveDeciliters, barID: bar1.id)
        let price2 = makePrice(amount: 8, currency: "CHF", size: .fiveDeciliters, barID: bar1.id)

        let summary = AreaCoverage.build(
            bars: [bar1, bar2, bar3],
            prices: [price1, price2]
        )

        XCTAssertEqual(summary.totalBars, 3)
        XCTAssertEqual(summary.barsWithPrices, 1)
        XCTAssertEqual(summary.priceCount, 1)
        XCTAssertEqual(summary.missingBars.count, 2)
        XCTAssertEqual(summary.coverage, 1.0 / 3.0, accuracy: 0.0001)

        let area = summary.areas.first { $0.name == "8004 Zürich" }
        XCTAssertEqual(area?.barCount, 2)
        XCTAssertEqual(area?.barsWithPrices, 1)
        XCTAssertEqual(area?.priceCount, 1)
        XCTAssertEqual(area?.needsHelp, true)
    }

    func testAreaCoverageRespectsRadius() {
        let near = makeBar(
            name: "Near",
            address: "Street 1, 8004 Zürich",
            latitude: 47.3769,
            longitude: 8.5417
        )
        let far = makeBar(
            name: "Far",
            address: "Street 2, 8001 Zürich",
            latitude: 47.5000,
            longitude: 8.7000
        )

        let summary = AreaCoverage.build(
            bars: [near, far],
            prices: [],
            center: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
            radius: 1_000
        )

        XCTAssertEqual(summary.totalBars, 1)
        XCTAssertEqual(summary.missingBars.first?.id, near.id)
    }

    // MARK: - Auth token parsing

    func testCurrentUserIDDecodesUnpaddedBase64URLPayload() {
        let userID = UUID()
        let payload = "{\"sub\":\"\(userID.uuidString)\"}"
        let base64 = Data(payload.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        let token = "eyJhbGciOiJub25lIn0.\(base64).signature"

        AuthTokenStore.shared.update(
            accessToken: token,
            refreshToken: "refresh",
            expiresAt: nil
        )

        XCTAssertEqual(SupabaseClient.shared.currentUserID, userID)
    }

    // MARK: - Helpers

    private func makeBar(
        name: String = "Test Bar",
        address: String = "Teststrasse 1, 8000 Zürich",
        latitude: CLLocationDegrees = 47.3769,
        longitude: CLLocationDegrees = 8.5417
    ) -> Bar {
        Bar(
            id: UUID(),
            name: name,
            address: address,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            createdAt: Date(),
            createdBy: UUID()
        )
    }

    private func makePrice(
        amount: Decimal,
        currency: String,
        size: DrinkSize,
        barID: UUID = UUID(),
        userID: UUID = UUID(),
        drink: Drink = .beer
    ) -> Price {
        Price(
            id: UUID(),
            barID: barID,
            drink: drink,
            brand: nil,
            size: size,
            amount: amount,
            currency: currency,
            reportedAt: Date(),
            reportedBy: userID
        )
    }
}
