import UIKit

/// Turns a photo into something small enough to live inside a Firestore document.
///
/// **The ceiling is enforced here, not hoped for.** A Firestore document is capped at
/// 1 MiB and a raw phone photo is 3–5 MB, so an un-downscaled image would not fail at
/// the picker — it would fail at the write, silently, leaving an organiser with a Fight
/// that saves locally and never appears for anybody else.
enum FightImage {

    /// Longest edge. The detail card draws 170pt tall full-width and the list card
    /// 110×85, so 600 is generous on a 3× screen and still tiny encoded.
    private static let maxDimension: CGFloat = 600

    /// Base64 inflates by about a third, so this is roughly a 150 KB JPEG — well inside
    /// the document limit even alongside every other field.
    private static let maxEncodedBytes = 200_000

    /// Encode, shrinking quality until it fits. `nil` if it cannot be made to.
    static func encode(_ image: UIImage) -> String? {
        let scaled = downscaled(image)
        // Steps rather than a solve: two or three attempts always land, and a binary
        // search over JPEG quality is more code than the problem deserves.
        for quality in [0.5, 0.35, 0.25, 0.15] as [CGFloat] {
            guard let data = scaled.jpegData(compressionQuality: quality) else { continue }
            let encoded = data.base64EncodedString()
            if encoded.utf8.count <= maxEncodedBytes { return encoded }
        }
        return nil
    }

    static func decode(_ base64: String?) -> UIImage? {
        guard let base64, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension Fight {
    /// The organiser's photo, or `nil` to fall back to the bundled artwork.
    var photo: UIImage? { FightImage.decode(imageData) }
}
