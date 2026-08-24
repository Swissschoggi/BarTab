import Foundation

/// Fetches and caches exchange rates for currency conversion.
/// Uses hardcoded fallback rates so the app works offline.
final class ExchangeRateService {

    static let shared = ExchangeRateService()

    private var rates: [String: Double] = [
        "CHF": 1.0,
        "EUR": 0.94,
        "USD": 1.12,
        "GBP": 0.80,
        "SEK": 11.45,
        "NOK": 11.80,
        "DKK": 7.02,
        "PLN": 4.55,
        "CZK": 25.30
    ]
    private var lastFetched: Date?
    private let cacheKey = "exchangeRates"
    private let cacheDateKey = "exchangeRatesDate"

    private init() {
        loadCache()
    }

    /// Convert an amount from one currency to another.
    func convert(
        _ amount: Decimal,
        from sourceCurrency: String,
        to targetCurrency: String
    ) -> Decimal {
        guard sourceCurrency != targetCurrency,
              let sourceRate = rates[sourceCurrency],
              let targetRate = rates[targetCurrency],
              sourceRate > 0 else {
            return amount
        }

        // Convert: source → CHF → target
        let chfAmount = amount / Decimal(sourceRate)
        return chfAmount * Decimal(targetRate)
    }

    /// Fetch latest rates from the internet (with cache fallback).
    func fetchRates() async {
        // Don't fetch more than once per hour
        if let lastFetched, Date().timeIntervalSince(lastFetched) < 3600 {
            return
        }

        guard let url = URL(
            string: "https://api.exchangerate-api.com/v4/latest/CHF"
        ) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(
                ExchangeRateResponse.self,
                from: data
            )
            self.rates = decoded.rates
            self.lastFetched = Date()
            saveCache()
        } catch {
            // Keep using fallback/cached rates
        }
    }

    // MARK: - Cache

    private func saveCache() {
        UserDefaults.standard.set(rates, forKey: cacheKey)
        UserDefaults.standard.set(lastFetched, forKey: cacheDateKey)
    }

    private func loadCache() {
        if let cached = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double] {
            self.rates = cached
        }
        self.lastFetched = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
    }
}

private struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
}
