import UIKit

/// Photos taken through the camera, on this device only.
///
/// **The filename is the link to the log, and that is the whole design.** A photo is
/// stored as `{habitId}_{localDate}.jpg` — exactly `HabitLog.remoteId`, the same natural
/// key Firestore uses as its document id. So a log finds its photo by deriving the name,
/// and nothing has to be stored to connect them:
///
/// - no new field on `HabitLog`, which is encoded straight into Firestore — a local file
///   path pushed to the server would describe a file no other device has;
/// - no change to any `Codable` shape, which in this codebase has meant a wiped account
///   three times now;
/// - once-per-day is already enforced on that key, so one log can only ever have one
///   photo, and re-logging overwrites rather than accumulating orphans.
///
/// Per-account, like `PersistenceStore`: two people on one phone would otherwise collide
/// on `{habitId}_{localDate}` and see each other's photos.
///
/// Deliberately **not** synced. Firestore documents cap at 1 MB, images belong in Cloud
/// Storage, and that is a decision with a billing plan attached. Keeping the bytes local
/// and the key derivable means uploading later is additive — the name is already right.
enum EvidenceStore {

    /// Longest edge. The source is the 480×270 analysis frame today, so this is
    /// headroom for a real still capture rather than an upscale.
    private static let maxDimension: CGFloat = 1024
    private static let quality: CGFloat = 0.7

    private static var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("evidence", isDirectory: true)
    }

    private static func folder(_ userId: String) -> URL {
        root.appendingPathComponent(userId, isDirectory: true)
    }

    static func url(forLogId id: String, userId: String) -> URL {
        folder(userId).appendingPathComponent("\(id).jpg")
    }

    // MARK: - Writing

    @discardableResult
    static func save(_ image: UIImage, forLogId id: String, userId: String) -> URL? {
        guard let data = downscaled(image).jpegData(compressionQuality: quality) else { return nil }
        let destination = url(forLogId: id, userId: userId)
        do {
            try FileManager.default.createDirectory(at: folder(userId), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            // A failed write must never interrupt logging — the points are the point.
            return nil
        }
    }

    static func delete(forLogId id: String, userId: String) {
        try? FileManager.default.removeItem(at: url(forLogId: id, userId: userId))
    }

    /// Everything for one account. Used by "reset local data" and account deletion,
    /// where leaving the photos behind would resurrect them under a fresh log.
    static func purge(userId: String) {
        try? FileManager.default.removeItem(at: folder(userId))
    }

    // MARK: - Reading

    static func image(forLogId id: String, userId: String) -> UIImage? {
        UIImage(contentsOfFile: url(forLogId: id, userId: userId).path)
    }

    struct Saved: Identifiable {
        let id: String       // the log's remoteId — habitId_localDate
        let url: URL
        let bytes: Int
    }

    /// Newest first. Reads the directory rather than the logs, so a photo whose log has
    /// gone still shows up — which is exactly what a debug browser should reveal.
    static func all(userId: String) -> [Saved] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder(userId), includingPropertiesForKeys: keys)) ?? []

        return files
            .filter { $0.pathExtension == "jpg" }
            .map { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return (url, values?.contentModificationDate ?? .distantPast, values?.fileSize ?? 0)
            }
            .sorted { $0.1 > $1.1 }
            .map { Saved(id: $0.0.deletingPathExtension().lastPathComponent, url: $0.0, bytes: $0.2) }
    }

    static func totalBytes(userId: String) -> Int {
        all(userId: userId).reduce(0) { $0 + $1.bytes }
    }

    // MARK: - Resizing

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
