import SwiftUI
import MapKit

struct MapView: View {

    @StateObject private var locationService = LocationService()

    var body: some View {
        Map()
            .ignoreSafeArea()
            .onAppear {
                locationService.requestPermission()
            }
    }
}

#Preview {
    MapView()
}