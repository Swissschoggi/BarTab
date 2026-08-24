import SwiftUI

/// A row of 5 tappable stars for entering a 1...5 rating.
/// Tapping the currently selected star clears the rating.
struct StarRatingView: View {

    @Binding var rating: Int?

    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: filled(value) ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(.barTabAccent)
                    .onTapGesture {
                        rating = (rating == value) ? nil : value
                    }
            }
        }
    }

    private func filled(_ value: Int) -> Bool {
        guard let rating = rating else {
            return false
        }
        return value <= rating
    }
}

/// Read-only stars for showing a crowd-sourced average,
/// rounded to the nearest whole star.
struct StarRatingSummaryView: View {

    let average: Double
    let count: Int
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { value in
                    Image(
                        systemName:
                            Double(value) <= average.rounded()
                            ? "star.fill"
                            : "star"
                    )
                    .font(.system(size: size))
                    .foregroundColor(.barTabAccent)
                }
            }

            Text(
                "\(String(format: "%.1f", average)) (\(count))"
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}
