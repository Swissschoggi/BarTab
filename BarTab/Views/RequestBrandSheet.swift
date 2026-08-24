import SwiftUI

/// Lets a user request that a new brand be added to the catalog
/// for a given drink. Submitted requests are reviewed by an admin.
struct RequestBrandSheet: View {

    let drink: Drink

    @EnvironmentObject private var barRepository: BarRepository
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.presentationMode) private var presentationMode

    @State private var name = ""
    @State private var didSubmit = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var alreadyExists: Bool {
        barRepository.brands(for: drink).contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private var alreadyPending: Bool {
        guard let user = userSession.currentUser else { return false }
        return barRepository.hasPendingRequest(
            name: trimmedName,
            for: drink,
            by: user
        )
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {

                if didSubmit {

                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.barTabPrimary)

                        Text("Request sent")
                            .font(.headline)

                        Text(
                            "We'll review \"\(trimmedName)\" and "
                            + "add it if it's a good fit."
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)

                } else {

                    Text("Requesting a \(drink.displayName.lowercased()) brand")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Brand name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    if !trimmedName.isEmpty && alreadyExists {
                        Text("That brand is already in the list.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if !trimmedName.isEmpty && alreadyPending {
                        Text("You've already requested this brand.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Button {
                        submit()
                    } label: {
                        Text("Send request")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .barTabPrimaryButton()
                    }
                    .disabled(
                        trimmedName.isEmpty
                        || alreadyExists
                        || alreadyPending
                    )
                }
            }
            .padding()
            .background(
                Color.barTabBackground.ignoresSafeArea()
            )
            .navigationTitle("Request a brand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func submit() {
        guard let user = userSession.currentUser else { return }

        Task {
            await barRepository.requestBrand(
                name: trimmedName,
                for: drink,
                by: user
            )

            withAnimation {
                didSubmit = true
            }
        }
    }
}
