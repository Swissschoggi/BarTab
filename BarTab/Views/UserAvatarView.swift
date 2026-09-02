import SwiftUI

struct UserAvatarView: View {
    let urlString: String?
    let displayName: String?
    var size: CGFloat = 40

    private var initial: String {
        String((displayName ?? "U").prefix(1)).uppercased()
    }

    var body: some View {
        if let urlString,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    fallback
                default:
                    ProgressView()
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Circle()
            .fill(Color.barTabPrimary.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(size >= 36 ? .headline : .caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.barTabPrimary)
            )
    }
}
