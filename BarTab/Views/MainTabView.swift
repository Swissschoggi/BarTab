import SwiftUI

struct MainTabView: View {

    enum Tab {
        case map
        case nearby
        case profile
    }

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository

    @State private var selectedTab: Tab = .map

    private var adminBadgeCount: Int {
        guard userSession.currentUser?.isAdmin == true else { return 0 }
        return barRepository.pendingBrandRequestCount
    }

    var body: some View {

        VStack(spacing: 0) {

            Group {
                switch selectedTab {

                case .map:
                    MapView()

                case .nearby:
                    NearbyView()

                case .profile:
                    ProfileView()
                }
            }
            .id(selectedTab)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

            HStack(spacing: 8) {

                tabButton(
                    title: "Map",
                    icon: "map.fill",
                    tab: .map
                )

                tabButton(
                    title: "Discover",
                    icon: "safari.fill",
                    tab: .nearby
                )

                tabButton(
                    title: "Me",
                    icon: "person.fill",
                    tab: .profile,
                    badge: adminBadgeCount
                )
            }
            .padding(6)
            .background(
                Color.barTabCardFill
                    .opacity(0.9)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.barTabCardBorder.opacity(0.8), lineWidth: 0.5)
            )
            .shadow(
                color: Color.barTabPrimary.opacity(0.15),
                radius: 24,
                x: 0,
                y: 12
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(
            Color.barTabBackground
                .ignoresSafeArea()
        )
    }


    private func tabButton(
        title: LocalizedStringKey,
        icon: String,
        tab: Tab,
        badge: Int = 0
    ) -> some View {

        Button {

            HapticEngine.lightTap()
            withAnimation(
                .spring(response: 0.3, dampingFraction: 0.7)
            ) {
                selectedTab = tab
            }

        } label: {

            HStack(spacing: 6) {

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }

                if selectedTab == tab {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(
                selectedTab == tab
                    ? .white
                    : .barTabSecondary
            )
            .padding(.vertical, 12)
            .background(
                selectedTab == tab
                    ? LinearGradient(
                        colors: [Color.barTabGradientStart, Color.barTabGradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(
                Capsule()
            )
            .shadow(
                color: selectedTab == tab ? Color.barTabPrimary.opacity(0.3) : Color.clear,
                radius: 6,
                x: 0,
                y: 3
            )
        }
    }
}

struct MainTabView_Previews: PreviewProvider {

    static var previews: some View {

        MainTabView()
            .environmentObject(
                BarRepository()
            )
            .environmentObject(
                UserSession()
            )
            .environmentObject(
                ToastCenter()
            )
    }
}
