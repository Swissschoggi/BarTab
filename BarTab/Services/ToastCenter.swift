import SwiftUI

/// A lightweight toast message shown at the top of the screen —
/// a friendlier replacement for raw system alerts.
struct Toast: Identifiable, Equatable {

    enum Kind {
        case success
        case error
        case info

        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            case .info:
                return Color.barTabPrimary
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

@MainActor
final class ToastCenter: ObservableObject {

    @Published private(set) var currentToast: Toast?

    private var dismissTask: Task<Void, Never>?

    func show(
        _ message: String,
        kind: Toast.Kind = .info,
        duration: TimeInterval = 3
    ) {
        guard !message.isEmpty else { return }

        switch kind {
        case .success: HapticEngine.success()
        case .error:   HapticEngine.error()
        case .info:    HapticEngine.lightTap()
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = Toast(kind: kind, message: message)
        }

        scheduleDismiss(after: duration)
    }

    func showError(_ error: Error) {
        show(
            FriendlyError.message(for: error),
            kind: .error,
            duration: 4
        )
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
        }
    }

    private func scheduleDismiss(after duration: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(duration * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            self?.clear()
        }
    }
}

/// Maps low-level errors (URLSession, Supabase JSON bodies, GoTrue)
/// to short, human sentences.
enum FriendlyError {

    static func message(for error: Error) -> String {

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .dataNotAllowed:
                return "You seem to be offline. Check your connection and try again."
            case .timedOut:
                return "The connection timed out. Please try again."
            default:
                return "Something went wrong while talking to the server."
            }
        }

        if let supabaseError = error as? SupabaseClient.SupabaseError {
            return supabaseMessage(supabaseError)
        }

        if let authError = error as? SupabaseAuthService.AuthError {
            if let text = authError.errorDescription {
                return friendlyAuthMessage(text)
            }
            return "Sign in was cancelled."
        }

        if let localized = error as? LocalizedError,
           let text = localized.errorDescription,
           !text.isEmpty {
            return friendlyAuthMessage(text)
        }

        return "Something went wrong. Please try again."
    }

    private static func supabaseMessage(
        _ error: SupabaseClient.SupabaseError
    ) -> String {

        if let serverText = error.serverMessage {
            let lowered = serverText.lowercased()

            if lowered.contains("jwt") && lowered.contains("expired") {
                return "Your session expired. Please sign in again."
            }

            if lowered.contains("row-level security")
                || lowered.contains("duplicate key") {
                return "That entry already exists or isn't allowed."
            }

            if lowered.contains("invalid login credentials") {
                return "Wrong email or password."
            }

            if lowered.contains("already registered") {
                return "An account with this email already exists."
            }

            if lowered.contains("new row violates row-level security")
                || lowered.contains("permission denied")
                || lowered.contains("violates foreign key") {
                return "You don't have permission to do that."
            }

            return "The server rejected that request."
        }

        switch error.statusCode {
        case 401:
            return "Your session expired. Please sign in again."
        case 403:
            return "You don't have permission to do that."
        case 404:
            return "That entry could not be found."
        case 500...599:
            return "BarTab's server is having trouble right now. Please try again soon."
        default:
            return "Something went wrong. Please try again."
        }
    }

    private static func friendlyAuthMessage(
        _ text: String
    ) -> String {

        let lowered = text.lowercased()

        if lowered.contains("invalid login credentials") {
            return "Wrong email or password."
        }

        if lowered.contains("email not confirmed") {
            return "Please confirm your email first — check your inbox."
        }

        if lowered.contains("rate limit") {
            return "Too many attempts. Please wait a moment and try again."
        }

        if lowered.contains("password should be at least") {
            return "That password is too short."
        }

        if lowered.contains("signup requires") || lowered.contains("unable to exchange external") {
            return "Sign-in failed. Please try again."
        }

        return "Something went wrong. Please try again."
    }
}

// MARK: - View integration

private struct ToastOverlay: View {

    @EnvironmentObject private var toastCenter: ToastCenter
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.kind.icon)
                .foregroundColor(toast.kind.tint)

            Text(toast.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.barTabText)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.barTabCardFill)
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 18,
                    x: 0,
                    y: 8
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.barTabCardBorder.opacity(0.7), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }
}

struct BarTabToastModifier: ViewModifier {

    @EnvironmentObject private var toastCenter: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = toastCenter.currentToast {
                ToastOverlay(toast: toast)
                    .padding(.top, 8)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                    )
                    .onTapGesture {
                        toastCenter.clear()
                    }
                    .zIndex(999)
            }
        }
    }
}

extension View {

    /// Attach once near the root of a scene; toasts appear at the top.
    func barTabToast() -> some View {
        modifier(BarTabToastModifier())
    }
}
