import FirebaseFirestore
import Foundation

/// Pushes and pulls `/users/{uid}`.
///
/// A protocol so the local-only build has something to *not* inject: `AppState` holds an
/// optional, and `nil` means "this device is offline-only". That is what keeps
/// `tools/run-checks.sh` compiling and running against the economy without Firebase.
protocol UserStateSyncing: Sendable {
    func fetch(userId: String) async throws -> UserDocument?
    func push(_ document: UserDocument, userId: String) async throws
    func deleteAccount(userId: String) async throws

    // Subcollections. These are separate from the user document because a document has
    // a hard 1 MB limit and a daily user's log array would eventually reach it — at
    // which point saving simply stops working, with no warning.
    func fetchLogs(userId: String) async throws -> [HabitLog]
    func pushLogs(_ logs: [HabitLog], userId: String) async throws
    func deleteLogs(ids: [String], userId: String) async throws

    func fetchBadges(userId: String) async throws -> [EarnedBadge]
    func pushBadges(_ badges: [EarnedBadge], userId: String) async throws

    /// Remove every log and badge, leaving the user document alone.
    func purgeSubcollections(userId: String) async throws

    // MARK: - Fights
    //
    // The only genuinely SHARED data in the app. Everything above is one account's own
    // record; a Fight is written by its host and read by everybody, which is what makes
    // "an organiser publishes an event and other people turn up" work at all. Until
    // this existed, a hosted Fight lived on exactly one phone.

    /// Publish or update a Fight the signed-in user hosts.
    func putFight(_ fight: Fight) async throws

    /// Every published Fight. Drafts are excluded by the rules, not by the query — a
    /// half-written event must not be listable even if the client asks for it.
    func fetchPublishedFights() async throws -> [Fight]

    /// Record attendance at `/attendance/{fightId}_{userId}`.
    func checkIn(_ attendance: FightAttendance) async throws

    /// Everyone who checked in to one Fight. **Host-only in practice** — the rules let
    /// a caller read an attendance record if they own it or host the Fight, so this
    /// query only returns anything to the organiser.
    func fetchAttendance(fightId: String) async throws -> [FightAttendance]
}


/// Firestore implementation.
///
/// **The local file stays the working copy.** Every mutation writes to disk
/// synchronously as it always has, and the push here is a background echo. That keeps
/// the app exactly as responsive as it was, keeps it working with no network, and means
/// a Firestore outage degrades sync rather than breaking logging.
///
/// The trade is last-write-wins across devices. With `merge: true` that is per-field
/// rather than per-document, and for one person with one phone it is invisible. Two
/// devices editing at once would need real conflict resolution, which is not worth
/// building for a v1 with no multi-device story.
struct FirebaseUserStateSync: UserStateSyncing {

    private var db: Firestore { Firestore.firestore() }

    private func document(_ userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    func fetch(userId: String) async throws -> UserDocument? {
        let snapshot = try await document(userId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UserDocument.self)
    }

    func push(_ userDocument: UserDocument, userId: String) async throws {
        // merge: true, always. A whole-document replace loses whichever device wrote
        // last, and it is also what lets a field be added later without a migration.
        try document(userId).setData(from: userDocument, merge: true)
    }

    // MARK: - Logs

    private func logs(_ userId: String) -> CollectionReference {
        document(userId).collection("logs")
    }

    func fetchLogs(userId: String) async throws -> [HabitLog] {
        try await logs(userId).getDocuments().documents.compactMap {
            try? $0.data(as: HabitLog.self)
        }
    }

    func pushLogs(_ newLogs: [HabitLog], userId: String) async throws {
        guard !newLogs.isEmpty else { return }
        let batch = db.batch()
        for log in newLogs {
            // setData, not addDocument: the id IS the dedup.
            try batch.setData(from: log, forDocument: logs(userId).document(log.remoteId))
        }
        try await batch.commit()
    }

    func deleteLogs(ids: [String], userId: String) async throws {
        guard !ids.isEmpty else { return }
        let batch = db.batch()
        ids.forEach { batch.deleteDocument(logs(userId).document($0)) }
        try await batch.commit()
    }

    // MARK: - Badges

    private func badges(_ userId: String) -> CollectionReference {
        document(userId).collection("badges")
    }

    func fetchBadges(userId: String) async throws -> [EarnedBadge] {
        try await badges(userId).getDocuments().documents.compactMap {
            try? $0.data(as: EarnedBadge.self)
        }
    }

    func pushBadges(_ newBadges: [EarnedBadge], userId: String) async throws {
        guard !newBadges.isEmpty else { return }
        let batch = db.batch()
        for badge in newBadges {
            // Document id is the badgeId, so re-awarding is a no-op rather than a
            // second record — and `earnedAt` can never be moved.
            try batch.setData(from: badge, forDocument: badges(userId).document(badge.badgeId))
        }
        try await batch.commit()
    }

    /// **Subcollections are not free.** Deleting a document in Firestore does *not*
    /// delete what hangs off it — logs and badges would become orphans that no query
    /// reaches but that still exist and still bill. There is no recursive delete in the
    /// client SDK, so this walks them.
    func purgeSubcollections(userId: String) async throws {
        for collection in ["logs", "badges"] {
            let snapshot = try await document(userId).collection(collection).getDocuments()
            // 500 writes per batch is the Firestore limit; chunk rather than assume.
            for chunk in snapshot.documents.chunked(into: 400) {
                let batch = db.batch()
                chunk.forEach { batch.deleteDocument($0.reference) }
                try await batch.commit()
            }
        }
    }

    // MARK: - Fights

    func putFight(_ fight: Fight) async throws {
        // merge: true so editing a published Fight does not blank fields a future
        // version of the app might add.
        try db.collection("fights").document(fight.id).setData(from: fight, merge: true)
    }

    func fetchPublishedFights() async throws -> [Fight] {
        try await db.collection("fights")
            .whereField("status", isEqualTo: Fight.Status.published.rawValue)
            .getDocuments()
            .documents
            // `compactMap` rather than a throwing map: one malformed Fight written by a
            // future version of the app must not empty the whole list.
            .compactMap { try? $0.data(as: Fight.self) }
    }

    func checkIn(_ attendance: FightAttendance) async throws {
        // The composite id is what makes one-check-in-per-person structural: `create`
        // fails when the document exists, so a second scan cannot pay twice. No lock,
        // no transaction, no race.
        let id = "\(attendance.fightId)_\(attendance.userId)"
        try db.collection("attendance").document(id).setData(from: attendance)
    }

    func fetchAttendance(fightId: String) async throws -> [FightAttendance] {
        try await db.collection("attendance")
            .whereField("fightId", isEqualTo: fightId)
            .getDocuments()
            .documents
            .compactMap { try? $0.data(as: FightAttendance.self) }
    }

    /// Deletes the user's data, then the account itself.
    ///
    /// Order matters: the subcollections go first, while the token still exists. Once
    /// the auth user is gone the rules refuse every remaining delete, and the data would
    /// be stranded with nobody able to reach it.
    ///
    /// App Review requires an in-app account deletion path for any app with sign-in.
    func deleteAccount(userId: String) async throws {
        try await purgeSubcollections(userId: userId)
        try await document(userId).delete()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
