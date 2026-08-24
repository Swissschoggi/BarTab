import SwiftUI

struct MainTabView: View {

    enum Tab {
        case map
        case nearby
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
                    NearbyView()

                case .profile:
                    ProfileView()
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

            HStack(spacing: 2) {

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
                    tab: .profile
                )
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 16,
                x: 0,
                y: 4
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
                .easeInOut(duration: 0.25)
            ) {
                selectedTab = tab
            }

        } label: {

            VStack(spacing: 3) {

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))

                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(
                selectedTab == tab
                    ? .barTabPrimary
                    : .barTabSecondary
            )
            .padding(.vertical, 8)
            .background(
                selectedTab == tab
                    ? Color.barTabPrimary.opacity(0.08)
                    : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
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
