import SwiftUI

struct GroupPlanningView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var groups: [BarGroup] = []
    @State private var isLoading = true
    @State private var showingCreateGroup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                BarTabScreenHeader(
                    title: "Groups",
                    subtitle: "Plan where to go with friends."
                )

                Button {
                    showingCreateGroup = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Create Group")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .barTabPrimaryButton()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if groups.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.barTabPrimary)

                        Text("No groups yet")
                            .font(.headline)

                        Text("Create a group to plan nights out with friends.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()
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
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Groups")
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
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [.barTabPrimary, .barTabPrimary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabText)

                Text("Tap to open")
                    .font(.caption2)
                    .foregroundColor(.barTabSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.barTabSecondary)
        }
        .barTabCard()
    }

    private func loadGroups() async {
        do {
            groups = try await SupabaseClient.shared.fetchGroups()
        } catch {
            toastCenter.showError(error)
        }
        isLoading = false
    }
}
