import SwiftUI

struct MainTabView: View {

    enum Tab: CaseIterable {
        case map
        case nearby
        case groups
        case profile

        var icon: String {
            switch self {
            case .map: return "map.fill"
            case .nearby: return "safari.fill"
            case .groups: return "person.3.fill"
            case .profile: return "person.fill"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .map: return "Map"
            case .nearby: return "Discover"
            case .groups: return "Group"
            case .profile: return "Me"
            }
        }
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
    @State private var dragStartIndex: Int = 0
    @State private var isTabDragging = false

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

    /// The tab the pill is anchored to while dragging vs. the committed
    /// selection at rest.
    private var activeBaseIndex: Int {
        isTabDragging ? dragStartIndex : selectedIndex
    }

    /// Rubber-banded drag offset so the pill resists at the edges.
    private var clampedDragOffset: CGFloat {
        let base = activeBaseIndex
        let minX = -CGFloat(base) * tabWidth
        let maxX = CGFloat(tabCount - 1 - base) * tabWidth

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
        CGFloat(activeBaseIndex) * tabWidth + 2 + clampedDragOffset
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

            // Layer 1: unselected labels (gray) + tap targets
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectTab(tab, haptic: .lightTap)
                    } label: {
                        tabLabel(tab: tab, isSelected: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Layer 2: fluid selection pill (slides above the gray labels)
            Capsule()
                .fill(Color.barTabPrimary)
                .frame(width: max(tabWidth - 4, 0), height: 40)
                .offset(x: pillOffsetX)
                .scaleEffect(x: pillStretch, y: 1, anchor: .center)

            // Layer 3: selected label (white), drawn above the pill
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    if tab == selectedTab {
                        tabLabel(tab: tab, isSelected: true)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .allowsHitTesting(false)
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
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: BarTabRadius.sheet, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BarTabRadius.sheet, style: .continuous)
                .stroke(Color.barTabCardBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, BarTabSpacing.lg)
        .padding(.bottom, BarTabSpacing.lg)
    }

    private var tabBarSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard tabBarWidth > 0 else { return }

                if !isTabDragging {
                    isTabDragging = true
                    dragStartIndex = min(
                        max(Int(value.startLocation.x / tabWidth), 0),
                        tabCount - 1
                    )
                }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                isTabDragging = false
                guard tabBarWidth > 0 else { return }

                // Snap to the tab under the finger, anchored to where the
                // press started.
                let rawPosition = CGFloat(dragStartIndex) * tabWidth + dragOffset
                let targetIndex = min(
                    max(Int((rawPosition / tabWidth).rounded()), 0),
                    tabCount - 1
                )

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

    private func tabLabel(
        tab: Tab,
        isSelected: Bool
    ) -> some View {

        let badge = (tab == .profile) ? adminBadgeCount : 0

        return HStack(spacing: 4) {

            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .semibold))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.barTabBadge)
                            .foregroundColor(.white)
                            .frame(width: 15, height: 15)
                            .background(Color.barTabDanger)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.barTabCardFill, lineWidth: 1.5))
                            .offset(x: 9, y: -7)
                    }
                }

            if isSelected {
                Text(tab.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(
            isSelected
                ? .white
                : .barTabSecondary.opacity(0.8)
        )
        .contentShape(Rectangle())
        .accessibilityLabel(Text(tab.title))
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
                    title: String(localized: "Bar not found"),
                    message: String(localized: "This bar may have been removed.")
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
                .font(.barTabEmptyIcon)
                .foregroundColor(.barTabPrimary)
            Text(title)
                .font(.barTabHeading)
            Text(message)
                .font(.barTabBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Close")) { dismiss() }
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
                        .font(.barTabEmptyIcon)
                        .foregroundColor(.barTabPrimary)
                    Text(String(localized: "Group not found"))
                        .font(.barTabHeading)
                    Text(String(localized: "You may not be a member of this group."))
                        .font(.barTabBody)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(String(localized: "Close")) { dismiss() }
                        .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
