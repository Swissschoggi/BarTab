import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationService: LocationService

    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, message: String)] = [
        (
            "wineglass.fill",
            String(localized: "Welcome to BarTab"),
            String(localized: "Discover drink prices at bars near you, crowdsourced by the community.")
        ),
        (
            "mappin.circle.fill",
            String(localized: "Find Nearby Bars"),
            String(localized: "See what drinks cost at bars around you. Compare prices and find the best deals.")
        ),
        (
            "plus.circle.fill",
            String(localized: "Contribute Prices"),
            String(localized: "Spotted a price? Add it to help others find great drink deals.")
        ),
        (
            "person.3.fill",
            String(localized: "Go Social"),
            String(localized: "Create groups, plan nights out, and see what your friends are drinking.")
        )
    ]

    var body: some View {
        VStack(spacing: 0) {

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 20) {

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.barTabPrimary.opacity(0.1))
                                .frame(width: 128, height: 128)

                            Circle()
                                .stroke(Color.barTabPrimary.opacity(0.18), lineWidth: 1)
                                .frame(width: 128, height: 128)

                            Image(systemName: page.icon)
                                .font(.barTabEmptyIconLarge)
                                .foregroundColor(.barTabPrimary)
                        }

                        Text(page.title)
                            .font(.barTabTitle)
                            .foregroundColor(.barTabText)

                        Text(page.message)
                            .font(.barTabBody)
                            .foregroundColor(.barTabSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { page in
                if page == 1 {
                    locationService.requestPermission()
                }
            }

            VStack(spacing: 16) {

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.barTabPrimary : Color.barTabPrimary.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        locationService.requestPermission()
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? String(localized: "Continue") : String(localized: "Get Started"))
                        .barTabPrimaryButton()
                }

                if currentPage < pages.count - 1 {
                    Button(String(localized: "Skip")) {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    }
                    .font(.barTabBody)
                    .foregroundColor(.barTabSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
    }
}
