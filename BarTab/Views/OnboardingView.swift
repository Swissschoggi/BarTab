import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, message: String)] = [
        (
            "wineglass.fill",
            "Welcome to BarTab",
            "Discover drink prices at bars near you, crowdsourced by the community."
        ),
        (
            "mappin.circle.fill",
            "Find Nearby Bars",
            "See what drinks cost at bars around you. Compare prices and find the best deals."
        ),
        (
            "plus.circle.fill",
            "Contribute Prices",
            "Spotted a price? Add it to help others find great drink deals."
        ),
        (
            "person.3.fill",
            "Go Social",
            "Create groups, plan nights out, and see what your friends are drinking."
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
                                .fill(Color.barTabPrimary.opacity(0.12))
                                .frame(width: 120, height: 120)

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
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.barTabBodySemibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.barTabGradientStart, Color.barTabGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.barTabSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
    }
}
