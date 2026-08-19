import Foundation
import MapKit
import Combine

final class PlaceSearchService: NSObject, ObservableObject {

    @Published var query = ""

    @Published private(set) var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()

        completer.delegate = self

        completer.resultTypes = [
            .address,
            .pointOfInterest
        ]
    }

    func updateQuery(_ query: String) {
        self.query = query
        completer.queryFragment = query
    }

    func clearResults() {
        query = ""
        results = []
        completer.queryFragment = ""
    }
}

extension PlaceSearchService: MKLocalSearchCompleterDelegate {

    func completerDidUpdateResults(
        _ completer: MKLocalSearchCompleter
    ) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        DispatchQueue.main.async {
            self.results = []
        }
    }
}
