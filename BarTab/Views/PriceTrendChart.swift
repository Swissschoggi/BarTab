import SwiftUI


extension Array where Element == Price {

    var priceChange: Double? {

        guard count >= 2 else {
            return nil
        }

        let sorted = sorted {
            $0.reportedAt < $1.reportedAt
        }

        guard let firstAmount = sorted.first?.amount,
              let lastAmount = sorted.last?.amount else {
            return nil
        }

        let first = NSDecimalNumber(decimal: firstAmount).doubleValue
        let last = NSDecimalNumber(decimal: lastAmount).doubleValue

        guard first > 0 else {
            return nil
        }

        return (last - first) / first
    }
}


struct PriceTrendChart: View {

    let prices: [Price]

    private struct ReportPoint: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Double
    }

    private var reports: [ReportPoint] {
        prices
            .sorted { $0.reportedAt < $1.reportedAt }
            .map {
                ReportPoint(
                    date: $0.reportedAt,
                    amount: NSDecimalNumber(
                        decimal: $0.amount
                    ).doubleValue
                )
            }
    }

    var body: some View {

        let points = reports

        Group {

            if points.isEmpty {

                placeholder(
                    "No reports to chart."
                )

            } else if points.count == 1 {

                singlePoint(points[0])

            } else {

                chart(points)
            }
        }
        .frame(height: 90)
    }

    private func chart(
        _ points: [ReportPoint]
    ) -> some View {
        let amounts = points.map(\.amount)
        let dates = points.map(\.date)

        let minAmount = amounts.min() ?? 0
        let maxAmount = amounts.max() ?? (minAmount + 1)
        let range = max(maxAmount - minAmount, 1)

        let minDate = dates.min() ?? Date()
        let maxDate = dates.max() ?? minDate

        let dateRange = max(
            maxDate.timeIntervalSince(minDate),
            1
        )

        return GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let padding: CGFloat = 6

            let chartPoints: [CGPoint] = points.map { point in
                let t =
                    point.date.timeIntervalSince(minDate)
                    / dateRange

                let x =
                    padding
                    + t * (width - 2 * padding)

                let normalized =
                    (point.amount - minAmount) / range

                let y =
                    height
                    - padding
                    - normalized * (height - 2 * padding)

                return CGPoint(
                    x: x,
                    y: y
                )
            }

            ZStack {
                if let first = chartPoints.first,
                   let last = chartPoints.last {

                    Path { path in
                        path.move(
                            to: CGPoint(
                                x: first.x,
                                y: height - padding
                            )
                        )

                        path.addLine(to: first)

                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }

                        path.addLine(
                            to: CGPoint(
                                x: last.x,
                                y: height - padding
                            )
                        )

                        path.closeSubpath()
                    }
                    .fill(
                        Color.barTabPrimary.opacity(0.15)
                    )

                    Path { path in
                        path.move(to: first)

                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        Color.barTabPrimary,
                        style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                ForEach(
                    chartPoints.indices,
                    id: \.self
                ) { index in
                    Circle()
                        .fill(
                            index == chartPoints.count - 1
                                ? Color.barTabAccent
                                : Color.barTabPrimary
                        )
                        .frame(
                            width:
                                index == chartPoints.count - 1
                                    ? 8
                                    : 5,
                            height:
                                index == chartPoints.count - 1
                                    ? 8
                                    : 5
                        )
                        .position(
                            chartPoints[index]
                        )
                }
            }
        }
    }
    private func singlePoint(
        _ point: ReportPoint
    ) -> some View {

        HStack(spacing: 8) {

            Circle()
                .fill(Color.barTabAccent)
                .frame(width: 10, height: 10)

            Text("Only one report so far — add another to see a trend.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private func placeholder(
        _ message: String
    ) -> some View {

        Text(message)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
    }
}

struct PriceTrendChart_Previews: PreviewProvider {

    static var previews: some View {

        PriceTrendChart(
            prices: [
                Price(
                    id: UUID(),
                    barID: Bar.mockBars[0].id,
                    drink: .beer,
                    brand: nil,
                    size: .fiveDeciliters,
                    amount: Decimal(string: "5.00")!,
                    currency: "CHF",
                    reportedAt: Date().addingTimeInterval(-86_400 * 40),
                    reportedBy: User.mockUser.id
                ),
                Price(
                    id: UUID(),
                    barID: Bar.mockBars[0].id,
                    drink: .beer,
                    brand: nil,
                    size: .fiveDeciliters,
                    amount: Decimal(string: "5.50")!,
                    currency: "CHF",
                    reportedAt: Date().addingTimeInterval(-86_400 * 20),
                    reportedBy: User.mockUser.id
                ),
                Price(
                    id: UUID(),
                    barID: Bar.mockBars[0].id,
                    drink: .beer,
                    brand: nil,
                    size: .fiveDeciliters,
                    amount: Decimal(string: "6.00")!,
                    currency: "CHF",
                    reportedAt: Date(),
                    reportedBy: User.mockUser.id
                )
            ]
        )
        .padding()
        .background(Color.barTabBackground)
    }
}
