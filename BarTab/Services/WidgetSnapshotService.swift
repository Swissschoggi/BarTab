import Foundation
import CoreLocation
import WidgetKit

/// Computes the widget snapshot (cheapest beer + next crawl stop) and
/// writes it to the shared App Group container for the widget to read.
enum WidgetSnapshotService {

    @MainActor
    static func refresh(
        barRepository: BarRepository,
        locationService: LocationService
    ) async {
        var snapshot = WidgetDataStore.load() ?? .empty
        snapshot.updatedAt = Date()
        snapshot.cheapestBeer = cheapestBeer(
            barRepository: barRepository,
            locationService: locationService
        )
        snapshot.nextCrawlStop = await nextCrawlStop(barRepository: barRepository)
        WidgetDataStore.save(snapshot)

        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Cheapest beer

    @MainActor
    private static func cheapestBeer(
        barRepository: BarRepository,
        locationService: LocationService
    ) -> WidgetSnapshot.CheapestBeer? {
        var best: (bar: Bar, summary: PriceSummary)?

        for bar in barRepository.bars {
            guard !barRepository.isBarAutoHidden(bar) else { continue }
            for summary in barRepository.getPriceSummaries(for: bar)
            where summary.drink == .beer {
                if best == nil || summary.convertedAmount < best!.summary.convertedAmount {
                    best = (bar, summary)
                }
            }
        }

        guard let best else { return nil }

        var distanceLabel: String?
        if let location = locationService.location {
            distanceLabel = DistanceService.formattedDistance(from: location, to: best.bar)
        }

        return WidgetSnapshot.CheapestBeer(
            barName: best.bar.name,
            amount: NSDecimalNumber(decimal: best.summary.convertedAmount).doubleValue,
            currency: Currency.defaultCurrency.rawValue,
            distanceLabel: distanceLabel
        )
    }

    // MARK: - Next crawl stop

    @MainActor
    private static func nextCrawlStop(
        barRepository: BarRepository
    ) async -> WidgetSnapshot.NextCrawlStop? {
        guard let groups = try? await SupabaseClient.shared.fetchGroups(),
              !groups.isEmpty else { return nil }

        for group in groups {
            guard let events = try? await SupabaseClient.shared.fetchEvents(groupID: group.id),
                  !events.isEmpty else { continue }

            for event in events {
                guard let stops = try? await SupabaseClient.shared.fetchCrawlStops(eventID: event.id),
                      !stops.isEmpty else { continue }

                let ordered = stops.sorted { $0.position < $1.position }
                guard let first = ordered.first,
                      let bar = barRepository.getBar(id: first.barID) else { continue }

                let goingCount = (try? await SupabaseClient.shared.fetchRSVPs(eventID: event.id))?.count ?? 0

                return WidgetSnapshot.NextCrawlStop(
                    groupName: group.name,
                    eventTitle: event.title,
                    barName: bar.name,
                    stopIndex: first.position + 1,
                    stopCount: ordered.count,
                    goingCount: goingCount
                )
            }
        }

        return nil
    }
}
