import Foundation
import UIKit

/// Prepares avatar images for upload: downscaled to a small square
/// and re-encoded as JPEG so each picture stays in the ~20–50 KB
/// range (friendly to the free Supabase Storage tier).
enum AvatarService {

    enum AvatarError: LocalizedError {
        case processingFailed

        var errorDescription: String? {
            switch self {
            case .processingFailed:
                return "The image could not be processed. Please try another photo."
            }
        }
    }

    private static let maxDimension: CGFloat = 256
    private static let compressionQuality: CGFloat = 0.7

    /// Downscales the image to a square JPEG, or nil if it can't be
    /// processed.
    static func processedJPEGData(
        from image: UIImage
    ) -> Data? {

        let resized = resizedImage(from: image)
        return resized.jpegData(
            compressionQuality: compressionQuality
        )
    }

    private static func resizedImage(
        from image: UIImage
    ) -> UIImage {

        let size = image.size

        guard size.width > maxDimension
                || size.height > maxDimension else {
            return normalizedOrientation(image)
        }

        let scale = min(
            maxDimension / size.width,
            maxDimension / size.height
        )

        let newSize = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(
            size: newSize,
            format: format
        ).image { _ in
            normalizedOrientation(image)
                .draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func normalizedOrientation(
        _ image: UIImage
    ) -> UIImage {

        guard image.imageOrientation != .up else {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        return UIGraphicsImageRenderer(
            size: image.size,
            format: format
        ).image { _ in
            image.draw(in: CGRect(
                origin: .zero,
                size: image.size
            ))
        }
    }
}
