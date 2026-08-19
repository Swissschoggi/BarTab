import Foundation

struct PriceConfidence {

    enum Level {
        case low
        case medium
        case high
        case veryHigh

        var title: String {
            switch self {
            case .low:
                return "Low confidence"
            case .medium:
                return "Medium confidence"
            case .high:
                return "High confidence"
            case .veryHigh:
                return "Very high confidence"
            }
        }
    }

    struct Result {
        let score: Double
        let level: Level
        let reportCount: Int
    }

    static func calculate(
        for price: Price,
        from reports: [Price]
    ) -> Result {

        let matchingReports = reports.filter { report in
            report.drink == price.drink &&
            report.size == price.size &&
            report.brand == price.brand
        }

        guard !matchingReports.isEmpty else {
            return Result(
                score: 0.1,
                level: .low,
                reportCount: 1
            )
        }

        let now = Date()

        let weights: [Double] = matchingReports.map { report in
            let age = now.timeIntervalSince(
                report.reportedAt
            )

            let days = max(
                age / 86_400,
                0
            )

            // Reports lose half their influence
            // approximately every 90 days.
            return pow(
                0.5,
                days / 90
            )
        }

        let totalWeight = weights.reduce(
            0,
            +
        )

        guard totalWeight > 0 else {
            return Result(
                score: 0.1,
                level: .low,
                reportCount: matchingReports.count
            )
        }

        let weightedAverage =
            zip(matchingReports, weights)
                .reduce(Decimal.zero) { result, pair in

                    let (report, weight) = pair

                    return result +
                        report.amount *
                        Decimal(weight)
                }
                / Decimal(totalWeight)

        let weightedDeviation =
            zip(matchingReports, weights)
                .reduce(0.0) { result, pair in

                    let (report, weight) = pair

                    let reportPrice =
                        NSDecimalNumber(
                            decimal: report.amount
                        ).doubleValue

                    let average =
                        NSDecimalNumber(
                            decimal: weightedAverage
                        ).doubleValue

                    let deviation =
                        abs(
                            reportPrice - average
                        )

                    return result +
                        deviation * weight
                }
                / totalWeight

        let average =
            NSDecimalNumber(
                decimal: weightedAverage
            ).doubleValue

        let deviationRatio =
            average > 0
            ? weightedDeviation / average
            : 1

        let agreement = max(
            0,
            min(
                1,
                1 - deviationRatio / 0.25
            )
        )

        let sampleConfidence = min(
            1,
            Double(matchingReports.count) / 10.0
        )

        let score =
            (sampleConfidence * 0.6) +
            (agreement * 0.4)

        let level: Level

        switch score {
        case 0..<0.3:
            level = .low

        case 0.3..<0.6:
            level = .medium

        case 0.6..<0.85:
            level = .high

        default:
            level = .veryHigh
        }

        return Result(
            score: score,
            level: level,
            reportCount: matchingReports.count
        )
    }
}
