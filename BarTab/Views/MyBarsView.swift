import SwiftUI

struct MyBarsView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @EnvironmentObject private var locationService: LocationService
    @State private var editingBar: Bar?

    private var myBars: [Bar] {
        guard let user = userSession.currentUser else {
            return []
        }

        return barRepository.getBars().filter {
            $0.createdBy == user.id
        }
    }

    var body: some View {
        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                if barRepository.bars.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if myBars.isEmpty {

                    emptyState

                } else {

                    HStack {

                        Text(
                            String(localized: "\(myBars.count) \(myBars.count == 1 ? "bar" : "bars")")
                        )
                        .font(.BartapBody)
                        .foregroundColor(.secondary)

                        Spacer()
                    }

                    VStack(spacing: 12) {

                        ForEach(myBars) { bar in

                            NavigationLink {
                                BarView(bar: bar)
                            } label: {
                                barCard(bar)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: false
                            ) {

                                if let user = userSession.currentUser {

                                    Button {
                                        editingBar = bar
                                    } label: {
                                        Label(
                                            String(localized: "Edit"),
                                            systemImage: "pencil"
                                        )
                                    }
                                    .tint(.BartapPrimary)

                                    Button(role: .destructive) {
                                        Task {
                                            await barRepository.deleteBar(
                                                bar,
                                                createdBy: user
                                            )
                                        }
                                    } label: {
                                        Label(
                                            String(localized: "Delete"),
                                            systemImage: "trash"
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(
            Color.BartapBackground
                .ignoresSafeArea()
        )
        .navigationTitle(String(localized: "My Bars"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingBar) { bar in
            EditBarView(bar: bar)
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        }
        .onAppear {
            locationService.requestPermission()
        }
    }

    private var emptyState: some View {

        VStack(spacing: BartapSpacing.sm) {

            ZStack {

                Circle()
                    .fill(
                        Color.BartapPrimary.opacity(0.12)
                    )
                    .frame(
                        width: 72,
                        height: 72
                    )

                Image(
                    systemName: "building.2.fill"
                )
                .font(.system(size: 28))
                .foregroundColor(
                    .BartapPrimary
                )
            }

            Text(String(localized: "No bars yet"))
                .font(.BartapHeading)
                .fontWeight(.semibold)

            Text(
                String(localized: "Bars you add will appear here.")
            )
            .font(.BartapBody)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func barCard(
        _ bar: Bar
    ) -> some View {

        let summaries =
            barRepository.getPriceSummaries(
                for: bar
            )

        let visibleSummaries =
            Array(summaries.prefix(3))

        return VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack(spacing: 12) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: BartapRadius.control,
                        style: .continuous
                    )
                    .fill(
                        Color.BartapPrimary.opacity(0.12)
                    )

                    Image(
                        systemName: "wineglass.fill"
                    )
                    .font(.BartapHeading)
                    .foregroundColor(
                        .BartapPrimary
                    )
                }
                .frame(
                    width: 48,
                    height: 48
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(bar.name)
                        .font(.BartapHeading)
                        .foregroundColor(.primary)

                    Text(bar.address)
                        .font(.BartapBody)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: BartapSpacing.sm) {

                        if let location = locationService.location {

                            Label(
                                DistanceService.formattedDistance(
                                    from: location,
                                    to: bar
                                ),
                                systemImage: "location.fill"
                            )
                        }

                        Label(
                            String(localized: "\(summaries.count) \(summaries.count == 1 ? "drink" : "drinks")"),
                            systemImage: "mug.fill"
                        )
                    }
                    .font(.BartapSmall)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Image(
                    systemName: "chevron.right"
                )
                .font(.BartapSmall)
                .foregroundColor(.secondary)
            }

            if !visibleSummaries.isEmpty {

                Divider()

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    ForEach(visibleSummaries) { summary in

                        HStack {

                            Text(
                                "\(summary.drink.displayName) · \(summary.size.displayName)"
                            )
                            .font(.BartapBody)
                            .foregroundColor(.secondary)

                            Spacer()

                            Text(
                                "\(summary.formattedConvertedAmount) \(Currency.defaultCurrency.rawValue)"
                            )
                            .font(.BartapBody)
                            .fontWeight(.semibold)
                            .foregroundColor(.BartapPrimary)
                        }
                    }

                    if summaries.count > visibleSummaries.count {

                        Text(
                            String(localized: "And \(summaries.count - visibleSummaries.count) more…")
                        )
                        .font(.BartapSmall)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .BartapCard()
    }
}

struct MyBarsView_Previews: PreviewProvider {

    static var previews: some View {

        NavigationStack {

            MyBarsView()
                .environmentObject(
                    BarRepository()
                )
                .environmentObject(
                    UserSession()
                )
        }
    }
}
