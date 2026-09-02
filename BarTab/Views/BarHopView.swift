import SwiftUI
import CoreLocation

/// Generates a fun 3-bar walking crawl route with estimated drink savings.
struct BarHopView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationService: LocationService

    @State private var selectedRoute: [Bar] = []
    @State private var isGenerating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Hero banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.barTabTitle)
                                .foregroundColor(.barTabPrimary)
                            Text("Bar Hop Generator")
                                .font(.barTabStat)
                                .foregroundColor(.barTabText)
                        }

                        Text("Let BarTab curate a 3-stop walking crawl featuring great drink deals near you.")
                            .font(.barTabCaption)
                            .foregroundColor(.barTabSecondary)
                    }
                    .barTabCard()

                    if selectedRoute.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "map.fill")
                                .font(.barTabEmptyIconLarge)
                                .foregroundColor(.barTabPrimary.opacity(0.6))

                            Text("Ready for a night out?")
                                .font(.barTabHeading)
                                .foregroundColor(.barTabText)

                            Button {
                                generateRoute()
                            } label: {
                                Text("Generate Route")
                                    .barTabPrimaryButton()
                            }
                            .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .barTabCard()
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Your Crawl Route")
                                    .font(.barTabHeading)
                                    .foregroundColor(.barTabText)

                                Spacer()

                                Button("Shuffle") {
                                    generateRoute()
                                }
                                .font(.barTabCaption)
                                .foregroundColor(.barTabPrimary)
                            }

                            ForEach(Array(selectedRoute.enumerated()), id: \.element.id) { index, bar in
                                HStack(alignment: .top, spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.barTabPrimary)
                                            .frame(width: 32, height: 32)
                                        Text("\(index + 1)")
                                            .font(.barTabBodySemibold)
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bar.name)
                                            .font(.barTabBodySemibold)
                                            .foregroundColor(.barTabText)

                                        Text(bar.address)
                                            .font(.barTabCaption)
                                            .foregroundColor(.barTabSecondary)

                                        if let popular = barRepository.popularAmbience(for: bar) {
                                            HStack(spacing: 4) {
                                                Image(systemName: popular.icon)
                                                    .font(.barTabTiny)
                                                Text(popular.displayName)
                                                    .font(.barTabTiny)
                                            }
                                            .foregroundColor(.barTabPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.barTabPrimary.opacity(0.08))
                                            .clipShape(Capsule())
                                            .padding(.top, 4)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.barTabCardFill)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.barTabCardBorder, lineWidth: 0.5)
                                )
                            }

                            Button {
                                generateRoute()
                            } label: {
                                Text("Try Another Route")
                                    .barTabPrimaryButton()
                            }
                            .padding(.top, 8)
                        }
                        .barTabCard()
                    }
                }
                .padding(16)
            }
            .background(Color.barTabBackground.ignoresSafeArea())
            .navigationTitle("Bar Hop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateRoute() {
        let allBars = barRepository.bars
        guard allBars.count >= 3 else {
            selectedRoute = allBars
            return
        }

        if let userLocation = locationService.location {
            let sorted = allBars.sorted {
                let d0 = DistanceService.distance(from: userLocation, to: $0)
                let d1 = DistanceService.distance(from: userLocation, to: $1)
                return d0 < d1
            }
            let nearby = sorted.prefix(10)
            selectedRoute = Array(nearby.shuffled().prefix(3))
        } else {
            selectedRoute = Array(allBars.shuffled().prefix(3))
        }
    }
}
