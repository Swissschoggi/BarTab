import SwiftUI
import CoreLocation
import UserNotifications
import UIKit

struct OnboardingView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var barRepository: BarRepository
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var selectedInterests: Set<Drink> = []

    private let pages = OnboardingPage.allCases

    private var nearestBar: Bar? {
        guard let location = locationService.location else { return nil }
        return barRepository.bars
            .filter { !barRepository.isBarAutoHidden($0) }
            .min { a, b in
                DistanceService.distance(from: location, to: a)
                    < DistanceService.distance(from: location, to: b)
            }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.BartapBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(page + 1), total: Double(pages.count))
                    .tint(.BartapPrimary)
                    .padding(.horizontal, BartapSpacing.lg)
                    .padding(.top, BartapSpacing.sm)

                Text(String(localized: "Step \(page + 1) of \(pages.count)"))
                    .font(.BartapCaption)
                    .foregroundColor(.BartapSecondary)
                    .padding(.top, BartapSpacing.xs)

                TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pages[index].view(
                        page: $page,
                        locationService: locationService,
                        selectedInterests: $selectedInterests,
                        nearestBar: nearestBar,
                        onDone: { dismiss() }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            if page < pages.count - 1 {
                skipButton
            }
        }
        .onDisappear {
            completeOnboarding()
        }
    }

    // MARK: - Skip

    private var skipButton: some View {
        Button {
            dismiss()
        } label: {
            Text(String(localized: "Skip"))
                .font(.BartapCaption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, BartapSpacing.md)
                .padding(.vertical, BartapSpacing.xs)
                .contentShape(Rectangle())
        }
        .padding(.top, BartapSpacing.xs)
        .padding(.trailing, BartapSpacing.md)
        .accessibilityLabel(Text(String(localized: "Skip onboarding")))
    }

    /// Runs whenever the sheet closes — via the Done button, Skip, or a
    /// swipe-down — so onboarding never nags on the next launch, and any
    /// drink picks the user made get saved.
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        guard !selectedInterests.isEmpty else { return }

        // Always save locally so Discover/Activity can personalize even
        // before the user signs in.
        userSession.setDrinkInterests(selectedInterests)

        guard let user = userSession.currentUser else { return }

        Task {
            do {
                try await SupabaseClient.shared.updateProfileInterests(
                    userID: user.id,
                    interests: Array(selectedInterests)
                )
                await userSession.refreshDrinkInterests(userID: user.id)
            } catch {
                toastCenter.showError(error)
            }
        }
    }
}

// MARK: - Pages

private enum OnboardingPage: CaseIterable {
    case welcome
    case location
    case notifications
    case interests
    case done

    var title: String {
        switch self {
        case .welcome: return String(localized: "Welcome to Bartap")
        case .location: return String(localized: "Find bars near you")
        case .notifications: return String(localized: "Never miss a deal")
        case .interests: return String(localized: "What do you drink?")
        case .done: return String(localized: "You're all set!")
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return String(localized: "Your pocket guide to drink prices, crawls & friends.")
        case .location: return String(localized: "We'll show nearby bars, walking crawls & distance.")
        case .notifications: return String(localized: "Get push alerts when prices drop at your favorite bars.")
        case .interests: return String(localized: "Tap your favorites so we can personalize your feed.")
        case .done: return String(localized: "Start exploring, add prices, and plan nights out.")
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "mug.fill"
        case .location: return "location.fill"
        case .notifications: return "bell.fill"
        case .interests: return "tag.fill"
        case .done: return "checkmark.circle.fill"
        }
    }

