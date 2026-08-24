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

                    VStack(spacing: 14) {
                        Image(systemName: "tag.circle")
                            .font(.system(size: 44))
                            .foregroundColor(.barTabPrimary)

                        Text("No brand requests yet")
                            .font(.headline)

                        Text("Requests for new brands will show up here.")
                            .font(.subheadline)
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
                        .font(.subheadline)
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
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.subheadline)
                    .foregroundColor(.barTabPrimary)

                Text(request.name)
                    .font(.headline)

                Spacer()

                statusBadge(for: request.status)
            }

            Text(request.drink.displayName)
                .font(.subheadline)
                .foregroundColor(.primary)

            HStack(spacing: 6) {
                Text("by \(request.requestedByName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\u{00B7}")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(relativeDate(request.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if request.status == .pending {

                    Button {
                        Task {
                            await barRepository.rejectBrandRequest(request)
                        }
                    } label: {
                        Text("Reject")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task {
                            await barRepository.approveBrandRequest(request)
                        }
                    } label: {
                        Text("Approve")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.barTabPrimary)
                    }
                } else {
                    Button {
                        pendingDeleteRequest = request
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
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
            .font(.caption2)
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
