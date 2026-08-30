import SwiftUI

struct MainTabView: View {

    enum Tab: CaseIterable {
        case map
        case nearby
        case groups
        case profile
    }

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter

    @State private var selectedTab: Tab = .map
    @State private var showingOnboarding = false

    // Swipeable tab bar state
    @State private var tabBarWidth: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    private var adminBadgeCount: Int {
        guard userSession.currentUser?.isAdmin == true else { return 0 }
        return barRepository.pendingBrandRequestCount
    }

    private var tabCount: Int { Tab.allCases.count }

    private var selectedIndex: Int {
        Tab.allCases.firstIndex(of: selectedTab) ?? 0
    }

    private var tabWidth: CGFloat {
        guard tabBarWidth > 0 else { return 80 }
        return tabBarWidth / CGFloat(tabCount)
    }

    /// Rubber-banded drag offset so the pill resists at the edges.
    private var clampedDragOffset: CGFloat {
        let minX = -CGFloat(selectedIndex) * tabWidth
        let maxX = CGFloat(tabCount - 1 - selectedIndex) * tabWidth

        var value = dragOffset
        if value < minX {
            value = minX + (value - minX) * 0.35
        } else if value > maxX {
            value = maxX + (value - maxX) * 0.35
        }
        return value
    }

    /// Horizontal position of the pill's leading edge (plus inner inset).
    private var pillOffsetX: CGFloat {
        CGFloat(selectedIndex) * tabWidth + 4 + clampedDragOffset
    }

    /// The pill stretches slightly while dragging, like a pulled droplet.
    private var pillStretch: CGFloat {
        guard tabWidth > 0 else { return 1 }
        let intensity = min(abs(clampedDragOffset) / tabWidth, 1)
        return 1 + intensity * 0.18
    }

    var body: some View {

        VStack(spacing: 0) {

            Group {
                switch selectedTab {

                case .map:
                    MapView()

                case .nearby:
                    NearbyView()

                case .groups:
                    NavigationView {
                        GroupPlanningView()
                    }

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

            tabBar
        }
        .background(
            Color.barTabBackground
                .ignoresSafeArea()
        )
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .sheet(item: $deepLinkRouter.destination) { destination in
            switch destination {
            case .bar(let id):
                DeepLinkBarView(barID: id)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            case .group(let id):
                DeepLinkGroupView(groupID: id)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ZStack(alignment: .topLeading) {

            // Fluid selection pill
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.barTabGradientStart, Color.barTabGradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(tabWidth - 8, 0), height: 40)
                .offset(x: pillOffsetX)
                .scaleEffect(x: pillStretch, y: 1, anchor: .center)
                .shadow(
                    color: Color.barTabPrimary.opacity(0.3),
                    radius: 6,
                    x: 0,
                    y: 3
                )

            HStack(spacing: 0) {
                tabButton(tab: .map, title: "Map", icon: "map.fill")
                tabButton(tab: .nearby, title: "Discover", icon: "safari.fill")
                tabButton(tab: .groups, title: "Group", icon: "person.3.fill")
                tabButton(tab: .profile, title: "Me", icon: "person.fill", badge: adminBadgeCount)
            }
        }
        .frame(height: 40)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { tabBarWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { width in
                        tabBarWidth = width
                    }
            }
        )
        .simultaneousGesture(tabBarSwipeGesture)
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

    private var tabBarSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard tabBarWidth > 0 else { return }

                // Snap, using velocity to carry the pill forward.
                let rawPosition = CGFloat(selectedIndex) * tabWidth + dragOffset
                var targetIndex = Int((rawPosition / tabWidth).rounded())
                if abs(value.predictedEndTranslation.width) > tabWidth * 0.5 {
                    targetIndex += value.predictedEndTranslation.width > 0 ? 1 : -1
                }
                targetIndex = min(max(targetIndex, 0), tabCount - 1)

                selectTab(Tab.allCases[targetIndex], haptic: .selection)
            }
    }

    private func selectTab(_ tab: Tab, haptic: Haptic) {
        if haptic == .lightTap {
            HapticEngine.lightTap()
        } else {
            HapticEngine.selection()
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedTab = tab
            dragOffset = 0
        }
    }

    private enum Haptic {
        case lightTap
        case selection
    }

    private func tabButton(
        tab: Tab,
        title: LocalizedStringKey,
        icon: String,
        badge: Int = 0
    ) -> some View {

        let isSelected = selectedTab == tab

        return Button {
            selectTab(tab, haptic: .lightTap)
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

                if isSelected {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(
                isSelected
                    ? .white
                    : .barTabSecondary
            )
            .contentShape(Rectangle())
            .accessibilityLabel(Text(title))
        }
        .buttonStyle(.plain)
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
            .environmentObject(
                DeepLinkRouter()
            )
    }
}

// MARK: - Deep link destination views

private struct DeepLinkBarView: View {

    let barID: UUID

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var didTryFetch = false

    var body: some View {
        NavigationView {
            if let bar = barRepository.getBar(id: barID) {
                BarView(bar: bar, allowsDismissal: true)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            } else if !didTryFetch {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await barRepository.fetchAllData()
                        didTryFetch = true
                    }
            } else {
                unavailableView(
                    icon: "mappin.slash",
                    title: "Bar not found",
                    message: "This bar may have been removed."
                )
            }
        }
    }

    @ViewBuilder
    private func unavailableView(
        icon: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.barTabPrimary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DeepLinkGroupView: View {

    let groupID: UUID

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var group: BarGroup?
    @State private var didTryFetch = false

    var body: some View {
        NavigationView {
            if let group {
                GroupDetailView(group: group)
                    .environmentObject(barRepository)
                    .environmentObject(userSession)
                    .environmentObject(toastCenter)
            } else if !didTryFetch {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        group = try? await SupabaseClient.shared.fetchGroup(id: groupID)
                        didTryFetch = true
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.barTabPrimary)
                    Text("Group not found")
                        .font(.headline)
                    Text("You may not be a member of this group.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