    @ViewBuilder
    func view(
        page: Binding<Int>,
        locationService: LocationService,
        selectedInterests: Binding<Set<Drink>>,
        nearestBar: Bar?,
        onDone: @escaping () -> Void
    ) -> some View {
        switch self {
        case .welcome:
            StandardOnboardingPage(
                icon: icon,
                tint: .BartapPrimary,
                title: title,
                subtitle: subtitle
            ) {
                OnboardingPrimaryButton(title: String(localized: "Get Started")) {
                    withAnimation { page.wrappedValue += 1 }
                }
            }

        case .location:
            StandardOnboardingPage(
                icon: icon,
                tint: .BartapPrimary,
                title: title,
                subtitle: subtitle
            ) {
                VStack(spacing: BartapSpacing.sm) {
                    let isAuthorized =
                        locationService.authorizationStatus == .authorizedWhenInUse ||
                        locationService.authorizationStatus == .authorizedAlways

                    OnboardingPrimaryButton(
                        title: isAuthorized
                            ? String(localized: "Location enabled ✓")
                            : String(localized: "Allow location access")
                    ) {
                        locationService.requestPermission()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation { page.wrappedValue += 1 }
                        }
                    }
                    .disabled(isAuthorized)

                    OnboardingSecondaryButton(title: String(localized: "Skip for now")) {
                        withAnimation { page.wrappedValue += 1 }
                    }
                }
            }
            .onAppear {
                locationService.requestPermission()
            }

        case .notifications:
            StandardOnboardingPage(
                icon: icon,
                tint: .BartapPrimary,
                title: title,
                subtitle: subtitle
            ) {
                VStack(spacing: BartapSpacing.sm) {
                    OnboardingPrimaryButton(title: String(localized: "Enable notifications")) {
                        UNUserNotificationCenter.current().requestAuthorization(
                            options: [.alert, .sound, .badge]
                        ) { _, _ in
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                                withAnimation { page.wrappedValue += 1 }
                            }
                        }
                    }

                    OnboardingSecondaryButton(title: String(localized: "Not now")) {
                        withAnimation { page.wrappedValue += 1 }
                    }
                }
            }
            .onAppear {
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                ) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            }

        case .interests:
            InterestsPage(
                icon: icon,
                title: title,
                subtitle: subtitle,
                page: page,
                selectedInterests: selectedInterests
            )

        case .done:
            StandardOnboardingPage(
                icon: icon,
                tint: .BartapAccent,
                title: title,
                subtitle: subtitle
            ) {
                VStack(spacing: BartapSpacing.sm) {
                    if let bar = nearestBar {
                        VStack(alignment: .leading, spacing: BartapSpacing.xs) {
                            Text(String(localized: "Nearest bar to you"))
                                .font(.BartapCaption)
                                .foregroundColor(.BartapSecondary)
                            Text(bar.name)
                                .font(.BartapBodySemibold)
                                .foregroundColor(.BartapText)
                            Text(bar.address)
                                .font(.BartapSmall)
                                .foregroundColor(.BartapSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(BartapSpacing.md)
                        .BartapCard()
                    }

                    OnboardingPrimaryButton(
                        title: nearestBar != nil
                            ? String(localized: "Add your first price")
                            : String(localized: "Start exploring")
                    ) {
                        if let bar = nearestBar {
                            UserDefaults.standard.set(
                                bar.id.uuidString,
                                forKey: "pendingFirstPriceBarID"
                            )
                        }
                        onDone()
                    }

                    if nearestBar != nil {
                        OnboardingSecondaryButton(title: String(localized: "Skip for now")) {
                            onDone()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Page chrome

/// Shared icon / title / subtitle block so every page lines up the same.
private struct OnboardingPageHeader: View {

    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: BartapSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 108, height: 108)
                .background(Color.BartapSurface)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(tint.opacity(0.20), lineWidth: 1)
                )

            VStack(spacing: BartapSpacing.sm) {
                Text(title)
                    .font(.BartapTitle)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.BartapBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.horizontal, BartapSpacing.lg)
    }
}

/// Vertically centered layout for pages whose only content is a footer
/// (welcome, permissions, done).
private struct StandardOnboardingPage<Footer: View>: View {

    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    private let footer: Footer

    init(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder footer: () -> Footer
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: BartapSpacing.xl)

            OnboardingPageHeader(
                icon: icon,
                tint: tint,
                title: title,
                subtitle: subtitle
            )

            Spacer(minLength: BartapSpacing.xl)

            footer
                .padding(.horizontal, BartapSpacing.md)
                .padding(.bottom, BartapSpacing.xl + 12)
        }
    }
}

// MARK: - Buttons

private struct OnboardingPrimaryButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.BartapHeading)
                .frame(maxWidth: .infinity)
                .padding()
                .BartapPrimaryButton()
        }
    }
}

private struct OnboardingSecondaryButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.BartapHeading)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BartapSpacing.xs)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Interests page

private struct InterestsPage: View {

    let icon: String
    let title: String
    let subtitle: String

    @Binding var page: Int
    @Binding var selectedInterests: Set<Drink>

    private let allDrinks = Drink.allCases.filter { $0 != .other }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingPageHeader(
                icon: icon,
                tint: .BartapPrimary,
                title: title,
                subtitle: subtitle
            )
            .padding(.top, BartapSpacing.lg)

            // The grid is the only flexible element on this page, so it
            // always gets the full height between header and button.
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 100), spacing: BartapSpacing.sm)
                    ],
                    spacing: BartapSpacing.sm
                ) {
                    ForEach(allDrinks) { drink in
                        InterestChip(
                            drink: drink,
                            isSelected: selectedInterests.contains(drink)
                        ) {
                            if selectedInterests.contains(drink) {
                                selectedInterests.remove(drink)
                            } else {
                                selectedInterests.insert(drink)
                            }
                        }
                    }
                }
                .padding(.horizontal, BartapSpacing.md)
                .padding(.top, BartapSpacing.md)
                .padding(.bottom, BartapSpacing.sm)
            }

            OnboardingPrimaryButton(title: String(localized: "Continue")) {
                withAnimation { page += 1 }
            }
            .padding(.horizontal, BartapSpacing.md)
            .padding(.top, BartapSpacing.xs)
            .padding(.bottom, BartapSpacing.xl + 12)
        }
    }
}

private struct InterestChip: View {
    let drink: Drink
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: drink.icon)
                    .font(.title2)
                Text(drink.displayName)
                    .font(.BartapSmall)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BartapSpacing.md)
            .background(isSelected ? Color.BartapPrimary : Color.BartapSurface)
            .foregroundColor(isSelected ? .white : .BartapText)
            .clipShape(RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BartapRadius.control, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.BartapCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
