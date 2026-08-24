import SwiftUI

struct MainTabView: View {

    enum Tab {
        case map
        case nearby
        case search
        case profile
    }

    @State private var selectedTab: Tab = .map

    var body: some View {

        VStack(spacing: 0) {


            Group {
                switch selectedTab {

                case .map:
                    MapView()

                case .nearby:
                    NearbyBarsView()

                case .search:
                    PriceSearchView()

                case .profile:
                    ProfileView()
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )


            HStack(spacing: 4) {

                tabButton(
                    title: "Map",
                    icon: "map.fill",
                    tab: .map
                )

                tabButton(
                    title: "Nearby",
                    icon: "location.circle.fill",
                    tab: .nearby
                )

                tabButton(
                    title: "Prices",
                    icon: "magnifyingglass",
                    tab: .search
                )

                tabButton(
                    title: "Me",
                    icon: "person.fill",
                    tab: .profile
                )
            }
            .padding(6)
            .background(
                Color.barTabBackground
                    .opacity(0.95)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(0.2),
                radius: 8,
                x: 0,
                y: 4
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(
            Color.barTabBackground
                .ignoresSafeArea()
        )
    }


    private func tabButton(
        title: LocalizedStringKey,
        icon: String,
        tab: Tab
    ) -> some View {

        Button {

            withAnimation(
                .easeInOut(duration: 0.2)
            ) {
                selectedTab = tab
            }

        } label: {

            HStack(spacing: 6) {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(
                selectedTab == tab
                    ? .white
                    : .barTabText
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                selectedTab == tab
                    ? Color.barTabPrimary
                    : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
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
    }
}
