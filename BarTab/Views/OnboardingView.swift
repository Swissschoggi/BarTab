import SwiftUI
import CoreLocation
import UserNotifications
import UIKit

struct OnboardingView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var selectedInterests: Set<Drink> = []

    private let pages = OnboardingPage.allCases

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.barTabBackground.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pages[index].view(
                        page: $page,
                        locationService: locationService,
                        selectedInterests: $selectedInterests,
                        onDone: { dismiss() }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

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
                .font(.barTabCaption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.vertical, BarTabSpacing.xs)
                .contentShape(Rectangle())
        }
        .padding(.top, BarTabSpacing.xs)
        .padding(.trailing, BarTabSpacing.md)
        .accessibilityLabel(Text(String(localized: "Skip onboarding")))
    }

    /// Runs whenever the sheet closes — via the Done button, Skip, or a
    /// swipe-down — so onboarding never nags on the next launch, and any
    /// drink picks the user made get saved.
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        guard let user = userSession.currentUser,
              !selectedInterests.isEmpty else { return }

        userSession.setDrinkInterests(selectedInterests)

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
        case .welcome: return String(localized: "Welcome to BarTab")
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
        onDone: @escaping () -> Void
    ) -> some View {
        switch self {
        case .welcome:
            StandardOnboardingPage(
                icon: icon,
                tint: .barTabPrimary,
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
                tint: .barTabPrimary,
                title: title,
                subtitle: subtitle
            ) {
                VStack(spacing: BarTabSpacing.sm) {
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

        case .notifications:
            StandardOnboardingPage(
                icon: icon,
                tint: .barTabPrimary,
                title: title,
                subtitle: subtitle
            ) {
                VStack(spacing: BarTabSpacing.sm) {
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
                tint: .barTabAccent,
                title: title,
                subtitle: subtitle
            ) {
                OnboardingPrimaryButton(title: String(localized: "Start exploring")) {
                    onDone()
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
        VStack(spacing: BarTabSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 108, height: 108)
                .background(Color.barTabSurface)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(tint.opacity(0.20), lineWidth: 1)
                )

            VStack(spacing: BarTabSpacing.sm) {
                Text(title)
                    .font(.barTabTitle)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.barTabBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .padding(.horizontal, BarTabSpacing.lg)
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
            Spacer(minLength: BarTabSpacing.xl)

            OnboardingPageHeader(
                icon: icon,
                tint: tint,
                title: title,
                subtitle: subtitle
            )

            Spacer(minLength: BarTabSpacing.xl)

            footer
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.bottom, BarTabSpacing.xl + 12)
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
                .font(.barTabHeading)
                .frame(maxWidth: .infinity)
                .padding()
                .barTabPrimaryButton()
        }
    }
}

private struct OnboardingSecondaryButton: View {

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.barTabHeading)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BarTabSpacing.xs)
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
                tint: .barTabPrimary,
                title: title,
                subtitle: subtitle
            )
            .padding(.top, BarTabSpacing.lg)

            // The grid is the only flexible element on this page, so it
            // always gets the full height between header and button.
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 100), spacing: BarTabSpacing.sm)
                    ],
                    spacing: BarTabSpacing.sm
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
                .padding(.horizontal, BarTabSpacing.md)
                .padding(.top, BarTabSpacing.md)
                .padding(.bottom, BarTabSpacing.sm)
            }

            OnboardingPrimaryButton(title: String(localized: "Continue")) {
                withAnimation { page += 1 }
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.top, BarTabSpacing.xs)
            .padding(.bottom, BarTabSpacing.xl + 12)
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
                    .font(.barTabSmall)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BarTabSpacing.md)
            .background(isSelected ? Color.barTabPrimary : Color.barTabSurface)
            .foregroundColor(isSelected ? .white : .barTabText)
            .clipShape(RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BarTabRadius.control, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.barTabCardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
