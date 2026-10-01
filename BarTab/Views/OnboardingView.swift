import SwiftUI
import CoreLocation
import UserNotifications
import UIKit

struct OnboardingView: View {

    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var page = 0
    @State private var selectedInterests: Set<Drink> = []

    private let pages = OnboardingPage.allCases

    var body: some View {
        ZStack {
            Color.barTabBackground.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pages[index].view(
                        page: $page,
                        locationService: locationService,
                        selectedInterests: $selectedInterests,
                        toastCenter: toastCenter,
                        userSession: userSession
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

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
        toastCenter: ToastCenter,
        userSession: UserSession
    ) -> some View {
        switch self {
        case .welcome:
            WelcomePage(page: page)
        case .location:
            LocationPermissionPage(page: page, locationService: locationService)
        case .notifications:
            NotificationPermissionPage(page: page)
        case .interests:
            InterestsPage(page: page, selectedInterests: selectedInterests)
        case .done:
            DonePage(page: page, selectedInterests: selectedInterests, userSession: userSession, toastCenter: toastCenter)
        }
    }
}

private struct WelcomePage: View {
    @Binding var page: Int

    var body: some View {
        VStack(spacing: BarTabSpacing.xl) {
            Spacer()

            Image(systemName: "mug.fill")
                .font(.system(size: 80))
                .foregroundColor(.barTabPrimary)

            Text(String(localized: "Welcome to BarTab"))
                .font(.barTabTitle)
                .multilineTextAlignment(.center)

            Text(String(localized: "Your pocket guide to drink prices, crawls & friends."))
                .font(.barTabBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BarTabSpacing.xl)

            Spacer()

            Button {
                withAnimation { page += 1 }
            } label: {
                Text(String(localized: "Get Started"))
                    .font(.barTabHeading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .barTabPrimaryButton()
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.bottom, BarTabSpacing.xl)
        }
    }
}

private struct LocationPermissionPage: View {
    @Binding var page: Int
    @ObservedObject var locationService: LocationService

    var body: some View {
        VStack(spacing: BarTabSpacing.xl) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 80))
                .foregroundColor(.barTabPrimary)

            Text(String(localized: "Find bars near you"))
                .font(.barTabTitle)
                .multilineTextAlignment(.center)

            Text(String(localized: "We'll show nearby bars, walking crawls & distance."))
                .font(.barTabBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BarTabSpacing.xl)

            Spacer()

            VStack(spacing: BarTabSpacing.sm) {
                Button {
                    locationService.requestPermission()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways
                        ? String(localized: "Location enabled ✓")
                        : String(localized: "Allow location access"))
                        .font(.barTabHeading)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .barTabPrimaryButton()
                }
                .disabled(locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways)

                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(String(localized: "Skip for now"))
                        .font(.barTabHeading)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.bottom, BarTabSpacing.xl)
        }
    }
}

private struct NotificationPermissionPage: View {
    @Binding var page: Int

    var body: some View {
        VStack(spacing: BarTabSpacing.xl) {
            Spacer()

            Image(systemName: "bell.fill")
                .font(.system(size: 80))
                .foregroundColor(.barTabPrimary)

            Text(String(localized: "Never miss a deal"))
                .font(.barTabTitle)
                .multilineTextAlignment(.center)

            Text(String(localized: "Get push alerts when prices drop at your favorite bars."))
                .font(.barTabBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BarTabSpacing.xl)

            Spacer()

            VStack(spacing: BarTabSpacing.sm) {
                Button {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                            withAnimation { page += 1 }
                        }
                    }
                } label: {
                    Text(String(localized: "Enable notifications"))
                        .font(.barTabHeading)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .barTabPrimaryButton()
                }

                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(String(localized: "Not now"))
                        .font(.barTabHeading)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.bottom, BarTabSpacing.xl)
        }
    }
}

private struct InterestsPage: View {
    @Binding var page: Int
    @Binding var selectedInterests: Set<Drink>

    private let allDrinks = Drink.allCases.filter { $0 != .other }

    var body: some View {
        VStack(spacing: BarTabSpacing.lg) {
            Spacer(minLength: BarTabSpacing.xl)

            Image(systemName: "tag.fill")
                .font(.system(size: 80))
                .foregroundColor(.barTabPrimary)

            Text(String(localized: "What do you drink?"))
                .font(.barTabTitle)
                .multilineTextAlignment(.center)

            Text(String(localized: "Tap your favorites so we can personalize your feed."))
                .font(.barTabBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BarTabSpacing.xl)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: BarTabSpacing.sm)], spacing: BarTabSpacing.sm) {
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
            }

            Spacer()

            Button {
                withAnimation { page += 1 }
            } label: {
                Text(String(localized: "Continue"))
                    .font(.barTabHeading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .barTabPrimaryButton()
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.bottom, BarTabSpacing.xl)
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
    }
}

private struct DonePage: View {
    @Binding var page: Int
    @Binding var selectedInterests: Set<Drink>
    @ObservedObject var userSession: UserSession
    @ObservedObject var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: BarTabSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.barTabAccent)

            Text(String(localized: "You're all set!"))
                .font(.barTabTitle)
                .multilineTextAlignment(.center)

            Text(String(localized: "Start exploring, add prices, and plan nights out."))
                .font(.barTabBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BarTabSpacing.xl)

            Spacer()

            Button {
                if let user = userSession.currentUser, !selectedInterests.isEmpty {
                    Task {
                        do {
                            try await SupabaseClient.shared.updateProfileInterests(
                                userID: user.id,
                                interests: Array(selectedInterests)
                            )
                        } catch {
                            toastCenter.showError(error)
                        }
                    }
                }
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                dismiss()
            } label: {
                Text(String(localized: "Start exploring"))
                    .font(.barTabHeading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .barTabPrimaryButton()
            }
            .padding(.horizontal, BarTabSpacing.md)
            .padding(.bottom, BarTabSpacing.xl)
        }
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}