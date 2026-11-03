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

                    VStack(spacing: BartapSpacing.sm) {
                        Image(systemName: "tag.circle")
                            .font(.BartapEmptyIcon)
                            .foregroundColor(.BartapPrimary)

                        Text(String(localized: "No brand requests yet"))
                            .font(.BartapHeading)

                        Text(String(localized: "Requests for new brands will show up here."))
                            .font(.BartapBody)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .BartapCard()

                } else {

                    HStack {
                        Label(
                            String(localized: "\(barRepository.pendingBrandRequestCount) pending"),
                            systemImage: "clock"
                        )
                        .font(.BartapBody)
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
        .background(Color.BartapBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "Brand requests"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "Delete this request?"), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: "Delete"), role: .destructive) {
                guard let request = pendingDeleteRequest else { return }
                Task {
                    await barRepository.deleteBrandRequest(request)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This removes the brand request permanently."))
        }
    }

    private func requestCard(_ request: BrandRequest) -> some View {
        VStack(alignment: .leading, spacing: BartapSpacing.sm) {

            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.BartapBody)
                    .foregroundColor(.BartapPrimary)

                Text(request.name)
                    .font(.BartapHeading)

                Spacer()

                statusBadge(for: request.status)
            }

            Text(request.drink.displayName)
                .font(.BartapBody)
                .foregroundColor(.primary)

            HStack(spacing: 6) {
                Text(String(localized: "by \(request.requestedByName)"))
                    .font(.BartapSmall)
                    .foregroundColor(.secondary)

                Text("\u{00B7}")
                    .font(.BartapSmall)
                    .foregroundColor(.secondary)

                Text(relativeDate(request.createdAt))
                    .font(.BartapSmall)
                    .foregroundColor(.secondary)

                Spacer()

                if request.status == .pending {

                    Button {
                        Task {
                            await barRepository.rejectBrandRequest(request)
                        }
                    } label: {
                        Text(String(localized: "Reject"))
                            .font(.BartapSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.BartapDanger)
                    }

                    Button {
                        Task {
                            await barRepository.approveBrandRequest(request)
                        }
                    } label: {
                        Text(String(localized: "Approve"))
                            .font(.BartapSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.BartapPrimary)
                    }
                } else {
                    Button {
                        pendingDeleteRequest = request
                        showingDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "Remove"), systemImage: "trash")
                            .font(.BartapSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.BartapDanger)
                    }
                }
            }
        }
        .BartapCard()
    }

    private func statusBadge(for status: BrandRequestStatus) -> some View {

        let (label, color): (String, Color) = {
            switch status {
            case .pending:
                return (String(localized: "Pending"), .orange)
            case .approved:
                return (String(localized: "Approved"), .green)
            case .rejected:
                return (String(localized: "Rejected"), .gray)
            }
        }()

        return Text(label)
            .font(.BartapTiny)
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
        NavigationStack {
            AdminBrandRequestsView()
                .environmentObject(BarRepository())
                .environmentObject(UserSession())
        }
    }
}
