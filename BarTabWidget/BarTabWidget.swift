import WidgetKit
import SwiftUI

// MARK: - Bundle

@main
struct BarTabWidgetBundle: WidgetBundle {
    var body: some Widget {
        CheapestBeerWidget()
        NextCrawlStopWidget()
    }
}

// MARK: - Timeline entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Shared provider

struct SnapshotProvider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let snapshot = WidgetDataStore.load() ?? .empty
        completion(WidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.load() ?? .empty
        let entry = WidgetEntry(date: Date(), snapshot: snapshot)
        // The app reloads timelines after writing a fresh snapshot, so a
        // long fallback policy is fine here.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Cheapest beer widget

struct CheapestBeerWidget: Widget {
    let kind = "CheapestBeerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            CheapestBeerView(entry: entry)
        }
        .configurationDisplayName("Cheapest Beer")
        .description("The best nearby beer price in your default currency.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CheapestBeerView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "mug.fill")
                    .font(.caption)
                Text("Cheapest beer")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            if let beer = entry.snapshot.cheapestBeer {
                Text(priceText(beer))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(beer.barName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let distance = beer.distanceLabel {
                    Label(distance, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No prices yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func priceText(_ beer: WidgetSnapshot.CheapestBeer) -> String {
        String(format: "%.2f %@", beer.amount, beer.currency)
    }
}

// MARK: - Next crawl stop widget

struct NextCrawlStopWidget: Widget {
    let kind = "NextCrawlStopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            NextCrawlStopView(entry: entry)
        }
        .configurationDisplayName("Next Crawl Stop")
        .description("Where your group is headed next.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextCrawlStopView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.caption)
                Text("Next stop")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            if let stop = entry.snapshot.nextCrawlStop {
                Text("\(stop.stopIndex)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)

                Text(stop.barName)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(stop.eventTitle) · \(stop.groupName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("\(stop.stopIndex) of \(stop.stopCount) · \(stop.goingCount) going")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("Plan a night out")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
