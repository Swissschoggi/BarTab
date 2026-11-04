import SwiftUI

struct GroupPlanningView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var groups: [BarGroup] = []
    @State private var isLoading = true
    @State private var showingCreateGroup = false
    @State private var refreshError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BartapScreenHeader(
                    title: String(localized: "Groups"),
                    subtitle: String(localized: "Plan where to go with friends.")
                )

                if let refreshError {
                    Text(refreshError)
                        .font(.BartapSmall)
                        .foregroundColor(.BartapDanger)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Button {
                    showingCreateGroup = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text(String(localized: "Create Group"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .BartapPrimaryButton()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if groups.isEmpty {
                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "person.3.fill")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)

                        Text(String(localized: "No groups yet"))
                            .font(.BartapHeading)

                        Text(String(localized: "Create a group to plan nights out with friends."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()
                } else {
                    ForEach(groups) { group in
                        NavigationLink {
                            GroupDetailView(group: group)
                                .environmentObject(barRepository)
                                .environmentObject(userSession)
                                .environmentObject(toastCenter)
                        } label: {
                            groupRow(group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Groups"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupSheet()
                .environmentObject(barRepository)
                .environmentObject(userSession)
                .environmentObject(toastCenter)
        }
        .onChange(of: showingCreateGroup) { showing in
            if !showing {
                Task { await loadGroups() }
            }
        }
        .refreshable {
            await loadGroups()
        }
        .task {
            await loadGroups()
        }
    }

    private func groupRow(_ group: BarGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.BartapHeading)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.BartapPrimary)
                .clipShape(RoundedRectangle(cornerRadius: BartapRadius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.BartapBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.BartapText)

                Text(String(localized: "Tap to open"))
                    .font(.BartapTiny)
                    .foregroundColor(.BartapSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.BartapTiny)
                .foregroundColor(.BartapSecondary)
        }
        .BartapCard()
    }

    private func loadGroups() async {
        do {
            groups = try await SupabaseClient.shared.fetchGroups()
            refreshError = nil
        } catch {
            toastCenter.showError(error)
            if !groups.isEmpty {
                refreshError = String(localized: "Couldn't refresh. Showing earlier groups.")
            }
        }
        isLoading = false
    }
}
