import SwiftUI

@main
struct BarTabApp: App {

    @StateObject private var barRepository = BarRepository()
    @StateObject private var userSession = UserSession()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(barRepository)
                .environmentObject(userSession)
        }
    }
}
