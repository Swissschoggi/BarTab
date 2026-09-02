import SwiftUI

struct AdminBrandRequestsView: View {

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession

    @State private var pendingDeleteRequest: BrandRequest?
    @State private var showingDeleteConfirmation = false

    private var requests: [BrandRequest] {
        barRepository.brandRequests.sorted {
            $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        ScrollView {

            VStack(alignment: .leading, spacing: 20) {

                if requests.isEmpty {

                    VStack(spacing: BarTabSpacing.sm) {
                        Image(systemName: "tag.circle")
                            .font(.barTabEmptyIcon)
                            .foregroundColor(.barTabPrimary)

                        Text("No brand requests yet")
                            .font(.barTabHeading)

                        Text("Requests for new brands will show up here.")
                            .font(.barTabBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .barTabCard()

                } else {

                    HStack {
                        Label(
                            "\(barRepository.pendingBrandRequestCount) pending",
                            systemImage: "clock"
                        )
                        .font(.barTabBody)
                        .foregroundColor(.secondary)

                        Spacer()
                    }

                    VStack(spacing: 12) {
                        ForEach(requests) { request in
                            requestCard(request)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color.barTabBackground.ignoresSafeArea())
        .navigationTitle("Brand requests")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this request?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                guard let request = pendingDeleteRequest else { return }
                Task {
                    await barRepository.deleteBrandRequest(request)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the brand request permanently.")
        }
    }

    private func requestCard(_ request: BrandRequest) -> some View {
        VStack(alignment: .leading, spacing: BarTabSpacing.sm) {

            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.barTabBody)
                    .foregroundColor(.barTabPrimary)

                Text(request.name)
                    .font(.barTabHeading)

                Spacer()

                statusBadge(for: request.status)
            }

            Text(request.drink.displayName)
                .font(.barTabBody)
                .foregroundColor(.primary)

            HStack(spacing: 6) {
                Text("by \(request.requestedByName)")
                    .font(.barTabSmall)
                    .foregroundColor(.secondary)

                Text("\u{00B7}")
                    .font(.barTabSmall)
                    .foregroundColor(.secondary)

                Text(relativeDate(request.createdAt))
                    .font(.barTabSmall)
                    .foregroundColor(.secondary)

                Spacer()

                if request.status == .pending {

                    Button {
                        Task {
                            await barRepository.rejectBrandRequest(request)
                        }
                    } label: {
                        Text("Reject")
                            .font(.barTabSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabDanger)
                    }

                    Button {
                        Task {
                            await barRepository.approveBrandRequest(request)
                        }
                    } label: {
                        Text("Approve")
                            .font(.barTabSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabPrimary)
                    }
                } else {
                    Button {
                        pendingDeleteRequest = request
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.barTabSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabDanger)
                    }
                }
            }
        }
        .barTabCard()
    }

    private func statusBadge(for status: BrandRequestStatus) -> some View {

        let (label, color): (String, Color) = {
            switch status {
            case .pending:
                return ("Pending", .orange)
            case .approved:
                return ("Approved", .green)
            case .rejected:
                return ("Rejected", .gray)
            }
        }()

        return Text(label)
            .font(.barTabTiny)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AdminBrandRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdminBrandRequestsView()
                .environmentObject(BarRepository())
                .environmentObject(UserSession())
        }
    }
}
