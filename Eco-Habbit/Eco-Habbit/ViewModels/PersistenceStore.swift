import UIKit

/// The whole local database. One `Codable` blob on disk — no Core Data at this stage,
/// and small enough that a single atomic write per mutation is cheap.
nonisolated struct PersistedState: Codable {
    // Account
    var isLoggedIn = false
    var hasCompletedOnboarding = false
    var userName = ""
    var email = ""

    // Onboarding choices
    var motivations: Set<Motivation> = []
    var favouriteCategories: Set<ActivityCategory> = []

    // Permission toggles (UI state; the real prompts are asked separately)
    var locationEnabled = false
    var cameraEnabled = false
    var notificationsEnabled = true

    // Points
    var earthPoints = 0
    var rewardPoints = 0
    var lifetimeEarthPoints = 0

    // Logs
    var completions: [Completion] = []
    var evidence: [EvidencePhoto] = []
    var history: [HistoryEntry] = []
    var redeemed: [RedeemedVoucher] = []
    var joinedMissionIds: Set<String> = []

    // Streak & decay bookkeeping
    var streakDays = 0
    var longestStreak = 0
    var lastActiveDay: Date?
    var decayWeeksApplied = 0
}

/// Reads and writes `PersistedState` as JSON in the app's Documents directory.
/// `nonisolated` on purpose: pure file I/O with no shared mutable state, so it stays
/// callable from `AppState.init`'s default argument and from detached tasks even with
/// the project's MainActor-by-default isolation.
nonisolated enum PersistenceStore {
    private static let fileName = "ecohabit-state.json"

    private static var url: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: url) else { return PersistedState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PersistedState.self, from: data)) ?? PersistedState()
    }

    static func save(_ state: PersistedState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: url)
        PhotoStore.wipe()
    }
}

/// Evidence photos live as JPEGs on disk; `PersistedState.evidence` only holds the index.
/// Also `nonisolated` — thumbnails decode off the main actor.
nonisolated enum PhotoStore {
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Evidence", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for photo: EvidencePhoto) -> URL {
        directory.appendingPathComponent(photo.fileName)
    }

    @discardableResult
    static func save(_ image: UIImage, id: UUID) -> Bool {
        // Downscale before writing — a full-resolution capture is far more than a
        // grid thumbnail and a fullscreen viewer will ever need.
        let resized = image.resized(maxDimension: 1_400)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return false }
        let target = directory.appendingPathComponent("\(id.uuidString).jpg")
        return (try? data.write(to: target, options: .atomic)) != nil
    }

    static func load(_ photo: EvidencePhoto) -> UIImage? {
        UIImage(contentsOfFile: url(for: photo).path)
    }

    static func delete(_ photo: EvidencePhoto) {
        try? FileManager.default.removeItem(at: url(for: photo))
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: directory)
    }
}

extension UIImage {
    nonisolated func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
